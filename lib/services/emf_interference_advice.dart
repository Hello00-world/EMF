import 'dart:math' as math;

import '../models/desk_pose.dart';
import '../models/magnetometer_snapshot.dart';
import 'desk_heatmap_store.dart';

/// 집중 세션 중 Focus Score 하락 시 표시할 휴리스틱 안내(의학적 진단 아님).
String buildFocusDropAdvice({
  required double focusScore,
  required MagnetometerSnapshot? snapshot,
  required DeskHeatmapStore heatmap,
  required DeskPose userPose,
}) {
  final buf = StringBuffer();
  buf.writeln('현재 Focus Score는 ${focusScore.toStringAsFixed(1)}점입니다.');
  buf.writeln('');
  buf.writeln('아래는 자기장 패턴을 바탕으로 한 참고 안내입니다. 주변 물체를 조금씩 옮기며 다시 측정해 보세요.\n');

  final snap = snapshot;
  if (snap != null) {
    if (snap.lineNoisePercent > 12) {
      buf.writeln(
        '· 전력선·어댑터·멀티탭·충전기에서 나오는 교류 자기장 비중이 큽니다. '
        '콘센트와 충전 중인 케이블을 50cm 이상 띄우거나, 책상 아래로 내려 보세요.',
      );
    }
    if (snap.varianceMicroTeslaSq > 70) {
      buf.writeln(
        '· 측정값이 들쭉날쭉합니다. 금속 책상·스탠드 램프·금속 트레이 근처를 피하거나, 휴대폰을 안정적으로 올려 두세요.',
      );
    }
    if (snap.filteredMagnitudeMicroTesla > 5) {
      buf.writeln(
        '· 비교적 강한 자기장 변동이 있습니다. 노트북·모니터·스피커·태블릿 등 큰 전자기기를 몸에서 조금 더 멀리 두어 보세요.',
      );
    }
    final f0 = snap.dominantFrequencyHz;
    if (f0 > 45 && f0 < 65) {
      buf.writeln(
        '· 50/60Hz 근처 성분이 두드러집니다. 전원에 연결된 기기(어댑터, 데스크 램프 등)를 의심해 보세요.',
      );
    }
  }

  final peaks = heatmap.peakOrbPositions(count: 5, minMicroTesla: 2.5);
  if (peaks.isNotEmpty) {
    buf.writeln('');
    buf.writeln('[본인(지금 측정 위치) ↔ 피크(EMF 강한 지점)]');
    buf.writeln(
      '좌표: 책상 면에서 앞(+Z)·오른쪽(+X) 기준. 각도는 수평면에서 앞쪽(Z+)을 0°로 하고 시계 방향(오른쪽이 +)입니다.\n',
    );
    for (var i = 0; i < peaks.length; i++) {
      final p = peaks[i];
      final dx = p.x - userPose.x;
      final dy = p.y - userPose.y;
      final dz = p.z - userPose.z;
      final horiz = math.sqrt(dx * dx + dz * dz);
      final dist3d = math.sqrt(dx * dx + dy * dy + dz * dz);
      final degCw = math.atan2(dx, dz) * 180 / math.pi;
      buf.writeln(
        '· 피크 ${i + 1}: 수평 거리 약 ${(horiz * 100).toStringAsFixed(0)}cm, '
        '공간 거리(3D) 약 ${(dist3d * 100).toStringAsFixed(0)}cm, '
        '방위 약 ${degCw.toStringAsFixed(0)}°',
      );
    }
    buf.writeln('');
    buf.writeln('· 피크 쪽(위 각도·거리 방향)에 있는 전자기기·충전기를 옮기거나 전원을 뽑아 보세요.');
  }

  if (buf.length < 120) {
    buf.writeln('');
    buf.writeln(
      '· 주변의 전원이 켜진 기기·충전기를 한 번 정리하고, 휴대폰으로 책상을 천천히 다시 스캔해 보세요.',
    );
  }

  return buf.toString().trim();
}
