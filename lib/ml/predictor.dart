// lib/ml/predictor.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

class HeartPredictor {
  late final Interpreter _interpreter;
  late final List<String> _features;
  late final String _scalerType;
  late final List<double> _mean, _scale, _dataMin, _dataMax, _frange;

  static Future<HeartPredictor> create() async {
    final p = HeartPredictor();
    p._interpreter = await Interpreter.fromAsset(
      'assets/models/mlp_best.tflite',
    );

    final fTxt = await rootBundle.loadString('assets/models/features.json');
    p._features = List<String>.from(json.decode(fTxt));

    final sTxt = await rootBundle.loadString('assets/models/scaler.json');
    final s = json.decode(sTxt);
    p._scalerType = s['type'];
    if (p._scalerType == 'standard') {
      p._mean = List<double>.from(
        (s['mean'] as List).map((e) => (e as num).toDouble()),
      );
      p._scale = List<double>.from(
        (s['scale'] as List).map((e) => (e as num).toDouble()),
      );
    } else if (p._scalerType == 'minmax') {
      p._dataMin = List<double>.from(
        (s['data_min'] as List).map((e) => (e as num).toDouble()),
      );
      p._dataMax = List<double>.from(
        (s['data_max'] as List).map((e) => (e as num).toDouble()),
      );
      final fr = (s['feature_range'] as List);
      p._frange = [(fr[0] as num).toDouble(), (fr[1] as num).toDouble()];
    } else {
      throw Exception('Unknown scaler type: ${p._scalerType}');
    }
    return p;
  }

  double predictProb(Map<String, num> inputMap) {
    // เรียงฟีเจอร์ตาม features.json
    final x = List<double>.generate(
      _features.length,
      (i) => (inputMap[_features[i]] ?? 0).toDouble(),
    );

    // scale
    final xs = List<double>.from(x);
    if (_scalerType == 'standard') {
      for (var i = 0; i < xs.length; i++) {
        xs[i] = (xs[i] - _mean[i]) / _scale[i];
      }
    } else {
      for (var i = 0; i < xs.length; i++) {
        final denom = (_dataMax[i] - _dataMin[i]);
        final norm = denom == 0 ? 0.0 : (xs[i] - _dataMin[i]) / denom;
        xs[i] = norm * (_frange[1] - _frange[0]) + _frange[0];
      }
    }

    // infer: assume input [1, n], output [1, 1]
    final input = [xs];
    final output = List.filled(1 * 1, 0.0).reshape([1, 1]);
    _interpreter.run(input, output);
    return (output[0][0] as double);
  }
}
