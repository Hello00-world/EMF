import 'dart:convert';

import '../models/desk_pose.dart';
import '../models/emf_sample.dart';

/// Packs batches for [compute] (only JSON-serializable payloads cross isolates).
List<Map<String, dynamic>> emfSamplesToMaps(List<EmfSample> samples) {
  return [
    for (final s in samples)
      {
        't': s.timestamp.toIso8601String(),
        'm': s.filteredMagnitudeMicroTesla,
        'v': s.variance,
        'bx': s.rawX,
        'by': s.rawY,
        'bz': s.rawZ,
        'line': s.lineNoisePercent,
        'f0': s.dominantFrequencyHz,
      },
  ];
}

List<Map<String, dynamic>> deskPosesToMaps(List<DeskPose> poses) {
  return [
    for (final p in poses) {'x': p.x, 'y': p.y, 'z': p.z},
  ];
}

/// Heavy string building off the UI isolate when batches are large.
String buildGeminiSummaryInIsolate(Map<String, dynamic> arg) {
  final emfRows = arg['emf'] as List<dynamic>;
  final poseRows = arg['poses'] as List<dynamic>;
  final avg = arg['avgM'] as double;
  final varAvg = arg['avgVar'] as double;
  final avgLine = arg['avgLine'] as double? ?? 0;
  final heat = arg['heatmapCompleteness'] as double? ?? 0;
  final focus = arg['focusScore'] as double?;

  final buf = StringBuffer()
    ..writeln('emf_count=${emfRows.length}, pose_count=${poseRows.length}')
    ..writeln('avg_filtered_uT=${avg.toStringAsFixed(3)}, avg_variance=${varAvg.toStringAsFixed(3)}')
    ..writeln('avg_line_noise_pct=${avgLine.toStringAsFixed(2)}, heatmap_completeness=${heat.toStringAsFixed(3)}')
    ..writeln('focus_score=${focus?.toStringAsFixed(1) ?? 'n/a'}')
    ..writeln('recent_emf_json=${jsonEncode(emfRows)}')
    ..writeln('recent_pose_json=${jsonEncode(poseRows)}');
  return buf.toString();
}
