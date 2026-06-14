import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/desk_pose.dart';
import '../services/desk_heatmap_store.dart';

/// 게임 미니맵 스타일 **탑다운** EMF 맵. 본인은 중앙, 피크는 녹→적 + 최대 1m 영향권(겹침 완화).
class EmfMinimapWidget extends StatelessWidget {
  const EmfMinimapWidget({
    super.key,
    required this.deskWidthM,
    required this.deskDepthM,
    required this.phonePose,
    required this.scanPoints,
    required this.intensityMin,
    required this.intensityMax,
  });

  final double deskWidthM;
  final double deskDepthM;
  final DeskPose phonePose;
  final List<HeatmapCell> scanPoints;
  final double intensityMin;
  final double intensityMax;

  static const Color _emfGreen = Color(0xFF22C55E);
  static const Color _emfRed = Color(0xFFEF4444);

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
              colors: [
                Color(0xFF0C1222),
                Color(0xFF151B2E),
                Color(0xFF1A1F35),
              ],
            ),
            border: Border.all(color: const Color(0xFF334155), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  size: Size(w, h),
                  painter: _EmfMinimapPainter(
                    deskWidthM: deskWidthM,
                    deskDepthM: deskDepthM,
                    phonePose: phonePose,
                    scanPoints: scanPoints,
                    intensityMin: intensityMin,
                    intensityMax: intensityMax,
                    green: _emfGreen,
                    red: _emfRed,
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF22D3EE).withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'TACTICAL MAP · TOP',
                      style: TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '영향권 최대 1m · 격자 샘플 수직 ±1m',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmfMinimapPainter extends CustomPainter {
  _EmfMinimapPainter({
    required this.deskWidthM,
    required this.deskDepthM,
    required this.phonePose,
    required this.scanPoints,
    required this.intensityMin,
    required this.intensityMax,
    required this.green,
    required this.red,
  });

  final double deskWidthM;
  final double deskDepthM;
  final DeskPose phonePose;
  final List<HeatmapCell> scanPoints;
  final double intensityMin;
  final double intensityMax;
  final Color green;
  final Color red;

  static const double _maxHaloM = 1.0;
  static const double _minHaloM = 0.07;
  static const double _corePx = 5.0;

  double _exclusionPx(double haloPx) => math.max(haloPx, _corePx);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final hw = deskWidthM / 2;
    final hd = deskDepthM / 2;
    final corner = math.sqrt(hw * hw + hd * hd);
    final viewHalfM = math.max(corner + _maxHaloM + 0.08, 1.65);
    final ppm = math.min(size.width, size.height) / (2 * viewHalfM);

    Offset toScreen(double lx, double lz) => Offset(cx + lx * ppm, cy - lz * ppm);

    final bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy),
        size.shortestSide * 0.55,
        [
          const Color(0xFF1E293B).withValues(alpha: 0.35),
          const Color(0xFF0F172A),
        ],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    _drawGrid(canvas, size, cx, cy, ppm, viewHalfM);
    _drawDesk(canvas, hw, hd, toScreen);
    _drawRangeRing(canvas, cx, cy, _maxHaloM * ppm);
    _drawCompass(canvas, size);

    final px = phonePose.x;
    final pz = phonePose.z;

    double lo;
    double hi;
    if (scanPoints.isEmpty) {
      lo = intensityMin;
      hi = intensityMax;
    } else {
      lo = double.infinity;
      hi = -double.infinity;
      for (final c in scanPoints) {
        if (c.intensity < lo) lo = c.intensity;
        if (c.intensity > hi) hi = c.intensity;
      }
      if (hi - lo < 0.25) hi = lo + 0.25;
    }
    final den = (hi - lo).abs() < 1e-6 ? 1.0 : (hi - lo);

    final peaks = scanPoints.map((c) {
      final lx = c.x - px;
      final lz = c.z - pz;
      final t = ((c.intensity - lo) / den).clamp(0.0, 1.0);
      final col = Color.lerp(green, red, t)!;
      final haloM = (_minHaloM + t * (_maxHaloM - _minHaloM)).clamp(_minHaloM, _maxHaloM);
      return _PeakWork(
        lx: lx,
        lz: lz,
        color: col,
        intensity: c.intensity,
        haloM: haloM,
      );
    }).toList()
      ..sort((a, b) => b.intensity.compareTo(a.intensity));

    final placed = <_PlacedHalo>[];
    const gap = 3.0;
    for (final p in peaks) {
      final center = toScreen(p.lx, p.lz);
      var haloPx = p.haloM * ppm;
      for (final o in placed) {
        final d = (center - o.center).distance;
        if (d < haloPx + _exclusionPx(o.haloPx) + gap) {
          haloPx = math.max(0, math.min(haloPx, d - _exclusionPx(o.haloPx) - gap));
        }
      }
      if (haloPx < 3) {
        haloPx = 0;
      }
      placed.add(_PlacedHalo(center: center, haloPx: haloPx, color: p.color));
    }

    for (final o in placed) {
      if (o.haloPx <= 0) continue;
      final haloFill = Paint()
        ..color = o.color.withValues(alpha: 0.14)
        ..style = PaintingStyle.fill;
      final haloStroke = Paint()
        ..color = o.color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(o.center, o.haloPx, haloFill);
      canvas.drawCircle(o.center, o.haloPx, haloStroke);
    }

    for (var i = 0; i < peaks.length; i++) {
      final p = peaks[i];
      final pt = toScreen(p.lx, p.lz);
      final dotR = 4.0 + (p.intensity / math.max(hi, 1.0)) * 2.5;
      final dotFill = Paint()..color = p.color;
      final dotStroke = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1;
      canvas.drawCircle(pt, dotR, dotFill);
      canvas.drawCircle(pt, dotR, dotStroke);
    }

    _drawPlayer(canvas, Offset(cx, cy));
    _drawCornerBrackets(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size, double cx, double cy, double ppm, double viewHalfM) {
    final grid = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: 0.35)
      ..strokeWidth = 0.8;
    const step = 0.25;
    for (var m = -viewHalfM; m <= viewHalfM; m += step) {
      final x = cx + m * ppm;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      final y = cy - m * ppm;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  void _drawDesk(Canvas canvas, double hw, double hd, Offset Function(double, double) toScreen) {
    final p0 = toScreen(-hw, -hd);
    final p1 = toScreen(hw, -hd);
    final p2 = toScreen(hw, hd);
    final p3 = toScreen(-hw, hd);
    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
    final fill = Paint()..color = const Color(0xFF1E293B).withValues(alpha: 0.55);
    final stroke = Paint()
      ..color = const Color(0xFF64748B).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  void _drawRangeRing(Canvas canvas, double cx, double cy, double rPx) {
    final paint = Paint()
      ..color = const Color(0xFF22D3EE).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawCircle(Offset(cx, cy), rPx, paint);
  }

  void _drawCompass(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: const TextSpan(
        text: '앞 +Z',
        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, 6));

    final tp2 = TextPainter(
      text: const TextSpan(
        text: '+X →',
        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(size.width - tp2.width - 8, size.height / 2 - tp2.height / 2));
  }

  void _drawPlayer(Canvas canvas, Offset c) {
    final body = Paint()..color = const Color(0xFF020617);
    final ring = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, 9, body);
    canvas.drawCircle(c, 9, ring);
    final tri = Path()
      ..moveTo(c.dx, c.dy - 14)
      ..lineTo(c.dx - 5, c.dy - 4)
      ..lineTo(c.dx + 5, c.dy - 4)
      ..close();
    canvas.drawPath(tri, Paint()..color = const Color(0xFF38BDF8));
    canvas.drawPath(
      tri,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawCornerBrackets(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF22D3EE).withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const o = 8.0;
    const l = 12.0;
    canvas.drawPath(
      Path()
        ..moveTo(o, o + l)
        ..lineTo(o, o)
        ..lineTo(o + l, o),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - o - l, o)
        ..lineTo(size.width - o, o)
        ..lineTo(size.width - o, o + l),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(o, size.height - o - l)
        ..lineTo(o, size.height - o)
        ..lineTo(o + l, size.height - o),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - o - l, size.height - o)
        ..lineTo(size.width - o, size.height - o)
        ..lineTo(size.width - o, size.height - o - l),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _EmfMinimapPainter oldDelegate) {
    return oldDelegate.scanPoints != scanPoints ||
        oldDelegate.phonePose != phonePose ||
        oldDelegate.intensityMin != intensityMin ||
        oldDelegate.intensityMax != intensityMax ||
        oldDelegate.deskWidthM != deskWidthM ||
        oldDelegate.deskDepthM != deskDepthM;
  }
}

class _PeakWork {
  _PeakWork({
    required this.lx,
    required this.lz,
    required this.color,
    required this.intensity,
    required this.haloM,
  });
  final double lx;
  final double lz;
  final Color color;
  final double intensity;
  final double haloM;
}

class _PlacedHalo {
  _PlacedHalo({required this.center, required this.haloPx, required this.color});
  final Offset center;
  final double haloPx;
  final Color color;
}
