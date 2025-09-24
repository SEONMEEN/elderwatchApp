// detailbox.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

/// ------------------------------------------------------------
///  Predict cache (โหลดโมเดล/สเกล/ฟีเจอร์ ครั้งเดียว ใช้ร่วมกันทุกการ์ด)
/// ------------------------------------------------------------
class _PredictorCache {
  static Interpreter? _interpreter;
  static List<String>?
  _features; // e.g. ["age","sex","cp","fbs","exang","thalach"]
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
      // --------- โหลด TFLite (เผื่อ magic อยู่ offset=4) ----------
      const modelAsset =
          'assets/models/mlp_best.tflite'; // << ใช้ชื่อไฟล์ที่คุณวางจริง
      final bd = await rootBundle.load(modelAsset);
      final u8 = bd.buffer.asUint8List();

      String hex(int n) => n.toRadixString(16).padLeft(2, '0');
      final headHex = u8.take(16).map(hex).join(' ');
      final magic0 =
          (u8.length >= 4) ? String.fromCharCodes(u8.sublist(0, 4)) : '';
      final magic4 =
          (u8.length >= 8) ? String.fromCharCodes(u8.sublist(4, 8)) : '';
      debugPrint(
        'TFL bytes=${u8.length}  head=$headHex  magic0="$magic0" magic4="$magic4"',
      );

      _interpreter?.close();
      _interpreter = Interpreter.fromBuffer(u8);
      debugPrint(
        'Interpreter OK: in=${_interpreter!.getInputTensors().length} out=${_interpreter!.getOutputTensors().length}',
      );

      // --------- โหลด features ----------
      final fTxt = await rootBundle.loadString('assets/models/features.json');
      final dynamic rawF = json.decode(fTxt);
      if (rawF is List) {
        _features = rawF.map((e) => e.toString()).toList();
      } else if (rawF is Map && rawF['features'] is List) {
        // รองรับไฟล์เก่า
        _features = List<String>.from(rawF['features']);
      } else {
        throw Exception('features.json รูปแบบไม่ถูกต้อง');
      }
      debugPrint('Features: ${_features}');

      // --------- โหลด scaler ----------
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
      debugPrint('Scaler: type=$_scalerType');
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

  /// สเกล 1 แถว ตามชนิด scaler
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

  /// คำนวณความน่าจะเป็น (0..1) จาก map คุณสมบัติ (key ตาม features.json)
  static double? predictProb(Map<String, dynamic> inputMap) {
    if (_interpreter == null || _features == null) return null;

    // เตรียมเวคเตอร์ตามลำดับชื่อฟีเจอร์
    final row = <double>[];
    for (final f in _features!) {
      final v = inputMap[f];
      if (v == null) return null; // ยังไม่ครบ
      row.add(_asD(v));
    }

    final x = transform(row);
    final input = Float32List.fromList(x);
    final shape = _interpreter!.getInputTensors().first.shape; // [1, n]
    if (shape.length == 2 && shape[0] == 1 && shape[1] != x.length) {
      debugPrint('ขนาดฟีเจอร์ไม่ตรงกับโมเดล: need ${shape[1]} got ${x.length}');
      return null;
    }

    // run
    final output = List.filled(1, 0.0).reshape([1, 1]);
    _interpreter!.run(input.reshape([1, x.length]), output);
    final p = output[0][0];
    // safety clamp
    return p.isNaN ? null : p.clamp(0.0, 1.0);
  }
}

/// ------------------------------------------------------------
///  Widget แสดงกล่องค่าต่าง ๆ + ทำนาย (บนสุด)
/// ------------------------------------------------------------
class Detailbox extends StatefulWidget {
  final String title;
  final double width;
  final num? value; // ค่าที่โชว์ในบรรทัดใหญ่ (HR/SpO2)
  final String? image; // ถ้ามี รูป Event
  final String? unitorstatus; // หน่วย หรือ "Normal/Fall/Seizure"
  final Color color;
  final String type; // 'heartrate' | 'oxygen' | 'status'
  final bool enablePrediction; // เปิด/ปิด แถบค่าทำนาย

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

class _DetailboxState extends State<Detailbox> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Map<String, dynamic>?
  _latestInput; // จาก Firestore heart_assessments/{uid}.input
  double? _predProb; // 0..1
  String? _err;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _initAll() async {
    await _PredictorCache.ensureLoaded();
    if (!mounted) return;

    // subscribe Firestore (ใช้ผู้ใช้ที่ล็อกอิน)
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
            setState(() {
              _latestInput = input.isEmpty ? null : input;
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

    // รันครั้งแรกก็ลองทำนาย (เผื่อ interpreter โหลดทันที)
    _recompute();
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            const SizedBox(height: 6),

            // ===== แถบค่าทำนาย (กลางบนสุด) =====
            if (widget.enablePrediction)
              Center(
                child: Text(
                  !_ready
                      ? 'กำลังโหลดโมเดล...'
                      : (_err != null)
                      ? _err!
                      : (_predProb == null
                          ? 'ยังไม่มีค่าทำนาย'
                          : 'ค่าทำนาย: ${_predProb!.toStringAsFixed(3)} '),
                  style: TextStyle(
                    color:
                        _predProb == null
                            ? Colors.grey
                            : (_predProb! >= 0.5 ? Colors.red : Colors.green),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 10),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Color.fromARGB(255, 0, 0, 0),
                    fontSize: 20,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ===== เนื้อหาเดิม =====
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 20),
                if (widget.image != null) ...[
                  Image.asset(widget.image!, width: 120, height: 140),
                  const SizedBox(width: 10),
                  Text(
                    (widget.unitorstatus != null &&
                            widget.unitorstatus == "Normal")
                        ? "ปกติ"
                        : (widget.unitorstatus != null &&
                            widget.unitorstatus == "Fall")
                        ? "ล้ม"
                        : "ชัก",
                    style: TextStyle(
                      color:
                          (widget.unitorstatus != null &&
                                  widget.unitorstatus == "Normal")
                              ? const Color.fromRGBO(56, 142, 60, 1)
                              : Colors.red,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      if (widget.type == "heartrate") ...[
                        Text(
                          (widget.value != null && widget.value! > 100)
                              ? "ผิดปกติ"
                              : "ปกติ",
                          style: TextStyle(
                            color:
                                (widget.value != null && widget.value! > 100)
                                    ? Colors.red
                                    : const Color.fromRGBO(56, 142, 60, 1),
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "${widget.value ?? '-'} ${widget.unitorstatus ?? ''}",
                          style: TextStyle(
                            color:
                                (widget.value != null && widget.value! > 100)
                                    ? Colors.red
                                    : const Color.fromRGBO(56, 142, 60, 1),
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 50),
                      ],
                      if (widget.type == "oxygen") ...[
                        Text(
                          (widget.value != null &&
                                  (widget.value! > 100 || widget.value! < 90))
                              ? "ผิดปกติ"
                              : "ปกติ",
                          style: TextStyle(
                            color:
                                (widget.value != null &&
                                        (widget.value! > 100 ||
                                            widget.value! < 90))
                                    ? Colors.red
                                    : const Color.fromRGBO(56, 142, 60, 1),
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "${widget.value ?? '-'} ${widget.unitorstatus ?? ''}",
                          style: TextStyle(
                            color:
                                (widget.value != null &&
                                        (widget.value! > 100 ||
                                            widget.value! < 90))
                                    ? Colors.red
                                    : const Color.fromRGBO(56, 142, 60, 1),
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
