import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/environment_provider.dart';
import 'focus_environment_alert_dialog.dart';

/// [EnvironmentProvider.pendingFocusAlert]가 켜지면 한 번만 집중 저하 다이얼로그를 띄웁니다.
class FocusScoreAlertHost extends StatefulWidget {
  const FocusScoreAlertHost({super.key, required this.child});

  final Widget child;

  @override
  State<FocusScoreAlertHost> createState() => _FocusScoreAlertHostState();
}

class _FocusScoreAlertHostState extends State<FocusScoreAlertHost> {
  bool _dialogScheduled = false;

  @override
  Widget build(BuildContext context) {
    final env = context.watch<EnvironmentProvider>();

    if (!env.pendingFocusAlert) {
      _dialogScheduled = false;
    } else if (!_dialogScheduled) {
      _dialogScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final e = context.read<EnvironmentProvider>();
        if (!e.pendingFocusAlert) {
          _dialogScheduled = false;
          return;
        }
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => FocusEnvironmentAlertDialog(
            adviceText: e.focusDropAdviceText,
          ),
        );
        if (!mounted) return;
        e.acknowledgeFocusAlert();
        _dialogScheduled = false;
      });
    }

    return widget.child;
  }
}
