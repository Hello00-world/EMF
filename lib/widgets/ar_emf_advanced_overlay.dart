import 'dart:math' as math;

import 'package:flutter/material.dart';

/// AR: 위험도별 색, 전자기력선(곡선), 방출 방향 화살표 8개.
class ArEmfAdvancedOverlay extends StatelessWidget {
  const ArEmfAdvancedOverlay({
    super.key,
    required this.filteredMicroTesla,
    required this.dx,
    required this.dy,
    required this.dz,
    required this.riskLevel,
  });

  final double filteredMicroTesla;
  final double dx;
  final double dy;
  final double dz;
  final int riskLevel;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ArFieldPainter(
        filteredMicroTesla: filteredMicroTesla,
        dx: dx,
        dy: dy,
        dz: dz,
        riskLevel: riskLevel.clamp(1, 5),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// 하단 범례: 위험도 색 설명.
class ArEmfRiskLegend extends StatelessWidget {
  const ArEmfRiskLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '위험도 색 (높을수록 강함)',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          _legendRow(const Color(0xFF22C55E), '1 안전'),
          _legendRow(const Color(0xFF84CC16), '2 낮음'),
          _legendRow(const Color(0xFFEAB308), '3 주의'),
          _legendRow(const Color(0xFFF97316), '4 높음'),
          _legendRow(const Color(0xFFEF4444), '5 매우 위험'),
        ],
      ),
    );
  }

  static Widget _legendRow(Color c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 4)],
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _ArFieldPainter extends CustomPainter {
  _ArFieldPainter({
    required this.filteredMicroTesla,
    required this.dx,
    required this.dy,
    required this.dz,
    required this.riskLevel,
  });

  final double filteredMicroTesla;
  final double dx;
  final double dy;
  final double dz;
  final int riskLevel;

  static const int _cols = 16;
  static const int _rows = 24;

  static double _tanhScaled(double v, double scale) {
    final x = v / scale;
    return (math.exp(x) - math.exp(-x)) / (math.exp(x) + math.exp(-x));
  }

  Color _riskHeatColor(int level, double tLocal) {
    const c1 = Color(0xFF22C55E);
    const c2 = Color(0xFF84CC16);
    const c3 = Color(0xFFEAB308);
    const c4 = Color(0xFFF97316);
    const c5 = Color(0xFFEF4444);
    final lv = level.clamp(1, 5);
    return switch (lv) {
      1 => Color.lerp(c1, c2, tLocal)!,
      2 => Color.lerp(c2, c3, tLocal)!,
      3 => Color.lerp(c3, c4, tLocal)!,
      4 => Color.lerp(c4, c5, tLocal)!,
      _ => Color.lerp(c4, c5, tLocal)!,
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final base = (filteredMicroTesla / 12.0).clamp(0.0, 1.0);
    final hotU = 0.5 + _tanhScaled(dx, 18.0) * 0.44;
    final hotV = 0.5 + _tanhScaled(dz, 18.0) * 0.44;
    final dyBoost = (dy.abs() / 28.0).clamp(0.0, 0.4);

    final cw = w / _cols;
    final ch = h / _rows;

    for (var j = 0; j < _rows; j++) {
      for (var i = 0; i < _cols; i++) {
        final u = (i + 0.5) / _cols;
        final v = (j + 0.5) / _rows;
        final du = u - hotU;
        final dv = v - hotV;
        final dist2 = du * du + dv * dv;
        var local = base * math.exp(-dist2 * 8.5) + base * 0.2 + dyBoost * 0.18;
        local += (riskLevel - 1) / 20.0;
        final t = local.clamp(0.0, 1.0);
        final col = _riskHeatColor(riskLevel, t).withValues(alpha: 0.35 + t * 0.28);
        final paint = Paint()..color = col;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(i * cw, j * ch, cw + 0.5, ch + 0.5),
          const Radius.circular(2),
        );
        canvas.drawRRect(rect, paint);
      }
    }

    final cx = w * hotU;
    final cy = h * hotV;

    _drawFieldLines(canvas, cx, cy, dx, dz, riskLevel);
    _drawEmissionArrows(canvas, size, cx, cy, dx, dz, riskLevel);
  }

  void _drawFieldLines(Canvas canvas, double cx, double cy, double bx, double bz, int risk) {
    final mag = math.sqrt(bx * bx + bz * bz) + 0.001;
    final nx = bx / mag;
    final nz = bz / mag;

    final linePaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.32 + risk * 0.07)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const nLines = 12;
    for (var k = 0; k < nLines; k++) {
      final a0 = 2 * math.pi * k / nLines;
      final path = Path();
      final sx = cx + math.cos(a0) * 22;
      final sy = cy + math.sin(a0) * 22;
      path.moveTo(sx, sy);
      final ex = cx + math.cos(a0) * 140 + nx * 28;
      final ey = cy + math.sin(a0) * 140 + nz * 28;
      final c1 = Offset(
        cx + math.cos(a0 + 0.25) * 75 + nx * 45,
        cy + math.sin(a0 + 0.25) * 75 + nz * 45,
      );
      path.quadraticBezierTo(c1.dx, c1.dy, ex, ey);
      canvas.drawPath(path, linePaint);
    }
  }

  void _drawEmissionArrows(Canvas canvas, Size size, double cx, double cy, double bx, double bz, int risk) {
    final mag = math.sqrt(bx * bx + bz * bz);
    final baseAngle = mag > 0.2 ? math.atan2(bz, bx) : 0.0;
    final r = math.min(size.width, size.height) * 0.14;

    final arrowColor = Color.lerp(
      const Color(0xFF38BDF8),
      const Color(0xFFF43F5E),
      (risk - 1) / 4.0,
    )!;

    const count = 8;
    for (var i = 0; i < count; i++) {
      final ang = baseAngle + 2 * math.pi * i / count + 0.12;
      final sx = cx + math.cos(ang) * (r * 0.35);
      final sy = cy + math.sin(ang) * (r * 0.35);
      final ex = cx + math.cos(ang) * (r * 1.05);
      final ey = cy + math.sin(ang) * (r * 1.05);

      final p = Paint()
        ..color = arrowColor.withValues(alpha: 0.88)
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(sx, sy), Offset(ex, ey), p);

      const head = 13.0;
      const ah = 0.42;
      final lineAng = math.atan2(ey - sy, ex - sx);
      final p1 = Offset(
        ex - head * math.cos(lineAng - ah),
        ey - head * math.sin(lineAng - ah),
      );
      final p2 = Offset(
        ex - head * math.cos(lineAng + ah),
        ey - head * math.sin(lineAng + ah),
      );
      final headPath = Path()
        ..moveTo(ex, ey)
        ..lineTo(p1.dx, p1.dy)
        ..moveTo(ex, ey)
        ..lineTo(p2.dx, p2.dy);
      canvas.drawPath(headPath, p);
    }
  }

  @override
  bool shouldRepaint(covariant _ArFieldPainter oldDelegate) {
    return oldDelegate.filteredMicroTesla != filteredMicroTesla ||
        oldDelegate.dx != dx ||
        oldDelegate.dy != dy ||
        oldDelegate.dz != dz ||
        oldDelegate.riskLevel != riskLevel;
  }
}
