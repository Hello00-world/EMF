import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/desk_pose.dart';
import '../models/focus_zone_cell.dart';

/// 탑다운 주변 스캔 맵 — 격자 색 = Focus Score(녹=높음, 적=낮음), 별 = 최고 구역.
class FocusZoneMapWidget extends StatelessWidget {
  const FocusZoneMapWidget({
    super.key,
    required this.spanM,
    required this.phonePose,
    required this.cells,
    this.bestZone,
  });

  final double spanM;
  final DeskPose phonePose;
  final List<FocusZoneCell> cells;
  final FocusZoneCell? bestZone;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0C1222), Color(0xFF151B2E), Color(0xFF1A1F35)],
            ),
            border: Border.all(color: const Color(0xFF334155), width: 1.2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: CustomPaint(
              size: Size(w, h),
              painter: _FocusZoneMapPainter(
                spanM: spanM,
                phonePose: phonePose,
                cells: cells,
                bestZone: bestZone,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FocusZoneMapPainter extends CustomPainter {
  _FocusZoneMapPainter({
    required this.spanM,
    required this.phonePose,
    required this.cells,
    required this.bestZone,
  });

  final double spanM;
  final DeskPose phonePose;
  final List<FocusZoneCell> cells;
  final FocusZoneCell? bestZone;

  static const Color _scoreGreen = Color(0xFF22C55E);
  static const Color _scoreRed = Color(0xFFEF4444);

  @override
  void paint(Canvas canvas, Size size) {
    final half = spanM / 2;
    final pad = 28.0;
    final mapW = size.width - pad * 2;
    final mapH = size.height - pad * 2;
    final scale = math.min(mapW, mapH) / spanM;
    final cx = size.width / 2;
    final cy = size.height / 2;

    Offset toScreen(double x, double z) {
      return Offset(cx + x * scale, cy - z * scale);
    }

    final bg = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(pad, pad, mapW, mapH), const Radius.circular(12)),
      bg,
    );

    final gridPaint = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: 0.35)
      ..strokeWidth = 0.6;
    for (var i = -3; i <= 3; i++) {
      final o = toScreen(i.toDouble(), 0);
      canvas.drawLine(Offset(o.dx, pad), Offset(o.dx, size.height - pad), gridPaint);
      final o2 = toScreen(0, i.toDouble());
      canvas.drawLine(Offset(pad, o2.dy), Offset(size.width - pad, o2.dy), gridPaint);
    }

    if (cells.isNotEmpty) {
      var minS = cells.last.focusScore;
      var maxS = cells.first.focusScore;
      if (maxS - minS < 1) {
        minS -= 0.5;
        maxS += 0.5;
      }
      for (final c in cells) {
        final t = ((c.focusScore - minS) / (maxS - minS)).clamp(0.0, 1.0);
        final color = Color.lerp(_scoreRed, _scoreGreen, t)!;
        final p = toScreen(c.x, c.z);
        final r = 10.0 + math.sqrt(c.sampleCount.toDouble()) * 1.2;
        canvas.drawCircle(
          p,
          r,
          Paint()..color = color.withValues(alpha: 0.82),
        );
      }
    }

    if (bestZone != null) {
      final bp = toScreen(bestZone!.x, bestZone!.z);
      final star = Paint()
        ..color = const Color(0xFFFBBF24)
        ..style = PaintingStyle.fill;
      _drawStar(canvas, bp, 14, star);
      final ring = Paint()
        ..color = const Color(0xFFFBBF24).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(bp, 22, ring);
    }

    final me = toScreen(phonePose.x, phonePose.z);
    final tri = Path()
      ..moveTo(me.dx, me.dy - 10)
      ..lineTo(me.dx - 8, me.dy + 8)
      ..lineTo(me.dx + 8, me.dy + 8)
      ..close();
    canvas.drawPath(tri, Paint()..color = const Color(0xFF22D3EE));
    canvas.drawPath(
      tri,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final origin = toScreen(0, 0);
    canvas.drawCircle(
      origin,
      4,
      Paint()..color = const Color(0xFF94A3B8).withValues(alpha: 0.8),
    );

    final label = TextPainter(
      text: TextSpan(
        text: '±${half.toStringAsFixed(0)}m · 높이 ±1m',
        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(pad + 4, pad + 4));
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 4 * math.pi / 5;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FocusZoneMapPainter old) =>
      old.cells != cells ||
      old.bestZone != bestZone ||
      old.phonePose != phonePose;
}
