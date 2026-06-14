import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/focus_environment_preset.dart';
import '../providers/environment_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/focus_score_alert_host.dart';
import '../widgets/focus_score_gauge.dart';
import '../widgets/focus_session_strip.dart';
import '../widgets/emf_minimap_widget.dart';
import 'ar_visualizer_screen.dart';
import 'focus_zone_finder_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final env = context.read<EnvironmentProvider>();
      await env.loadCalibrationFromDisk();
      try {
        await env.startSensors();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EnvironmentProvider>(
      builder: (context, env, _) {
        return FocusScoreAlertHost(
          child: Scaffold(
          appBar: AppBar(
            title: Text(['몰입 대시보드', 'AR EMF 스캔', 'EMF 미니맵', '집중 구역 찾기'][_index]),
            actions: [
              IconButton(
                tooltip: env.sensorRunning ? '측정 중지' : '측정 시작',
                onPressed: () async {
                  try {
                    if (env.sensorRunning) {
                      await env.stopSensors();
                    } else {
                      await env.startSensors();
                    }
                  } catch (e, st) {
                    debugPrint('toggle sensors: $e\n$st');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('센서 전환 중 오류가 발생했습니다.')),
                      );
                    }
                  }
                },
                icon: Icon(env.sensorRunning ? Icons.pause_circle_outline : Icons.play_circle_outline),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: [
                    _buildDashboard(context, env),
                    const ArVisualizerScreen(),
                    _buildQuantum(context, env),
                    const FocusZoneFinderScreen(),
                  ],
                ),
              ),
              if (env.focusSessionActive)
                FocusSessionStrip(
                  env: env,
                  onOpenDashboard: () => setState(() => _index = 0),
                ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: '홈',
              ),
              NavigationDestination(
                icon: Icon(Icons.view_in_ar_outlined),
                selectedIcon: Icon(Icons.view_in_ar),
                label: 'AR',
              ),
              NavigationDestination(
                icon: Icon(Icons.layers_outlined),
                selectedIcon: Icon(Icons.layers),
                label: '미니맵',
              ),
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: '구역',
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildDashboard(BuildContext context, EnvironmentProvider env) {
    final score = env.currentFocusScore;
    final todayMin = (env.focusTodaySeconds / 60).floor();
    final totalMin = (env.focusTotalSeconds / 60).floor();
    final goalSec = EnvironmentProvider.focusGoalMinutes * 60;
    final secondaryRing = env.focusSessionActive
        ? (env.focusSessionElapsed.inSeconds / goalSec).clamp(0.0, 1.0)
        : env.heatmap.completeness.clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘의 집중',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '누적 ${todayMin}분 · 전체 기록 ${totalMin}분 · 세션 ${env.focusCompletedSessions}회',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                  ),
                ],
              ),
            ),
            _SensorPill(running: env.sensorRunning),
          ],
        ),
        const SizedBox(height: AppTheme.gapMd),
        Center(
          child: FocusScoreGauge(
            score: score,
            secondaryProgress: secondaryRing,
            size: 232,
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            env.focusSessionActive
                ? '안쪽 링: 이번 세션 ${EnvironmentProvider.focusGoalMinutes}분 목표 진행 · 바깥 링: Focus Score'
                : '안쪽 링: 환경 데이터 축적 진행 · 바깥 링: Focus Score',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8)),
          ),
        ),
        const SizedBox(height: AppTheme.gapMd),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: env.focusSessionActive ? const Color(0xFFDC2626) : const Color(0xFF6366F1),
          ),
          onPressed: env.focusSessionActive
              ? () {
                  env.stopFocusSession();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('집중 모니터링을 종료했습니다. 오늘 통계에 반영되었습니다.')),
                  );
                }
              : () {
                  env.startFocusSession();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '집중 모니터링을 시작했습니다. 다른 탭으로 이동해도 하단에 타이머가 표시됩니다.',
                      ),
                    ),
                  );
                },
          icon: Icon(env.focusSessionActive ? Icons.stop_circle_outlined : Icons.play_arrow_rounded),
          label: Text(
            env.focusSessionActive ? '집중 종료' : '집중 시작',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: AppTheme.gapMd),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(
                    '집중 알림 모드',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    '일반 ≤60점 · 도서관 ≤63점 · 민감 ≤70점 이하에서 알림',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: DropdownButtonFormField<FocusEnvironmentPreset>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '모드 선택',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      value: env.environmentPreset,
                      items: FocusEnvironmentPreset.values
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.labelKo, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) env.setEnvironmentPreset(v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    '알림을 닫은 뒤에는 점수가 기준보다 ${EnvironmentProvider.focusAlertRecoverHysteresis.toStringAsFixed(0)}점 이상 올라갔다가 '
                    '다시 떨어져야 다음 알림이 뜹니다.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (env.focusSessionActive) ...[
          const SizedBox(height: AppTheme.gapSm),
          Card(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.07),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_outlined, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '세션 ${formatFocusDuration(env.focusSessionElapsed)} · '
                          'Score ${env.effectiveFocusAlertThreshold.toStringAsFixed(0)} 미만이면 알림',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  if (env.handheldMotionPenalty > 0.5) ...[
                    const SizedBox(height: 8),
                    Text(
                      '손 움직임 패널티 −${env.handheldMotionPenalty.toStringAsFixed(0)}점',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFDC2626),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppTheme.gapMd),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              '개인정보 · 무엇을 재는가 / 한계',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
            ),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [
              Text(
                '센서 데이터는 기기 안에서만 처리됩니다. Gemini는 100개 샘플마다 요약 통계만 전송합니다. '
                '휴대폰 위치는 가속도 추적 기준이며, ARCore 연동 시 SLAM 좌표로 바꿀 수 있습니다.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Text(
                '이 앱은 휴대폰 자기장 센서로 교란(잔여·변동)을 추정합니다. '
                '정확한 50/60Hz RMS 자계나 ICNIRP 준수 여부를 계측기처럼 증명하지는 않습니다. '
                'Focus Score·색·알림은 같은 자세에서의 상대 비교·습관 형성용입니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
        if (env.lastAiReport != null) ...[
          const SizedBox(height: AppTheme.gapSm),
          Text('AI 인사이트', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(env.lastAiReport!),
            ),
          ),
        ],
        if (env.notices.isNotEmpty) ...[
          const SizedBox(height: AppTheme.gapMd),
          Text('안내', style: Theme.of(context).textTheme.titleSmall),
          ...env.notices.take(6).map(
                (n) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('· $n', style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildQuantum(BuildContext context, EnvironmentProvider env) {
    final (lo, hi) = env.heatmap.intensityBounds;
    final peaks = env.heatmap.topCellsDeviceLevel(maxCount: 12, minMicroTesla: 5.5);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TACTICAL EMF MAP',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        letterSpacing: 1.6,
                        color: const Color(0xFF4F46E5),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '탑다운 미니맵: 중앙 삼각형이 나(측정 기준), 책상은 회색 사각형. '
                  '기기급 이상(약 5.5µT+) 격자만 점으로 찍고, 영향권 원은 최대 반지름 1m까지입니다. '
                  '겹치면 약한 쪽 원이 줄어듭니다.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '격자에 쌓는 샘플은 책상 기준 높이에서 수직 ±1m 안에서만 반영합니다(위아래로 멀리 벗어나면 제외).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 6),
                Text(
                  '「우선 조치」는 홈 탭과 동일 기준입니다. AR 좌상단 축(+Z 앞, +X 오른쪽)과 같습니다.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6366F1),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '집중 알림에서는 본인과 EMF 피크 사이의 수평 거리·3D 거리·방위 각도를 함께 안내합니다.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (env.heatmap.filledCellCount == 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '아직 스캔 포인트가 없습니다. 측정을 켠 뒤 책상 위에서 휴대폰을 천천히 움직여 주세요.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6366F1)),
            ),
          ),
        const SizedBox(height: 14),
        SizedBox(
          height: 400,
          child: EmfMinimapWidget(
            deskWidthM: env.deskWidthM,
            deskDepthM: env.deskDepthM,
            phonePose: env.virtualPhonePose,
            scanPoints: peaks,
            intensityMin: lo,
            intensityMax: hi,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '스캔 셀 ${env.heatmap.filledCellCount}개 · 맵 완성도 '
          '${(env.heatmap.completeness * 100).toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SensorPill extends StatelessWidget {
  const _SensorPill({required this.running});

  final bool running;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: running ? const Color(0xFF22C55E).withValues(alpha: 0.45) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            running ? Icons.sensors : Icons.sensors_off_outlined,
            size: 18,
            color: running ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 6),
          Text(
            running ? '측정 중' : '대기',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: running ? const Color(0xFF15803D) : const Color(0xFF64748B),
                ),
          ),
        ],
      ),
    );
  }
}
