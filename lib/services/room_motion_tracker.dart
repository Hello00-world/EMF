import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/desk_pose.dart';

/// 주변 스캔용: 가속도 적분으로 **넓은 범위**(수 m) 이동 추정. ARCore/SLAM 전 스텁.
class RoomMotionTracker {
  RoomMotionTracker({
    this.scale = 0.022,
    this.damping = 0.88,
    this.horizontalLimitM = 3.0,
    this.verticalLimitM = 1.0,
    this.referenceYM = 0.02,
  });

  final double scale;
  final double damping;
  final double horizontalLimitM;
  final double verticalLimitM;
  final double referenceYM;

  StreamSubscription<UserAccelerometerEvent>? _sub;
  DateTime? _lastT;

  double _x = 0;
  double _y = 0.02;
  double _z = 0;
  double _vx = 0;
  double _vy = 0;
  double _vz = 0;

  DeskPose get pose => DeskPose(_x, _y, _z);

  bool _running = false;
  bool get isRunning => _running;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _lastT = null;
    try {
      _sub = userAccelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 20),
      ).listen(
        _onAccel,
        onError: (Object e, StackTrace st) {
          debugPrint('RoomMotionTracker: $e\n$st');
        },
        cancelOnError: false,
      );
    } catch (e, st) {
      _running = false;
      debugPrint('RoomMotionTracker start failed: $e\n$st');
    }
  }

  void _onAccel(UserAccelerometerEvent e) {
    final now = DateTime.now();
    final prev = _lastT;
    _lastT = now;
    final dt = prev == null ? 0.02 : now.difference(prev).inMicroseconds / 1e6;
    if (dt <= 0 || dt > 0.5) return;

    _vx = (_vx + e.x * dt * scale) * damping;
    _vy = (_vy + e.y * dt * scale * 0.6) * damping;
    _vz = (_vz + e.z * dt * scale) * damping;
    _x = _x + _vx;
    _z = _z + _vz;
    _y = referenceYM + (_y - referenceYM + _vy).clamp(-verticalLimitM, verticalLimitM);

    final r = math.sqrt(_x * _x + _z * _z);
    if (r > horizontalLimitM) {
      final s = horizontalLimitM / r;
      _x *= s;
      _z *= s;
      _vx *= 0.5;
      _vz *= 0.5;
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _running = false;
  }

  void resetOrigin() {
    _x = 0;
    _y = referenceYM;
    _z = 0;
    _vx = 0;
    _vy = 0;
    _vz = 0;
  }
}
