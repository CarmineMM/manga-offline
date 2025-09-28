import 'dart:async';

/// Log severity levels used by the in-app debug console.
enum DebugLogLevel { info, warning, error }

/// Immutable entry describing a diagnostic event to be rendered in the debug
/// screen.
class DebugLogEntry {
  /// Creates a new [DebugLogEntry] instance.
  const DebugLogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.metadata = const <String, Object?>{},
  });

  /// Unique identifier, useful for list diffing in the UI.
  final String id;

  /// Moment when the event was recorded.
  final DateTime timestamp;

  /// Severity level associated with the event.
  final DebugLogLevel level;

  /// Logical classification (e.g. `network`, `catalog`).
  final String category;

  /// Short human readable description.
  final String message;

  /// Optional structured data attached to the event.
  final Map<String, Object?> metadata;
}

/// Captures diagnostic events and exposes them as a stream for the debug UI.
class DebugLogger {
  DebugLogger({int maxEntries = 200}) : _maxEntries = maxEntries {
    _controller.onListen = () => _controller.add(entries);
  }

  final int _maxEntries;
  final List<DebugLogEntry> _entries = <DebugLogEntry>[];
  final StreamController<List<DebugLogEntry>> _controller =
      StreamController<List<DebugLogEntry>>.broadcast();
  int _idSeed = 0;

  /// Returns the current snapshot of entries (newest first).
  List<DebugLogEntry> get entries =>
      List<DebugLogEntry>.unmodifiable(_entries.reversed);

  /// Registers a new diagnostic entry.
  void log(DebugLogEntry entry) {
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    _controller.add(entries);
  }

  /// Convenience helper to track network requests performed by remote data
  /// sources.
  void logNetworkEvent({
    required String sourceId,
    required String method,
    required Uri uri,
    required bool success,
    int? statusCode,
    Duration? duration,
    String? error,
  }) {
    final metadata = <String, Object?>{
      'sourceId': sourceId,
      'method': method,
      'url': uri.toString(),
      if (statusCode != null) 'statusCode': statusCode,
      if (duration != null) 'durationMs': duration.inMilliseconds,
      if (error != null) 'error': error,
    };
    log(
      DebugLogEntry(
        id: _nextId(),
        timestamp: DateTime.now(),
        level: success ? DebugLogLevel.info : DebugLogLevel.error,
        category: 'network',
        message: success
            ? 'Solicitud ${method.toUpperCase()} exitosa'
            : 'Fallo en solicitud ${method.toUpperCase()}',
        metadata: metadata,
      ),
    );
  }

  /// Removes every stored entry and notifies listeners.
  void clear() {
    _entries.clear();
    _controller.add(const <DebugLogEntry>[]);
  }

  /// Subscribes to entry updates. Listeners immediately receive the current
  /// snapshot upon subscription.
  Stream<List<DebugLogEntry>> watchEntries() => _controller.stream;

  String _nextId() {
    _idSeed += 1;
    return _idSeed.toString().padLeft(6, '0');
  }
}
