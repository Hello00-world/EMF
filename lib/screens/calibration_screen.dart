import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../services/calibration_store.dart';

/// 8자 그리기 UX + 이 구간 동안 자기장 평균을 하드 아이언 오프셋으로 저장합니다.
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  final List<Offset> _path = [];
  final List<MagnetometerEvent> _magSamples = [];
  StreamSubscription<MagnetometerEvent>? _magSub;
  bool _drawing = false;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startMagnetometer();
  }

  Future<void> _startMagnetometer() async {
    try {
      await _magSub?.cancel();
      _magSub = magnetometerEventStream(samplingPeriod: const Duration(milliseconds: 20)).listen(
        (e) {
          if (_drawing) {
            _magSamples.add(e);
          }
        },
        onError: (Object e, StackTrace st) {
          debugPrint('calibration magnetometer: $e\n$st');
          setState(() => _error = '자기장 센서를 사용할 수 없습니다. 이 화면을 건너뛰려면 아래 버튼을 누르세요.');
        },
      );
    } catch (e, st) {
      debugPrint('calibration start: $e\n$st');
      setState(() => _error = '센서 초기화에 실패했습니다.');
    }
  }

  @override
  void dispose() {
    unawaited(_magSub?.cancel());
    super.dispose();
  }

  Future<void> _complete() async {
    if (_magSamples.isEmpty) {
      setState(() => _error = '8자를 그리는 동안 자기장 샘플이 수집되지 않았습니다. 손가락을 떼지 않고 천천히 다시 시도해 주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var sx = 0.0;
      var sy = 0.0;
      var sz = 0.0;
      for (final e in _magSamples) {
        sx += e.x;
        sy += e.y;
        sz += e.z;
      }
      final n = _magSamples.length.toDouble();
      final store = CalibrationStore();
      await store.saveOffset(sx / n, sy / n, sz / n);
      if (mounted) widget.onFinished();
    } catch (e, st) {
      debugPrint('calibration save: $e\n$st');
      setState(() => _error = '보정 데이터를 저장하지 못했습니다.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _skip() async {
    setState(() => _saving = true);
    try {
      await CalibrationStore().saveOffset(0, 0, 0);
      if (mounted) widget.onFinished();
    } catch (e, st) {
      debugPrint('calibration skip: $e\n$st');
      if (mounted) setState(() => _error = '건너뛰기 설정에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('환경 보정 (8자 그리기)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '화면 위에서 천천히 「8」 모양을 그려 주세요. 이 동안 수집된 자기장 평균으로 주변 DC 성분을 맞춥니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Card(
                color: Colors.red.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (context, c) {
                    return GestureDetector(
                      onPanStart: (_) {
                        setState(() {
                          _drawing = true;
                          _path.clear();
                          _magSamples.clear();
                        });
                      },
                      onPanUpdate: (d) {
                        setState(() {
                          _path.add(d.localPosition);
                        });
                      },
                      onPanEnd: (_) {
                        setState(() => _drawing = false);
                      },
                      child: CustomPaint(
                        painter: _FigureEightGuidePainter(path: _path, drawing: _drawing),
                        size: Size(c.maxWidth, c.maxHeight),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('수집 샘플: ${_magSamples.length}', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _complete,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('보정 완료'),
            ),
            TextButton(
              onPressed: _saving ? null : _skip,
              child: const Text('건너뛰기 (보정 없이 시작)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FigureEightGuidePainter extends CustomPainter {
  _FigureEightGuidePainter({required this.path, required this.drawing});

  final List<Offset> path;
  final bool drawing;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawRect(Offset.zero & size, bg);

    final guide = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width * 0.28;
    final ry = size.height * 0.22;
    final path8 = Path();
    for (var t = 0.0; t <= 1.0; t += 0.01) {
      final u = t * math.pi * 2;
      final x = cx + rx * math.sin(u);
      final y = cy + ry * math.sin(u) * math.cos(u);
      if (t == 0) {
        path8.moveTo(x, y);
      } else {
        path8.lineTo(x, y);
      }
    }
    canvas.drawPath(path8, guide);

    if (path.length > 1) {
      final trace = Paint()
        ..color = drawing ? const Color(0xFF6366F1) : const Color(0xFF22D3EE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final p = Path()..moveTo(path.first.dx, path.first.dy);
      for (var i = 1; i < path.length; i++) {
        p.lineTo(path[i].dx, path[i].dy);
      }
      canvas.drawPath(p, trace);
    }
  }

  @override
  bool shouldRepaint(covariant _FigureEightGuidePainter oldDelegate) {
    return oldDelegate.drawing != drawing || !listEquals(oldDelegate.path, path);
  }
}
