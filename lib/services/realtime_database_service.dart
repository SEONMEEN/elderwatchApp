import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/health_data.dart';

class RealtimeDatabaseService {
  // 👉 ใส่ URL ของ Realtime Database จากหน้า Console ให้ตรงเป๊ะ
  static const _dbUrl =
      'https://elderwatchtest-default-rtdb.asia-southeast1.firebasedatabase.app';

  late final FirebaseDatabase _db;
  late final DatabaseReference _log;

  RealtimeDatabaseService() {
    _db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: _dbUrl,
    );
    _db.setPersistenceEnabled(true);
    _db.setPersistenceCacheSizeBytes(10 * 1024 * 1024);
    _log = _db.ref('log')..keepSynced(true);
  }

  DatabaseReference get log => _log;

  HealthData _fromNode(Map<String, dynamic> node, {String? iso}) {
    if (node['processed'] is Map) {
      return HealthData.fromProcessed(
        Map<String, dynamic>.from(node['processed']),
        timestampIso: iso,
      );
    }
    // เผื่อกรณีไม่มี processed (ไม่คาดว่าจะเกิดกับวิธี 1 แต่กันไว้)
    int ts = 0;
    if (iso != null) {
      try {
        ts = DateTime.parse(iso).millisecondsSinceEpoch ~/ 1000;
      } catch (_) {}
    }
    return HealthData(heartRate: 0, spo2: 0, fell: false, timestamp: ts);
  }

  /// one-shot: ดึงตัวล่าสุด (ไม่กรอง)
  Future<HealthData?> getLatestOnce() async {
    final snap = await _log.orderByKey().limitToLast(1).get();
    final v = snap.value;
    if (v is! Map || v.isEmpty) return null;
    final entry = Map<String, dynamic>.from(v);
    final iso = entry.keys.first.toString();
    final node = Map<String, dynamic>.from(entry.values.first);
    return _fromNode(node, iso: iso);
  }

  /// stream: ดึงตัวล่าสุด (ไม่กรอง)
  Stream<HealthData?> latestAny() {
    final q = _log.orderByKey().limitToLast(1);
    return q.onValue.map((e) {
      final v = e.snapshot.value;
      if (v is! Map || v.isEmpty) return null;
      final entry = Map<String, dynamic>.from(v);
      final iso = entry.keys.first.toString();
      final node = Map<String, dynamic>.from(entry.values.first);
      return _fromNode(node, iso: iso);
    });
  }

  // เมธอดชื่อเดิม (เพื่อความเข้ากันได้)
  Stream<HealthData?> latestHealthFromLogFast() => latestAny();
  Future<void> debugPrintLatest() async {
    final snap = await _log.orderByKey().limitToLast(1).get();
    // ignore: avoid_print
    print('[DEBUG] db=$_dbUrl last1=${snap.value}');
  }

  Future<void> linkCheckQuick() async => debugPrintLatest();
  Future<void> sanityCheck() async => debugPrintLatest();
}
