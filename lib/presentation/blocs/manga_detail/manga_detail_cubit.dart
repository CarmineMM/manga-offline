import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/usecases/fetch_manga_detail.dart';
import 'package:manga_offline/domain/usecases/queue_chapter_download.dart';
import 'package:manga_offline/domain/usecases/watch_downloaded_mangas.dart';

part 'manga_detail_state.dart';

/// Cubit that loads and exposes a single manga detail.
class MangaDetailCubit extends Cubit<MangaDetailState> {
  /// Creates a new cubit configured with the [FetchMangaDetail] use case.
  MangaDetailCubit({
    required FetchMangaDetail fetchMangaDetail,
    required WatchDownloadedMangas watchDownloadedMangas,
    required QueueChapterDownload queueChapterDownload,
  }) : _fetchMangaDetail = fetchMangaDetail,
       _watchDownloadedMangas = watchDownloadedMangas,
       _queueChapterDownload = queueChapterDownload,
       super(const MangaDetailState.initial());

  final FetchMangaDetail _fetchMangaDetail;
  final WatchDownloadedMangas _watchDownloadedMangas;
  final QueueChapterDownload _queueChapterDownload;

  StreamSubscription<List<Manga>>? _librarySubscription;

  /// Loads the detail for [mangaId] from the provided [sourceId].
  Future<void> load({required String sourceId, required String mangaId}) async {
    emit(state.copyWith(status: MangaDetailStatus.loading));
    try {
      final manga = await _fetchMangaDetail(
        sourceId: sourceId,
        mangaId: mangaId,
      );
      emit(
        state.copyWith(
          status: MangaDetailStatus.success,
          manga: manga,
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

  @override
  Future<void> close() async {
    await _librarySubscription?.cancel();
    return super.close();
  }
}
