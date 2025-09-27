import 'package:shared_preferences/shared_preferences.dart';

/// Enumerates available reader modes.
enum ReaderMode { vertical, paged }

/// Abstraction for reader related user preferences.
class ReaderPreferences {
  ReaderPreferences._(this._prefs);
  static const String _keyMode = 'reader.mode';

  final SharedPreferences _prefs;

  static Future<ReaderPreferences> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ReaderPreferences._(prefs);
  }

  ReaderMode get mode {
    final value = _prefs.getString(_keyMode);
    switch (value) {
      case 'paged':
        return ReaderMode.paged;
      case 'vertical':
      default:
        return ReaderMode.vertical;
    }
  }

  Future<void> setMode(ReaderMode mode) async {
    await _prefs.setString(_keyMode, mode.name);
  }
}
