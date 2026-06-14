import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/magnetometer_snapshot.dart';
import '../signal_processing/fft_utility.dart';
import '../signal_processing/high_pass_filter.dart';
import '../signal_processing/icnirp_mapper.dart';
import '../signal_processing/moving_average_filter.dart';
import '../signal_processing/rolling_vector_mean.dart';

/// Thrown when hardware / platform denies magnetometer access.
class SensorUnavailableException implements Exception {
  SensorUnavailableException(this.message);
  final String message;

  @override
  String toString() => 'SensorUnavailableException: $message';
}

/// Magnetometer pipeline: user figure-8 offset, 5 s rolling vector mean, per-axis HPF,
/// magnitude, N=10 moving average, rolling variance, 128-pt FFT (line band), ICNIRP-style UX band.
///
/// Requests ~100 Hz sampling when the platform allows ([sensorInterval] default 10 ms).
class SensorService {
  SensorService({
    this.rollingMeanWindow = const Duration(seconds: 5),
    this.movingAverageWindow = 10,
    this.saturationMicroTesla = 1000,
    this.sensorInterval = const Duration(milliseconds: 10),
    this.highPassCutoffHz = 0.08,
    this.fftSize = 128,
  })  : assert(movingAverageWindow > 0),
        assert(fftSize > 0 && (fftSize & (fftSize - 1)) == 0, 'fftSize must be power of 2'),
        _rolling = RollingVectorMean(window: rollingMeanWindow),
        _hpX = HighPassFilter(cutoffHz: highPassCutoffHz, sampleRateHz: 100),
        _hpY = HighPassFilter(cutoffHz: highPassCutoffHz, sampleRateHz: 100),
        _hpZ = HighPassFilter(cutoffHz: highPassCutoffHz, sampleRateHz: 100),
        _ma = MovingAverageFilter(movingAverageWindow) {
    _hpX.setSampleRateHz(100, cutoffHz: highPassCutoffHz);
    _hpY.setSampleRateHz(100, cutoffHz: highPassCutoffHz);
    _hpZ.setSampleRateHz(100, cutoffHz: highPassCutoffHz);
  }

  final Duration rollingMeanWindow;
  final int movingAverageWindow;
  final double saturationMicroTesla;
  final Duration sensorInterval;
  final double highPassCutoffHz;
  final int fftSize;

  final _controller = StreamController<MagnetometerSnapshot>.broadcast();
  final _userMessageController = StreamController<String>.broadcast();

  StreamSubscription<MagnetometerEvent>? _sub;
  DateTime? _lastSampleTime;

  double _userOffX = 0;
  double _userOffY = 0;
  double _userOffZ = 0;

  final RollingVectorMean _rolling;
  final HighPassFilter _hpX;
  final HighPassFilter _hpY;
  final HighPassFilter _hpZ;
  final MovingAverageFilter _ma;

  final List<double> _varianceWindow = [];
  static const int _varianceWindowLen = 32;

  final List<double> _fftBuffer = [];
  final List<double> _dtHistory = [];
  static const int _dtHistoryMax = 64;

  double _estimatedFs = 100.0;
  bool _warnedLowFsForFft = false;

  Stream<MagnetometerSnapshot> get snapshots => _controller.stream;
  Stream<String> get userMessages => _userMessageController.stream;

  bool get isRunning => _sub != null;

  /// Hard-iron / figure-8 calibration offset in sensor units (typically µT).
  void setUserCalibrationOffset(double x, double y, double z) {
    _userOffX = x;
    _userOffY = y;
    _userOffZ = z;
    _resetSignalBuffers();
    _userMessageController.add('사용자 자기장 보정 오프셋이 적용되었습니다.');
  }

  /// Clears figure-8 offsets (e.g. before re-calibration). Does not post a notice.
  void clearSessionCalibration() {
    _userOffX = _userOffY = _userOffZ = 0;
    _resetSignalBuffers();
  }

  void _resetSignalBuffers() {
    _rolling.clear();
    _hpX.reset();
    _hpY.reset();
    _hpZ.reset();
    _ma.reset();
    _fftBuffer.clear();
    _varianceWindow.clear();
  }

  Future<void> start() async {
    if (_sub != null) return;
    _lastSampleTime = null;
    _dtHistory.clear();
    _warnedLowFsForFft = false;
    try {
      _sub = magnetometerEventStream(samplingPeriod: sensorInterval).listen(
        _onMagnetometer,
        onError: (Object e, StackTrace st) {
          debugPrint('SensorService stream error: $e\n$st');
          _userMessageController.add(
            '자기장 센서를 읽는 중 오류가 발생했습니다. 기기를 재시작하거나 설정에서 권한/센서 사용을 확인해 주세요.',
          );
        },
        cancelOnError: false,
      );
    } catch (e, st) {
      debugPrint('SensorService start failed: $e\n$st');
      _userMessageController.add(
        '이 기기에서 자기장 센서를 사용할 수 없거나 접근이 거부되었습니다. 다른 기기에서 시도하거나 앱을 업데이트해 주세요.',
      );
      throw SensorUnavailableException(e.toString());
    }
  }

  void _updateSampleRateEstimate(DateTime now) {
    final prev = _lastSampleTime;
    _lastSampleTime = now;
    if (prev == null) return;
    final dt = now.difference(prev).inMicroseconds / 1e6;
    if (dt > 1e-4 && dt < 1.0) {
      _dtHistory.add(dt);
      if (_dtHistory.length > _dtHistoryMax) {
        _dtHistory.removeAt(0);
      }
      final meanDt = _dtHistory.reduce((a, b) => a + b) / _dtHistory.length;
      _estimatedFs = (1.0 / meanDt).clamp(5.0, 400.0);
      _hpX.setSampleRateHz(_estimatedFs, cutoffHz: highPassCutoffHz);
      _hpY.setSampleRateHz(_estimatedFs, cutoffHz: highPassCutoffHz);
      _hpZ.setSampleRateHz(_estimatedFs, cutoffHz: highPassCutoffHz);
    }
  }

  void _onMagnetometer(MagnetometerEvent event) {
    try {
      final now = DateTime.now();
      _updateSampleRateEstimate(now);

      final bx = event.x - _userOffX;
      final by = event.y - _userOffY;
      final bz = event.z - _userOffZ;

      _rolling.push(now, bx, by, bz);
      final (mx, my, mz) = _rolling.demean(bx, by, bz);

      final fx = _hpX.push(mx);
      final fy = _hpY.push(my);
      final fz = _hpZ.push(mz);
      final instantMag = RollingVectorMean.magnitude(fx, fy, fz);

      if (instantMag >= saturationMicroTesla) {
        _userMessageController.add('강한 자석이 감지되었습니다. 측정값이 포화 상태일 수 있습니다.');
        final varSat = _rollingVariance(instantMag);
        _emit(_snapshotFor(
          now: now,
          filteredMag: instantMag,
          varianceMicroTeslaSq: varSat,
          dx: fx,
          dy: fy,
          dz: fz,
          saturated: true,
          linePct: 0,
          domHz: 0,
          fftReady: false,
        ));
        return;
      }

      final filtered = _ma.push(instantMag);
      final varSq = _rollingVariance(filtered);

      var linePct = 0.0;
      var domHz = 0.0;
      var fftReady = false;

      _fftBuffer.add(filtered);
      if (_fftBuffer.length > fftSize) {
        _fftBuffer.removeAt(0);
      }
      if (_fftBuffer.length == fftSize) {
        fftReady = true;
        final re = List<double>.from(_fftBuffer);
        final im = List<double>.filled(fftSize, 0);
        fftInPlace(re, im);
        if (_estimatedFs >= 120) {
          final k50 = math.max(1, (50 * fftSize / _estimatedFs).floor());
          final k60 = math.min((fftSize ~/ 2) - 1, (60 * fftSize / _estimatedFs).ceil());
          linePct = bandEnergyRatio(re: re, im: im, kLow: k50, kHigh: k60);
        } else {
          if (!_warnedLowFsForFft) {
            _warnedLowFsForFft = true;
            _userMessageController.add(
              '샘플링 속도가 낮아 50–60 Hz 전력선 대역 FFT 해상도가 제한됩니다. 가능하면 더 빠른 자기장 스트림을 사용하는 기기에서 시도해 주세요.',
            );
          }
          linePct = 0;
        }
        final kb = dominantBin(re, im);
        domHz = binToHz(kb, _estimatedFs, fftSize);
      }

      _emit(_snapshotFor(
        now: now,
        filteredMag: filtered,
        varianceMicroTeslaSq: varSq,
        dx: fx,
        dy: fy,
        dz: fz,
        saturated: false,
        linePct: linePct,
        domHz: domHz,
        fftReady: fftReady,
      ));
    } catch (e, st) {
      debugPrint('SensorService processing error: $e\n$st');
      _userMessageController.add('센서 데이터 처리 중 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.');
    }
  }

  MagnetometerSnapshot _snapshotFor({
    required DateTime now,
    required double filteredMag,
    required double varianceMicroTeslaSq,
    required double dx,
    required double dy,
    required double dz,
    required bool saturated,
    required double linePct,
    required double domHz,
    required bool fftReady,
  }) {
    return MagnetometerSnapshot(
      timestamp: now,
      filteredMagnitudeMicroTesla: filteredMag,
      varianceMicroTeslaSq: varianceMicroTeslaSq,
      dx: dx,
      dy: dy,
      dz: dz,
      isSaturated: saturated,
      lineNoisePercent: linePct,
      dominantFrequencyHz: domHz,
      fftReady: fftReady,
      riskLevel: IcnirpMapper.riskLevel(filteredMag),
      icnirpBand: IcnirpMapper.bandForMagnitude(filteredMag),
      estimatedSampleRateHz: _estimatedFs,
    );
  }

  void _emit(MagnetometerSnapshot s) {
    if (!_controller.isClosed) _controller.add(s);
  }

  double _rollingVariance(double latestFiltered) {
    _varianceWindow.add(latestFiltered);
    if (_varianceWindow.length > _varianceWindowLen) {
      _varianceWindow.removeAt(0);
    }
    if (_varianceWindow.length < 2) return 0;
    final mean = _average(_varianceWindow);
    var acc = 0.0;
    for (final v in _varianceWindow) {
      final d = v - mean;
      acc += d * d;
    }
    return acc / (_varianceWindow.length - 1);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    unawaited(stop());
    unawaited(_controller.close());
    unawaited(_userMessageController.close());
  }

  static double _average(List<double> xs) {
    if (xs.isEmpty) return 0;
    var s = 0.0;
    for (final x in xs) {
      s += x;
    }
    return s / xs.length;
  }
}
