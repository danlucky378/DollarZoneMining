import 'package:shared_preferences/shared_preferences.dart';

class DateUtilsHelper {
  static const _lastResetKey = 'last_reset_date';

  /// Check if we’ve passed 1 AM local time since last reset
  static Future<bool> shouldReset() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReset = prefs.getString(_lastResetKey);
    final now = DateTime.now();

    if (lastReset == null) return true;

    final lastResetDate = DateTime.parse(lastReset);
    // If it’s a new day and after 1 AM, allow reset
    return now.day != lastResetDate.day && now.hour >= 1;
  }

  /// Mark reset as completed
  static Future<void> markReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastResetKey, DateTime.now().toIso8601String());
  }
}