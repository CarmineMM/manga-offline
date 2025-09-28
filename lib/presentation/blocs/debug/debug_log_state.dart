part of 'debug_log_cubit.dart';

/// Immutable state describing the debug log console contents.
class DebugLogState extends Equatable {
  /// Creates a new [DebugLogState] instance.
  const DebugLogState({
    this.entries = const <DebugLogEntry>[],
    this.isStreaming = false,
  });

  /// Current collection of log entries (newest first).
  final List<DebugLogEntry> entries;

  /// Indicates whether the cubit is actively listening to the logger stream.
  final bool isStreaming;

  /// Helper to derive a new state with selective overrides.
  DebugLogState copyWith({List<DebugLogEntry>? entries, bool? isStreaming}) {
    return DebugLogState(
      entries: entries != null
          ? List<DebugLogEntry>.unmodifiable(entries)
          : this.entries,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  @override
  List<Object?> get props => <Object?>[entries, isStreaming];
}
