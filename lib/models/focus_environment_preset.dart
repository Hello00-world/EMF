/// 집중 알림 민감도 — [standard]는 60점, [sensitive]는 70점 이하에서 알림.
enum FocusEnvironmentPreset {
  /// 일반 (이 점수 이하로 떨어지면 알림).
  standard,

  /// 도서관·독서실 (조금 더 일찍).
  libraryQuiet,

  /// 민감 (더 일찍 알림).
  sensitive,
}

extension FocusEnvironmentPresetX on FocusEnvironmentPreset {
  double get focusAlertThreshold {
    switch (this) {
      case FocusEnvironmentPreset.standard:
        return 60;
      case FocusEnvironmentPreset.libraryQuiet:
        return 63;
      case FocusEnvironmentPreset.sensitive:
        return 70;
    }
  }

  String get labelKo {
    switch (this) {
      case FocusEnvironmentPreset.standard:
        return '일반 (≤60점)';
      case FocusEnvironmentPreset.libraryQuiet:
        return '도서관·독서실 (≤63점)';
      case FocusEnvironmentPreset.sensitive:
        return '민감 (≤70점)';
    }
  }
}
