import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
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
      emit(
        state.copyWith(
          status: MangaDetailStatus.success,
          manga: hydrated,
          errorMessage: null,
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
      final updated = _findManga(mangas, mangaId);
      if (updated != null && state.manga != updated) {
        emit(state.copyWith(manga: updated));
      }
    });
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
      final updatedManga = current.copyWith(chapters: updatedChapters);
      emit(state.copyWith(manga: updatedManga));
      // Persist the new page asynchronously (fire-and-forget)
      unawaited(
        _readingProgressDataSource.upsertProgress(
          sourceId: updatedManga.sourceId,
          mangaId: updatedManga.id,
          chapterId: chapterId,
          lastReadPage: updatedChapters
              .firstWhere((c) => c.id == chapterId)
              .lastReadPage!,
        ),
      );
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

  @override
  Future<void> close() async {
    await _librarySubscription?.cancel();
    return super.close();
  }
}
