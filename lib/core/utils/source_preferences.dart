import 'package:shared_preferences/shared_preferences.dart';

/// Persistence layer for source selection & sync metadata.
class SourcePreferences {
  SourcePreferences._(this._prefs);
  final SharedPreferences _prefs;

  static const String _keyEnabled = 'sources.enabled'; // string list
  static const String _prefixSync = 'source.sync.'; // + sourceId => ISO8601

  static Future<SourcePreferences> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SourcePreferences._(prefs);
  }

  Set<String> enabledSources() {
    final list = _prefs.getStringList(_keyEnabled) ?? const <String>[];
    return list.toSet();
  }

  Future<void> setEnabled(String sourceId, bool enabled) async {
    final current = enabledSources();
    if (enabled) {
      if (current.add(sourceId)) {
        await _prefs.setStringList(_keyEnabled, current.toList());
      }
    } else {
      if (current.remove(sourceId)) {
        await _prefs.setStringList(_keyEnabled, current.toList());
      }
    }
  }

  Future<void> markSynced(String sourceId, [DateTime? at]) async {
    await _prefs.setString(
      _prefixSync + sourceId,
      (at ?? DateTime.now()).toIso8601String(),
    );
  }

  bool isSourceSynced(String sourceId) =>
      _prefs.containsKey(_prefixSync + sourceId);

  DateTime? lastSync(String sourceId) {
    final raw = _prefs.getString(_prefixSync + sourceId);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}
