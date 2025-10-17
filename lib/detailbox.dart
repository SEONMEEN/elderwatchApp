import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

/// สวิตช์สำหรับทดสอบ "บังคับให้ขึ้นล้ม (คาดการณ์)" โดยไม่ต้องรอข้อมูลจริง
const bool kDebugForceFall = true; // ตั้ง true เพื่อลอง UI
// ถ้าอยากบังคับ "ชัก" เพื่อเทส UI แบบไม่พึ่งข้อมูลจริง ให้เปิดคีย์นี้ได้
// const bool kDebugForceSeizure = true; // <-- เอา // ออกเพื่อเปิดทดสอบ

/// ------------------------------------------------------------
///  Predict cache (โหลดโมเดล/สเกล/ฟีเจอร์ ครั้งเดียว ใช้ร่วมกันทุกการ์ด)
/// ------------------------------------------------------------
class _PredictorCache {
  static Interpreter? _interpreter;
  static List<String>? _features;
  static String _scalerType = 'identity';
  static List<double>? _mean, _scale; // standard
  static List<double>? _dataMin, _dataMax, _frange; // minmax

  static bool _loading = false;
  static String? _lastError;

  static Future<void> ensureLoaded() async {
    if (_interpreter != null || _loading) return;
    _loading = true;
    _lastError = null;

    try {
      const modelAsset = 'assets/models/mlp_best.tflite';
      final bd = await rootBundle.load(modelAsset);
      final u8 = bd.buffer.asUint8List();

      _interpreter?.close();
      _interpreter = Interpreter.fromBuffer(u8);

      // features
      final fTxt = await rootBundle.loadString('assets/models/features.json');
      final dynamic rawF = json.decode(fTxt);
      if (rawF is List) {
        _features = rawF.map((e) => e.toString()).toList();
      } else if (rawF is Map && rawF['features'] is List) {
        _features = List<String>.from(rawF['features']);
      } else {
        throw Exception('features.json รูปแบบไม่ถูกต้อง');
      }

      // scaler
      final sTxt = await rootBundle.loadString('assets/models/scaler.json');
      final s = json.decode(sTxt);
      _scalerType = (s['type'] ?? 'identity').toString();
      if (_scalerType == 'standard') {
        _mean = _toDoubleList(s['mean']);
        _scale = _toDoubleList(s['scale']);
      } else if (_scalerType == 'minmax') {
        _dataMin = _toDoubleList(s['data_min']);
        _dataMax = _toDoubleList(s['data_max']);
        final fr = (s['feature_range'] ?? [0.0, 1.0]) as List;
        _frange = [_asD(fr[0]), _asD(fr[1])];
      } else {
        _scalerType = 'identity';
      }
    } catch (e) {
      _lastError = 'โหลดโมเดลไม่สำเร็จ: $e';
      debugPrint(_lastError);
    } finally {
      _loading = false;
    }
  }

  static List<double> _toDoubleList(dynamic v) =>
      (v as List).map((e) => _asD(e)).toList();

  static double _asD(dynamic x) =>
      (x is num) ? x.toDouble() : double.parse(x.toString());

  static List<double> transform(List<double> x) {
    if (_scalerType == 'standard' && _mean != null && _scale != null) {
      final out = <double>[];
      for (int i = 0; i < x.length; i++) {
        out.add((x[i] - _mean![i]) / (_scale![i] == 0 ? 1.0 : _scale![i]));
      }
      return out;
    }
    if (_scalerType == 'minmax' &&
        _dataMin != null &&
        _dataMax != null &&
        _frange != null) {
      final out = <double>[];
      final fmin = _frange![0], fmax = _frange![1];
      for (int i = 0; i < x.length; i++) {
        final dmin = _dataMin![i], dmax = _dataMax![i];
        final denom = (dmax - dmin) == 0 ? 1.0 : (dmax - dmin);
        out.add((x[i] - dmin) / denom * (fmax - fmin) + fmin);
      }
      return out;
    }
    return x; // identity
  }

  static double? predictProb(Map<String, dynamic> inputMap) {
    if (_interpreter == null || _features == null) return null;
    final row = <double>[];
    for (final f in _features!) {
      final v = inputMap[f];
      if (v == null) return null;
      row.add(_asD(v));
    }
    final x = transform(row);
    final input = Float32List.fromList(x);
    final shape = _interpreter!.getInputTensors().first.shape; // [1, n]
    if (shape.length == 2 && shape[0] == 1 && shape[1] != x.length) {
      debugPrint('ขนาดฟีเจอร์ไม่ตรงกับโมเดล: need ${shape[1]} got ${x.length}');
      return null;
    }
    final output = List.filled(1, 0.0).reshape([1, 1]);
    _interpreter!.run(input.reshape([1, x.length]), output);
    final p = output[0][0];
    return p.isNaN ? null : p.clamp(0.0, 1.0);
  }
}

/// ------------------------------------------------------------
///  Fall predictor (เพิ่ม Normalization จาก assets/models/normalization_stats.json)
///  - รองรับ 3 โหมด: identity, standard(mean/std), minmax(min/max, feature_range)
///  - ไม่แตะ logic อื่นของไฟล์คุณ
/// ------------------------------------------------------------
class _FallPredictor {
  static Interpreter? _interpreter;
  static List<String>? _features;

  // === Normalization state ===
  static String _normType = 'identity';
  static List<double>? _mean, _std; // standard
  static List<double>? _minV, _maxV, _frange; // minmax

  static bool _loading = false;
  static String? _lastError;

  static Future<void> ensureLoaded() async {
    if (_interpreter != null || _loading) return;
    _loading = true;
    _lastError = null;
    try {
      // โหลดโมเดล
      const modelAsset = 'assets/models/fall_detection_model_best.tflite';
      final bd = await rootBundle.load(modelAsset);
      final u8 = bd.buffer.asUint8List();
      _interpreter?.close();
      _interpreter = Interpreter.fromBuffer(u8);

      // โหลดรายชื่อฟีเจอร์
      final fTxt = await rootBundle.loadString(
        'assets/models/fall_features.json',
      );
      final raw = json.decode(fTxt);
      if (raw is Map && raw['features'] is List) {
        _features = List<String>.from(raw['features']);
      } else if (raw is List) {
        _features = raw.map((e) => e.toString()).toList();
      } else {
        throw Exception('fall_features.json รูปแบบไม่ถูกต้อง');
      }

      // โหลด normalization (ถ้ามี)
      try {
        final nTxt = await rootBundle.loadString(
          'assets/models/normalization_stats.json',
        );
        final n = json.decode(nTxt);
        _normType = (n['type'] ?? 'identity').toString();

        if (_normType == 'standard') {
          _mean = _toDList(n['mean']);
          _std = _toDList(n['std']);
          if (_features != null && _mean!.length != _features!.length) {
            throw Exception(
              'mean length (${_mean!.length}) != features length (${_features!.length})',
            );
          }
          if (_features != null && _std!.length != _features!.length) {
            throw Exception(
              'std length (${_std!.length}) != features length (${_features!.length})',
            );
          }
        } else if (_normType == 'minmax') {
          _minV = _toDList(n['min']);
          _maxV = _toDList(n['max']);
          final fr = (n['feature_range'] ?? [0.0, 1.0]) as List;
          _frange = [_asD(fr[0]), _asD(fr[1])];
          if (_features != null && _minV!.length != _features!.length) {
            throw Exception(
              'min length (${_minV!.length}) != features length (${_features!.length})',
            );
          }
          if (_features != null && _maxV!.length != _features!.length) {
            throw Exception(
              'max length (${_maxV!.length}) != features length (${_features!.length})',
            );
          }
        } else {
          _normType = 'identity';
        }
      } catch (e) {
        // ถ้าไม่มีไฟล์/อ่านไม่ได้ → ใช้ identity
        _normType = 'identity';
        debugPrint(
          'normalize: ใช้ identity (ไม่มี/อ่าน normalization_stats.json ไม่ได้): $e',
        );
      }
    } catch (e) {
      _lastError = 'โหลดโมเดลล้มไม่สำเร็จ: $e';
      debugPrint(_lastError);
    } finally {
      _loading = false;
    }
  }

  static List<double> _toDList(dynamic v) =>
      (v as List).map((e) => _asD(e)).toList();

  static double _asD(dynamic x) =>
      (x is num) ? x.toDouble() : double.tryParse('$x') ?? 0.0;

  static List<double> _applyNorm(List<double> x) {
    if (_normType == 'standard' && _mean != null && _std != null) {
      final out = <double>[];
      for (int i = 0; i < x.length; i++) {
        final s = (_std![i] == 0) ? 1.0 : _std![i];
        out.add((x[i] - _mean![i]) / s);
      }
      return out;
    }
    if (_normType == 'minmax' &&
        _minV != null &&
        _maxV != null &&
        _frange != null) {
      final out = <double>[];
      final fmin = _frange![0], fmax = _frange![1];
      for (int i = 0; i < x.length; i++) {
        final denom =
            (_maxV![i] - _minV![i]) == 0 ? 1.0 : (_maxV![i] - _minV![i]);
        out.add((x[i] - _minV![i]) / denom * (fmax - fmin) + fmin);
      }
      return out;
    }
    return x; // identity
  }

  static double? predict(Map<String, dynamic> sample) {
    if (_interpreter == null || _features == null) return null;

    // จัดเวกเตอร์ตามลำดับ features
    final vec = <double>[];
    for (final f in _features!) {
      final v = sample[f];
      if (v == null) return null;
      vec.add((v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0);
    }

    // Normalize ก่อนส่งเข้าโมเดล (ตาม normalization_stats.json)
    final x = _applyNorm(vec);

    // รันโมเดล
    final input = Float32List.fromList(x).reshape([1, x.length]);
    final output = List.filled(1, 0.0).reshape([1, 1]);
    _interpreter!.run(input, output);
    final p = output[0][0];
    return p.isNaN ? null : p.clamp(0.0, 1.0);
  }
}

/// ------------------------------------------------------------
///  Widget แสดงกล่องค่าต่าง ๆ + ทำนาย
/// ------------------------------------------------------------
class Detailbox extends StatefulWidget {
  final String title;
  final double width;
  final num? value; // HR/SpO2
  final String? image; // Event image
  final String? unitorstatus; // หน่วย หรือข้อความสถานะ
  final Color color;
  final String type; // 'heartrate' | 'oxygen' | 'status'
  final bool enablePrediction;

  Detailbox(
    this.title,
    this.width,
    this.value,
    this.image,
    this.unitorstatus,
    this.color,
    this.type, {
    this.enablePrediction = true,
    Key? key,
  }) : super(key: key);

  @override
  State<Detailbox> createState() => _DetailboxState();
}

enum HrPane { timeline, predict }

class AbnormalHrEvent {
  final DateTime at;
  final num? hr;
  AbnormalHrEvent(this.at, this.hr);
}

class _DetailboxState extends State<Detailbox> {
  // heart prediction
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Map<String, dynamic>? _latestInput;
  double? _predProb; // 0..1
  String? _err;
  bool _ready = false;

  // fall prediction
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _fallSub;
  Map<String, dynamic>? _latestProcessed;
  double? _fallProb; // 0..1

  HrPane _hrPane = HrPane.timeline;
  List<AbnormalHrEvent> _abnormalHrEvents = [];

  @override
  void initState() {
    super.initState();
    _initAll();

    // ✅ FORCE TEST UI: ถ้าต้องการบังคับให้การ์ดขึ้น "ล้ม (คาดการณ์)"
    //    ให้ตั้ง kDebugForceFall = true (ด้านบนไฟล์)
    //    แล้วโค้ดนี้จะตั้ง _fallProb = 0.5 ให้อัตโนมัติหลังเฟรมแรก
    if (kDebugForceFall) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _fallProb = 0.5);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _fallSub?.cancel();
    super.dispose();
  }

  // ===== รูปสถานะ (มีแค่ 3 รูป) =====
  static const Map<String, String> _statusImages = {
    'normal': 'assets/images/status_normal.png',
    'fall': 'assets/images/status_fall.png',
    'seizure': 'assets/images/status_seizure.png',
  };

  // ===== helper: ค่าปัจจุบันจาก input =====
  double? _latestHr() {
    final v =
        _latestInput?['hr'] ??
        _latestInput?['heart_rate'] ??
        _latestInput?['current_hr'];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  double? _latestSpo2() {
    final v =
        _latestInput?['spo2'] ??
        _latestInput?['SpO2'] ??
        _latestInput?['oxygen'];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// --- Seizure heuristic after fall ----------------------------------------
  /// ใช้เกณฑ์ HR/SpO₂ เพื่ออนุมาน "ชัก" เมื่อพบว่าล้มแล้ว
  /// ปรับ threshold ได้ด้านล่าง
  ({bool flag, double score}) _inferSeizureFromVitals(
    double? hr,
    double? spo2,
  ) {
    if (hr == null || spo2 == null) return (flag: false, score: 0.0);

    // ------------------ ปรับเกณฑ์ได้ตรงนี้ ------------------
    final bool tachy = hr >= 120; // HR สูงมาก
    final bool hypox = spo2 < 92; // SpO₂ ต่ำ
    final bool brady = hr <= 50; // HR ต่ำผิดปกติ (บางครั้งพบหลังชัก)
    // ---------------------------------------------------------

    double score = 0.0;
    if (tachy) score += 0.6;
    if (hypox) score += 0.6;
    if (brady) score += 0.4;

    // จำกัดให้อยู่ช่วง 0..1
    score = score.clamp(0.0, 1.0);
    // เกณฑ์ตัดสิน "ชัก"
    final bool flag = score >= 0.6;

    return (flag: flag, score: score);
  }

  String _selectStatusImage({required bool isFall, required bool isSeizure}) {
    if (isSeizure) return _statusImages['seizure']!;
    if (isFall) return _statusImages['fall']!;
    return _statusImages['normal']!;
  }

  Future<void> _initAll() async {
    await _PredictorCache.ensureLoaded();
    await _FallPredictor.ensureLoaded();
    if (!mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _err = 'ยังไม่ได้เข้าสู่ระบบ';
        _ready = true;
      });
      return;
    }

    _sub = FirebaseFirestore.instance
        .collection('heart_assessments')
        .doc(uid)
        .snapshots()
        .listen(
          (snap) {
            final data = snap.data();
            final input = (data?['input'] ?? {}) as Map<String, dynamic>;

            final raw = (data?['abnormal_hr_events'] ?? []) as List;
            final events = <AbnormalHrEvent>[];
            for (final e in raw) {
              if (e is Map) {
                final at = DateTime.tryParse('${e['at']}');
                final hr = e['hr'];
                if (at != null) {
                  events.add(AbnormalHrEvent(at, hr is num ? hr : null));
                }
              } else {
                final at = DateTime.tryParse(e.toString());
                if (at != null) events.add(AbnormalHrEvent(at, null));
              }
            }
            events.sort((a, b) => a.at.compareTo(b.at));

            setState(() {
              _latestInput = input.isEmpty ? null : input;
              _abnormalHrEvents = events;
              _ready = true;
            });

            _recompute();
          },
          onError: (e) {
            setState(() {
              _err = 'อ่านข้อมูลไม่สำเร็จ: $e';
              _ready = true;
            });
          },
        );

    _listenLatestProcessedFrame(uid);
    _recompute();
  }

  // ฟังเฟรมล่าสุดจาก Firestore เพื่อคำนวณความน่าจะเป็นการล้ม
  void _listenLatestProcessedFrame(String uid) {
    _fallSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('stream')
        .orderBy('processed.timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen(
          (qs) {
            if (qs.docs.isEmpty) return;
            final doc = qs.docs.first.data();
            final processed = (doc['processed'] ?? {}) as Map<String, dynamic>;
            setState(() => _latestProcessed = processed);

            // หาก backend มี field 'fall' ให้ใช้ได้เลย (0/1 หรือ prob)
            if (processed.containsKey('fall')) {
              final v = processed['fall'];
              final p = (v is num) ? v.toDouble() : double.tryParse('$v');
              if (p != null) {
                debugPrint('processed.fall=$p');
                setState(() => _fallProb = p.clamp(0.0, 1.0));
                return;
              }
            }

            // ถ้าไม่มีค่า fall โดยตรง → ลองทำนายจากฟีเจอร์ (normalize + tflite)
            final candidate = <String, dynamic>{
              'Acc_X': processed['Acc_X'],
              'Acc_Y': processed['Acc_Y'],
              'Acc_Z': processed['Acc_Z'],
              'Gyro_X': processed['Gyro_X'],
              'Gyro_Y': processed['Gyro_Y'],
              'Gyro_Z': processed['Gyro_Z'],
            };

            final p = _FallPredictor.predict(candidate) ?? 0.0;
            debugPrint('predicted fall prob=$p from candidate=$candidate');
            setState(() => _fallProb = p);
          },
          onError: (e) {
            debugPrint('อ่านเฟรมล่าสุดล้มไม่สำเร็จ: $e');
          },
        );
  }

  void _recompute() {
    if (!widget.enablePrediction) return;
    if (_latestInput == null) {
      setState(() => _predProb = null);
      return;
    }
    final p = _PredictorCache.predictProb(_latestInput!);
    setState(() => _predProb = p);
  }

  int? _getAgeYears() {
    final v = _latestInput?['age'];
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  ({int min, int max}) _hrNormalRangeForAge(int? age) {
    if (age == null) return (min: 60, max: 100);
    if (age <= 3) return (min: 98, max: 140);
    if (age <= 5) return (min: 80, max: 120);
    if (age <= 12) return (min: 75, max: 118);
    if (age <= 17) return (min: 60, max: 100);
    return (min: 60, max: 100);
  }

  double _targetWidth(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final base = widget.width;
    bool expand = false;

    final isHR = widget.type == "heartrate";
    final isSpO2 = widget.type == "oxygen";
    final isStatus = widget.type == "status";

    if (isHR && widget.value != null) {
      final ageYears = _getAgeYears();
      final range = _hrNormalRangeForAge(ageYears);
      final hr = widget.value!.toDouble();
      final isAbnormal = hr < range.min || hr > range.max;
      if (isAbnormal) expand = true;
    }
    if (isHR &&
        _hrPane == HrPane.predict &&
        _predProb != null &&
        _predProb! >= 0.5) {
      expand = true;
    }
    if (isSpO2 && widget.value != null) {
      final spo2 = widget.value!.toDouble();
      if (spo2 < 95) expand = true;
    }
    if (isStatus) {
      if (_fallProb != null && _fallProb! >= 0.5) expand = true;
      final msg = (widget.unitorstatus ?? "").toLowerCase();
      final textSaysFall = msg.contains('fall') || msg.contains('ล้ม');
      final textSaysSeizure = msg.contains('seizure') || msg.contains('ชัก');
      if (textSaysFall || textSaysSeizure) expand = true;
    }

    final expanded = math.min(screenW - 32, base + 80);
    return expand ? expanded : base;
  }

  Widget _infoCard(String text, {Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (color ?? const Color.fromARGB(255, 250, 250, 250)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4)),
    );
  }

  Widget _buildHrRiskPanel(double p, num? hrNow) {
    String level, note;
    Color dotColor;

    if (p < 0.25) {
      level = "น้อย";
      note = "หัวใจแข็งแรงดี ไม่มีสัญญาณผิดปกติ";
      dotColor = const Color(0xFF2E7D32);
    } else if (p < 0.50) {
      level = "เฝ้าระวัง";
      note = "มีแนวโน้มเริ่มผิดปกติ ควรตรวจเช็กเป็นระยะ";
      dotColor = const Color(0xFFF9A825);
    } else if (p < 0.75) {
      level = "เสี่ยงสูง";
      note = "มีความเสี่ยงเป็นโรคหัวใจ ควรพบแพทย์";
      dotColor = const Color.fromARGB(255, 239, 41, 41);
    } else {
      level = "เสี่ยงรุนแรง";
      note = "อาจมีอาการของโรคหัวใจ ต้องตรวจทันที";
      dotColor = const Color(0xFFC62828);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "แนวโน้มของภาวะ: $level",
                style: TextStyle(
                  color: dotColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoCard("ค่าชีพจรปัจจุบัน: ${hrNow ?? '-'} bpm\n(SpO₂ ดีหาก ≥95%)"),
          const SizedBox(height: 10),
          _infoCard(
            p < 0.50
                ? "ยังไม่พบสัญญาณที่ต้องเฝ้าระวัง"
                : "พบแนวโน้มความเสี่ยงจากการประเมิน ควรติดตามอาการ",
          ),
          const SizedBox(height: 10),
          Text(
            p < 0.25
                ? "สุขภาพหัวใจปกติดี แนะนำตรวจสุขภาพประจำปีตามปกติ"
                : (p < 0.50
                    ? "ควรดูแลสุขภาพ นอนพอ ออกกำลังกายสม่ำเสมอ"
                    : (p < 0.75
                        ? "ควรไปพบแพทย์เฉพาะทางหัวใจเพื่อตรวจเพิ่มเติม"
                        : "รีบพบแพทย์ทันที หากมีอาการแน่นหน้าอก/ใจสั่นผิดปกติ")),
            style: TextStyle(color: dotColor, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningSignsPanel() {
    final List<String> warningSigns = [
      "หัวใจเต้นเร็วกว่า 100 ครั้งต่อนาที (โดยเฉพาะอย่างยิ่งหากมีอาการร่วม)",
      "หัวใจเต้นช้ากว่า 60 ครั้งต่อนาที (ยกเว้นในนักกีฬาที่ออกกำลังกายเป็นประจำ)",
      "หายใจไม่ออก หรือหายใจลำบาก",
      "วิงเวียนศีรษะ หรือหน้ามืด",
      "เจ็บหน้าอก หรือแน่นหน้าอก",
      "รู้สึกหัวใจเต้นแรงผิดปกติ หรือใจสั่น",
      "รู้สึกว่าชีพจรเต้นผิดจังหวะ หรือไม่สม่ำเสมอ",
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "⚠️ สัญญาณอันตรายที่ควรพบแพทย์ทันที",
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          ...warningSigns.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "• ",
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  Expanded(
                    child: Text(
                      t,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeizureFirstAidPanel() {
    final Color color = const Color(0xFFC62828);
    Widget bullet(String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(Icons.circle, size: 6, color: Colors.black54),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, height: 1.35)),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "การปฐมพยาบาลเบื้องต้น (อาการชัก)",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "ป้องกันอันตราย:",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          bullet("อย่ายัดสิ่งของใดๆ เข้าปากผู้ป่วย"),
          bullet("รองศีรษะด้วยของนุ่มและเคลียร์ของแหลมคมรอบตัว"),
          const SizedBox(height: 10),
          const Text(
            "ช่วยให้หายใจสะดวก:",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          bullet("จับนอนตะแคง"),
          const SizedBox(height: 10),
          const Text(
            "สังเกตและจับเวลา:",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          bullet("เริ่มจับเวลาตั้งแต่เริ่มชัก"),
          const SizedBox(height: 10),
          const Text(
            "หากอาการชักยังไม่หยุด:",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          bullet("ชัก > 5 นาที หรือชักซ้ำ ๆ ให้รีบนำส่งโรงพยาบาล"),
        ],
      ),
    );
  }

  Widget _buildFallFirstAidPanel() {
    final Color color = const Color(0xFFC62828);
    Widget bullet(String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(Icons.circle, size: 6, color: Colors.black54),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, height: 1.35)),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "การช่วยเหลือเบื้องต้น (ล้ม)",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 10),
          bullet("ประเมินอาการบาดเจ็บ: ศีรษะ สะโพก แขนขา เลือดออก"),
          bullet("อย่าดึงให้ลุกทันที หากเจ็บมากหรือสงสัยกระดูกหัก"),
          bullet("ถ้าหายใจลำบาก/หมดสติ/เจ็บหน้าอก ให้โทรฉุกเฉิน"),
        ],
      ),
    );
  }

  Widget _buildHrPaneSwitcher() {
    return Row(
      children: [
        ChoiceChip(
          label: const Text('การเต้นของหัวใจ'),
          selected: _hrPane == HrPane.timeline,
          onSelected: (_) => setState(() => _hrPane = HrPane.timeline),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('โรคหัวใจ'),
          selected: _hrPane == HrPane.predict,
          onSelected: (_) => setState(() => _hrPane = HrPane.predict),
        ),
      ],
    );
  }

  Widget _buildAbnormalTimesPanel() {
    if (_abnormalHrEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 180),
        child: Scrollbar(
          thumbVisibility: true,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _abnormalHrEvents.length,
            separatorBuilder: (_, __) => const Divider(height: 12),
            itemBuilder: (_, i) {
              final ev = _abnormalHrEvents[i];
              final dt = ev.at.toLocal();
              final ts =
                  "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
                  "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "HR ผิดปกติ",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(ev.hr == null ? ts : "$ts  •  ${ev.hr} bpm"),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _comboGuideBox({
    required String title,
    required String note,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(note, style: TextStyle(color: color, fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isHR = widget.type == "heartrate";
    final bool isSpO2 = widget.type == "oxygen";
    final bool isStatus = widget.type == "status";

    final double? hrNow =
        (widget.value != null) ? widget.value!.toDouble() : null;
    final int? ageYears = _getAgeYears();
    final hrRange = _hrNormalRangeForAge(ageYears);
    final bool abnormal =
        hrNow != null && (hrNow < hrRange.min || hrNow > hrRange.max);

    final double? spo2Val =
        (isSpO2 && widget.value != null) ? widget.value!.toDouble() : null;
    final bool showOxygenPanel = isSpO2 && spo2Val != null && spo2Val < 95;
    final bool oxygenAbnormal =
        widget.value != null && (widget.value! > 100 || widget.value! < 95);

    // ✅ ปรับการตีความสถานะจากข้อความ
    final String statusRaw = (widget.unitorstatus ?? "Normal");
    final String statusLower = statusRaw.toLowerCase();
    final bool textSaysFall =
        statusLower.contains('fall') || statusLower.contains('ล้ม');
    final bool textSaysSeizure =
        statusLower.contains('seizure') || statusLower.contains('ชัก');

    final bool modelPredictFallHigh = _fallProb != null && _fallProb! >= 0.5;
    final bool showStatusPanel =
        isStatus && (textSaysFall || textSaysSeizure || modelPredictFallHigh);

    final double targetHeight = () {
      if (isHR) {
        if (_hrPane == HrPane.predict) {
          if (_predProb != null && _predProb! >= 0.5) return 460.0;
          return 260.0;
        } else {
          if (!abnormal) return 200.0;
          return _abnormalHrEvents.isEmpty ? 500.0 : 520.0;
        }
      }
      if (showOxygenPanel) return 260.0;
      if (isStatus) {
        if (modelPredictFallHigh) return 460.0;
        if (showStatusPanel) return textSaysSeizure ? 760.0 : 390.0;
      }
      return isSpO2 ? 130.0 : 180.0;
    }();

    // -------------------- สรุปสถานะเพื่อแสดงผล --------------------
    final bool isFallNow = modelPredictFallHigh || textSaysFall;

    // vital ล่าสุดจาก input
    final double? hrL = _latestHr();
    final double? spo2L = _latestSpo2();

    // อนุมาน "ชัก" ทำเฉพาะเมื่อ "ล้ม" แล้ว
    final seizureInfer =
        isFallNow
            ? _inferSeizureFromVitals(hrL, spo2L)
            : (flag: false, score: 0.0);

    // ถ้ามีสวิตช์ debug ชัก ให้อนุมานเป็น true ได้ (เปิดคอมเมนต์ด้านบน)
    // final bool forceSeizure = (kDebugForceSeizure == true);
    // final bool isSeizureNow = textSaysSeizure || forceSeizure || seizureInfer.flag;

    final bool isSeizureNow = textSaysSeizure || seizureInfer.flag;

    final String statusTitle =
        isSeizureNow
            ? "ชัก"
            : (modelPredictFallHigh
                ? "ล้ม (คาดการณ์)"
                : (textSaysFall ? "ล้ม" : "ปกติ"));

    final String imgPath = _selectStatusImage(
      isFall: (isSeizureNow ? false : isFallNow), // ถ้าชัก ให้รูปชักเด่น
      isSeizure: isSeizureNow,
    );
    // --------------------------------------------------------------

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      width: _targetWidth(context),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      height: targetHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.normal,
            ),
          ),
          const SizedBox(height: 8),

          if (isHR) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  abnormal ? "ผิดปกติ" : "ปกติ",
                  style: TextStyle(
                    color:
                        abnormal
                            ? Colors.red
                            : const Color.fromRGBO(56, 142, 60, 1),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${widget.value ?? '-'} ${widget.unitorstatus ?? ''}",
                  style: TextStyle(
                    color:
                        abnormal
                            ? Colors.red
                            : const Color.fromRGBO(56, 142, 60, 1),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "ช่วงปกติสำหรับอายุ${ageYears ?? '-'}ปี: ${hrRange.min}-${hrRange.max} bpm",
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),

            _buildHrPaneSwitcher(),
            const SizedBox(height: 8),

            if (_hrPane == HrPane.timeline) ...[
              if (abnormal) ...[
                _buildAbnormalTimesPanel(),
                const SizedBox(height: 12),
                _buildWarningSignsPanel(),
              ] else ...[
                const SizedBox.shrink(),
              ],
            ] else ...[
              if (_predProb != null) ...[
                const Divider(thickness: 1, color: Colors.white),
                const SizedBox(height: 4),
                _buildHrRiskPanel(_predProb!, widget.value),
              ] else
                _infoCard("ยังไม่มีค่าทำนาย (รอข้อมูลให้ครบ)"),
            ],
          ] else if (isSpO2) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  oxygenAbnormal ? "ผิดปกติ" : "ปกติ",
                  style: TextStyle(
                    color:
                        oxygenAbnormal
                            ? Colors.red
                            : const Color.fromRGBO(56, 142, 60, 1),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${widget.value ?? '-'} ${widget.unitorstatus ?? ''}",
                  style: TextStyle(
                    color:
                        oxygenAbnormal
                            ? Colors.red
                            : const Color.fromRGBO(56, 142, 60, 1),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            Builder(
              builder: (_) {
                double? hrForCombo;
                final dynamic _hrRaw =
                    _latestInput?['hr'] ??
                    _latestInput?['heart_rate'] ??
                    _latestInput?['current_hr'];
                if (_hrRaw is num) {
                  hrForCombo = _hrRaw.toDouble();
                } else if (_hrRaw is String) {
                  hrForCombo = double.tryParse(_hrRaw);
                }

                if (hrForCombo != null && spo2Val != null) {
                  final h = hrForCombo!;
                  final s = spo2Val;

                  if (h < 50 && s < 90) {
                    return _comboGuideBox(
                      title: "⚠️ ภาวะหัวใจล้มเหลว / ขาดออกซิเจน",
                      note: "HR < 50 bpm และ SpO₂ < 90% — ภาวะวิกฤต โทรฉุกเฉิน",
                      color: const Color(0xFFC62828),
                    );
                  }

                  if (h > 100 && s < 90) {
                    return _comboGuideBox(
                      title: "⚠️ ปอด/หัวใจอาจผิดปกติ",
                      note: "HR > 100 และ SpO₂ < 90% — พบแพทย์โดยเร็ว",
                      color: const Color(0xFFD32F2F),
                    );
                  }

                  if (h > 100 && s >= 98) {
                    return _comboGuideBox(
                      title: "ℹ️ ออกแรง/เครียดชั่วคราว",
                      note: "HR > 100 แต่ SpO₂ ปกติ — พักและวัดซ้ำ",
                      color: const Color(0xFFF57C00),
                    );
                  }

                  if (h < 60 && s >= 98) {
                    return _comboGuideBox(
                      title: "ℹ️ หัวใจเต้นช้าแต่ค่าออกซิเจนปกติ",
                      note: "อาจเป็นนักกีฬาหรือภาวะชั่วคราว",
                      color: const Color(0xFF1976D2),
                    );
                  }
                }

                if (showOxygenPanel && spo2Val != null) {
                  final s = spo2Val;
                  String level, note;
                  Color dotColor;

                  if (s >= 92 && s < 95) {
                    level = "ควรเฝ้าระวัง";
                    note = "ต่ำกว่า 95%: ควรติดต่อผู้ให้บริการด้านสุขภาพ";
                    dotColor = const Color(0xFFF9A825);
                  } else if (s >= 90 && s < 92) {
                    level = "อาจอันตราย";
                    note = "ต่ำกว่า 92%: ควรติดต่อแพทย์โดยเร็ว";
                    dotColor = const Color(0xFFF57C00);
                  } else if (s >= 88 && s < 90) {
                    level = "ฉุกเฉิน";
                    note = "ต่ำกว่า 90%: ต้องรักษาทันที";
                    dotColor = const Color(0xFFC62828);
                  } else if (s >= 80 && s < 88) {
                    level = "รุนแรง (COPD)";
                    note =
                        "ผู้ที่เป็นโรคปอดอุดกั้นเรื้อรัง 88–92% ปลอดภัย แต่ถ้าต่ำกว่า 88% ไปโรงพยาบาลทันที";
                    dotColor = const Color(0xFFD32F2F);
                  } else {
                    level = "อันตรายมาก";
                    note =
                        "ต่ำกว่า 80%: อันตรายต่ออวัยวะสำคัญ ไปโรงพยาบาลทันที";
                    dotColor = const Color(0xFFB71C1C);
                  }

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "ระดับความเสี่ยง: $level",
                              style: TextStyle(
                                color: dotColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          note,
                          style: TextStyle(
                            color: dotColor,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ] else if (isStatus) ...[
            Row(
              children: [
                Image.asset(imgPath, width: 100, height: 100),
                const SizedBox(width: 12),
                Text(
                  statusTitle,
                  style: TextStyle(
                    color:
                        (isSeizureNow || isFallNow)
                            ? Colors.red
                            : const Color.fromRGBO(56, 142, 60, 1),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (showStatusPanel) ...[
              const SizedBox(height: 12),
              const Divider(thickness: 1, color: Colors.white),
              const SizedBox(height: 6),

              if (isSeizureNow) ...[
                _infoCard(
                  "เกณฑ์สงสัยชัก (หลังล้ม): "
                  "${hrL != null ? 'HR=${hrL.toStringAsFixed(0)} bpm  ' : ''}"
                  "${spo2L != null ? 'SpO₂=${spo2L.toStringAsFixed(0)}%  ' : ''}"
                  "• seizureScore=${seizureInfer.score.toStringAsFixed(2)}",
                ),
                const SizedBox(height: 8),
                _buildSeizureFirstAidPanel(),
              ] else if (modelPredictFallHigh) ...[
                _infoCard(
                  "ความน่าจะเป็นการล้มจากเฟรมล่าสุด: ${_fallProb?.toStringAsFixed(2) ?? '-'}",
                ),
                const SizedBox(height: 8),
                _buildFallFirstAidPanel(),
              ] else if (textSaysFall) ...[
                _buildFallFirstAidPanel(),
              ],
            ],
          ],
        ],
      ),
    );
  }
}
