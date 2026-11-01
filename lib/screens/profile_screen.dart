import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../services/background_monitoring.dart';
import '../services/health_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  BiometricSnapshot? _bio;
  bool _loading = true;
  bool _fit3Ok = false;
  bool _editing = false;
  bool _saving = false;

  final _formKey = GlobalKey<FormState>();
  final _ageCtrl = TextEditingController();
  final _gluCtrl = TextEditingController();
  final _bmiCtrl = TextEditingController();

  int _editGender = 0;
  bool _editHypertension = false;
  bool _editHeartDisease = false;
  bool _editEverMarried = false;
  int _editResidenceType = 1;
  String _editWorkType = 'Private';
  String _editSmokingStatus = 'never smoked';

  static const List<String> _workTypes = [
    'Private',
    'Self-employed',
    'Govt_job',
    'children',
    'Never_worked',
  ];
  static const Map<String, String> _workTypeLabel = {
    'Private': 'Tư nhân',
    'Self-employed': 'Tự kinh doanh',
    'Govt_job': 'Nhà nước',
    'children': 'Trẻ em',
    'Never_worked': 'Chưa đi làm',
  };
  static const List<String> _smokingStatuses = [
    'never smoked',
    'formerly smoked',
    'smokes',
    'Unknown',
  ];
  static const Map<String, String> _smokingLabel = {
    'never smoked': 'Chưa bao giờ hút',
    'formerly smoked': 'Đã bỏ thuốc',
    'smokes': 'Đang hút thuốc',
    'Unknown': 'Không rõ',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _gluCtrl.dispose();
    _bmiCtrl.dispose();
    super.dispose();
  }

  void _syncEditState(UserModel u) {
    _editGender = u.gender;
    _editHypertension = u.hypertension;
    _editHeartDisease = u.heartDisease;
    _editEverMarried = u.everMarried;
    _editResidenceType = u.residenceType;
    _editWorkType = _workTypes.contains(u.workType) ? u.workType : 'Private';
    _editSmokingStatus = _smokingStatuses.contains(u.smokingStatus)
        ? u.smokingStatus
        : 'never smoked';
    _ageCtrl.text = u.age.toString();
    _gluCtrl.text = u.avgGlucoseLevel.toString();
    _bmiCtrl.text = u.bmi.toString();
  }

  Future<void> _load() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      final doc = await ref.get();
      if (!doc.exists) {
        final fbUser = FirebaseAuth.instance.currentUser!;
        await ref.set({
          'uid': uid,
          'name':
              fbUser.displayName ?? fbUser.email?.split('@')[0] ?? 'Người dùng',
          'email': fbUser.email ?? '',
          'gender': 0,
          'age': 25,
          'hypertension': false,
          'heart_disease': false,
          'ever_married': false,
          'residence_type': 1,
          'work_type': 'Private',
          'smoking_status': 'never smoked',
          'avg_glucose_level': 90.0,
          'bmi': 22.0,
        });
        final newDoc = await ref.get();
        if (newDoc.exists && mounted) {
          final u = UserModel.fromJson(newDoc.data()!);
          setState(() => _user = u);
          _syncEditState(u);
        }
      } else if (mounted) {
        final u = UserModel.fromJson(doc.data()!);
        setState(() => _user = u);
        _syncEditState(u);
      }
    } catch (e) {
      debugPrint('_load Firestore error: $e');
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final granted = await HealthService.requestPermissions()
          .timeout(const Duration(seconds: 10), onTimeout: () => false);
      final bio = granted
          ? await HealthService.fetchLatestData().timeout(
              const Duration(seconds: 15),
              onTimeout: () => BiometricSnapshot.defaultValues())
          : BiometricSnapshot.defaultValues();
      if (mounted) {
        setState(() {
          _bio = bio;
          _fit3Ok = granted && !bio.isSimulated;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('_load Health error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chưa nạp được hồ sơ, vui lòng thử lại'),
          backgroundColor: Colors.orange));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _saving = false);
      return;
    }

    try {
      final updated = UserModel(
        uid: _user!.uid,
        name: _user!.name,
        email: _user!.email,
        gender: _editGender,
        age: int.parse(_ageCtrl.text),
        hypertension: _editHypertension,
        heartDisease: _editHeartDisease,
        everMarried: _editEverMarried,
        residenceType: _editResidenceType,
        workType: _editWorkType,
        smokingStatus: _editSmokingStatus,
        avgGlucoseLevel: double.parse(_gluCtrl.text),
        bmi: double.parse(_bmiCtrl.text),
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updated.toJson());
      if (!mounted) return;
      setState(() {
        _user = updated;
        _editing = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã cập nhật hồ sơ lâm sàng thành công!'),
          backgroundColor: SGColor.riskLow));
    } catch (error) {
      debugPrint('_save profile error: $error');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Không thể cập nhật hồ sơ: $error'),
          backgroundColor: SGColor.riskHigh));
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Đăng xuất khỏi hệ thống?'),
              content: const Text(
                  'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản StrokeGuard này không?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Hủy')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Đăng xuất',
                        style: TextStyle(color: SGColor.riskHigh))),
              ],
            ));
    if (ok == true) {
      await BackgroundMonitoring.stop();
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: SGColor.bg,
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, size: 28),
              onPressed: () {
                if (_user != null) _syncEditState(_user!);
                setState(() => _editing = true);
              },
            ),
          if (_editing) ...[
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Lưu',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
      body: _user == null
          ? const Center(
              child: Text('Chưa có dữ liệu hồ sơ. Vui lòng đăng nhập lại.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Form(
                  key: _formKey,
                  child: Column(children: [
                    SGCard(
                      child: Row(children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: SGColor.primary.withOpacity(0.12),
                          child: Text(
                            _user!.name.isNotEmpty
                                ? _user!.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: SGColor.primary),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_user!.name, style: SGText.h2),
                              const SizedBox(height: 4),
                              Text(_user!.email, style: SGText.caption),
                            ]),
                      ]),
                    ),
                    SGCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.watch_rounded,
                                  color:
                                      _fit3Ok ? SGColor.riskLow : Colors.orange,
                                  size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Samsung Galaxy Fit 3',
                                        style: SGText.h3),
                                    Text(
                                      _fit3Ok
                                          ? 'Đã kết nối - Dữ liệu thời gian thực'
                                          : 'Chưa kết nối / Chế độ mô phỏng',
                                      style: TextStyle(
                                        color: _fit3Ok
                                            ? SGColor.riskLow
                                            : Colors.orange,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_bio != null)
                                Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                          '${_bio!.heartRate.toStringAsFixed(0)} bpm',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.redAccent)),
                                      Text(
                                          'SpO2 ${_bio!.spo2.toStringAsFixed(1)}%',
                                          style: SGText.caption),
                                    ]),
                            ]),
                            if (_bio != null) ...[
                              const SizedBox(height: 14),
                              const Divider(),
                              const SizedBox(height: 10),
                              const Text(
                                  'Chỉ số Stress ước tính (HR + SpO2 + Sleep)',
                                  style: SGText.label),
                              const SizedBox(height: 8),
                              Row(children: [
                                Text('${_bio!.stressScore.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange)),
                                const Text(' / 100',
                                    style: TextStyle(color: SGColor.textSub)),
                              ]),
                              const SizedBox(height: 8),
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: _bio!.stressScore / 100,
                                    minHeight: 10,
                                    backgroundColor: Colors.orange.shade100,
                                    valueColor: const AlwaysStoppedAnimation(
                                        Colors.orange),
                                  )),
                            ],
                          ]),
                    ),
                    SGCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Thông tin khám sức khỏe',
                                style: SGText.h3),
                            const SizedBox(height: 12),
                            _editing
                                ? _toggleRow(
                                    label: 'Giới tính',
                                    value: _editGender == 0,
                                    trueLabel: 'Nam',
                                    falseLabel: 'Nữ',
                                    onChanged: (v) =>
                                        setState(() => _editGender = v ? 0 : 1),
                                  )
                                : _row('Giới tính',
                                    _user!.gender == 0 ? 'Nam' : 'Nữ'),
                            _editing
                                ? _numField(_ageCtrl, 'Tuổi', (v) {
                                    final n = int.tryParse(v ?? '');
                                    return (n == null || n < 1 || n > 120)
                                        ? 'Vui lòng nhập từ 1-120 tuổi'
                                        : null;
                                  })
                                : _row('Tuổi', '${_user!.age} tuổi'),
                            const Divider(height: 20),
                            _editing
                                ? _switchRow(
                                    label: 'Tăng huyết áp',
                                    value: _editHypertension,
                                    onChanged: (v) =>
                                        setState(() => _editHypertension = v),
                                  )
                                : _row('Tăng huyết áp',
                                    _user!.hypertension ? 'Có' : 'Không'),
                            _editing
                                ? _switchRow(
                                    label: 'Bệnh lý tim mạch',
                                    value: _editHeartDisease,
                                    onChanged: (v) =>
                                        setState(() => _editHeartDisease = v),
                                  )
                                : _row('Bệnh lý tim mạch',
                                    _user!.heartDisease ? 'Có' : 'Không'),
                            _editing
                                ? _switchRow(
                                    label: 'Từng kết hôn',
                                    value: _editEverMarried,
                                    onChanged: (v) =>
                                        setState(() => _editEverMarried = v),
                                  )
                                : _row(
                                    'Từng kết hôn',
                                    _user!.everMarried
                                        ? 'Đã kết hôn'
                                        : 'Chưa kết hôn'),
                            _editing
                                ? _toggleRow(
                                    label: 'Khu vực cư trú',
                                    value: _editResidenceType == 1,
                                    trueLabel: 'Thành thị',
                                    falseLabel: 'Nông thôn',
                                    onChanged: (v) => setState(
                                        () => _editResidenceType = v ? 1 : 0),
                                  )
                                : _row(
                                    'Khu vực cư trú',
                                    _user!.residenceType == 1
                                        ? 'Thành thị'
                                        : 'Nông thôn'),
                            const Divider(height: 20),
                            _editing
                                ? _dropdownRow<String>(
                                    label: 'Nhóm công việc',
                                    value: _editWorkType,
                                    items: _workTypes,
                                    itemLabel: (v) => _workTypeLabel[v] ?? v,
                                    onChanged: (v) =>
                                        setState(() => _editWorkType = v!),
                                  )
                                : _row(
                                    'Nhóm công việc',
                                    _workTypeLabel[_user!.workType] ??
                                        _user!.workType),
                            _editing
                                ? _dropdownRow<String>(
                                    label: 'Tình trạng hút thuốc',
                                    value: _editSmokingStatus,
                                    items: _smokingStatuses,
                                    itemLabel: (v) => _smokingLabel[v] ?? v,
                                    onChanged: (v) =>
                                        setState(() => _editSmokingStatus = v!),
                                  )
                                : _row(
                                    'Tình trạng hút thuốc',
                                    _smokingLabel[_user!.smokingStatus] ??
                                        _user!.smokingStatus),
                            const Divider(height: 20),
                            _editing
                                ? _numField(_gluCtrl,
                                    'Chỉ số đường huyết trung bình (mg/dL)',
                                    (v) {
                                    final n = double.tryParse(v ?? '');
                                    return (n == null || n < 50 || n > 300)
                                        ? 'Nhập giá trị hợp lệ 50-300 mg/dL'
                                        : null;
                                  })
                                : _row('Đường huyết trung bình',
                                    '${_user!.avgGlucoseLevel} mg/dL'),
                            _editing
                                ? _numField(
                                    _bmiCtrl, 'Chỉ số khối cơ thể (BMI)', (v) {
                                    final n = double.tryParse(v ?? '');
                                    return (n == null || n < 10 || n > 60)
                                        ? 'Nhập chỉ số BMI hợp lệ từ 10-60'
                                        : null;
                                  })
                                : _row('Chỉ số khối cơ thể (BMI)',
                                    _user!.bmi.toString()),
                          ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: SGColor.riskHigh,
                            side: const BorderSide(color: SGColor.riskHigh),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Đăng xuất tài khoản',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ])),
            ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Text(label, style: SGText.label),
          const Spacer(),
          Text(value, style: SGText.body),
        ]),
      );

  Widget _switchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(label, style: SGText.label),
          const Spacer(),
          Row(children: [
            Text(value ? 'Có' : 'Không',
                style: TextStyle(
                    color: value ? SGColor.riskHigh : SGColor.textSub,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(width: 6),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: SGColor.riskHigh,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ]),
        ]),
      );

  Widget _toggleRow({
    required String label,
    required bool value,
    required String trueLabel,
    required String falseLabel,
    required ValueChanged<bool> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(label, style: SGText.label),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _toggleBtn(trueLabel, value, () => onChanged(true)),
              _toggleBtn(falseLabel, !value, () => onChanged(false)),
            ]),
          ),
        ]),
      );

  Widget _toggleBtn(String text, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? SGColor.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(text,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: active ? Colors.white : SGColor.textSub)),
        ),
      );

  Widget _dropdownRow<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(label, style: SGText.label),
          const Spacer(),
          DropdownButton<T>(
            value: value,
            underline: const SizedBox(),
            style: const TextStyle(fontSize: 13, color: SGColor.textSub),
            items: items
                .map((e) => DropdownMenuItem<T>(
                      value: e,
                      child: Text(itemLabel(e)),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ]),
      );

  Widget _numField(
    TextEditingController ctrl,
    String label,
    String? Function(String?) validator,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          validator: validator,
        ),
      );
}
