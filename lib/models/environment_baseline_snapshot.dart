/// 대시보드 "기준 저장"용 스냅샷 — 이후 수치와 비교해 변화를 요약합니다.
class EnvironmentBaselineSnapshot {
  const EnvironmentBaselineSnapshot({
    required this.capturedAt,
    required this.avgEmfMicroTesla,
    required this.avgVariance,
    required this.avgLineNoisePercent,
    required this.baseFocusScore,
    required this.heatmapCompleteness,
  });

  final DateTime capturedAt;
  final double avgEmfMicroTesla;
  final double avgVariance;
  final double avgLineNoisePercent;
  final double baseFocusScore;
  final double heatmapCompleteness;
}
