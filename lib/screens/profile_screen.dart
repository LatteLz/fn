// STT5 - Trần Thị Hiền
// Thông tin người dùng + trạng thái Samsung Fit 3 + stress estimate + đăng xuất
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
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
    'Private': 'Tu nhan',
    'Self-employed': 'Tu kinh doanh',
    'Govt_job': 'Nha nuoc',
    'children': 'Tre em',
    'Never_worked': 'Chua di lam',
  };
  static const List<String> _smokingStatuses = [
    'never smoked',
    'formerly smoked',
    'smokes',
    'Unknown',
  ];
  static const Map<String, String> _smokingLabel = {
    'never smoked': 'Chua bao gio hut',
    'formerly smoked': 'Da bo thuoc',
    'smokes': 'Dang hut thuoc',
    'Unknown': 'Khong ro',
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
              fbUser.displayName ?? fbUser.email?.split('@')[0] ?? 'Nguoi dung',
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
      if (mounted)
        setState(() {
          _bio = bio;
          _fit3Ok = granted && !bio.isSimulated;
          _loading = false;
        });
    } catch (e) {
      debugPrint('_load Health error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chua load duoc ho so, vui long thu lai'),
          backgroundColor: Colors.orange));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
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
      if (mounted)
        setState(() {
          _user = updated;
          _editing = false;
          _saving = false;
        });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Da luu'), backgroundColor: SGColor.riskLow));
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Dang xuat?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Huy')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Dang xuat',
                        style: TextStyle(color: SGColor.riskHigh))),
              ],
            ));
    if (ok == true) await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: SGColor.bg,
      appBar: AppBar(
        title: const Text('Ho so ca nhan'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                if (_user != null) _syncEditState(_user!);
                setState(() => _editing = true);
              },
            ),
          if (_editing) ...[
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: const Text('Huy', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Luu',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
      body: _user == null
          ? const Center(
              child: Text('Chua co ho so. Dang xuat roi dang ky lai.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Form(
                  key: _formKey,
                  child: Column(children: [
                    SGCard(
                      child: Row(children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor:
                              SGColor.primary.withValues(alpha: 0.12),
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
                                      _fit3Ok ? SGColor.riskLow : Colors.grey,
                                  size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    const Text('Samsung Galaxy Fit 3',
                                        style: SGText.h3),
                                    Text(
                                        _fit3Ok
                                            ? 'Da ket noi - du lieu thuc'
                                            : 'Chua ket noi / mo phong',
                                        style: TextStyle(
                                            color: _fit3Ok
                                                ? SGColor.riskLow
                                                : Colors.orange,
                                            fontSize: 13)),
                                  ])),
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
                                  'Chi so Stress uoc tinh (HR + SpO2 + Sleep)',
                                  style: SGText.label),
                              const SizedBox(height: 8),
                              Row(children: [
                                Text(_bio!.stressScore.toStringAsFixed(0),
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
                                ),
                              ),
                            ],
                          ]),
                    ),
                    SGCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Thong tin lam sang', style: SGText.h3),
                            const SizedBox(height: 12),
                            _editing
                                ? _toggleRow(
                                    label: 'Gioi tinh',
                                    value: _editGender == 0,
                                    trueLabel: 'Nam',
                                    falseLabel: 'Nu',
                                    onChanged: (v) =>
                                        setState(() => _editGender = v ? 0 : 1),
                                  )
                                : _row('Gioi tinh',
                                    _user!.gender == 0 ? 'Nam' : 'Nu'),
                            _editing
                                ? _numField(_ageCtrl, 'Tuoi', (v) {
                                    final n = int.tryParse(v ?? '');
                                    return (n == null || n < 1 || n > 120)
                                        ? 'Nhap 1-120'
                                        : null;
                                  })
                                : _row('Tuoi', '${_user!.age} tuoi'),
                            const Divider(height: 20),
                            _editing
                                ? _switchRow(
                                    label: 'Cao huyet ap',
                                    value: _editHypertension,
                                    onChanged: (v) =>
                                        setState(() => _editHypertension = v),
                                  )
                                : _row('Cao huyet ap',
                                    _user!.hypertension ? 'Co' : 'Khong'),
                            _editing
                                ? _switchRow(
                                    label: 'Benh tim',
                                    value: _editHeartDisease,
                                    onChanged: (v) =>
                                        setState(() => _editHeartDisease = v),
                                  )
                                : _row('Benh tim',
                                    _user!.heartDisease ? 'Co' : 'Khong'),
                            _editing
                                ? _switchRow(
                                    label: 'Da ket hon',
                                    value: _editEverMarried,
                                    onChanged: (v) =>
                                        setState(() => _editEverMarried = v),
                                  )
                                : _row('Ket hon',
                                    _user!.everMarried ? 'Da ket hon' : 'Chua'),
                            _editing
                                ? _toggleRow(
                                    label: 'Cu tru',
                                    value: _editResidenceType == 1,
                                    trueLabel: 'Thanh thi',
                                    falseLabel: 'Nong thon',
                                    onChanged: (v) => setState(
                                        () => _editResidenceType = v ? 1 : 0),
                                  )
                                : _row(
                                    'Cu tru',
                                    _user!.residenceType == 1
                                        ? 'Thanh thi'
                                        : 'Nong thon'),
                            const Divider(height: 20),
                            _editing
                                ? _dropdownRow<String>(
                                    label: 'Cong viec',
                                    value: _editWorkType,
                                    items: _workTypes,
                                    itemLabel: (v) => _workTypeLabel[v] ?? v,
                                    onChanged: (v) =>
                                        setState(() => _editWorkType = v!),
                                  )
                                : _row(
                                    'Cong viec',
                                    _workTypeLabel[_user!.workType] ??
                                        _user!.workType),
                            _editing
                                ? _dropdownRow<String>(
                                    label: 'Hut thuoc',
                                    value: _editSmokingStatus,
                                    items: _smokingStatuses,
                                    itemLabel: (v) => _smokingLabel[v] ?? v,
                                    onChanged: (v) =>
                                        setState(() => _editSmokingStatus = v!),
                                  )
                                : _row(
                                    'Hut thuoc',
                                    _smokingLabel[_user!.smokingStatus] ??
                                        _user!.smokingStatus),
                            const Divider(height: 20),
                            _editing
                                ? _numField(_gluCtrl, 'Duong huyet (mg/dL)',
                                    (v) {
                                    final n = double.tryParse(v ?? '');
                                    return (n == null || n < 50 || n > 300)
                                        ? 'Nhap 50-300'
                                        : null;
                                  })
                                : _row('Duong huyet',
                                    '${_user!.avgGlucoseLevel} mg/dL'),
                            _editing
                                ? _numField(_bmiCtrl, 'BMI', (v) {
                                    final n = double.tryParse(v ?? '');
                                    return (n == null || n < 10 || n > 60)
                                        ? 'Nhap 10-60'
                                        : null;
                                  })
                                : _row('BMI', _user!.bmi.toString()),
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
                          icon: const Icon(Icons.logout),
                          label: const Text('Dang xuat',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ])),
            ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
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
            Text(value ? 'Co' : 'Khong',
                style: TextStyle(
                    color: value ? SGColor.riskHigh : SGColor.textSub,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(width: 6),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: SGColor.riskHigh,
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
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          validator: validator,
        ),
      );
}
