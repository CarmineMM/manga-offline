import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/usecases/watch_downloaded_mangas.dart';

part 'library_state.dart';

/// Cubit responsible for exposing the offline library state to the UI.
class LibraryCubit extends Cubit<LibraryState> {
  /// Creates a cubit hooked to the [WatchDownloadedMangas] use case.
  LibraryCubit(this._watchDownloadedMangas)
    : super(const LibraryState.initial());

  final WatchDownloadedMangas _watchDownloadedMangas;
  StreamSubscription<List<Manga>>? _subscription;

  /// Starts listening to local library updates.
  void start() {
    emit(state.copyWith(status: LibraryStatus.loading));
    _subscription?.cancel();
    _subscription = _watchDownloadedMangas().listen(
      (mangas) {
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
        emit(state.copyWith(status: LibraryStatus.failure));
      },
    );
  }

  /// Updates the current search query and recomputes visible mangas.
  void updateSearchQuery(String query) {
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
    emit(
      state.copyWith(
        searchQuery: '',
        selectedSourceIds: <String>{},
        filteredMangas: state.allMangas,
      ),
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
