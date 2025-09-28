import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:manga_offline/core/debug/debug_logger.dart';

part 'debug_log_state.dart';

/// Cubit that exposes diagnostic log entries for the debug console screen.
class DebugLogCubit extends Cubit<DebugLogState> {
  /// Creates a new cubit bound to the shared [DebugLogger].
  DebugLogCubit(this._logger) : super(const DebugLogState());

  final DebugLogger _logger;
  StreamSubscription<List<DebugLogEntry>>? _subscription;

  /// Begins streaming log updates to the presentation layer.
  void start() {
    _subscription?.cancel();
    emit(state.copyWith(entries: _logger.entries, isStreaming: true));
    _subscription = _logger.watchEntries().listen((entries) {
      emit(state.copyWith(entries: entries));
    });
  }

  /// Clears all recorded entries.
  void clear() => _logger.clear();

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
