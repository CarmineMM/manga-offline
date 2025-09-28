import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:manga_offline/domain/entities/manga_source.dart';
import 'package:manga_offline/domain/usecases/fetch_source_catalog.dart';
import 'package:manga_offline/domain/usecases/get_available_sources.dart';
import 'package:manga_offline/domain/usecases/get_source_last_sync.dart';
import 'package:manga_offline/domain/usecases/mark_source_synced.dart';
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
    required FetchSourceCatalog fetchSourceCatalog,
    required MarkSourceSynced markSourceSynced,
    required GetSourceLastSync getSourceLastSync,
  }) : _watchAvailableSources = watchAvailableSources,
       _getAvailableSources = getAvailableSources,
       _updateSourceSelection = updateSourceSelection,
       _syncSourceCatalog = syncSourceCatalog,
       _fetchSourceCatalog = fetchSourceCatalog,
       _markSourceSynced = markSourceSynced,
       _getSourceLastSync = getSourceLastSync,
       super(const SourcesState.initial());

  final WatchAvailableSources _watchAvailableSources;
  final GetAvailableSources _getAvailableSources;
  final UpdateSourceSelection _updateSourceSelection;
  final SyncSourceCatalog _syncSourceCatalog;
  final FetchSourceCatalog _fetchSourceCatalog;
  final MarkSourceSynced _markSourceSynced;
  final GetSourceLastSync _getSourceLastSync;

  static const Duration _catalogStaleThreshold = Duration(hours: 12);

  StreamSubscription<List<MangaSource>>? _subscription;

  /// Starts the cubit by loading the initial sources and subscribing to
  /// subsequent updates.
  Future<void> start() async {
    emit(state.copyWith(status: SourcesStatus.loading));
    try {
      final sources = await _getAvailableSources();
      emit(state.copyWith(status: SourcesStatus.ready, sources: sources));
      unawaited(_autoSyncEnabledSources(sources));
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
    try {
      await _performSyncOperation(
        sourceId: sourceId,
        operation: () async {
          await _updateSourceSelection(
            sourceId: sourceId,
            isEnabled: isEnabled,
          );
          if (isEnabled) {
            final needsSync = await _shouldSyncOnEnable(sourceId);
            if (needsSync) {
              await _syncAndStamp(sourceId);
            } else {
              await _markSourceSynced(sourceId: sourceId);
            }
          }
        },
      );
    } catch (_) {
      // The state already reflects the failure scenario.
    }
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
    try {
      await _performSyncOperation(
        sourceId: sourceId,
        operation: () => _syncAndStamp(sourceId),
      );
    } catch (_) {
      // Failure already propagated to the state.
    }
  }

  Future<void> _autoSyncEnabledSources(List<MangaSource> sources) async {
    for (final source in sources) {
      if (!source.isEnabled) {
        continue;
      }
      try {
        final needsSync = await _shouldSyncOnEnable(source.id);
        if (!needsSync) {
          continue;
        }
        await _performSyncOperation(
          sourceId: source.id,
          operation: () => _syncAndStamp(source.id),
        );
      } catch (_) {
        // The state already reflects the failure; keep iterating over
        // the remaining sources.
      }
    }
  }

  Future<void> _performSyncOperation({
    required String sourceId,
    required Future<void> Function() operation,
  }) async {
    final busy = <String>{...state.syncingSources, sourceId};
    emit(state.copyWith(syncingSources: busy));
    try {
      await operation();
    } catch (error) {
      final updated = <String>{...busy}..remove(sourceId);
      emit(
        state.copyWith(
          status: SourcesStatus.failure,
          errorMessage: error.toString(),
          syncingSources: updated,
        ),
      );
      rethrow;
    }
    final updated = <String>{...busy}..remove(sourceId);
    emit(state.copyWith(syncingSources: updated, status: SourcesStatus.ready));
  }

  Future<bool> _shouldSyncOnEnable(String sourceId) async {
    try {
      final catalog = await _fetchSourceCatalog(sourceId: sourceId);
      if (catalog.isEmpty) {
        return true;
      }
    } catch (error) {
      // If fetching the cached catalog fails, prefer to trigger a sync to
      // recover from the inconsistent state.
      return true;
    }

    final lastSync = await _getSourceLastSync(sourceId);
    if (lastSync == null) {
      return true;
    }

    final now = DateTime.now();
    return now.difference(lastSync) > _catalogStaleThreshold;
  }

  Future<void> _syncAndStamp(String sourceId) async {
    await _syncSourceCatalog(sourceId: sourceId);
    await _markSourceSynced(sourceId: sourceId, timestamp: DateTime.now());
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
