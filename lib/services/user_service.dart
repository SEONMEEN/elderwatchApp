import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final _db = FirebaseFirestore.instance;
  String get uid => FirebaseAuth.instance.currentUser!.uid;
  Future<void> ensureProfile() async {
    final u = FirebaseAuth.instance.currentUser!;
    await _db.collection('users').doc(uid).set({
      'email': u.email,
      'displayName': u.displayName,
      'providers': u.providerData.map((p) => p.providerId).toList(),
      'lastLogin': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
