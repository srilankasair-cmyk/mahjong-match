import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_config.dart';

class ProgressService {
  static const _keyPrefix = 'level_completed_';

  static String _key(LevelMode mode) => '$_keyPrefix${mode.name}';

  static Future<void> markCompleted(LevelMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(mode), true);
  }

  static Future<bool> isCompleted(LevelMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(mode)) ?? false;
  }

  static Future<Map<LevelMode, bool>> loadAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final mode in LevelMode.values)
        mode: prefs.getBool(_key(mode)) ?? false,
    };
  }

  static Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    for (final mode in LevelMode.values) {
      await prefs.remove(_key(mode));
    }
  }
}
