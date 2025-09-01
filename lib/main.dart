import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'login.dart';
import 'register.dart';
import 'fromhealth.dart';
import 'security_page.dart';
import 'home.dart';
import 'profile.dart'; // ถ้ามี

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Health App',
      // อย่าแม็พ '/' ไปหน้าอื่น ให้ใช้ home: AuthGate() เป็น landing เสมอ
      home: const AuthGate(),
      routes: {
        '/home': (_) => const RequireAuth(child: HomePage()),
        '/login': (_) => Login(),
        '/register': (_) => Register(),
        '/edit': (_) => RequireAuth(child: Fromhealth()),
        '/security': (_) => const RequireAuth(child: SecurityPage()),
        '/profile': (_) => const RequireAuth(child: ProfilePage()),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) return Login(); // ยังไม่ล็อกอิน → หน้า Login
        return const HomePage(); // ล็อกอินแล้ว → หน้า Home (ที่ล็อกอินเท่านั้น)
      },
    );
  }
}

// ตัวห่อกันหน้า: ถ้าไม่ล็อกอินจะพาไปหน้า Login
class RequireAuth extends StatelessWidget {
  final Widget child;
  const RequireAuth({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (FirebaseAuth.instance.currentUser == null) return Login();
        return child;
      },
    );
  }
}
