import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 학습 앱 스타일: 중앙 Focus Score + 외곽 진행 링(점수) + 안쪽 보조 링(세션/맵).
class FocusScoreGauge extends StatelessWidget {
  const FocusScoreGauge({
    super.key,
    required this.score,
    this.secondaryProgress,
    this.size = 220,
    this.strokeWidth = 14,
  });

  final double score;
  /// 0~1. 집중 세션 중이면 포모 목표 대비 경과, 아니면 null이면 맵 완성도 등으로 채움.
  final double? secondaryProgress;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final t = (score / 100).clamp(0.0, 1.0);
    final primaryColor = Color.lerp(
      const Color(0xFFEF4444),
      const Color(0xFF22C55E),
      t,
    )!;
    final sec = secondaryProgress?.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: t,
              color: primaryColor,
              strokeWidth: strokeWidth,
              startAngle: -math.pi / 2,
              backgroundColor: const Color(0xFFE2E8F0),
            ),
          ),
          if (sec != null)
            CustomPaint(
              size: Size(size * 0.72, size * 0.72),
              painter: _RingPainter(
                progress: sec,
                color: const Color(0xFF6366F1).withValues(alpha: 0.85),
                strokeWidth: strokeWidth * 0.45,
                startAngle: -math.pi / 2,
                backgroundColor: const Color(0xFFEEF2FF),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  color: const Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Focus Score',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.6,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.startAngle,
    required this.backgroundColor,
  });

  final double progress;
  final Color color;
  final double strokeWidth;
  final double startAngle;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = (size.shortestSide - strokeWidth) / 2;
    final bg = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, r, bg);
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      startAngle,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
