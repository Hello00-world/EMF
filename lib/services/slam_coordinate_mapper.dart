import '../models/desk_pose.dart';

/// ARCore/ARKit 카메라 포즈 → 퀀텀 스페이스(책상 원점) 좌표 변환 스텁.
///
/// 실제 통합 시:
/// 1. AR 세션에서 [devicePositionWorld], [deviceRotation] (quaternion)을 프레임마다 수신합니다.
/// 2. 사용자가 "책상 원점"을 탭해 고정할 때의 월드 변환 \(T_{desk\leftarrow world}\)를 저장합니다.
/// 3. \(p_{desk} = R_{desk}^{-1}(p_{world} - t_{desk})\) 로 [DeskPose] 미터 단위로 환산합니다.
///
/// 아래는 단위 변환(scale)과 Y-up 보정만 적용한 예시입니다.
class SlamCoordinateMapper {
  SlamCoordinateMapper({
    this.deskOriginWorldX = 0,
    this.deskOriginWorldY = 0,
    this.deskOriginWorldZ = 0,
    this.metersPerArUnit = 1.0,
  });

  double deskOriginWorldX;
  double deskOriginWorldY;
  double deskOriginWorldZ;
  double metersPerArUnit;

  /// [qx,qy,qz,qw] 단위 쿼터니언, [px,py,pz] AR 월드 위치(플러그인 단위).
  DeskPose arPoseToDeskPose({
    required double px,
    required double py,
    required double pz,
    required double qx,
    required double qy,
    required double qz,
    required double qw,
  }) {
    // 회전(qx,qy,qz,qw)은 향후 R^-1 보정·가속도계 정합 시 사용합니다.
    final mx = (px - deskOriginWorldX) * metersPerArUnit;
    final my = (py - deskOriginWorldY) * metersPerArUnit;
    final mz = (pz - deskOriginWorldZ) * metersPerArUnit;
    return DeskPose(mx, my, mz);
  }
}
