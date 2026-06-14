import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 카메라 프리뷰 위 실시간 EMF 히트맵: 청→적 그라데이션 격자 + 자기장 벡터 기반 핫스팟.
class ArEmfHeatmapOverlay extends StatelessWidget {
  const ArEmfHeatmapOverlay({
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
      painter: _HeatmapPainter(
        filteredMicroTesla: filteredMicroTesla,
        dx: dx,
        dy: dy,
        dz: dz,
        riskLevel: riskLevel,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
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

  static const int _cols = 18;
  static const int _rows = 28;

  static double _tanhScaled(double v, double scale) {
    final x = v / scale;
    return (math.exp(x) - math.exp(-x)) / (math.exp(x) + math.exp(-x));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // 일상 근거리 기기에서도 적색이 잘 보이도록 스케일 완화 (구 58µT → ~14µT 기준)
    final base = (filteredMicroTesla / 14.0).clamp(0.0, 1.0);
    final riskT = ((riskLevel - 1) / 4.0).clamp(0.0, 1.0);

    // 자기장 수평 성분 → 화면 핫스팟 (전자기 "중심" 방향 시각화)
    final hotU = 0.5 + _tanhScaled(dx, 22.0) * 0.42;
    final hotV = 0.5 + _tanhScaled(dz, 22.0) * 0.42;
    final dyBoost = (dy.abs() / 35.0).clamp(0.0, 0.35);

    const cold = Color(0xFF0EA5E9);
    const hot = Color(0xFFFF3366);

    final cw = w / _cols;
    final ch = h / _rows;

    for (var j = 0; j < _rows; j++) {
      for (var i = 0; i < _cols; i++) {
        final u = (i + 0.5) / _cols;
        final v = (j + 0.5) / _rows;
        final du = u - hotU;
        final dv = v - hotV;
        final dist2 = du * du + dv * dv;
        var local = base * math.exp(-dist2 * 9.0) + base * 0.22 + dyBoost * 0.15;
        local += riskT * 0.08;
        final t = local.clamp(0.0, 1.0);
        final c = Color.lerp(cold, hot, t)!;
        final paint = Paint()
          ..color = c.withValues(alpha: 0.38 + t * 0.22)
          ..style = PaintingStyle.fill;

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(i * cw, j * ch, cw + 0.5, ch + 0.5),
          const Radius.circular(2),
        );
        canvas.drawRRect(rect, paint);
      }
    }

    // 중앙 십자 가이드 (약하게)
    final g = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), g);
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), g);
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return oldDelegate.filteredMicroTesla != filteredMicroTesla ||
        oldDelegate.dx != dx ||
        oldDelegate.dy != dy ||
        oldDelegate.dz != dz ||
        oldDelegate.riskLevel != riskLevel;
  }
}
