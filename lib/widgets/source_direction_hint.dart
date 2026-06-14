import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 자기장 변화 벡터(dx,dy,dz)를 화면 상단 힌트로 투영(단순 근사).
class SourceDirectionHint extends StatelessWidget {
  const SourceDirectionHint({
    super.key,
    required this.dx,
    required this.dy,
    required this.dz,
  });

  final double dx;
  final double dy;
  final double dz;

  @override
  Widget build(BuildContext context) {
    final mag = math.sqrt(dx * dx + dy * dy + dz * dz);
    if (mag < 0.5) {
      return const SizedBox.shrink();
    }
    final nx = dx / mag;
    final nz = dz / mag;
    return LayoutBuilder(
      builder: (context, c) {
        return CustomPaint(
          size: Size(c.maxWidth, c.maxHeight),
          painter: _ArrowPainter(nx: nx, nz: nz, strength: (mag / 25).clamp(0.2, 1.0)),
        );
      },
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.nx, required this.nz, required this.strength});

  final double nx;
  final double nz;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final len = 22 + 40 * strength;
    final ex = cx + nx * len;
    final ey = cy - nz * len;
    final paint = Paint()
      ..color = const Color(0xFF4F46E5).withValues(alpha: 0.92)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(cx, cy), Offset(ex, ey), paint);

    final ang = math.atan2(ey - cy, ex - cx);
    final ah = 0.45;
    final s1 = Offset(
      ex - 14 * math.cos(ang - ah),
      ey - 14 * math.sin(ang - ah),
    );
    final s2 = Offset(
      ex - 14 * math.cos(ang + ah),
      ey - 14 * math.sin(ang + ah),
    );
    final path = Path()
      ..moveTo(ex, ey)
      ..lineTo(s1.dx, s1.dy)
      ..moveTo(ex, ey)
      ..lineTo(s2.dx, s2.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) {
    return oldDelegate.nx != nx || oldDelegate.nz != nz || oldDelegate.strength != strength;
  }
}
