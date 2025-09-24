import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'bottom_menu.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final String icon = "assets/images/icon.png";
  int _selectedIndex = 2;

  void _onMenuTap(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        Navigator.pushNamed(context, '/home'); // หรือ '/' ถ้าคุณใช้เป็น Home
        break;
      case 1:
        Navigator.pushNamed(context, '/edit');
        break;
      case 2:
        // อยู่หน้าโปรไฟล์แล้ว
        break;
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    // กลับไปหน้า Login/ AuthGate
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // ถ้ายังไม่ล็อกอิน ส่งไปหน้า login
    if (user == null) {
      Future.microtask(
        () =>
            Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false),
      );
      return const Scaffold(body: SizedBox());
    }

    final photoUrl = user.photoURL;
    final name = user.displayName ?? (user.email?.split('@').first ?? 'ผู้ใช้');
    final email = user.email ?? '-';
    final uid = user.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Header โลโก้ (สไตล์เดิม)
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

              // การ์ดฟ้า (สไตล์เดิม)
              Container(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color.fromRGBO(227, 242, 253, 1),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white,
                          backgroundImage:
                              photoUrl != null ? NetworkImage(photoUrl) : null,
                          child:
                              photoUrl == null
                                  ? const Icon(
                                    Icons.person,
                                    size: 48,
                                    color: Colors.black,
                                  )
                                  : null,
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
                          _title('ชื่อ'),
                          _pill(name),
                          const SizedBox(height: 12),
                          _title('อีเมล'),
                          _pill(email),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromRGBO(
                                  220,
                                  38,
                                  38,
                                  1,
                                ), // แดง
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.logout),
                              label: const Text('ออกจากระบบ'),
                              onPressed: _signOut,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.lock_outline),
                              label: const Text('การตั้งค่าความปลอดภัย'),
                              onPressed:
                                  () =>
                                      Navigator.pushNamed(context, '/security'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
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

  Widget _title(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.normal,
      color: Color.fromRGBO(0, 0, 0, 1),
    ),
  );

  Widget _pill(String text) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    ),
  );
}
