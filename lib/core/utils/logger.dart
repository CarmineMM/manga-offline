import 'dart:developer' as developer;

/// Lightweight logging façade to keep logging-related calls in one place.
class AppLogger {
  const AppLogger._();

  /// Logs a message tagged with the given [name].
  static void log(String message, {String name = 'MangaOffline'}) {
    developer.log(message, name: name);
  }
}
