import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _accKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLogin = false;
  bool _loadingAuth = false;

  final _profKey = GlobalKey<FormState>();
  final _ageCtrl = TextEditingController();
  final _glucoseCtrl = TextEditingController();
  final _bmiCtrl = TextEditingController();
  int _gender = 0;
  bool _htn = false;
  bool _hd = false;
  bool _married = false;
  int _res = 1;
  String _work = 'Private';
  String _smoke = 'never smoked';
  bool _saving = false;

  static const _workTypes = [
    'Govt_job',
    'Never_worked',
    'Private',
    'Self-employed',
    'children'
  ];
  static const _smokeTypes = [
    'Unknown',
    'formerly smoked',
    'never smoked',
    'smokes'
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in [
      _nameCtrl,
      _emailCtrl,
      _passCtrl,
      _ageCtrl,
      _glucoseCtrl,
      _bmiCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submitAuth() async {
    if (!_accKey.currentState!.validate()) return;
    setState(() => _loadingAuth = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _emailCtrl.text.trim(), password: _passCtrl.text);
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _emailCtrl.text.trim(), password: _passCtrl.text);
        final user = cred.user!;
        await user.updateDisplayName(_nameCtrl.text.trim());

        final defaultProfile = {
          'uid': user.uid,
          'name': _nameCtrl.text.trim(),
          'email': user.email ?? '',
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
        };
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(defaultProfile, SetOptions(merge: true));

        if (mounted && !_tab.indexIsChanging) _tab.animateTo(1);
      }
    } on FirebaseAuthException catch (e) {
      _snack(_authMsg(e.code), isError: true);
    } finally {
      if (mounted) setState(() => _loadingAuth = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_profKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final model = UserModel(
        uid: uid,
        name: _nameCtrl.text.trim().isNotEmpty
            ? _nameCtrl.text.trim()
            : FirebaseAuth.instance.currentUser?.displayName ?? '',
        email: FirebaseAuth.instance.currentUser?.email ?? '',
        gender: _gender,
        age: int.parse(_ageCtrl.text),
        hypertension: _htn,
        heartDisease: _hd,
        everMarried: _married,
        residenceType: _res,
        workType: _work,
        smokingStatus: _smoke,
        avgGlucoseLevel: double.parse(_glucoseCtrl.text),
        bmi: double.parse(_bmiCtrl.text),
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(model.toJson(), SetOptions(merge: true));
      _snack('✅ Hồ sơ đã lưu! Bắt đầu sử dụng StrokeGuard');
    } catch (e) {
      _snack('Lỗi: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? SGColor.riskHigh : SGColor.riskLow,
      ));

  String _authMsg(String code) => switch (code) {
        'email-already-in-use' => 'Email đã được đăng ký',
        'invalid-email' => 'Email không hợp lệ',
        'weak-password' => 'Mật khẩu phải từ 6 ký tự',
        'user-not-found' => 'Tài khoản không tồn tại',
        'wrong-password' => 'Sai mật khẩu',
        _ => 'Lỗi: $code',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SGColor.bg,
      body: SafeArea(
        child: Column(children: [
          Container(
            color: SGColor.primary,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
            child: Column(children: [
              const Icon(Icons.favorite_rounded,
                  color: Colors.redAccent, size: 44),
              const SizedBox(height: 8),
              const Text('StrokeGuard AI',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_isLogin ? 'Đăng nhập tài khoản' : 'Tạo tài khoản mới',
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 16),
              if (!_isLogin)
                TabBar(
                  controller: _tab,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  tabs: const [
                    Tab(text: 'Bước 1: Tài khoản'),
                    Tab(text: 'Bước 2: Hồ sơ'),
                  ],
                ),
            ]),
          ),
          Expanded(
            child: _isLogin
                ? _LoginForm(
                    emailCtrl: _emailCtrl,
                    passCtrl: _passCtrl,
                    formKey: _accKey,
                    loading: _loadingAuth,
                    obscure: _obscure,
                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                    onSubmit: _submitAuth,
                  )
                : TabBarView(controller: _tab, children: [
                    _AccountForm(
                      formKey: _accKey,
                      nameCtrl: _nameCtrl,
                      emailCtrl: _emailCtrl,
                      passCtrl: _passCtrl,
                      obscure: _obscure,
                      loading: _loadingAuth,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      onSubmit: _submitAuth,
                    ),
                    _ProfileForm(
                      formKey: _profKey,
                      ageCtrl: _ageCtrl,
                      glucoseCtrl: _glucoseCtrl,
                      bmiCtrl: _bmiCtrl,
                      gender: _gender,
                      htn: _htn,
                      hd: _hd,
                      married: _married,
                      res: _res,
                      work: _work,
                      smoke: _smoke,
                      saving: _saving,
                      workTypes: _workTypes,
                      smokeTypes: _smokeTypes,
                      onGender: (v) => setState(() => _gender = v),
                      onHtn: (v) => setState(() => _htn = v),
                      onHd: (v) => setState(() => _hd = v),
                      onMarried: (v) => setState(() => _married = v),
                      onRes: (v) => setState(() => _res = v),
                      onWork: (v) => setState(() => _work = v!),
                      onSmoke: (v) => setState(() => _smoke = v!),
                      onSave: _saveProfile,
                    ),
                  ]),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(
                _isLogin
                    ? 'Chưa có tài khoản? Đăng ký ngay'
                    : 'Đã có tài khoản? Đăng nhập',
                style: const TextStyle(
                    color: SGColor.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _AccountForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl, emailCtrl, passCtrl;
  final bool obscure, loading;
  final VoidCallback onToggleObscure, onSubmit;

  const _AccountForm({
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.loading,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
            key: formKey,
            child: Column(children: [
              const SizedBox(height: 16),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Họ và tên', prefixIcon: Icon(Icons.person)),
                validator: (v) => v!.isEmpty ? 'Vui lòng nhập tên' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email', prefixIcon: Icon(Icons.email)),
                validator: (v) =>
                    !v!.contains('@') ? 'Email không hợp lệ' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: passCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon:
                        Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: onToggleObscure,
                  ),
                ),
                validator: (v) => v!.length < 6 ? 'Tối thiểu 6 ký tự' : null,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: loading ? null : onSubmit,
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Đăng ký & Tiếp tục →'),
                ),
              ),
            ])),
      );
}

class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl, passCtrl;
  final bool obscure, loading;
  final VoidCallback onToggleObscure, onSubmit;

  const _LoginForm({
    required this.formKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.loading,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
            key: formKey,
            child: Column(children: [
              const SizedBox(height: 30),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email', prefixIcon: Icon(Icons.email)),
                validator: (v) =>
                    !v!.contains('@') ? 'Email không hợp lệ' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: passCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon:
                        Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: onToggleObscure,
                  ),
                ),
                validator: (v) => v!.length < 6 ? 'Tối thiểu 6 ký tự' : null,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: loading ? null : onSubmit,
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Đăng nhập'),
                ),
              ),
            ])),
      );
}

class _ProfileForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController ageCtrl, glucoseCtrl, bmiCtrl;
  final int gender, res;
  final bool htn, hd, married, saving;
  final String work, smoke;
  final List<String> workTypes, smokeTypes;
  final void Function(int) onGender, onRes;
  final void Function(bool) onHtn, onHd, onMarried;
  final void Function(String?) onWork, onSmoke;
  final VoidCallback onSave;

  const _ProfileForm({
    required this.formKey,
    required this.ageCtrl,
    required this.glucoseCtrl,
    required this.bmiCtrl,
    required this.gender,
    required this.res,
    required this.htn,
    required this.hd,
    required this.married,
    required this.saving,
    required this.work,
    required this.smoke,
    required this.workTypes,
    required this.smokeTypes,
    required this.onGender,
    required this.onRes,
    required this.onHtn,
    required this.onHd,
    required this.onMarried,
    required this.onWork,
    required this.onSmoke,
    required this.onSave,
  });

  Widget _sec(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: SGColor.primary)),
      );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
            key: formKey,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sec('Thông tin cơ bản'),
              TextFormField(
                controller: ageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Tuổi', prefixIcon: Icon(Icons.cake)),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n == null || n < 1 || n > 120) ? '1–120' : null;
                },
              ),
              const SizedBox(height: 12),
              const Text('Giới tính', style: SGText.label),
              Row(children: [
                Expanded(
                    child: RadioListTile<int>(
                        title: const Text('Nam'),
                        value: 0,
                        groupValue: gender,
                        onChanged: (v) => onGender(v!))),
                Expanded(
                    child: RadioListTile<int>(
                        title: const Text('Nữ'),
                        value: 1,
                        groupValue: gender,
                        onChanged: (v) => onGender(v!))),
              ]),
              _sec('Tình trạng sức khỏe'),
              SwitchListTile(
                title: const Text('Cao huyết áp'),
                subtitle: const Text('Đã được chẩn đoán'),
                value: htn,
                onChanged: onHtn,
              ),
              SwitchListTile(
                title: const Text('Bệnh tim mạch'),
                subtitle: const Text('Đã được chẩn đoán'),
                value: hd,
                onChanged: onHd,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: glucoseCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Đường huyết TB (mg/dL)',
                  prefixIcon: Icon(Icons.water_drop),
                  helperText: 'Bình thường lúc đói: 70–100 mg/dL',
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  return (n == null || n < 50 || n > 300) ? '50–300' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: bmiCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'BMI',
                  prefixIcon: Icon(Icons.monitor_weight),
                  helperText: 'Bình thường: 18.5–24.9',
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  return (n == null || n < 10 || n > 60) ? '10–60' : null;
                },
              ),
              _sec('Thông tin xã hội'),
              SwitchListTile(
                  title: const Text('Đã kết hôn'),
                  value: married,
                  onChanged: onMarried),
              const Text('Nơi cư trú', style: SGText.label),
              Row(children: [
                Expanded(
                    child: RadioListTile<int>(
                        title: const Text('Nông thôn'),
                        value: 0,
                        groupValue: res,
                        onChanged: (v) => onRes(v!))),
                Expanded(
                    child: RadioListTile<int>(
                        title: const Text('Thành thị'),
                        value: 1,
                        groupValue: res,
                        onChanged: (v) => onRes(v!))),
              ]),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: work,
                decoration: const InputDecoration(
                    labelText: 'Loại công việc', prefixIcon: Icon(Icons.work)),
                items: workTypes
                    .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                    .toList(),
                onChanged: onWork,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: smoke,
                decoration: const InputDecoration(
                    labelText: 'Tình trạng hút thuốc',
                    prefixIcon: Icon(Icons.smoking_rooms)),
                items: smokeTypes
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: onSmoke,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label: const Text('Lưu hồ sơ & Bắt đầu'),
                ),
              ),
              const SizedBox(height: 20),
            ])),
      );
}
