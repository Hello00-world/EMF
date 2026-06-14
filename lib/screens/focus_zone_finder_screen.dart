import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/desk_pose.dart';

import '../models/focus_zone_cell.dart';
import '../providers/environment_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/focus_zone_map_widget.dart';

/// 주변을 걸으며 스캔해 Focus Score가 가장 높은 위치를 찾는 탭.
class FocusZoneFinderScreen extends StatelessWidget {
  const FocusZoneFinderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EnvironmentProvider>(
      builder: (context, env, _) {
        final ranked = env.roomScanRankedZones(minSamples: 3);
        final best = env.roomScanBestZone(minSamples: 3);
        final pose = env.roomScanPose;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '집중 구역 찾기',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '휴대폰 자기장 센서는 지금 기기가 있는 위치만 측정할 수 있습니다. '
                      '스캔을 시작한 뒤 천천히 주변을 돌아다니면, 각 위치의 Focus Score를 격자에 쌓아 '
                      '가장 점수가 높은 구역을 표시합니다.\n\n'
                      '범위: 수평 약 ${EnvironmentProvider.roomScanSpanM.toStringAsFixed(0)}m(±${(EnvironmentProvider.roomScanSpanM / 2).toStringAsFixed(0)}m), '
                      '높이 ±${(EnvironmentProvider.roomScanHeightM / 2).toStringAsFixed(0)}m '
                      '(10m 요청 대비 센서·적분 한계로 축소).',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF64748B),
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.gapMd),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: env.sensorRunning
                        ? () {
                            if (env.roomScanActive) {
                              env.stopRoomScan();
                            } else {
                              env.startRoomScan();
                            }
                          }
                        : null,
                    icon: Icon(env.roomScanActive ? Icons.stop_rounded : Icons.radar_rounded),
                    label: Text(env.roomScanActive ? '스캔 중지' : '주변 스캔 시작'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: '스캔 데이터 초기화',
                  onPressed: env.roomScanFilledCells > 0 ? () => env.resetRoomScan() : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (!env.sensorRunning)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '상단에서 측정을 켠 뒤 스캔을 시작하세요.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFFDC2626)),
                ),
              ),
            const SizedBox(height: AppTheme.gapMd),
            SizedBox(
              height: 340,
              child: FocusZoneMapWidget(
                spanM: EnvironmentProvider.roomScanSpanM,
                phonePose: pose,
                cells: ranked,
                bestZone: best,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '녹색=높은 Focus Score · 금색 별=최고 구역 · 청록 삼각형=현재 위치',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: AppTheme.gapMd),
            _ScanStatsCard(
              filledCells: env.roomScanFilledCells,
              completeness: env.roomScanCompleteness,
              scanActive: env.roomScanActive,
            ),
            if (best != null) ...[
              const SizedBox(height: AppTheme.gapSm),
              _BestZoneCard(best: best, currentPose: pose),
            ] else if (env.roomScanFilledCells > 0) ...[
              const SizedBox(height: AppTheme.gapSm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    '격자당 최소 3회 이상 샘플이 필요합니다. 조금 더 천천히 이동해 주세요.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
            if (ranked.length > 1) ...[
              const SizedBox(height: AppTheme.gapMd),
              Text('상위 구역', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...ranked.take(5).map((c) => _RankTile(rank: ranked.indexOf(c) + 1, cell: c)),
            ],
          ],
        );
      },
    );
  }
}

class _ScanStatsCard extends StatelessWidget {
  const _ScanStatsCard({
    required this.filledCells,
    required this.completeness,
    required this.scanActive,
  });

  final int filledCells;
  final double completeness;
  final bool scanActive;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              scanActive ? Icons.sensors : Icons.sensors_off_outlined,
              color: scanActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scanActive ? '스캔 중 — 천천히 주변을 이동하세요' : '스캔 대기',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '채워진 격자 $filledCells개 · 커버리지 ${(completeness * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestZoneCard extends StatelessWidget {
  const _BestZoneCard({required this.best, required this.currentPose});

  final FocusZoneCell best;
  final DeskPose currentPose;

  @override
  Widget build(BuildContext context) {
    final dx = best.x - currentPose.x;
    final dz = best.z - currentPose.z;
    final distM = math.sqrt(dx * dx + dz * dz);

    return Card(
      color: const Color(0xFF22C55E).withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFFBBF24)),
                const SizedBox(width: 8),
                Text(
                  '최고 Focus Score 구역',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Score ${best.focusScore.toStringAsFixed(1)} · 샘플 ${best.sampleCount}회',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF15803D),
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '위치 (스캔 시작점 기준): X ${best.x.toStringAsFixed(2)}m · '
              'Y ${best.y.toStringAsFixed(2)}m · Z ${best.z.toStringAsFixed(2)}m',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '수평 거리 ${best.horizontalDistanceM.toStringAsFixed(2)}m · '
              '방위 ${best.bearingDegrees.toStringAsFixed(0)}° (앞=0°, 오른쪽=90°)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
            ),
            if (distM > 0.05) ...[
              const SizedBox(height: 6),
              Text(
                '현재 위치에서 약 ${distM.toStringAsFixed(2)}m · '
                '이동 방향 약 ${(math.atan2(dx, dz) * 180 / math.pi).toStringAsFixed(0)}°',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4F46E5),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

}

class _RankTile extends StatelessWidget {
  const _RankTile({required this.rank, required this.cell});

  final int rank;
  final FocusZoneCell cell;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        tileColor: Colors.white.withValues(alpha: 0.7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        title: Text('Score ${cell.focusScore.toStringAsFixed(1)}'),
        subtitle: Text(
          'X ${cell.x.toStringAsFixed(1)}m · Z ${cell.z.toStringAsFixed(1)}m · ${cell.sampleCount}샘플',
        ),
      ),
    );
  }
}
