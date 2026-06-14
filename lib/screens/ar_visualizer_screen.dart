import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../providers/environment_provider.dart';
import '../widgets/ar_emf_advanced_overlay.dart';
import '../widgets/emf_particle_overlay.dart';

/// 카메라 AR + 실시간 EMF 컬러 히트맵(청→적) + 파티클. 영상은 온디바이스만.
class ArVisualizerScreen extends StatefulWidget {
  const ArVisualizerScreen({super.key});

  @override
  State<ArVisualizerScreen> createState() => _ArVisualizerScreenState();
}

class _ArVisualizerScreenState extends State<ArVisualizerScreen> {
  CameraController? _cam;
  String? _error;
  Timer? _powerHintTimer;
  bool _hintShown = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initCamera());
    _powerHintTimer = Timer(const Duration(minutes: 5), () {
      if (!mounted || _hintShown) return;
      _hintShown = true;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('절전 제안'),
          content: const Text(
            'AR 모드를 오래 사용하면 발열과 배터리 소모가 커질 수 있습니다. 잠시 휴식하거나 EMF 미니맵으로 전환해 보세요.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
          ],
        ),
      );
    });
  }

  Future<void> _initCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() => _error = '카메라 권한이 필요합니다. 설정에서 허용해 주세요.');
        return;
      }
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _error = '사용 가능한 카메라가 없습니다.');
        return;
      }
      final ctrl = CameraController(
        cams.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _cam = ctrl;
        _error = null;
      });
    } catch (e, st) {
      debugPrint('AR camera init: $e\n$st');
        setState(() => _error = '카메라를 시작할 수 없습니다. 저조도 환경이면 EMF 미니맵을 이용해 주세요.');
    }
  }

  @override
  void dispose() {
    _powerHintTimer?.cancel();
    unawaited(_cam?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final env = context.watch<EnvironmentProvider>();
    final snap = env.latestSnapshot;
    final risk = snap?.riskLevel ?? 1;
    final m = snap?.filteredMagnitudeMicroTesla ?? 0;
    final dx = snap?.dx ?? 0;
    final dy = snap?.dy ?? 0;
    final dz = snap?.dz ?? 0;

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    if (_cam == null || !_cam!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cam!),
        ArEmfAdvancedOverlay(
          filteredMicroTesla: m,
          dx: dx,
          dy: dy,
          dz: dz,
          riskLevel: risk,
        ),
        EmfParticleOverlay(
          riskLevel: risk,
          seed: snap?.timestamp.millisecondsSinceEpoch ?? 0,
          lightMode: true,
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: const Text(
              '미니맵과 동일 축\n앞(+Z) · 오른쪽(+X)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 10,
          child: const ArEmfRiskLegend(),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                '실시간 EMF · 시안 곡선=전자기력선 · 파란↔빨강 화살표=방출 방향(8개) · '
                'ICNIRP(참고) ${snap?.icnirpBand ?? '—'} · 위험도 $risk/5 · ${m.toStringAsFixed(1)} µT',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
