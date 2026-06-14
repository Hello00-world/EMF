import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/environment_provider.dart';
import 'screens/app_shell.dart';
import 'screens/calibration_screen.dart';
import 'services/calibration_store.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EmfQuantumFocusApp());
}

class EmfQuantumFocusApp extends StatelessWidget {
  const EmfQuantumFocusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EMF Quantum Focus',
      theme: AppTheme.light(),
      home: const _Bootstrap(),
    );
  }
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  bool _loading = true;
  bool _calibrationDone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final done = await CalibrationStore().isCalibrationDone();
      if (mounted) {
        setState(() {
          _calibrationDone = done;
          _loading = false;
        });
      }
    } catch (e, st) {
      debugPrint('_Bootstrap _load: $e\n$st');
      if (mounted) {
        setState(() {
          _calibrationDone = false;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_calibrationDone) {
      return CalibrationScreen(
        onFinished: () {
          setState(() => _calibrationDone = true);
        },
      );
    }
    return ChangeNotifierProvider(
      create: (_) => EnvironmentProvider(),
      child: const AppShell(),
    );
  }
}
