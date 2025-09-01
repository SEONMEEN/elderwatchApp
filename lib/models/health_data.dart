class HealthData {
  final int heartRate; // bpm
  final int spo2; // %
  final bool fell;
  final int timestamp; // epoch seconds

  HealthData({
    required this.heartRate,
    required this.spo2,
    required this.fell,
    required this.timestamp,
  });

  static int toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  static bool toBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  factory HealthData.fromProcessed(
    Map<String, dynamic> m, {
    String? timestampIso,
  }) {
    final bpm = toInt(m['bpm']);
    final spo2 = toInt(m['spo2']);
    final fell = toBool(m['fall']);
    int ts = toInt(m['timestamp']);
    if (ts == 0 && timestampIso != null) {
      try {
        ts = DateTime.parse(timestampIso).millisecondsSinceEpoch ~/ 1000;
      } catch (_) {}
    }
    return HealthData(heartRate: bpm, spo2: spo2, fell: fell, timestamp: ts);
  }
}
