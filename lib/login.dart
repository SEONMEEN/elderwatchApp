import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bottom_menu.dart';
import 'register.dart';

class Login extends StatefulWidget {
  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final String icon = "assets/images/icon.png";
  int _selectedIndex = 2;

  // controllers
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
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
        // โปรไฟล์/ความปลอดภัย ถ้ามี
        break;
    }
  }

  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (!email.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรอกอีเมลให้ถูกต้อง')));
      return;
    }
    if (pass.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรอกรหัสผ่าน')));
      return;
    }

    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      // ensure users/{uid} ไว้สำหรับเก็บโปรไฟล์เบื้องต้น
      final uid = cred.user!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': cred.user!.email,
        'providers': cred.user!.providerData.map((p) => p.providerId).toList(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/edit');
    } on FirebaseAuthException catch (e) {
      String m = 'เข้าสู่ระบบไม่สำเร็จ';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        m = 'รหัสผ่านไม่ถูกต้อง';
      } else if (e.code == 'user-not-found') {
        m = 'ไม่พบบัญชีผู้ใช้นี้';
      } else if (e.code == 'invalid-email') {
        m = 'อีเมลไม่ถูกต้อง';
      } else if (e.code == 'network-request-failed') {
        m = 'เครือข่ายมีปัญหา ลองใหม่อีกครั้ง';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรอกอีเมลในช่องก่อน')));
      return;
    }
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ส่งลิงก์รีเซ็ตรหัสผ่านไปที่อีเมลแล้ว')),
    );
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
              // --- Header ตามดีไซน์เดิม ---
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

              // --- Card ฟอร์ม ตามดีไซน์เดิม ---
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
                          Icons.person,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ชื่อผู้ใช้', // ใช้เป็น "อีเมล"
                            style: TextStyle(
                              fontSize: 20,
                              color: Color.fromRGBO(0, 0, 0, 1),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              hintText: 'กรอกอีเมล',
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'รหัสผ่าน',
                            style: TextStyle(
                              fontSize: 20,
                              color: Color.fromRGBO(0, 0, 0, 1),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed:
                                    () => setState(() => _obscure = !_obscure),
                              ),
                              hintText: 'กรอกรหัสผ่าน',
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromRGBO(
                                  23,
                                  187,
                                  78,
                                  1,
                                ),
                              ),
                              onPressed: _loading ? null : _signIn,
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
                                      : const Text(
                                        'เข้าสู่ระบบ',
                                        style: TextStyle(color: Colors.white),
                                      ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: _forgotPassword,
                              child: const Text('ลืมรหัสผ่าน?'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => Register()),
                        );
                      },
                      child: const Text(
                        "สมัครสมาชิกใหม่",
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
}
