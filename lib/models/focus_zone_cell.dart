import 'dart:math' as math;

/// 주변 스캔 격자 한 칸 + 해당 위치의 추정 Focus Score.
class FocusZoneCell {
  const FocusZoneCell({
    required this.x,
    required this.y,
    required this.z,
    required this.focusScore,
    required this.sampleCount,
    required this.avgEmfMicroTesla,
    required this.avgVariance,
    required this.avgLineNoisePercent,
  });

  final double x;
  final double y;
  final double z;
  final double focusScore;
  final int sampleCount;
  final double avgEmfMicroTesla;
  final double avgVariance;
  final double avgLineNoisePercent;

  /// 스캔 시작 원점 기준 수평 거리(m).
  double get horizontalDistanceM => math.sqrt(x * x + z * z);

  /// 원점에서 본 방위(도). +Z=앞 0°, +X=오른쪽 90°.
  double get bearingDegrees => math.atan2(x, z) * 180 / math.pi;
}
