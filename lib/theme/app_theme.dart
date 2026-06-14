import 'package:flutter/material.dart';

/// 밝고 미래지향적인 UI (PRD: 몰입·가독성).
class AppTheme {
  static const Color _ice = Color(0xFFE8EEF9);
  static const Color _surface = Color(0xFFF5F8FF);
  static const Color _accent = Color(0xFF6366F1);
  static const Color _accent2 = Color(0xFF22D3EE);

  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: Brightness.light,
      primary: _accent,
      secondary: _accent2,
      surface: _surface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: base,
      scaffoldBackgroundColor: _ice,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0.5,
        backgroundColor: _surface.withValues(alpha: 0.92),
        foregroundColor: const Color(0xFF1E1B4B),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E1B4B),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white.withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        indicatorColor: _accent.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: const Color(0xFF312E81),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? _accent : const Color(0xFF64748B),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF334155), height: 1.45),
        bodyMedium: TextStyle(color: Color(0xFF475569), height: 1.45),
        bodySmall: TextStyle(color: Color(0xFF64748B), height: 1.4),
        titleMedium: TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 학습/집중 앱식 간격 스케일.
  static const double gapXs = 6;
  static const double gapSm = 10;
  static const double gapMd = 16;
  static const double gapLg = 22;
  static const double radiusCard = 16;
  static const double radiusHero = 22;

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: _accent.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}
