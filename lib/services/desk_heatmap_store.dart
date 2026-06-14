import 'dart:math' as math;

import '../models/desk_pose.dart';

/// Desk plane grid (X–Z). Duplicate cells use weighted average by sample count.
/// Default [cellM] 4cm — easier to see peaks vs 1cm.
class DeskHeatmapStore {
  DeskHeatmapStore({
    required this.widthM,
    required this.depthM,
    this.cellM = 0.04,
  })  : assert(widthM > 0 && depthM > 0),
        assert(cellM > 0);

  final double widthM;
  final double depthM;
  final double cellM;

  final Map<String, _CellAgg> _cells = {};
  int _renderRevision = 0;

  int get renderRevision => _renderRevision;

  int get filledCellCount => _cells.length;

  int get totalCells => math.max(1, (widthM / cellM).ceil() * (depthM / cellM).ceil());

  double get completeness => (filledCellCount / totalCells).clamp(0.0, 1.0);

  static String _key(int gx, int gz) => '$gx,$gz';

  (int, int) _grid(double x, double z) {
    final hx = widthM / 2;
    final hz = depthM / 2;
    final gx = ((x + hx) / cellM).floor();
    final gz = ((z + hz) / cellM).floor();
    return (gx, gz);
  }

  /// 책상 기준 높이에서 수직으로 **±1m**을 벗어난 샘플은 격자에 넣지 않음(수직 스캔 혼선 완화).
  static const double deskReferenceYM = 0.02;
  static const double verticalSampleBandM = 1.0;

  void addSample(DeskPose pose, double emfMicroTesla) {
    if ((pose.y - deskReferenceYM).abs() > verticalSampleBandM) {
      return;
    }
    final (gx, gz) = _grid(pose.x, pose.z);
    final k = _key(gx, gz);
    final prev = _cells[k];
    if (prev == null) {
      _cells[k] = _CellAgg(emfMicroTesla, 1);
    } else {
      _cells[k] = _CellAgg(prev.sum + emfMicroTesla, prev.count + 1);
    }
    _renderRevision++;
  }

  (double min, double max) get intensityBounds {
    if (_cells.isEmpty) return (0.0, 1.0);
    var minV = double.infinity;
    var maxV = -double.infinity;
    for (final e in _cells.values) {
      final a = e.avg;
      if (a < minV) minV = a;
      if (a > maxV) maxV = a;
    }
    if (!maxV.isFinite || !minV.isFinite) return (0.0, 1.0);
    if (maxV - minV < 0.5) maxV = minV + 0.5;
    return (minV, maxV);
  }

  /// 스캔으로 채워진 모든 격자 셀 (3D 포인트 클라우드용). 키 정렬로 샘플링이 안정적입니다.
  List<HeatmapCell> allCells() {
    final out = <HeatmapCell>[];
    final hx = widthM / 2;
    final hz = depthM / 2;
    final keys = _cells.keys.toList()..sort();
    for (final k in keys) {
      final e = _cells[k]!;
      final parts = k.split(',');
      final gx = int.parse(parts[0]);
      final gz = int.parse(parts[1]);
      final x = gx * cellM - hx + cellM / 2;
      final z = gz * cellM - hz + cellM / 2;
      out.add(HeatmapCell(x: x, z: z, intensity: e.avg));
    }
    return out;
  }

  /// Normalized cell centers and intensities for rendering (0…1 intensity).
  List<HeatmapCell> topCells({int maxCount = 64}) {
    final entries = _cells.entries.toList()
      ..sort((a, b) => b.value.avg.compareTo(a.value.avg));
    final out = <HeatmapCell>[];
    for (var i = 0; i < entries.length && i < maxCount; i++) {
      final e = entries[i];
      final parts = e.key.split(',');
      final gx = int.parse(parts[0]);
      final gz = int.parse(parts[1]);
      final hx = widthM / 2;
      final hz = depthM / 2;
      final x = gx * cellM - hx + cellM / 2;
      final z = gz * cellM - hz + cellM / 2;
      out.add(HeatmapCell(x: x, z: z, intensity: e.value.avg));
    }
    return out;
  }

  /// 3D 맵용: 배경보다 강한 **기기급** 셀만, 그중 상위 [maxCount]개.
  /// [minMicroTesla] 기본 5.5µT는 앱 내 ICNIRP 스타일 ‘주의’ 구간 하한과 맞춤.
  List<HeatmapCell> topCellsDeviceLevel({
    int maxCount = 12,
    double minMicroTesla = 5.5,
  }) {
    final entries = _cells.entries.where((e) => e.value.avg >= minMicroTesla).toList()
      ..sort((a, b) => b.value.avg.compareTo(a.value.avg));
    final out = <HeatmapCell>[];
    final hx = widthM / 2;
    final hz = depthM / 2;
    for (var i = 0; i < entries.length && i < maxCount; i++) {
      final e = entries[i];
      final parts = e.key.split(',');
      final gx = int.parse(parts[0]);
      final gz = int.parse(parts[1]);
      final x = gx * cellM - hx + cellM / 2;
      final z = gz * cellM - hz + cellM / 2;
      out.add(HeatmapCell(x: x, z: z, intensity: e.value.avg));
    }
    return out;
  }

  List<DeskPose> peakOrbPositions({int count = 3, double minMicroTesla = 2.5}) {
    final tops = topCells(maxCount: math.max(count, 8));
    final orbs = <DeskPose>[];
    for (final c in tops) {
      if (c.intensity >= minMicroTesla && orbs.length < count) {
        orbs.add(DeskPose(c.x, 0.02, c.z));
      }
    }
    return orbs;
  }

  void clear() {
    _cells.clear();
    _renderRevision++;
  }
}

class _CellAgg {
  _CellAgg(this.sum, this.count);
  double sum;
  int count;
  double get avg => sum / count;
}

class HeatmapCell {
  const HeatmapCell({required this.x, required this.z, required this.intensity});
  final double x;
  final double z;
  final double intensity;
}
