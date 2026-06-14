import 'dart:async';
import 'dart:math' show sqrt;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// 집중 세션 중 사용자 가속도(중력 제거)로 '손으로 폰을 쥐고 움직이는' 정도를 추정합니다.
/// 유튜브·릴스·게임 등과 같이 **스크롤/조작이 잦을 때** 점수를 크게 깎습니다.
/// (앱 사용 종류를 직접 식별하지는 않습니다.)
class MotionActivityMonitor {
  MotionActivityMonitor();

  VoidCallback? onActivityChanged;

  StreamSubscription<UserAccelerometerEvent>? _sub;
  final List<double> _magSamples = [];
  static const int _maxSamples = 45;
  double _stress01 = 0;
  DateTime? _lastNotify;

  /// 0…1, 높을수록 손떨림·스크롤에 가깝다고 가정.
  double get stress01 => _stress01;

  /// Focus Score에서 빼는 점수(최대 ~40).
  double get penaltyPoints => _stress01 * 40.0;

  bool get isRunning => _sub != null;

  Future<void> start() async {
    if (_sub != null) return;
    _magSamples.clear();
    _stress01 = 0;
    try {
      _sub = userAccelerometerEventStream(samplingPeriod: const Duration(milliseconds: 16)).listen(
        _onAccel,
        onError: (_, __) {},
        cancelOnError: false,
      );
    } catch (e, st) {
      debugPrint('MotionActivityMonitor start: $e\n$st');
    }
  }

  void _onAccel(UserAccelerometerEvent e) {
    final m = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    _magSamples.add(m);
    if (_magSamples.length > _maxSamples) {
      _magSamples.removeAt(0);
    }
    if (_magSamples.length < 12) return;

    var sum = 0.0;
    for (final v in _magSamples) {
      sum += v;
    }
    final mean = sum / _magSamples.length;
    double varAcc = 0;
    for (final v in _magSamples) {
      final d = v - mean;
      varAcc += d * d;
    }
    varAcc /= _magSamples.length;

    // 평균 크기 + 분산: 조용히 둔 폰 vs 스크롤/게임
    final meanStress = ((mean - 0.15) / 2.8).clamp(0.0, 1.0);
    final varStress = (varAcc / 1.8).clamp(0.0, 1.0);
    final next = (0.55 * meanStress + 0.45 * varStress).clamp(0.0, 1.0);
    _stress01 = next;
    final now = DateTime.now();
    final last = _lastNotify;
    if (last == null || now.difference(last).inMilliseconds >= 180) {
      _lastNotify = now;
      onActivityChanged?.call();
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _magSamples.clear();
    _stress01 = 0;
    onActivityChanged?.call();
  }
}
