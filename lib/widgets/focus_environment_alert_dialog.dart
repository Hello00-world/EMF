import 'package:flutter/material.dart';

/// 집중 저하 알림 — 기존 안내 문구 + **선택형 체크리스트**(행동 기억 보조, 확인과 무관).
class FocusEnvironmentAlertDialog extends StatefulWidget {
  const FocusEnvironmentAlertDialog({
    super.key,
    required this.adviceText,
  });

  final String adviceText;

  @override
  State<FocusEnvironmentAlertDialog> createState() => _FocusEnvironmentAlertDialogState();
}

class _FocusEnvironmentAlertDialogState extends State<FocusEnvironmentAlertDialog> {
  static const _hints = <String>[
    '충전기·멀티탭·어댑터를 50cm 이상 띄웠다',
    '노트북·모니터·스피커 전원·위치를 점검했다',
    '금속 트레이·스탠드 램프를 의심 위치에서 치웠다',
    '휴대폰을 책상 위에 안정적으로 두었다',
  ];

  final List<bool> _checked = List<bool>.filled(_hints.length, false);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
          SizedBox(width: 8),
          Expanded(child: Text('집중 환경 알림')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.adviceText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              '정리 체크(선택)',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '체크 여부와 관계없이 확인을 누르면 됩니다. 한 번에 한 가지만 해도 좋아요.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            ...List<Widget>.generate(_hints.length, (i) {
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _checked[i],
                onChanged: (v) => setState(() => _checked[i] = v ?? false),
                title: Text(_hints[i], style: Theme.of(context).textTheme.bodySmall),
                controlAffinity: ListTileControlAffinity.leading,
              );
            }),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인 — 정리 후 다시 측정'),
        ),
      ],
    );
  }
}
