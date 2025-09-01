import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'bottom_menu.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final String icon = "assets/images/icon.png";
  int _selectedIndex = 2;

  // เปลี่ยนอีเมล (ส่งลิงก์ยืนยัน)
  final _newEmailCtrl = TextEditingController();

  // เปลี่ยนรหัสผ่าน
  final _newPassCtrl = TextEditingController();

  // เชื่อมอีเมล/รหัส (สำหรับบัญชีที่ยังไม่มี provider 'password')
  final _linkEmailCtrl = TextEditingController();
  final _linkPassCtrl = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _newEmailCtrl.dispose();
    _newPassCtrl.dispose();
    _linkEmailCtrl.dispose();
    _linkPassCtrl.dispose();
    super.dispose();
  }

  void _onMenuTap(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        Navigator.pushNamed(context, '/home'); // หรือ '/' ตามที่ตั้ง route
        break;
      case 1:
        Navigator.pushNamed(context, '/edit');
        break;
      case 2:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  User get _user => FirebaseAuth.instance.currentUser!;

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // --- Re-auth dialog (ถามรหัสผ่านเดิม) ---
  Future<bool> _promptAndReauth() async {
    if (_user.email == null) {
      _toast('บัญชีนี้ไม่มีอีเมล/รหัสผ่านสำหรับยืนยันตัวตน');
      return false;
    }
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('ยืนยันรหัสผ่าน'),
            content: TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'รหัสผ่านปัจจุบัน',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ยืนยัน'),
              ),
            ],
          ),
    );
    if (ok != true) return false;

    try {
      final cred = EmailAuthProvider.credential(
        email: _user.email!,
        password: ctrl.text,
      );
      await _user.reauthenticateWithCredential(cred);
      return true;
    } on FirebaseAuthException catch (e) {
      final msg =
          (e.code == 'wrong-password' || e.code == 'invalid-credential')
              ? 'รหัสผ่านไม่ถูกต้อง'
              : 'ผิดพลาด: ${e.code}';
      _toast(msg);
      return false;
    }
  }

  Future<void> _sendEmailVerification() async {
    setState(() => _loading = true);
    try {
      await _user.sendEmailVerification();
      _toast('ส่งอีเมลยืนยันแล้ว กรุณาตรวจกล่องจดหมาย');
    } catch (e) {
      _toast('ส่งอีเมลยืนยันไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyBeforeUpdateEmail() async {
    final newEmail = _newEmailCtrl.text.trim();
    if (!newEmail.contains('@')) {
      _toast('กรอกอีเมลใหม่ให้ถูกต้อง');
      return;
    }
    setState(() => _loading = true);
    try {
      await _user.verifyBeforeUpdateEmail(newEmail);
      _toast('ส่งลิงก์ไปอีเมลใหม่แล้ว กดยืนยันแล้วกดปุ่มรีเฟรชที่หน้านี้');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        final ok = await _promptAndReauth();
        if (ok) {
          await _user.verifyBeforeUpdateEmail(newEmail);
          _toast('ส่งลิงก์ไปอีเมลใหม่แล้ว');
        }
      } else {
        _toast('อัปเดตอีเมลไม่สำเร็จ: ${e.code}');
      }
    } catch (e) {
      _toast('อัปเดตอีเมลไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePassword() async {
    final newPass = _newPassCtrl.text.trim();
    if (newPass.length < 6) {
      _toast('รหัสผ่านใหม่อย่างน้อย 6 ตัวอักษร');
      return;
    }
    setState(() => _loading = true);
    try {
      final ok = await _promptAndReauth();
      if (!ok) return;
      await _user.updatePassword(newPass);
      _toast('เปลี่ยนรหัสผ่านสำเร็จ');
      _newPassCtrl.clear();
    } on FirebaseAuthException catch (e) {
      _toast('เปลี่ยนรหัสผ่านไม่สำเร็จ: ${e.code}');
    } catch (e) {
      _toast('เปลี่ยนรหัสผ่านไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _linkEmailPassword() async {
    final email = _linkEmailCtrl.text.trim();
    final pass = _linkPassCtrl.text.trim();
    if (!email.contains('@') || pass.length < 6) {
      _toast('กรอกอีเมลให้ถูกต้องและรหัสผ่านอย่างน้อย 6 ตัวอักษร');
      return;
    }
    setState(() => _loading = true);
    try {
      final cred = EmailAuthProvider.credential(email: email, password: pass);
      await _user.linkWithCredential(cred);
      _toast('เชื่อมอีเมล/รหัสกับบัญชีนี้สำเร็จ');
      _linkEmailCtrl.clear();
      _linkPassCtrl.clear();
      setState(() {}); // refresh provider list
    } on FirebaseAuthException catch (e) {
      String msg = 'เชื่อมบัญชีไม่สำเร็จ: ${e.code}';
      if (e.code == 'provider-already-linked')
        msg = 'มีอีเมล/รหัสเชื่อมอยู่แล้ว';
      if (e.code == 'email-already-in-use')
        msg = 'อีเมลนี้ถูกใช้ในบัญชีอื่นแล้ว';
      _toast(msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('ลบบัญชีผู้ใช้'),
            content: const Text(
              'ยืนยันการลบบัญชีถาวร? ข้อมูลจะไม่สามารถกู้คืนได้',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ลบ'),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final ok = await _promptAndReauth();
      if (!ok) return;
      await _user.delete();
      _toast('ลบบัญชีสำเร็จ');
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    } on FirebaseAuthException catch (e) {
      _toast('ลบบัญชีไม่สำเร็จ: ${e.code}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    try {
      await _user.reload();
      setState(() {});
      _toast('รีเฟรชสถานะแล้ว');
    } catch (e) {
      _toast('รีเฟรชไม่สำเร็จ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // ถ้าไม่มีผู้ใช้ ให้เด้งกลับ login
      Future.microtask(
        () =>
            Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false),
      );
      return const Scaffold(body: SizedBox());
    }

    final providers = user.providerData.map((p) => p.providerId).toList();
    final hasPassword = providers.contains('password');

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Center(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Header โลโก้ (ธีมเดียวกัน)
                  Container(
                    height: 100,
                    color: const Color(0xFFFFFFFF),
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

                  // การ์ดฟ้าใหญ่ (กล่องหลัก)
                  Container(
                    width: 330,
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(227, 242, 253, 1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Avatar + หัวข้อ + ปุ่ม action
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white,
                              child: const Icon(
                                Icons.lock_outline,
                                size: 28,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'ความปลอดภัยบัญชี',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'รีเฟรช',
                              onPressed: _reload,
                              icon: const Icon(Icons.refresh),
                            ),
                            IconButton(
                              tooltip: 'ออกจากระบบ',
                              onPressed: () async {
                                await FirebaseAuth.instance.signOut();
                                if (mounted) {
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    '/login',
                                    (_) => false,
                                  );
                                }
                              },
                              icon: const Icon(Icons.logout),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // กล่องข้อมูลบัญชี (ขาว)
                        _whiteCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('ข้อมูลบัญชี'),
                              const SizedBox(height: 12),
                              _infoRow('UID', user.uid),
                              _infoRow('อีเมล', user.email ?? '-'),
                              _infoRow(
                                'ยืนยันอีเมล',
                                user.emailVerified ? 'ใช่' : 'ไม่ใช่',
                                color:
                                    user.emailVerified
                                        ? Colors.green
                                        : Colors.red,
                              ),
                              _infoRow(
                                'ผู้ให้บริการ',
                                providers.isEmpty ? '-' : providers.join(', '),
                              ),
                              _infoRow(
                                'สร้างเมื่อ',
                                user.metadata.creationTime
                                        ?.toLocal()
                                        .toString() ??
                                    '-',
                              ),
                              _infoRow(
                                'เข้าใช้ล่าสุด',
                                user.metadata.lastSignInTime
                                        ?.toLocal()
                                        .toString() ??
                                    '-',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ยืนยันอีเมล
                        _whiteCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('ยืนยันอีเมล'),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed:
                                        _loading
                                            ? null
                                            : _sendEmailVerification,
                                    icon: const Icon(
                                      Icons.mark_email_unread_outlined,
                                    ),
                                    label: const Text('ส่งอีเมลยืนยัน'),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    user.emailVerified
                                        ? 'ยืนยันแล้ว'
                                        : 'ยังไม่ยืนยัน',
                                    style: TextStyle(
                                      color:
                                          user.emailVerified
                                              ? Colors.green
                                              : Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // เปลี่ยนอีเมล (verifyBeforeUpdateEmail)
                        _whiteCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle(
                                'เปลี่ยนอีเมล (ส่งลิงก์ไปอีเมลใหม่)',
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _newEmailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _inputDecoration('อีเมลใหม่'),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed:
                                    _loading ? null : _verifyBeforeUpdateEmail,
                                icon: const Icon(Icons.alternate_email),
                                label: const Text(
                                  'ส่งลิงก์ยืนยันเพื่อเปลี่ยนอีเมล',
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'หลังจากกดยืนยันในอีเมลใหม่แล้ว ให้กดปุ่มรีเฟรชด้านบน',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // เปลี่ยนรหัสผ่าน
                        _whiteCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle('เปลี่ยนรหัสผ่าน'),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _newPassCtrl,
                                obscureText: true,
                                decoration: _inputDecoration(
                                  'รหัสผ่านใหม่ (≥ 6 ตัวอักษร)',
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed:
                                    (!hasPassword || _loading)
                                        ? null
                                        : _updatePassword,
                                icon: const Icon(Icons.password),
                                label: const Text(
                                  'ยืนยันรหัสเดิมแล้วเปลี่ยนรหัสใหม่',
                                ),
                              ),
                              if (!hasPassword)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text(
                                    'บัญชีนี้ยังไม่มีรหัสผ่าน ให้เชื่อมอีเมล/รหัสก่อน',
                                    style: TextStyle(color: Colors.orange),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        if (!hasPassword) ...[
                          const SizedBox(height: 12),

                          // เชื่อมอีเมล/รหัส
                          _whiteCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle(
                                  'เชื่อมอีเมล/รหัสเข้ากับบัญชีนี้',
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _linkEmailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _inputDecoration('อีเมล'),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _linkPassCtrl,
                                  obscureText: true,
                                  decoration: _inputDecoration(
                                    'รหัสผ่าน (≥ 6)',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton.icon(
                                  onPressed:
                                      _loading ? null : _linkEmailPassword,
                                  icon: const Icon(Icons.link),
                                  label: const Text('เชื่อมอีเมล/รหัส'),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // ลบบัญชี
                        _whiteCard(
                          background: Colors.red.withOpacity(.04),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ลบบัญชี (อันตราย)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _loading ? null : _deleteAccount,
                                icon: const Icon(Icons.delete_forever),
                                label: const Text('ลบบัญชีถาวร'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // Overlay Loading
          if (_loading)
            const Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Color.fromARGB(80, 0, 0, 0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomMenuBar(
        currentIndex: _selectedIndex,
        onTap: _onMenuTap,
      ),
    );
  }

  // ---------- UI helpers ----------
  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  Widget _whiteCard({required Widget child, Color? background}) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  );

  Widget _infoRow(String k, String v, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(k)),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                v,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color ?? Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
