import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bottom_menu.dart';

class Register extends StatefulWidget {
  @override
  _RegisterState createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final String icon = "assets/images/icon.png";
  int _selectedIndex = 2;

  // step (0 = บัญชี, 1 = สุขภาพ)
  int _step = 0;

  // controllers
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController(); // <<< เพิ่มชื่อ
  final _ageCtrl = TextEditingController();

  // dropdown states
  String? _gender, _cp, _fbs, _exang;

  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose(); // <<< dispose ชื่อ
    _ageCtrl.dispose();
    super.dispose();
  }

  void _onMenuTap(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        Navigator.pushNamed(context, '/');
        break;
      case 1:
        Navigator.pushNamed(context, '/edit');
        break;
      case 2:
        break;
    }
  }

  // === lists
  final List<String> _genders = ['ชาย', 'หญิง'];
  final List<String> _cpTypes = [
    'เจ็บหน้าอกแบบปกติ (Typical Angina)',
    'เจ็บหน้าอกผิดปกติ (Atypical Angina)',
    'เจ็บหน้าอกไม่เกี่ยวกับหัวใจ (Non-anginal Pain)',
    'ไม่มีอาการเจ็บหน้าอก (Asymptomatic)',
  ];
  final List<String> _fbsTypes = ['ใช่', 'ไม่ใช่'];
  final List<String> _exangTypes = ['มี', 'ไม่มี'];

  // === maps
  int? _mapSex(String? g) => g == null ? null : (g == 'ชาย' ? 1 : 0);
  int? _mapCp(String? cp) => cp == null ? null : _cpTypes.indexOf(cp);
  int? _mapYesNo(String? v) => v == null ? null : (v == 'ใช่' ? 1 : 0);
  int? _mapExang(String? v) => v == null ? null : (v == 'มี' ? 1 : 0);

  void _next() async {
    if (_step == 0) {
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text.trim();
      if (!email.contains('@')) {
        _toast('กรอกอีเมลให้ถูกต้อง');
        return;
      }
      if (pass.length < 6) {
        _toast('รหัสผ่านอย่างน้อย 6 ตัวอักษร');
        return;
      }
      setState(() => _step = 1);
    } else {
      await _submit();
    }
  }

  void _prev() => setState(() => _step = 0);
  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim(); // <<< อ่านชื่อ
    final age = int.tryParse(_ageCtrl.text.trim());
    if (name.isEmpty) {
      _toast('กรอกชื่อ');
      return;
    } // <<< validate ชื่อ
    if (age == null) {
      _toast('กรอกอายุเป็นตัวเลข');
      return;
    }
    if (_gender == null || _cp == null || _fbs == null || _exang == null) {
      _toast('เลือกข้อมูลสุขภาพให้ครบ');
      return;
    }

    setState(() => _loading = true);
    try {
      // 1) สมัครสมาชิก
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      final uid = cred.user!.uid;

      // 1.1 อัปเดต displayName ใน Auth
      await cred.user!.updateDisplayName(name);

      // 2) users/{uid}
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': cred.user!.email,
        'displayName': name, // <<< เก็บชื่อ
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'providers': ['password'],
      }, SetOptions(merge: true));

      // 3) heart_assessments/{uid} (ชุดล่าสุด)
      final payload = {
        'age': age,
        'sex': _mapSex(_gender),
        'cp': _mapCp(_cp),
        'fbs': _mapYesNo(_fbs),
        'exang': _mapExang(_exang),
        'thalach': 220 - age,
      };
      await FirebaseFirestore.instance
          .collection('heart_assessments')
          .doc(uid)
          .set({
            'input': payload,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      _toast('สมัครสมาชิกสำเร็จ');
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      String msg = 'สมัครสมาชิกไม่สำเร็จ';
      if (e.code == 'email-already-in-use')
        msg = 'อีเมลนี้ถูกใช้แล้ว';
      else if (e.code == 'invalid-email')
        msg = 'อีเมลไม่ถูกต้อง';
      else if (e.code == 'weak-password')
        msg = 'รหัสผ่านอ่อนเกินไป';
      else if (e.code == 'operation-not-allowed')
        msg = 'ยังไม่เปิด Email/Password ใน Console';
      else if (e.code == 'configuration-not-found' ||
          e.code == 'internal-error') {
        msg =
            'คอนฟิก Firebase/Play Integrity ไม่ครบ (เพิ่ม SHA-256 แล้วโหลด google-services.json ใหม่)';
      }
      _toast(msg);
    } on FirebaseException catch (e) {
      _toast('เขียน Firestore ไม่สำเร็จ: ${e.code}');
    } catch (e) {
      _toast('ผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Header โลโก้ (ดีไซน์เดิม)
              Container(
                height: 100,
                color: const Color.fromARGB(255, 255, 255, 255),
                child: Stack(
                  children: [
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.center,
                      child: Image.asset(icon, width: 500, height: 80),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // การ์ดฟอร์ม (ดีไซน์เดิม)
              Container(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color.fromRGBO(227, 242, 253, 1),
                        child: const Icon(
                          Icons.person_add,
                          size: 50,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      width: 300,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(227, 242, 253, 1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _step == 0 ? _accountStep() : _healthStep(),
                      ),
                    ),

                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_step == 1)
                          TextButton(
                            onPressed: _loading ? null : _prev,
                            child: const Text(
                              "ย้อนกลับ",
                              style: TextStyle(
                                color: Color.fromARGB(255, 67, 67, 67),
                              ),
                            ),
                          ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromRGBO(
                              23,
                              187,
                              78,
                              1,
                            ),
                          ),
                          onPressed: _loading ? null : _next,
                          child:
                              _loading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : Text(
                                    _step == 1 ? 'สมัครสมาชิก' : 'ถัดไป',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed:
                          () =>
                              Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text(
                        "มีบัญชีแล้ว? เข้าสู่ระบบ",
                        style: TextStyle(
                          color: Color.fromARGB(255, 86, 86, 86),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomMenuBar(
        currentIndex: _selectedIndex,
        onTap: _onMenuTap,
      ),
    );
  }

  // --- UI steps (คงดีไซน์เดียวกับ Login) ---
  Widget _accountStep() {
    return Column(
      key: const ValueKey('step0'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'อีเมล',
          style: TextStyle(fontSize: 20, color: Color.fromRGBO(0, 0, 0, 1)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
            hintText: 'กรอกอีเมล',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'รหัสผ่าน',
          style: TextStyle(fontSize: 20, color: Color.fromRGBO(0, 0, 0, 1)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passCtrl,
          obscureText: _obscure,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            hintText: 'อย่างน้อย 6 ตัวอักษร',
          ),
        ),
      ],
    );
  }

  Widget _healthStep() {
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // <<< ชื่อ (ใหม่) — อยู่เหนือ “อายุ”
        const Text(
          'ชื่อ',
          style: TextStyle(fontSize: 20, color: Color.fromRGBO(0, 0, 0, 1)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _nameCtrl,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
            hintText: 'กรอกชื่อ',
          ),
        ),
        const SizedBox(height: 12),

        const Text(
          'อายุ',
          style: TextStyle(fontSize: 20, color: Color.fromRGBO(0, 0, 0, 1)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _ageCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
            hintText: 'กรอกอายุ',
          ),
        ),
        const SizedBox(height: 12),

        const Text(
          'เพศ',
          style: TextStyle(fontSize: 20, color: Color.fromRGBO(0, 0, 0, 1)),
        ),
        const SizedBox(height: 10),
        _dropdown(_genders, _gender, (v) => setState(() => _gender = v)),

        const SizedBox(height: 12),
        const Text(
          'ประเภทของอาการเจ็บหน้าอก',
          style: TextStyle(fontSize: 20, color: Color.fromRGBO(0, 0, 0, 1)),
        ),
        const SizedBox(height: 10),
        _dropdown(
          _cpTypes,
          _cp,
          (v) => setState(() => _cp = v),
          isExpanded: true,
        ),

        const SizedBox(height: 12),
        const Text(
          'ระดับน้ำตาลในเลือด > 120 mg/dl',
          style: TextStyle(fontSize: 20, color: Color.fromRGBO(0, 0, 0, 1)),
        ),
        const SizedBox(height: 10),
        _dropdown(_fbsTypes, _fbs, (v) => setState(() => _fbs = v)),

        const SizedBox(height: 12),
        const Text(
          'เจ็บหน้าอกจากการออกกำลังกายหรือไม่',
          style: TextStyle(fontSize: 20, color: Color.fromRGBO(0, 0, 0, 1)),
        ),
        const SizedBox(height: 10),
        _dropdown(_exangTypes, _exang, (v) => setState(() => _exang = v)),
      ],
    );
  }

  Widget _dropdown(
    List<String> items,
    String? value,
    ValueChanged<String?> onChanged, {
    bool isExpanded = false,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: isExpanded,
      value: value,
      items:
          items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              )
              .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
        hintText: 'กรุณาเลือก',
      ),
    );
  }
}
