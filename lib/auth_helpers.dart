import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> ensureUserDoc() async {
  final u = FirebaseAuth.instance.currentUser!;
  await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
    'email': u.email,
    'displayName': u.displayName,
    'providers': u.providerData.map((p) => p.providerId).toList(),
    'lastLogin': FieldValue.serverTimestamp(),
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

/// ให้ผู้ใช้พิมพ์รหัสเพื่อ reauthenticate ก่อนทำ action สำคัญ
Future<bool> promptAndVerifyPassword(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.email == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('บัญชีนี้ไม่มีอีเมล/รหัสผ่าน')),
    );
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
            decoration: const InputDecoration(labelText: 'รหัสผ่าน'),
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
      email: user.email!,
      password: ctrl.text,
    );
    await user.reauthenticateWithCredential(cred);
    return true;
  } on FirebaseAuthException catch (e) {
    final msg =
        (e.code == 'wrong-password' || e.code == 'invalid-credential')
            ? 'รหัสผ่านไม่ถูกต้อง'
            : 'ผิดพลาด: ${e.code}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    return false;
  }
}
