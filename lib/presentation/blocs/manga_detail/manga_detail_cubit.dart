import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/usecases/fetch_manga_detail.dart';
import 'package:manga_offline/domain/usecases/queue_chapter_download.dart';
import 'package:manga_offline/domain/usecases/watch_downloaded_mangas.dart';
import 'package:manga_offline/data/datasources/cache/reading_progress_datasource.dart';

part 'manga_detail_state.dart';

/// Cubit that loads and exposes a single manga detail.
class MangaDetailCubit extends Cubit<MangaDetailState> {
  /// Creates a new cubit configured with the [FetchMangaDetail] use case.
  MangaDetailCubit({
    required FetchMangaDetail fetchMangaDetail,
    required WatchDownloadedMangas watchDownloadedMangas,
    required QueueChapterDownload queueChapterDownload,
    required ReadingProgressDataSource readingProgressDataSource,
  }) : _fetchMangaDetail = fetchMangaDetail,
       _watchDownloadedMangas = watchDownloadedMangas,
       _queueChapterDownload = queueChapterDownload,
       _readingProgressDataSource = readingProgressDataSource,
       super(const MangaDetailState.initial());

  final FetchMangaDetail _fetchMangaDetail;
  final WatchDownloadedMangas _watchDownloadedMangas;
  final QueueChapterDownload _queueChapterDownload;
  final ReadingProgressDataSource _readingProgressDataSource;

  StreamSubscription<List<Manga>>? _librarySubscription;

  /// Loads the detail for [mangaId] from the provided [sourceId].
  Future<void> load({required String sourceId, required String mangaId}) async {
    emit(state.copyWith(status: MangaDetailStatus.loading));
    try {
      final manga = await _fetchMangaDetail(
        sourceId: sourceId,
        mangaId: mangaId,
      );
      // Merge persisted reading progress
      final hydrated = await _mergeProgress(manga);
      final visible = _composeVisibleChapters(
        hydrated.chapters,
        sortOrder: state.sortOrder,
        filter: state.filter,
      );
      emit(
        state.copyWith(
          status: MangaDetailStatus.success,
          manga: hydrated,
          errorMessage: null,
          visibleChapters: visible,
        ),
      );
      await _subscribeToMangaUpdates(mangaId);
    } catch (error) {
      emit(
        state.copyWith(
          status: MangaDetailStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _subscribeToMangaUpdates(String mangaId) async {
    await _librarySubscription?.cancel();
    _librarySubscription = _watchDownloadedMangas().listen((mangas) {
      unawaited(_handleLibraryUpdate(mangas, mangaId));
    });
  }

  Future<void> _handleLibraryUpdate(List<Manga> mangas, String mangaId) async {
    final updated = _findManga(mangas, mangaId);
    if (updated == null) {
      return;
    }
    final hydrated = await _mergeProgress(updated);
    if (!_shouldEmitUpdatedManga(hydrated)) {
      return;
    }
    emit(
      state.copyWith(
        manga: hydrated,
        visibleChapters: _composeVisibleChapters(
          hydrated.chapters,
          sortOrder: state.sortOrder,
          filter: state.filter,
        ),
      ),
    );
  }

  bool _shouldEmitUpdatedManga(Manga next) {
    final current = state.manga;
    if (current == null) {
      return true;
    }
    if (!identical(current, next) &&
        (current.downloadedChapters != next.downloadedChapters ||
            current.status != next.status ||
            !_chaptersEquivalent(current.chapters, next.chapters))) {
      return true;
    }
    return false;
  }

  bool _chaptersEquivalent(List<Chapter> a, List<Chapter> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      final current = a[i];
      final next = b[i];
      if (current.id != next.id ||
          current.status != next.status ||
          current.downloadedPages != next.downloadedPages ||
          current.totalPages != next.totalPages ||
          current.lastReadPage != next.lastReadPage ||
          !_dateEquals(current.lastReadAt, next.lastReadAt)) {
        return false;
      }
    }
    return true;
  }

  bool _dateEquals(DateTime? a, DateTime? b) {
    if (a == null && b == null) {
      return true;
    }
    if (a == null || b == null) {
      return false;
    }
    return a.millisecondsSinceEpoch == b.millisecondsSinceEpoch;
  }

  Manga? _findManga(List<Manga> mangas, String mangaId) {
    for (final manga in mangas) {
      if (manga.id == mangaId) {
        return manga;
      }
    }
    return null;
  }

  /// Clears the current error (if any).
  void clearError() {
    if (state.errorMessage != null) {
      emit(state.copyWith(clearError: true));
    }
  }

  /// Adds the provided [chapter] to the download queue.
  Future<void> downloadChapter(Chapter chapter) {
    return _queueChapterDownload(chapter);
  }

  /// Updates the reading progress for a chapter (in-memory only for now).
  /// This will optimistically update the current manga state so the UI
  /// (e.g., ChapterList) can reflect the last read page immediately.
  void updateChapterProgress({
    required String chapterId,
    required int pageNumber,
  }) {
    final current = state.manga;
    if (current == null) return;
    final chapters = current.chapters;
    bool changed = false;
    final updatedChapters = <Chapter>[];
    for (final c in chapters) {
      if (c.id == chapterId) {
        // Only update if progress advanced.
        final newPage = pageNumber + 1; // store human-friendly 1-based
        if ((c.lastReadPage ?? 0) < newPage) {
          updatedChapters.add(
            c.copyWith(lastReadPage: newPage, lastReadAt: DateTime.now()),
          );
          changed = true;
        } else {
          updatedChapters.add(c);
        }
      } else {
        updatedChapters.add(c);
      }
    }
    if (changed) {
      _emitChapters(updatedChapters);
      // Persist the new page asynchronously (fire-and-forget)
      unawaited(
        _readingProgressDataSource.upsertProgress(
          sourceId: current.sourceId,
          mangaId: current.id,
          chapterId: chapterId,
          lastReadPage: updatedChapters
              .firstWhere((c) => c.id == chapterId)
              .lastReadPage!,
        ),
      );
    }
  }

  void markChapterAsRead(String chapterId, {bool complete = false}) {
    final current = state.manga;
    if (current == null) return;
    final chapters = List<Chapter>.from(current.chapters);
    final index = chapters.indexWhere((c) => c.id == chapterId);
    if (index == -1) {
      return;
    }

    final chapter = chapters[index];
    final now = DateTime.now();
    final computedPage = () {
      if (complete) {
        if (chapter.totalPages > 0) {
          return chapter.totalPages;
        }
        if (chapter.pages.isNotEmpty) {
          return chapter.pages.length;
        }
        if (chapter.downloadedPages > 0) {
          return chapter.downloadedPages;
        }
      }
      final existing = chapter.lastReadPage ?? 0;
      return existing > 0 ? existing : 1;
    }();
    final updated = chapter.copyWith(
      lastReadAt: now,
      lastReadPage: computedPage,
    );

    chapters[index] = updated;
    _emitChapters(chapters);

    final pageToPersist = updated.lastReadPage ?? computedPage;
    unawaited(
      _readingProgressDataSource.upsertProgress(
        sourceId: current.sourceId,
        mangaId: current.id,
        chapterId: chapterId,
        lastReadPage: pageToPersist <= 0 ? 1 : pageToPersist,
      ),
    );
  }

  void markChapterAsUnread(String chapterId) {
    final current = state.manga;
    if (current == null) return;
    final chapters = List<Chapter>.from(current.chapters);
    final index = chapters.indexWhere((c) => c.id == chapterId);
    if (index == -1) {
      return;
    }

    final chapter = chapters[index];
    if (chapter.lastReadAt == null && chapter.lastReadPage == null) {
      return;
    }

    chapters[index] = chapter.copyWith(lastReadAt: null, lastReadPage: null);
    _emitChapters(chapters);

    unawaited(_readingProgressDataSource.deleteProgress(chapterId));
  }

  void toggleChapterReadStatus(String chapterId) {
    final current = state.manga;
    if (current == null) return;
    final index = current.chapters.indexWhere((c) => c.id == chapterId);
    if (index == -1) {
      return;
    }
    final chapter = current.chapters[index];
    if (chapter.lastReadAt != null || (chapter.lastReadPage ?? 0) > 0) {
      markChapterAsUnread(chapterId);
    } else {
      markChapterAsRead(chapterId, complete: true);
    }
  }

  Future<Manga> _mergeProgress(Manga manga) async {
    try {
      final stored = await _readingProgressDataSource.getProgressForManga(
        manga.id,
      );
      if (stored.isEmpty) return manga;
      final map = {for (final p in stored) p.chapterId: p};
      final updatedChapters = [
        for (final c in manga.chapters)
          map.containsKey(c.id)
              ? c.copyWith(
                  lastReadPage: map[c.id]!.lastReadPage,
                  lastReadAt: map[c.id]!.lastReadAt,
                )
              : c,
      ];
      return manga.copyWith(chapters: updatedChapters);
    } catch (_) {
      return manga; // Fail silent; we can log later.
    }
  }

  /// Toggles between ascending and descending chapter order.
  void toggleChapterOrder() {
    final nextOrder = state.sortOrder == ChapterSortOrder.ascending
        ? ChapterSortOrder.descending
        : ChapterSortOrder.ascending;
    final chapters = state.manga?.chapters ?? const <Chapter>[];
    emit(
      state.copyWith(
        sortOrder: nextOrder,
        visibleChapters: _composeVisibleChapters(
          chapters,
          sortOrder: nextOrder,
          filter: state.filter,
        ),
      ),
    );
  }

  /// Cycles the active filter among all, downloaded and not downloaded.
  void toggleChapterFilter() {
    final nextFilter = switch (state.filter) {
      ChapterFilter.all => ChapterFilter.downloaded,
      ChapterFilter.downloaded => ChapterFilter.notDownloaded,
      ChapterFilter.notDownloaded => ChapterFilter.all,
    };
    final chapters = state.manga?.chapters ?? const <Chapter>[];
    emit(
      state.copyWith(
        filter: nextFilter,
        visibleChapters: _composeVisibleChapters(
          chapters,
          sortOrder: state.sortOrder,
          filter: nextFilter,
        ),
      ),
    );
  }

  List<Chapter> _composeVisibleChapters(
    List<Chapter> chapters, {
    required ChapterSortOrder sortOrder,
    required ChapterFilter filter,
  }) {
    if (chapters.isEmpty) {
      return const <Chapter>[];
    }
    final filtered = _applyFilter(chapters, filter);
    return _applySorting(filtered, sortOrder);
  }

  List<Chapter> _applyFilter(List<Chapter> chapters, ChapterFilter filter) {
    switch (filter) {
      case ChapterFilter.all:
        return List<Chapter>.from(chapters);
      case ChapterFilter.downloaded:
        return chapters
            .where((chapter) => chapter.status == DownloadStatus.downloaded)
            .toList(growable: false);
      case ChapterFilter.notDownloaded:
        return chapters
            .where((chapter) => chapter.status != DownloadStatus.downloaded)
            .toList(growable: false);
    }
  }

  List<Chapter> _applySorting(List<Chapter> chapters, ChapterSortOrder order) {
    if (chapters.isEmpty) {
      return const <Chapter>[];
    }
    final sorted = List<Chapter>.from(chapters);
    sorted.sort((a, b) => a.number.compareTo(b.number));
    if (order == ChapterSortOrder.descending) {
      return sorted.reversed.toList(growable: false);
    }
    return sorted;
  }

  void _emitChapters(List<Chapter> updatedChapters) {
    final current = state.manga;
    if (current == null) return;
    final updatedManga = current.copyWith(chapters: updatedChapters);
    emit(
      state.copyWith(
        manga: updatedManga,
        visibleChapters: _composeVisibleChapters(
          updatedChapters,
          sortOrder: state.sortOrder,
          filter: state.filter,
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _librarySubscription?.cancel();
    return super.close();
  }
}
