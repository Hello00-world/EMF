import 'dart:math' as math;

import '../models/desk_pose.dart';
import '../models/focus_zone_cell.dart';

/// 스마트폰 자기장 센서 한계를 고려한 주변 스캔 격자.
///
/// 요청 범위(수평 10m·높이 2m)는 가속도 적분 오차가 커서 **수평 ±3m(6×6m), 높이 ±1m**로 축소합니다.
/// 실제 측정은 기기가 **물리적으로 도달한 위치**에서만 가능합니다.
class RoomFocusScanStore {
  RoomFocusScanStore({
    this.spanM = 6.0,
    this.heightSpanM = 2.0,
    this.cellM = 0.25,
    this.referenceYM = 0.02,
  })  : assert(spanM > 0 && heightSpanM > 0 && cellM > 0),
        _halfSpan = spanM / 2,
        _halfHeight = heightSpanM / 2;

  final double spanM;
  final double heightSpanM;
  final double cellM;
  final double referenceYM;

  final double _halfSpan;
  final double _halfHeight;

  final Map<String, _RoomCellAgg> _cells = {};
  int _renderRevision = 0;

  int get renderRevision => _renderRevision;
  int get filledCellCount => _cells.length;

  int get totalCells {
    final gx = math.max(1, (spanM / cellM).ceil());
    final gz = math.max(1, (spanM / cellM).ceil());
    final gy = math.max(1, (heightSpanM / cellM).ceil());
    return gx * gz * gy;
  }

  double get completeness => (filledCellCount / totalCells).clamp(0.0, 1.0);

  static String _key(int gx, int gz, int gy) => '$gx,$gz,$gy';

  (int, int, int) _grid(DeskPose pose) {
    final gx = ((pose.x + _halfSpan) / cellM).floor();
    final gz = ((pose.z + _halfSpan) / cellM).floor();
    final gy = ((pose.y - referenceYM + _halfHeight) / cellM).floor();
    return (gx, gz, gy);
  }

  bool isPoseInBounds(DeskPose pose) {
    if (pose.x.abs() > _halfSpan || pose.z.abs() > _halfSpan) return false;
    if ((pose.y - referenceYM).abs() > _halfHeight) return false;
    return true;
  }

  void addSample({
    required DeskPose pose,
    required double emfMicroTesla,
    required double variance,
    required double lineNoisePercent,
  }) {
    if (!isPoseInBounds(pose)) return;
    final (gx, gz, gy) = _grid(pose);
    final k = _key(gx, gz, gy);
    final prev = _cells[k];
    if (prev == null) {
      _cells[k] = _RoomCellAgg(
        x: gx * cellM - _halfSpan + cellM / 2,
        y: referenceYM + gy * cellM - _halfHeight + cellM / 2,
        z: gz * cellM - _halfSpan + cellM / 2,
        emfSum: emfMicroTesla,
        varSum: variance,
        lineSum: lineNoisePercent,
        count: 1,
      );
    } else {
      prev.emfSum += emfMicroTesla;
      prev.varSum += variance;
      prev.lineSum += lineNoisePercent;
      prev.count++;
    }
    _renderRevision++;
  }

  List<FocusZoneCell> cellsWithScores({
    required double Function({
      required double emfAvgMicroTesla,
      required double varianceAvg,
      required double lineNoisePercent,
    }) scoreFn,
    int minSamples = 3,
  }) {
    final out = <FocusZoneCell>[];
    for (final e in _cells.values) {
      if (e.count < minSamples) continue;
      final avgEmf = e.emfSum / e.count;
      final avgVar = e.varSum / e.count;
      final avgLine = e.lineSum / e.count;
      final score = scoreFn(
        emfAvgMicroTesla: avgEmf,
        varianceAvg: avgVar,
        lineNoisePercent: avgLine,
      );
      out.add(
        FocusZoneCell(
          x: e.x,
          y: e.y,
          z: e.z,
          focusScore: score,
          sampleCount: e.count,
          avgEmfMicroTesla: avgEmf,
          avgVariance: avgVar,
          avgLineNoisePercent: avgLine,
        ),
      );
    }
    out.sort((a, b) => b.focusScore.compareTo(a.focusScore));
    return out;
  }

  FocusZoneCell? bestZone({
    required double Function({
      required double emfAvgMicroTesla,
      required double varianceAvg,
      required double lineNoisePercent,
    }) scoreFn,
    int minSamples = 3,
  }) {
    final ranked = cellsWithScores(scoreFn: scoreFn, minSamples: minSamples);
    return ranked.isEmpty ? null : ranked.first;
  }

  void clear() {
    _cells.clear();
    _renderRevision++;
  }
}

class _RoomCellAgg {
  _RoomCellAgg({
    required this.x,
    required this.y,
    required this.z,
    required this.emfSum,
    required this.varSum,
    required this.lineSum,
    required this.count,
  });

  final double x;
  final double y;
  final double z;
  double emfSum;
  double varSum;
  double lineSum;
  int count;
}
