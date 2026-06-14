import 'package:shared_preferences/shared_preferences.dart';

/// 집중 세션 누적 시간·횟수 (로컬만 저장, 학습 앱의 통계 패널용).
class FocusStatsSnapshot {
  const FocusStatsSnapshot({
    required this.totalSeconds,
    required this.todaySeconds,
    required this.completedSessions,
  });

  final int totalSeconds;
  final int todaySeconds;
  final int completedSessions;

  static const empty = FocusStatsSnapshot(totalSeconds: 0, todaySeconds: 0, completedSessions: 0);
}

class FocusStatsStore {
  static const _kTotal = 'focus_stats_total_sec_v1';
  static const _kToday = 'focus_stats_today_sec_v1';
  static const _kDay = 'focus_stats_day_key_v1';
  static const _kSessions = 'focus_stats_sessions_v1';

  String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  Future<FocusStatsSnapshot> load() async {
    final p = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final key = _dayKey(now);
    final storedDay = p.getString(_kDay);
    final total = p.getInt(_kTotal) ?? 0;
    final sessions = p.getInt(_kSessions) ?? 0;
    final todayRaw = p.getInt(_kToday) ?? 0;
    final today = storedDay == key ? todayRaw : 0;
    return FocusStatsSnapshot(
      totalSeconds: total,
      todaySeconds: today,
      completedSessions: sessions,
    );
  }

  /// 세션 종료 시 호출 — 1초 이상일 때만 집계.
  Future<void> addCompletedSession(Duration elapsed) async {
    if (elapsed.inSeconds < 1) return;
    final sec = elapsed.inSeconds;
    final p = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final key = _dayKey(now);
    final storedDay = p.getString(_kDay);
    var today = p.getInt(_kToday) ?? 0;
    if (storedDay != key) {
      today = 0;
    }
    today += sec;
    await p.setString(_kDay, key);
    await p.setInt(_kToday, today);
    await p.setInt(_kTotal, (p.getInt(_kTotal) ?? 0) + sec);
    await p.setInt(_kSessions, (p.getInt(_kSessions) ?? 0) + 1);
  }
}
