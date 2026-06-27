// STT1 - Trần Thị Cẩm Tú
// Gauge chart xác suất, ensemble verdict, risk badge, so sánh 3 mô hình
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/health_service.dart';
import '../theme/app_theme.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});
  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  UserModel?         _user;
  BiometricSnapshot? _bio;
  PredictionResult?  _result;
  bool _loadingInit = true;
  bool _predicting  = false;
  String _predictStep = ''; // mô tả bước đang làm khi predicting

  @override
  void initState() {
    super.initState();
    _init();
  }

  // Chỉ load user + bio lần đầu để hiển thị preview
  Future<void> _init() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && mounted) setState(() => _user = UserModel.fromJson(doc.data()!));
      }
    } catch (e) {
      debugPrint('_init Firestore error: $e');
    }

    try {
      final granted = await HealthService.requestPermissions()
          .timeout(const Duration(seconds: 10), onTimeout: () => false);
      final bio = granted
          ? await HealthService.fetchLatestData()
              .timeout(const Duration(seconds: 15), onTimeout: () => BiometricSnapshot.defaultValues())
          : BiometricSnapshot.defaultValues();
      if (mounted) setState(() => _bio = bio);
    } catch (e) {
      debugPrint('_init Health error: $e');
      if (mounted) setState(() => _bio = BiometricSnapshot.defaultValues());
    }

    if (mounted) setState(() => _loadingInit = false);
  }

  Future<void> _predict() async {
    setState(() { _predicting = true; _predictStep = 'Đang đồng bộ hồ sơ...'; });

    // ── Bước 1: Reload user từ Firestore để lấy thay đổi mới nhất ──
    UserModel? freshUser;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) freshUser = UserModel.fromJson(doc.data()!);
      }
    } catch (e) {
      debugPrint('_predict reload user error: $e');
    }
    freshUser ??= _user; // fallback user cũ nếu lỗi

    if (freshUser == null) {
      if (mounted) {
        setState(() { _predicting = false; _predictStep = ''; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Vui lòng cập nhật hồ sơ trong tab Hồ Sơ trước!'),
            backgroundColor: SGColor.riskMid));
      }
      return;
    }

    // ── Bước 2: Fetch bio mới nhất từ Health Connect ──────────────
    if (mounted) setState(() => _predictStep = 'Đang lấy dữ liệu sức khoẻ...');
    BiometricSnapshot freshBio;
    try {
      final granted = await HealthService.requestPermissions()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      freshBio = granted
          ? await HealthService.fetchLatestData()
              .timeout(const Duration(seconds: 15), onTimeout: () => _bio ?? BiometricSnapshot.defaultValues())
          : (_bio ?? BiometricSnapshot.defaultValues());
    } catch (e) {
      debugPrint('_predict fetch bio error: $e');
      freshBio = _bio ?? BiometricSnapshot.defaultValues();
    }

    // Cập nhật bio hiển thị trên màn hình
    if (mounted) {
      setState(() {
        _user = freshUser;
        _bio  = freshBio;
        _predictStep = 'Đang phân tích AI...';
      });
    }

    // ── Bước 3: Gửi lên API ───────────────────────────────────────
    try {
      final r = await ApiService.predict(user: freshUser!, bio: freshBio);
      if (mounted) {
        setState(() { _result = r; _predicting = false; _predictStep = ''; });
        _saveFirestore(r);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _predicting = false; _predictStep = ''; });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi kết nối backend: $e'), backgroundColor: SGColor.riskHigh));
      }
    }
  }

  Future<void> _saveFirestore(PredictionResult r) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('predictions')
        .add(r.toFirestore());
  }

  Color _probColor(double p) =>
      p < 0.35 ? SGColor.riskLow : p < 0.65 ? SGColor.riskMid : SGColor.riskHigh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SGColor.bg,
      appBar: AppBar(title: const Text('Phân tích nguy cơ đột quỵ')),
      body: _loadingInit
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(children: [

                // ── Bio snapshot đang dùng để phân tích ─────────────
                if (_bio != null)
                  SGCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.sensors_rounded, size: 18, color: SGColor.primary),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Dữ liệu sức khoẻ dùng để phân tích', style: SGText.h3)),
                        if (_bio!.isSimulated)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange.shade300)),
                            child: const Text('Mô phỏng',
                                style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                          ),
                      ]),
                      const SizedBox(height: 12),
                      Wrap(spacing: 10, runSpacing: 8, children: [
                        _bioChip(Icons.favorite_rounded,         '${_bio!.heartRate.toStringAsFixed(0)} bpm',  Colors.redAccent),
                        _bioChip(Icons.air_rounded,               '${_bio!.spo2.toStringAsFixed(1)}% SpO₂',    Colors.blue),
                        _bioChip(Icons.bedtime_rounded,           '${_bio!.sleepHours.toStringAsFixed(1)}h ngủ', Colors.indigo),
                        _bioChip(Icons.psychology_rounded,        '${_bio!.stressScore.toStringAsFixed(0)}/100 stress', Colors.orange),
                        _bioChip(Icons.directions_walk_rounded,   '${_bio!.steps} bước',                       Colors.green),
                        _bioChip(Icons.monitor_weight_outlined,   'BMI ${_bio!.bmi.toStringAsFixed(1)}',        SGColor.primary),
                      ]),
                      if (_bio!.fetchedAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Cập nhật lúc ${_bio!.fetchedAt!.hour.toString().padLeft(2,'0')}:${_bio!.fetchedAt!.minute.toString().padLeft(2,'0')}',
                          style: SGText.caption,
                        ),
                      ],
                    ]),
                  ),

                // ── Gauge + Verdict ───────────────────────────────
                SGCard(
                  child: Column(children: [
                    const Text('Xác suất nguy cơ (Ensemble)', style: SGText.h2),
                    const SizedBox(height: 16),
                    if (_result == null)
                      Column(children: [
                        Icon(Icons.analytics_outlined, size: 72, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        const Text('Nhấn "Phân tích" để bắt đầu', style: SGText.body),
                        const SizedBox(height: 8),
                      ])
                    else ...[
                      SizedBox(
                        height: 160,
                        child: CustomPaint(
                          painter: _GaugePainter(
                              probability: _result!.ensemble,
                              color: _probColor(_result!.ensemble)),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${(_result!.ensemble * 100).toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold,
                              color: _probColor(_result!.ensemble))),
                      const SizedBox(height: 10),
                      RiskBadge(riskLevel: _result!.riskLevel),
                    ],
                  ]),
                ),

                // ── 3 Models bar progress ─────────────────────────
                if (_result != null) ...[
                  SGCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('So sánh 3 mô hình ML', style: SGText.h3),
                      const SizedBox(height: 16),
                      _modelBar('Logistic Regression', _result!.logisticRegression, Colors.blue),
                      _modelBar('Decision Tree',       _result!.decisionTree,       Colors.orange),
                      _modelBar('Random Forest',       _result!.randomForest,       Colors.green),
                    ]),
                  ),

                  // ── Bar Chart ─────────────────────────────────────
                  SGCard(
                    child: SizedBox(
                      height: 200,
                      child: BarChart(BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 1.0,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (g, gi, rod, _) => BarTooltipItem(
                                '${(rod.toY * 100).toStringAsFixed(1)}%',
                                const TextStyle(color: Colors.white)),
                          ),
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                              getTitlesWidget: (v, _) {
                                const l = ['LR', 'DT', 'RF', 'Ens.'];
                                return Padding(padding: const EdgeInsets.only(top: 4),
                                    child: Text(l[v.toInt()], style: SGText.caption));
                              })),
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (v, _) =>
                                  Text('${(v*100).toInt()}%', style: SGText.caption))),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          _bar(0, _result!.logisticRegression, Colors.blue),
                          _bar(1, _result!.decisionTree,       Colors.orange),
                          _bar(2, _result!.randomForest,       Colors.green),
                          _bar(3, _result!.ensemble,           SGColor.primary),
                        ],
                      )),
                    ),
                  ),

                  // ── Recommendation ────────────────────────────────
                  SGCard(
                    color: _probColor(_result!.ensemble).withOpacity(0.07),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.info_rounded, color: _probColor(_result!.ensemble), size: 24),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_result!.recommendation,
                          style: const TextStyle(fontSize: 14, height: 1.5))),
                    ]),
                  ),

                  // ── Risk Factors ──────────────────────────────────
                  if (_result!.topRiskFactors.isNotEmpty)
                    SGCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Yếu tố nguy cơ phát hiện', style: SGText.h3),
                        const SizedBox(height: 12),
                        ..._result!.topRiskFactors.map((f) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            Icon(f.impact == 'cao' ? Icons.warning_rounded : Icons.info_rounded,
                                color: f.impact == 'cao' ? SGColor.riskHigh : SGColor.riskMid, size: 18),
                            const SizedBox(width: 10),
                            Expanded(child: Text(f.factor, style: SGText.body)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (f.impact == 'cao' ? SGColor.riskHigh : SGColor.riskMid).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(f.value, style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12,
                                  color: f.impact == 'cao' ? SGColor.riskHigh : SGColor.riskMid)),
                            ),
                          ]),
                        )),
                      ]),
                    ),

                  if (_result!.simulationMode)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('⚠️ Chế độ mô phỏng — đặt file .pkl vào backend/models/ để dùng mô hình thật',
                          style: TextStyle(color: Colors.orange, fontSize: 12), textAlign: TextAlign.center),
                    ),
                ],

                // ── Predict Button ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _predicting ? null : _predict,
                      icon: _predicting
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.analytics_rounded),
                      label: Text(
                        _predicting
                            ? (_predictStep.isNotEmpty ? _predictStep : 'Đang phân tích...')
                            : 'Phân tích nguy cơ đột quỵ',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Kết quả chỉ mang tính hỗ trợ, không thay thế chẩn đoán y tế.',
                      style: SGText.caption, textAlign: TextAlign.center),
                ),
              ]),
            ),
    );
  }

  Widget _bioChip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _modelBar(String label, double prob, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Expanded(child: Text(label, style: SGText.label)),
        Text('${(prob * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontWeight: FontWeight.bold, color: _probColor(prob))),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(value: prob, minHeight: 12,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color)),
      ),
      const SizedBox(height: 12),
    ],
  );

  BarChartGroupData _bar(int x, double y, Color c) => BarChartGroupData(x: x, barRods: [
    BarChartRodData(toY: y, color: c, width: 26, borderRadius: BorderRadius.circular(6)),
  ]);
}

// ── Gauge Painter ──────────────────────────────────────────────────
class _GaugePainter extends CustomPainter {
  final double probability;
  final Color color;
  const _GaugePainter({required this.probability, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.78;
    final r  = size.width * 0.36;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    const sw = 16.0;

    canvas.drawArc(rect, 3.14, 3.14, false,
        Paint()..color = Colors.grey.shade200..strokeWidth = sw
          ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    canvas.drawArc(rect, 3.14, 3.14 * probability.clamp(0, 1), false,
        Paint()..color = color..strokeWidth = sw
          ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final e in {
      '0%':   Offset(cx - r - 8, cy + 8),
      '50%':  Offset(cx - 12, cy - r - 16),
      '100%': Offset(cx + r - 20, cy + 8),
    }.entries) {
      tp.text = TextSpan(text: e.key,
          style: const TextStyle(color: Colors.grey, fontSize: 11));
      tp.layout(); tp.paint(canvas, e.value);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter o) => o.probability != probability;
}