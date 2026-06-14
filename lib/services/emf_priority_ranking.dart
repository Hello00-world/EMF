import 'dart:math' as math;

import '../models/desk_pose.dart';
import '../services/desk_heatmap_store.dart';

/// 가까우면서 강한 EMF 소스일수록 우선(비용 대비 효과 가정).
class EmfPriorityItem {
  const EmfPriorityItem({
    required this.rank,
    required this.horizontalDistanceM,
    required this.intensityMicroTesla,
    required this.priorityScore,
  });

  final int rank;
  final double horizontalDistanceM;
  final double intensityMicroTesla;
  final double priorityScore;
}

List<EmfPriorityItem> rankDeviceLevelPeaks({
  required DeskHeatmapStore heatmap,
  required DeskPose userPose,
  int maxCandidates = 16,
  int takeTop = 3,
  double minMicroTesla = 5.5,
  double distanceFloorM = 0.08,
}) {
  final cells = heatmap.topCellsDeviceLevel(maxCount: maxCandidates, minMicroTesla: minMicroTesla);
  final px = userPose.x;
  final pz = userPose.z;
  final scored = <({HeatmapCell c, double score, double dist})>[];
  for (final c in cells) {
    final dx = c.x - px;
    final dz = c.z - pz;
    final dist = math.sqrt(dx * dx + dz * dz);
    final s = c.intensity / (dist + distanceFloorM);
    scored.add((c: c, score: s, dist: dist));
  }
  scored.sort((a, b) => b.score.compareTo(a.score));
  final out = <EmfPriorityItem>[];
  for (var i = 0; i < scored.length && i < takeTop; i++) {
    final e = scored[i];
    out.add(
      EmfPriorityItem(
        rank: i + 1,
        horizontalDistanceM: e.dist,
        intensityMicroTesla: e.c.intensity,
        priorityScore: e.score,
      ),
    );
  }
  return out;
}
