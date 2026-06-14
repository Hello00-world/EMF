import 'package:flutter/material.dart';

import '../providers/environment_provider.dart';

String formatFocusDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final h = d.inHours;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:$m:$s';
  }
  return '$m:$s';
}

/// Forest/스터디 타이머류: 다른 탭에서도 집중 세션 상태가 보이도록 하단 스트립.
class FocusSessionStrip extends StatelessWidget {
  const FocusSessionStrip({
    super.key,
    required this.env,
    required this.onOpenDashboard,
  });

  final EnvironmentProvider env;
  final VoidCallback onOpenDashboard;

  @override
  Widget build(BuildContext context) {
    final elapsed = env.focusSessionElapsed;
    final goalSec = EnvironmentProvider.focusGoalMinutes * 60;
    final goalProgress = (elapsed.inSeconds / goalSec).clamp(0.0, 1.0);
    final score = env.currentFocusScore;

    return Material(
      elevation: 6,
      shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.35),
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF312E81).withValues(alpha: 0.97),
              const Color(0xFF1E1B4B).withValues(alpha: 0.98),
            ],
          ),
          border: Border(
            top: BorderSide(color: const Color(0xFF22D3EE).withValues(alpha: 0.45)),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          14,
          10,
          8,
          10 + MediaQuery.paddingOf(context).bottom * 0.0,
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.timer_outlined, color: Color(0xFF4ADE80), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '집중 세션',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF94A3B8),
                            letterSpacing: 0.8,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatFocusDuration(elapsed),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [],
                      ),
                    ),
                    Text(
                      '목표 ${EnvironmentProvider.focusGoalMinutes}분 · ${(goalProgress * 100).toStringAsFixed(0)}% · '
                      '알림 ${env.effectiveFocusAlertThreshold.toStringAsFixed(0)}점 이하',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    score.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'SCORE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF94A3B8),
                          fontSize: 9,
                        ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: onOpenDashboard,
                child: const Text('홈'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
