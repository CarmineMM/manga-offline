import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:manga_offline/core/utils/source_preferences.dart';
import 'package:manga_offline/domain/entities/manga_source.dart';
import 'package:manga_offline/domain/usecases/get_available_sources.dart';
import 'package:manga_offline/domain/usecases/sync_source_catalog.dart';
import 'package:manga_offline/domain/usecases/update_source_selection.dart';
import 'package:manga_offline/domain/usecases/watch_available_sources.dart';

part 'sources_state.dart';

/// Cubit that exposes the available manga sources and handles selection.
class SourcesCubit extends Cubit<SourcesState> {
  /// Creates a cubit bound to the different source use cases.
  SourcesCubit({
    required WatchAvailableSources watchAvailableSources,
    required GetAvailableSources getAvailableSources,
    required UpdateSourceSelection updateSourceSelection,
    required SyncSourceCatalog syncSourceCatalog,
    SourcePreferences? sourcePreferences,
  }) : _watchAvailableSources = watchAvailableSources,
       _getAvailableSources = getAvailableSources,
       _updateSourceSelection = updateSourceSelection,
       _syncSourceCatalog = syncSourceCatalog,
       _sourcePreferences = sourcePreferences,
       super(const SourcesState.initial());

  final WatchAvailableSources _watchAvailableSources;
  final GetAvailableSources _getAvailableSources;
  final UpdateSourceSelection _updateSourceSelection;
  final SyncSourceCatalog _syncSourceCatalog;
  final SourcePreferences? _sourcePreferences;

  StreamSubscription<List<MangaSource>>? _subscription;

  /// Starts the cubit by loading the initial sources and subscribing to
  /// subsequent updates.
  Future<void> start() async {
    emit(state.copyWith(status: SourcesStatus.loading));
    try {
      final sources = await _getAvailableSources();
      emit(state.copyWith(status: SourcesStatus.ready, sources: sources));
    } catch (error) {
      emit(
        state.copyWith(
          status: SourcesStatus.failure,
          errorMessage: error.toString(),
        ),
      );
      return;
    }

    _subscription?.cancel();
    _subscription = _watchAvailableSources().listen(
      (sources) {
        emit(
          state.copyWith(
            status: SourcesStatus.ready,
            sources: sources,
            clearError: true,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        emit(
          state.copyWith(
            status: SourcesStatus.failure,
            errorMessage: error.toString(),
          ),
        );
      },
    );
  }

  /// Toggles a given source selection. When enabling one, the catalog sync is
  /// triggered immediately to populate the library.
  Future<void> toggleSource({
    required String sourceId,
    required bool isEnabled,
  }) async {
    final busy = <String>{...state.syncingSources, sourceId};
    emit(state.copyWith(syncingSources: busy));

    try {
      await _updateSourceSelection(sourceId: sourceId, isEnabled: isEnabled);
      if (isEnabled) {
        final alreadySynced =
            _sourcePreferences?.isSourceSynced(sourceId) ?? false;
        if (!alreadySynced) {
          await _syncSourceCatalog(sourceId: sourceId);
          await _sourcePreferences?.markSynced(sourceId);
        }
      }
    } catch (error) {
      final updated = <String>{...busy}..remove(sourceId);
      emit(
        state.copyWith(
          status: SourcesStatus.failure,
          errorMessage: error.toString(),
          syncingSources: updated,
        ),
      );
      return;
    }

    final updated = <String>{...busy}..remove(sourceId);
    emit(state.copyWith(syncingSources: updated, status: SourcesStatus.ready));
  }

  /// Clears the current error to avoid resurfacing it repeatedly.
  void clearError() {
    if (state.errorMessage != null) {
      emit(state.copyWith(clearError: true));
    }
  }

  /// Re-syncs a source immediately, updating its timestamp and forcing a
  /// catalog refresh.
  Future<void> forceResync(String sourceId) async {
    final busy = <String>{...state.syncingSources, sourceId};
    emit(state.copyWith(syncingSources: busy));
    try {
      await _syncSourceCatalog(sourceId: sourceId);
      await _sourcePreferences?.markSynced(sourceId);
    } catch (error) {
      final updated = <String>{...busy}..remove(sourceId);
      emit(
        state.copyWith(
          status: SourcesStatus.failure,
          errorMessage: error.toString(),
          syncingSources: updated,
        ),
      );
      return;
    }
    final updated = <String>{...busy}..remove(sourceId);
    emit(state.copyWith(syncingSources: updated, status: SourcesStatus.ready));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
