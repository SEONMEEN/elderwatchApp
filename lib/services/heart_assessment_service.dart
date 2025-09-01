import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HeartAssessmentService {
  final _db = FirebaseFirestore.instance;
  String get uid => FirebaseAuth.instance.currentUser!.uid;
  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('heart_assessments').doc(uid);

  Future<void> saveLatest(Map<String, dynamic> input) async {
    await _doc.set({
      'input': input,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getLatestOnce() async {
    final s = await _doc.get();
    return s.data();
  }

  Stream<Map<String, dynamic>?> watchLatest() =>
      _doc.snapshots().map((s) => s.data());
}
