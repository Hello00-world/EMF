import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/desk_pose.dart';
import '../models/emf_sample.dart';
import '../models/environment_baseline_snapshot.dart';
import '../models/focus_environment_preset.dart';
import '../models/focus_zone_cell.dart';
import '../models/magnetometer_snapshot.dart';
import '../services/calibration_store.dart';
import '../services/desk_heatmap_store.dart';
import '../services/emf_interference_advice.dart';
import '../services/emf_batch_codec.dart';
import '../services/focus_stats_store.dart';
import '../services/emf_priority_ranking.dart';
import '../services/gemini_analysis_service.dart';
import '../services/motion_activity_monitor.dart';
import '../services/motion_desk_tracker.dart';
import '../services/room_focus_scan_store.dart';
import '../services/room_motion_tracker.dart';
import '../services/sensor_service.dart';

/// Central state: EMF samples, Quantum Space poses, heatmap, optional Gemini batch reports.
class EnvironmentProvider extends ChangeNotifier {
  EnvironmentProvider({
    SensorService? sensorService,
    GeminiAnalysisService? gemini,
    CalibrationStore? calibrationStore,
    MotionDeskTracker? motionTracker,
    this.geminiBatchSize = 100,
    double deskWidthM = 0.9,
    double deskDepthM = 0.55,
  })  : _sensor = sensorService ?? SensorService(),
        _gemini = gemini ?? GeminiAnalysisService(),
        _calibrationStore = calibrationStore ?? CalibrationStore(),
        _motion = motionTracker ?? MotionDeskTracker(),
        _heatmap = DeskHeatmapStore(widthM: deskWidthM, depthM: deskDepthM) {
    _handMotion.onActivityChanged = () {
      if (_disposed) return;
      notifyListeners();
    };
    unawaited(_hydrateFocusStats());
  }

  bool _disposed = false;

  final FocusStatsStore _focusStats = FocusStatsStore();

  /// 누적 집중 시간(초) — [FocusStatsStore] 기준.
  int focusTotalSeconds = 0;
  int focusTodaySeconds = 0;
  int focusCompletedSessions = 0;

  /// 현재 집중 세션 경과(세션 비활성 시 0).
  Duration get focusSessionElapsed {
    if (!focusSessionActive || _focusSessionStartedAt == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(_focusSessionStartedAt!);
  }

  /// 포모도로 스타일 목표(분) — UI 진행 링용, 강제 종료 없음.
  static const int focusGoalMinutes = 25;

  final SensorService _sensor;
  final GeminiAnalysisService _gemini;
  final CalibrationStore _calibrationStore;
  final MotionDeskTracker _motion;
  final RoomMotionTracker _roomMotion = RoomMotionTracker();
  final RoomFocusScanStore _roomScan = RoomFocusScanStore();
  final MotionActivityMonitor _handMotion = MotionActivityMonitor();
  final DeskHeatmapStore _heatmap;

  /// 주변 스캔 격자 범위(수평 m). 요청 10m 대비 센서·적분 한계로 6m.
  static const double roomScanSpanM = 6.0;
  static const double roomScanHeightM = 2.0;

  bool roomScanActive = false;

  final int geminiBatchSize;

  final List<EmfSample> emfSeries = [];
  final List<DeskPose> poseSeries = [];

  String? lastAiReport;
  final List<String> notices = [];

  StreamSubscription<MagnetometerSnapshot>? _magSub;
  StreamSubscription<String>? _msgSub;
  int _sinceLastGemini = 0;

  MagnetometerSnapshot? latestSnapshot;
  DeskPose virtualPhonePose = const DeskPose(0, 0.02, 0);

  bool sensorRunning = false;

  /// 집중 세션: [공부 시작] 후 주기적으로 Focus Score를 검사.
  bool focusSessionActive = false;

  /// UI가 다이얼로그를 띄워야 할 때 true (응답 후 [acknowledgeFocusAlert]).
  bool pendingFocusAlert = false;

  /// [pendingFocusAlert]용 안내 문구.
  String get focusDropAdviceText => buildFocusDropAdvice(
        focusScore: currentFocusScore,
        snapshot: latestSnapshot,
        heatmap: _heatmap,
        userPose: virtualPhonePose,
      );

  /// [FocusEnvironmentPreset.standard] 기준(60점) — 문서·UI 참고용.
  static const double focusAlertScoreThreshold = 60.0;

  /// 집중 알림 민감도. [effectiveFocusAlertThreshold]는 프리셋별(일반 60 / 민감 70 등).
  FocusEnvironmentPreset environmentPreset = FocusEnvironmentPreset.standard;

  double get effectiveFocusAlertThreshold => environmentPreset.focusAlertThreshold;

  void setEnvironmentPreset(FocusEnvironmentPreset p) {
    if (environmentPreset == p) return;
    environmentPreset = p;
    notifyListeners();
  }

  /// 알림을 다시 켤 수 있도록: 점수가 (임계 + 여유) 위로 올라온 뒤에만 true.
  bool _focusAlertArmed = true;

  /// 알림 재발을 위해 점수가 임계값보다 얼마나 올라와야 '해결'로 볼지(히스테리시스).
  static const double focusAlertRecoverHysteresis = 4.0;

  /// "지금 상태를 기준으로 저장" 후 [baselineComparisonSummary]와 비교.
  EnvironmentBaselineSnapshot? baselineSnapshot;

  void captureEnvironmentBaseline() {
    if (emfSeries.isEmpty) {
      notices.add('기준을 저장하려면 측정이 켜져 있고 샘플이 있어야 합니다.');
      notifyListeners();
      return;
    }
    final tail = emfSeries.length > 120 ? emfSeries.sublist(emfSeries.length - 120) : emfSeries;
    final avgM = tail.map((e) => e.filteredMagnitudeMicroTesla).reduce((a, b) => a + b) / tail.length;
    final avgV = tail.map((e) => e.variance).reduce((a, b) => a + b) / tail.length;
    final avgL = tail.map((e) => e.lineNoisePercent).reduce((a, b) => a + b) / tail.length;
    baselineSnapshot = EnvironmentBaselineSnapshot(
      capturedAt: DateTime.now(),
      avgEmfMicroTesla: avgM,
      avgVariance: avgV,
      avgLineNoisePercent: avgL,
      baseFocusScore: _baseFocusScore,
      heatmapCompleteness: _heatmap.completeness,
    );
    notices.add('현재 환경을 기준선으로 저장했습니다. 정리 후 여기서 변화를 확인해 보세요.');
    notifyListeners();
  }

  /// 기준선 대비 변화 요약(손 패널티 제외한 베이스 Focus Score 기준).
  String? get baselineComparisonSummary {
    final b = baselineSnapshot;
    if (b == null || emfSeries.isEmpty) return null;
    final tail = emfSeries.length > 120 ? emfSeries.sublist(emfSeries.length - 120) : emfSeries;
    final avgM = tail.map((e) => e.filteredMagnitudeMicroTesla).reduce((a, b) => a + b) / tail.length;
    final avgV = tail.map((e) => e.variance).reduce((a, b) => a + b) / tail.length;
    final avgL = tail.map((e) => e.lineNoisePercent).reduce((a, b) => a + b) / tail.length;
    final dM = avgM - b.avgEmfMicroTesla;
    final dV = avgV - b.avgVariance;
    final dL = avgL - b.avgLineNoisePercent;
    final dScore = _baseFocusScore - b.baseFocusScore;
    final dMap = (_heatmap.completeness - b.heatmapCompleteness) * 100;
    return 'EMF(평균) ${dM >= 0 ? '+' : ''}${dM.toStringAsFixed(2)} µT · '
        '분산 ${dV >= 0 ? '+' : ''}${dV.toStringAsFixed(1)} · '
        '전력선% ${dL >= 0 ? '+' : ''}${dL.toStringAsFixed(1)} · '
        'Focus(베이스) ${dScore >= 0 ? '+' : ''}${dScore.toStringAsFixed(1)} · '
        '맵 ${dMap >= 0 ? '+' : ''}${dMap.toStringAsFixed(1)}%p';
  }

  /// 3D·대시보드 공통: 가까운 강한 소스 우선.
  List<EmfPriorityItem> get priorityInterventions => rankDeviceLevelPeaks(
        heatmap: _heatmap,
        userPose: virtualPhonePose,
      );

  /// 집중 세션 중 손떨림 패널티(0~40) — UI 표시용.
  double get handheldMotionPenalty => focusSessionActive ? _handMotion.penaltyPoints : 0;

  Timer? _focusSessionTimer;
  DateTime? _focusSessionStartedAt;

  Future<void> _hydrateFocusStats() async {
    try {
      final s = await _focusStats.load();
      if (_disposed) return;
      focusTotalSeconds = s.totalSeconds;
      focusTodaySeconds = s.todaySeconds;
      focusCompletedSessions = s.completedSessions;
      notifyListeners();
    } catch (e, st) {
      debugPrint('_hydrateFocusStats: $e\n$st');
    }
  }

  void _finalizeFocusSessionTime() {
    if (_focusSessionStartedAt == null) return;
    final elapsed = DateTime.now().difference(_focusSessionStartedAt!);
    _focusSessionStartedAt = null;
    unawaited(
      _focusStats.addCompletedSession(elapsed).then((_) => _hydrateFocusStats()),
    );
  }

  /// True after [bootstrapCalibrationState] has finished (disk read).
  bool bootstrapDone = false;

  /// True when saved figure-8 offsets exist or fresh calibration completed.
  bool calibrationReady = false;

  double get deskWidthM => _heatmap.widthM;
  double get deskDepthM => _heatmap.depthM;

  /// Call once at app start (see [_SessionRouter]).
  Future<void> bootstrapCalibrationState() async {
    try {
      await loadCalibrationFromDisk();
      calibrationReady = await isCalibrationDone();
    } catch (e, st) {
      debugPrint('bootstrapCalibrationState: $e\n$st');
      calibrationReady = false;
    } finally {
      bootstrapDone = true;
      notifyListeners();
    }
  }

  /// Figure-8 screen: persist offsets and allow main UI.
  Future<void> completeSessionCalibration(double ox, double oy, double oz) async {
    await saveCalibrationOffset(ox, oy, oz);
    calibrationReady = true;
    notices.add('8자 보정이 저장되었습니다. 측정을 시작할 수 있습니다.');
    notifyListeners();
  }

  /// AppBar: wipe disk offsets, reset pipeline, show calibration again.
  Future<void> redoCalibration() async {
    await stopSensors();
    await _calibrationStore.clear();
    _sensor.clearSessionCalibration();
    calibrationReady = false;
    latestSnapshot = null;
    clearSessionData();
    notifyListeners();
  }

  /// Call from SLAM / AR layer (or motion tracker) to mirror phone pose in Quantum Space.
  void setVirtualPhonePose(DeskPose pose) {
    virtualPhonePose = pose;
    notifyListeners();
  }

  DeskHeatmapStore get heatmap => _heatmap;

  RoomFocusScanStore get roomScan => _roomScan;

  DeskPose get roomScanPose => _roomMotion.pose;

  int get roomScanFilledCells => _roomScan.filledCellCount;

  double get roomScanCompleteness => _roomScan.completeness;

  /// 격자별 Focus Score(히트맵 완성도 페널티 제외 — 위치 간 공정 비교).
  double scoreAtLocation({
    required double emfAvgMicroTesla,
    required double varianceAvg,
    required double lineNoisePercent,
  }) {
    return computeFocusScore(
      emfAvgMicroTesla: emfAvgMicroTesla,
      varianceAvg: varianceAvg,
      heatmapCompleteness: 1.0,
      lineNoisePercent: lineNoisePercent,
    );
  }

  FocusZoneCell? roomScanBestZone({int minSamples = 3}) {
    return _roomScan.bestZone(scoreFn: scoreAtLocation, minSamples: minSamples);
  }

  List<FocusZoneCell> roomScanRankedZones({int minSamples = 3}) {
    return _roomScan.cellsWithScores(scoreFn: scoreAtLocation, minSamples: minSamples);
  }

  Future<void> startRoomScan() async {
    if (roomScanActive) return;
    roomScanActive = true;
    _roomMotion.resetOrigin();
    if (sensorRunning && !_roomMotion.isRunning) {
      await _roomMotion.start();
    }
    notifyListeners();
  }

  Future<void> stopRoomScan() async {
    if (!roomScanActive) return;
    roomScanActive = false;
    await _roomMotion.stop();
    notifyListeners();
  }

  void resetRoomScan() {
    _roomScan.clear();
    _roomMotion.resetOrigin();
    notifyListeners();
  }

  Future<void> loadCalibrationFromDisk() async {
    try {
      final off = await _calibrationStore.loadOffset();
      if (off != null) {
        final (x, y, z) = off;
        _sensor.setUserCalibrationOffset(x, y, z);
      }
    } catch (e, st) {
      debugPrint('loadCalibrationFromDisk: $e\n$st');
      notices.add('저장된 보정 데이터를 불러오지 못했습니다. 필요 시 다시 8자 보정을 진행해 주세요.');
      notifyListeners();
    }
  }

  Future<void> saveCalibrationOffset(double x, double y, double z) async {
    await _calibrationStore.saveOffset(x, y, z);
    _sensor.setUserCalibrationOffset(x, y, z);
    notifyListeners();
  }

  Future<bool> isCalibrationDone() => _calibrationStore.isCalibrationDone();

  void startFocusSession() {
    if (focusSessionActive) return;
    focusSessionActive = true;
    pendingFocusAlert = false;
    _focusAlertArmed = true;
    _focusSessionStartedAt = DateTime.now();
    unawaited(_handMotion.start());
    _focusSessionTimer?.cancel();
    _focusSessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!focusSessionActive) return;
      notifyListeners();
      if (pendingFocusAlert) return;
      final th = effectiveFocusAlertThreshold;
      final recoverAbove = th + focusAlertRecoverHysteresis;
      if (currentFocusScore > recoverAbove) {
        _focusAlertArmed = true;
      }
      if (_focusAlertArmed && currentFocusScore <= th) {
        pendingFocusAlert = true;
        _focusAlertArmed = false;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void stopFocusSession() {
    if (!focusSessionActive) return;
    _finalizeFocusSessionTime();
    focusSessionActive = false;
    _focusSessionTimer?.cancel();
    _focusSessionTimer = null;
    pendingFocusAlert = false;
    _focusAlertArmed = true;
    unawaited(_handMotion.stop());
    notifyListeners();
  }

  void acknowledgeFocusAlert() {
    pendingFocusAlert = false;
    notifyListeners();
  }

  /// PRD F4-1: Focus Score = 100 - (EMF_avg × w1) - (Variance × w2) - completeness penalty - line noise.
  /// Weights are provisional until tuned against bench data.
  double computeFocusScore({
    required double emfAvgMicroTesla,
    required double varianceAvg,
    double heatmapCompleteness = 0,
    double lineNoisePercent = 0,
  }) {
    const double w1 = 0.98;
    const double w2 = 0.17;
    const double w3 = 26.0;
    const double w4 = 0.26;
    final score = 100.0 -
        emfAvgMicroTesla * w1 -
        varianceAvg * w2 -
        (1.0 - heatmapCompleteness.clamp(0.0, 1.0)) * w3 -
        lineNoisePercent * w4;
    return score.clamp(0.0, 100.0);
  }

  double get _baseFocusScore {
    if (emfSeries.isEmpty) {
      return computeFocusScore(
        emfAvgMicroTesla: 0,
        varianceAvg: 0,
        heatmapCompleteness: _heatmap.completeness,
        lineNoisePercent: latestSnapshot?.lineNoisePercent ?? 0,
      );
    }
    final tail = emfSeries.length > 120 ? emfSeries.sublist(emfSeries.length - 120) : emfSeries;
    final avgM = tail.map((e) => e.filteredMagnitudeMicroTesla).reduce((a, b) => a + b) / tail.length;
    final avgV = tail.map((e) => e.variance).reduce((a, b) => a + b) / tail.length;
    final avgL = tail.map((e) => e.lineNoisePercent).reduce((a, b) => a + b) / tail.length;
    return computeFocusScore(
      emfAvgMicroTesla: avgM,
      varianceAvg: avgV,
      heatmapCompleteness: _heatmap.completeness,
      lineNoisePercent: avgL,
    );
  }

  /// EMF 기반 점수 + (집중 세션 시) 손떨림·스크롤 패널티.
  double get currentFocusScore {
    var s = _baseFocusScore;
    if (focusSessionActive) {
      s = (s - _handMotion.penaltyPoints).clamp(0.0, 100.0);
    }
    return s;
  }

  Future<void> startSensors() async {
    if (sensorRunning) return;
    try {
      await _sensor.start();
      sensorRunning = true;
      _magSub = _sensor.snapshots.listen(_onMagnetometer, onError: (Object e, StackTrace st) {
        debugPrint('EnvironmentProvider magnetometer stream: $e\n$st');
        notices.add('센서 스트림 오류가 발생했습니다. 앱을 다시 시작해 주세요.');
        notifyListeners();
      });
      _msgSub = _sensor.userMessages.listen((m) {
        notices.add(m);
        notifyListeners();
      });
      await _motion.start();
      if (!_motion.isRunning) {
        notices.add(
          '선형 가속도(사용자 가속도) 센서를 쓸 수 없습니다. 휴대폰 위치는 원점에 고정됩니다. '
          'ARCore/ARKit SLAM 연동 시 실제 좌표로 대체할 수 있습니다.',
        );
      }
      notifyListeners();
    } on SensorUnavailableException catch (e) {
      notices.add(e.message);
      sensorRunning = false;
      notifyListeners();
    } catch (e, st) {
      debugPrint('startSensors: $e\n$st');
      notices.add('센서를 초기화할 수 없습니다. 기기 호환성 및 권한을 확인해 주세요.');
      sensorRunning = false;
      notifyListeners();
    }
  }

  void _onMagnetometer(MagnetometerSnapshot s) {
    try {
      if (_motion.isRunning) {
        virtualPhonePose = _motion.pose;
      }

      latestSnapshot = s;
      final sample = EmfSample(
        timestamp: s.timestamp,
        filteredMagnitudeMicroTesla: s.filteredMagnitudeMicroTesla,
        variance: s.varianceMicroTeslaSq,
        rawX: s.dx,
        rawY: s.dy,
        rawZ: s.dz,
        lineNoisePercent: s.lineNoisePercent,
        dominantFrequencyHz: s.dominantFrequencyHz,
      );
      emfSeries.add(sample);
      poseSeries.add(virtualPhonePose);
      _heatmap.addSample(virtualPhonePose, s.filteredMagnitudeMicroTesla);

      if (roomScanActive && _roomMotion.isRunning) {
        _roomScan.addSample(
          pose: _roomMotion.pose,
          emfMicroTesla: s.filteredMagnitudeMicroTesla,
          variance: s.varianceMicroTeslaSq,
          lineNoisePercent: s.lineNoisePercent,
        );
      }

      _sinceLastGemini++;
      if (_sinceLastGemini >= geminiBatchSize) {
        _sinceLastGemini = 0;
        unawaited(_runGeminiBatch());
      }
      notifyListeners();
    } catch (e, st) {
      debugPrint('_onMagnetometer: $e\n$st');
      notices.add('측정 데이터를 기록하는 중 오류가 발생했습니다.');
      notifyListeners();
    }
  }

  Future<void> _runGeminiBatch() async {
    try {
      final take = geminiBatchSize.clamp(1, emfSeries.length);
      final emfBatch = emfSeries.sublist(emfSeries.length - take);
      final poseBatch = poseSeries.length >= take
          ? poseSeries.sublist(poseSeries.length - take)
          : List<DeskPose>.from(poseSeries);

      final avgM =
          emfBatch.map((e) => e.filteredMagnitudeMicroTesla).reduce((a, b) => a + b) / emfBatch.length;
      final avgV = emfBatch.map((e) => e.variance).reduce((a, b) => a + b) / emfBatch.length;
      final avgL = emfBatch.map((e) => e.lineNoisePercent).reduce((a, b) => a + b) / emfBatch.length;

      final emfMaps = emfSamplesToMaps(emfBatch);
      final poseMaps = deskPosesToMaps(poseBatch);

      final summary = await compute(buildGeminiSummaryInIsolate, {
        'emf': emfMaps,
        'poses': poseMaps,
        'avgM': avgM,
        'avgVar': avgV,
        'avgLine': avgL,
        'heatmapCompleteness': _heatmap.completeness,
        'focusScore': computeFocusScore(
          emfAvgMicroTesla: avgM,
          varianceAvg: avgV,
          heatmapCompleteness: _heatmap.completeness,
          lineNoisePercent: avgL,
        ),
      });

      lastAiReport = await _gemini.analyzeEnvironmentPattern(summary);
      notifyListeners();
    } catch (e, st) {
      debugPrint('_runGeminiBatch: $e\n$st');
      lastAiReport =
          '[로컬 폴백] 분석 배치 처리 중 문제가 발생했습니다. 네트워크 상태를 확인하거나 나중에 다시 시도해 주세요.';
      notifyListeners();
    }
  }

  Future<void> stopSensors() async {
    await _magSub?.cancel();
    await _msgSub?.cancel();
    _magSub = null;
    _msgSub = null;
    await _sensor.stop();
    await _motion.stop();
    if (roomScanActive) {
      roomScanActive = false;
      await _roomMotion.stop();
    }
    sensorRunning = false;
    notifyListeners();
  }

  void clearSessionData() {
    if (focusSessionActive) {
      _finalizeFocusSessionTime();
    }
    _focusSessionTimer?.cancel();
    _focusSessionTimer = null;
    focusSessionActive = false;
    pendingFocusAlert = false;
    _focusAlertArmed = true;
    unawaited(_handMotion.stop());
    emfSeries.clear();
    poseSeries.clear();
    _heatmap.clear();
    lastAiReport = null;
    _sinceLastGemini = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _handMotion.onActivityChanged = null;
    if (focusSessionActive) {
      _finalizeFocusSessionTime();
      focusSessionActive = false;
    }
    _focusSessionTimer?.cancel();
    unawaited(_handMotion.stop());
    unawaited(stopSensors());
    unawaited(_motion.stop());
    unawaited(_roomMotion.stop());
    _gemini.close();
    _sensor.dispose();
    super.dispose();
  }
}
