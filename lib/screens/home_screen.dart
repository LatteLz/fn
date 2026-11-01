import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../services/background_monitoring.dart';
import '../services/health_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BiometricSnapshot? _bio;
  UserModel? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadUser();
    await _fetchBio();
  }

  Future<void> _loadUser() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() => _user = UserModel.fromJson(doc.data()!));
      }
    } catch (e) {
      debugPrint('_loadUser error: $e');
    }
  }

  Future<void> _fetchBio() async {
    if (mounted) setState(() => _loading = true);

    try {
      final granted = await HealthService.requestPermissions();
      if (granted) {
        try {
          final backgroundGranted = await BackgroundMonitoring
              .requestBackgroundHealthReadPermission();
          if (!backgroundGranted && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                'Cần cho phép Health Connect đọc dữ liệu nền để quét tự động.',
              ),
            ));
          }
        } catch (error) {
          debugPrint('Background health permission request failed: $error');
        }
      }
      try {
        await BackgroundMonitoring.requestNotificationPermission();
      } catch (error) {
        debugPrint('Notification permission request failed: $error');
      }

      final bio = granted
          ? await HealthService.fetchLatestData().timeout(
              const Duration(seconds: 15),
              onTimeout: () => BiometricSnapshot.defaultValues())
          : BiometricSnapshot.defaultValues();

      if (mounted) {
        setState(() {
          _bio = bio;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bio = BiometricSnapshot.defaultValues();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?.name.split(' ').last ?? 'bạn';
    return Scaffold(
      backgroundColor: SGColor.bg,
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 20),
          SizedBox(width: 8),
          Text('StrokeGuard AI'),
        ]),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Cập nhật Fit 3',
              onPressed: _fetchBio),
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await BackgroundMonitoring.stop();
                await FirebaseAuth.instance.signOut();
              }),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchBio,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Xin chào, $name 👋', style: SGText.h1),
                    const SizedBox(height: 4),
                    const Text('Dữ liệu sức khoẻ hôm nay từ Samsung Fit 3',
                        style: SGText.body),
                  ]),
            ),
            const SizedBox(height: 12),
            if (_bio != null && _bio!.isSimulated)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                    'Dữ liệu mô phỏng — cấp quyền Health Connect để đọc thật từ Fit 3',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  )),
                ]),
              ),
            const SizedBox(height: 12),
            _loading
                ? const Center(
                    child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator()))
                : _bio == null
                    ? const Center(child: Text('Không lấy được dữ liệu'))
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(children: [
                          Row(children: [
                            Expanded(
                                child: _BioCard(
                                    icon: Icons.favorite_rounded,
                                    label: 'Nhịp tim',
                                    value: _bio!.heartRate.toStringAsFixed(0),
                                    unit: 'bpm',
                                    color: Colors.redAccent,
                                    warning: _bio!.heartRate > 100 ||
                                        _bio!.heartRate < 50,
                                    warn: _bio!.heartRate > 100
                                        ? 'Cao'
                                        : (_bio!.heartRate < 50
                                            ? 'Thấp'
                                            : null))),
                            const SizedBox(width: 10),
                            Expanded(
                                child: _BioCard(
                                    icon: Icons.air_rounded,
                                    label: 'SpO₂',
                                    value: _bio!.spo2.toStringAsFixed(1),
                                    unit: '%',
                                    color: Colors.blue,
                                    warning: _bio!.spo2 < 95,
                                    warn: _bio!.spo2 < 95 ? 'Thấp' : null)),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                                child: _BioCard(
                                    icon: Icons.bedtime_rounded,
                                    label: 'Giấc ngủ',
                                    value: _bio!.sleepHours.toStringAsFixed(1),
                                    unit: 'giờ',
                                    color: Colors.indigo,
                                    warning: _bio!.sleepHours < 6,
                                    warn:
                                        _bio!.sleepHours < 6 ? 'Thiếu' : null)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: _BioCard(
                                    icon: Icons.psychology_rounded,
                                    label: 'Stress',
                                    value: _bio!.stressScore.toStringAsFixed(0),
                                    unit: '/100',
                                    color: Colors.orange,
                                    warning: _bio!.stressScore > 70,
                                    warn:
                                        _bio!.stressScore > 70 ? 'Cao' : null)),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                                child: _BioCard(
                                    icon: Icons.directions_walk_rounded,
                                    label: 'Bước chân',
                                    value: _bio!.steps.toString(),
                                    unit: 'bước',
                                    color: Colors.green,
                                    warning: _bio!.steps < 5000,
                                    warn: _bio!.steps < 5000
                                        ? 'Ít vận động'
                                        : null)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: _BioCard(
                                    icon: Icons.local_fire_department_rounded,
                                    label: 'Calo',
                                    value: _bio!.calories.toStringAsFixed(0),
                                    unit: 'kcal',
                                    color: Colors.deepOrange,
                                    warning: false)),
                          ]),
                        ]),
                      ),
            const SizedBox(height: 16),
            if (_bio != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SGCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Chỉ số BMI', style: SGText.h3),
                        const SizedBox(height: 12),
                        Row(children: [
                          Text(_bio!.bmi.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: SGColor.primary)),
                          const SizedBox(width: 14),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_bmiLabel(_bio!.bmi),
                                    style: TextStyle(
                                        color: _bmiColor(_bio!.bmi),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                const Text('kg/m²', style: SGText.caption),
                              ]),
                        ]),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: ((_bio!.bmi - 10) / 50).clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade200,
                            valueColor:
                                AlwaysStoppedAnimation(_bmiColor(_bio!.bmi)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Gầy\n<18.5',
                                  style: SGText.caption,
                                  textAlign: TextAlign.center),
                              Text('Bình thường\n18.5–24.9',
                                  style: SGText.caption,
                                  textAlign: TextAlign.center),
                              Text('Béo phì\n>30',
                                  style: SGText.caption,
                                  textAlign: TextAlign.center),
                            ]),
                      ]),
                ),
              ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  String _bmiLabel(double b) {
    if (b < 18.5) return 'Thiếu cân';
    if (b < 25) return 'Bình thường';
    if (b < 30) return 'Thừa cân';
    return 'Béo phì';
  }

  Color _bmiColor(double b) {
    if (b < 18.5) return Colors.blue;
    if (b < 25) return SGColor.riskLow;
    if (b < 30) return SGColor.riskMid;
    return SGColor.riskHigh;
  }
}

class _BioCard extends StatelessWidget {
  final IconData icon;
  final String label, value, unit;
  final Color color;
  final bool warning;
  final String? warn;
  const _BioCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.unit,
      required this.color,
      required this.warning,
      this.warn});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: warning
                  ? SGColor.riskHigh.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const Spacer(),
            if (warning && warn != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: SGColor.riskHigh.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(warn!,
                    style: const TextStyle(
                        fontSize: 10,
                        color: SGColor.riskHigh,
                        fontWeight: FontWeight.bold)),
              ),
          ]),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text('$unit · $label', style: SGText.caption),
        ]),
      );
}
