import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/desk_pose.dart';

/// Placeholder for ARCore SLAM: integrates **linear** acceleration with heavy damping
/// to nudge a virtual phone on the desk plane (X–Z). Axis mapping is device-dependent.
class MotionDeskTracker {
  MotionDeskTracker({
    this.scale = 0.018,
    this.damping = 0.9,
    this.xLimit = 0.38,
    this.zLimit = 0.24,
  });

  final double scale;
  final double damping;
  final double xLimit;
  final double zLimit;

  StreamSubscription<UserAccelerometerEvent>? _sub;
  DateTime? _lastT;

  double _x = 0;
  double _z = 0;
  double _vx = 0;
  double _vz = 0;

  DeskPose get pose => DeskPose(_x, 0.02, _z);

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
          debugPrint('MotionDeskTracker: $e\n$st');
        },
        cancelOnError: false,
      );
    } catch (e, st) {
      _running = false;
      debugPrint('MotionDeskTracker start failed: $e\n$st');
    }
  }

  void _onAccel(UserAccelerometerEvent e) {
    final now = DateTime.now();
    final prev = _lastT;
    _lastT = now;
    final dt = prev == null ? 0.02 : now.difference(prev).inMicroseconds / 1e6;
    if (dt <= 0 || dt > 0.5) return;

    _vx = (_vx + e.x * dt * scale) * damping;
    _vz = (_vz + e.z * dt * scale) * damping;
    _x = (_x + _vx).clamp(-xLimit, xLimit);
    _z = (_z + _vz).clamp(-zLimit, zLimit);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _running = false;
  }

  void resetOrigin() {
    _x = 0;
    _z = 0;
    _vx = 0;
    _vz = 0;
  }
}
