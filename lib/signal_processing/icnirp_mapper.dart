/// UX bands inspired by public exposure guidelines (simplified, non-regulatory).
///
/// Magnetometer magnitude here reflects **perturbation / residual** field after DC removal,
/// not certified RMS magnetic flux density at 50/60 Hz.
///
/// **Calibration (앱 피드백용):** 일상 환경에서는 극단적 µT가 드물어, 이전보다 **낮은 µT에서도**
/// ‘주의/위험’이 나오도록 구간을 좁혔습니다. (노트북·휴대폰을 팔 길이 안에 두었을 때
/// 빨간색에 가깝게 보이도록 조정 — 실제 1m 거리는 자기장만으로 특정할 수 없음.)
class IcnirpMapper {
  static const double _safeMax = 1.8;
  static const double _cautionMax = 5.5;

  static String bandForMagnitude(double filteredMicroTesla) {
    final m = filteredMicroTesla.abs();
    if (m < _safeMax) return '안전';
    if (m < _cautionMax) return '주의';
    return '위험';
  }

  /// 1 … 5 for particle density / motion in AR overlay.
  /// 낮은 µT에서도 위험도가 빨리 오르도록 스케일을 낮춤.
  static int riskLevel(double filteredMicroTesla) {
    final t = (filteredMicroTesla.abs() / 12.0).clamp(0.0, 1.0);
    return (1 + (t * 4).round()).clamp(1, 5);
  }
}
