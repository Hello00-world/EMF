import 'dart:math' as math;

import 'package:flutter/material.dart';

/// AR 카메라 프리뷰 위 오버레이: 위험도(1–5)에 따라 파랑→빨강 입자 밀도·속도 조절.
class EmfParticleOverlay extends StatelessWidget {
  const EmfParticleOverlay({
    super.key,
    required this.riskLevel,
    this.seed = 42,
    this.lightMode = false,
  });

  final int riskLevel;
  final int seed;
  final bool lightMode;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ParticlePainter(
        risk: riskLevel.clamp(1, 5),
        seed: seed,
        lightMode: lightMode,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.risk, required this.seed, required this.lightMode});

  final int risk;
  final int seed;
  final bool lightMode;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final t = (risk - 1) / 4.0;
    final count = 28 + (t * 72).round();
    final speed = 0.4 + t * 1.6;
    final alphaScale = lightMode ? 0.45 : 1.0;

    for (var i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = 1.2 + rnd.nextDouble() * (1.5 + t * 2.5);
      final base = Color.lerp(const Color(0xFF38BDF8), const Color(0xFFF43F5E), t)!;
      final paint = Paint()
        ..color = base.withValues(alpha: (0.12 + t * 0.28) * alphaScale)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(Offset(x, y), r, paint);

      final ox = (rnd.nextDouble() - 0.5) * 6 * speed;
      final oy = (rnd.nextDouble() - 0.5) * 6 * speed - t * 8;
      canvas.drawCircle(Offset(x + ox, y + oy), r * 0.55, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.risk != risk ||
        oldDelegate.seed != seed ||
        oldDelegate.lightMode != lightMode;
  }
}
