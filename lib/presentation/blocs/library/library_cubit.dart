import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/usecases/watch_downloaded_mangas.dart';

part 'library_state.dart';

/// Cubit responsible for exposing the offline library state to the UI.
///
/// This cubit subscribes to the [WatchDownloadedMangas] use case and maintains
/// an in-memory filter state (search query and selected source ids). It
/// publishes filtered results via the [LibraryState] so presentation widgets
/// can reactively render the library list and available source filters.
class LibraryCubit extends Cubit<LibraryState> {
  /// Creates a cubit hooked to the [WatchDownloadedMangas] use case.
  ///
  /// The use case is expected to return a broadcast `Stream<List<Manga>>` and
  /// the cubit will listen to updates, apply local filters, and emit
  /// `LibraryState` snapshots.
  LibraryCubit(this._watchDownloadedMangas)
    : super(const LibraryState.initial());

  final WatchDownloadedMangas _watchDownloadedMangas;
  StreamSubscription<List<Manga>>? _subscription;

  /// Starts listening to local library updates.
  void start() {
    _log('Iniciando escucha de biblioteca local');
    emit(state.copyWith(status: LibraryStatus.loading));
    _subscription?.cancel();
    _subscription = _watchDownloadedMangas().listen(
      (mangas) {
        _log(
          'Actualización recibida con ${mangas.length} mangas',
          payload: {
            'seleccionados': state.selectedSourceIds.length,
            'busqueda': state.searchQuery,
          },
        );
        final sources = _buildSourceInfo(mangas);
        final validSelected = state.selectedSourceIds
            .where((id) => sources.any((source) => source.id == id))
            .toSet();
        final filtered = _applyFilters(
          mangas,
          state.searchQuery,
          validSelected,
        );
        emit(
          state.copyWith(
            status: LibraryStatus.success,
            allMangas: mangas,
            filteredMangas: filtered,
            availableSources: sources,
            selectedSourceIds: validSelected,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        _log(
          'Error al observar la biblioteca',
          error: error,
          stack: stackTrace,
        );
        emit(state.copyWith(status: LibraryStatus.failure));
      },
    );
  }

  /// Updates the current search query and recomputes visible mangas.
  void updateSearchQuery(String query) {
    _log('Actualizando búsqueda de biblioteca', payload: {'query': query});
    final filtered = _applyFilters(
      state.allMangas,
      query,
      state.selectedSourceIds,
    );
    emit(state.copyWith(searchQuery: query, filteredMangas: filtered));
  }

  /// Toggles the selection for the provided [sourceId] filter.
  void toggleSourceFilter(String sourceId) {
    final updatedSelection = Set<String>.of(state.selectedSourceIds);
    if (!updatedSelection.remove(sourceId)) {
      updatedSelection.add(sourceId);
    }

    _log(
      'Filtro de fuente actualizado',
      payload: {'fuente': sourceId, 'seleccionados': updatedSelection.length},
    );

    final filtered = _applyFilters(
      state.allMangas,
      state.searchQuery,
      updatedSelection,
    );

    emit(
      state.copyWith(
        selectedSourceIds: updatedSelection,
        filteredMangas: filtered,
      ),
    );
  }

  /// Clears all filters applied to the library.
  void resetFilters() {
    _log('Reiniciando filtros de biblioteca');
    emit(
      state.copyWith(
        searchQuery: '',
        selectedSourceIds: <String>{},
        filteredMangas: state.allMangas,
      ),
    );
  }

  void _log(
    String message, {
    Map<String, Object?>? payload,
    Object? error,
    StackTrace? stack,
  }) {
    final suffix = payload == null || payload.isEmpty ? '' : ' | $payload';
    developer.log(
      '$message$suffix',
      name: 'LibraryCubit',
      error: error,
      stackTrace: stack,
    );
  }

  List<LibrarySourceInfo> _buildSourceInfo(List<Manga> mangas) {
    final Map<String, String> bySource = <String, String>{};
    for (final manga in mangas) {
      final displayName = (manga.sourceName?.isNotEmpty ?? false)
          ? manga.sourceName!
          : (bySource[manga.sourceId] ?? manga.sourceId);
      bySource[manga.sourceId] = displayName;
    }

    final entries = bySource.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

    return List<LibrarySourceInfo>.unmodifiable(
      entries
          .map((entry) => LibrarySourceInfo(id: entry.key, name: entry.value))
          .toList(growable: false),
    );
  }

  List<Manga> _applyFilters(
    List<Manga> mangas,
    String query,
    Set<String> selectedSourceIds,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    final hasQuery = normalizedQuery.isNotEmpty;
    final hasSources = selectedSourceIds.isNotEmpty;

    return mangas
        .where((manga) {
          final matchesQuery =
              !hasQuery ||
              () {
                final titleMatch = manga.title.toLowerCase().contains(
                  normalizedQuery,
                );
                final sourceNameMatch = (manga.sourceName?.toLowerCase() ?? '')
                    .contains(normalizedQuery);
                final sourceIdMatch = manga.sourceId.toLowerCase().contains(
                  normalizedQuery,
                );
                return titleMatch || sourceNameMatch || sourceIdMatch;
              }();

          final matchesSource =
              !hasSources || selectedSourceIds.contains(manga.sourceId);

          return matchesQuery && matchesSource;
        })
        .toList(growable: false);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
