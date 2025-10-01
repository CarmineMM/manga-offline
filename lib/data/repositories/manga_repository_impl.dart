import 'dart:async';

import 'package:manga_offline/data/datasources/cache/reading_progress_datasource.dart';
import 'package:manga_offline/data/datasources/manga_local_datasource.dart';
import 'package:manga_offline/data/models/chapter_model.dart';
import 'package:manga_offline/data/models/manga_model.dart';
import 'package:manga_offline/data/models/page_image_model.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/repositories/manga_repository.dart';

/// Concrete implementation of [MangaRepository] backed by Isar.
class MangaRepositoryImpl implements MangaRepository {
  /// Creates the repository with its required [localDataSource].
  MangaRepositoryImpl({
    required MangaLocalDataSource localDataSource,
    required ReadingProgressDataSource readingProgressDataSource,
  }) : _localDataSource = localDataSource,
       _readingProgressDataSource = readingProgressDataSource;

  final MangaLocalDataSource _localDataSource;
  final ReadingProgressDataSource _readingProgressDataSource;

  @override
  Stream<List<Manga>> watchLocalLibrary() {
    return Stream.multi((controller) {
      var latestModels = const <MangaModel>[];
      var latestProgress = const <ReadingProgressEntity>[];
      var closed = false;

      Future<void> emitCombined() async {
        if (closed) return;
        try {
          final result = await _buildMangaEntities(
            latestModels,
            latestProgress,
          );
          if (!controller.isClosed) {
            controller.add(result);
          }
        } catch (error, stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        }
      }

      final mangaSubscription = _localDataSource.watchMangas().listen(
        (models) {
          latestModels = models;
          unawaited(emitCombined());
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
      );

      final progressSubscription = _readingProgressDataSource.watchAll().listen(
        (progress) {
          latestProgress = progress;
          unawaited(emitCombined());
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
      );

      controller.onListen = () => unawaited(emitCombined());
      controller.onCancel = () async {
        closed = true;
        await mangaSubscription.cancel();
        await progressSubscription.cancel();
      };
    });
  }

  @override
  Stream<List<Manga>> watchFollowedMangas() {
    return watchLocalLibrary().map(
      (mangas) =>
          mangas.where((manga) => manga.isFollowed).toList(growable: false),
    );
  }

  @override
  Future<void> saveManga(Manga manga) {
    final model = MangaModel.fromEntity(manga);
    final chapters = manga.chapters
        .map<ChapterModel>((chapter) => ChapterModel.fromEntity(chapter))
        .toList(growable: false);
    final pages = manga.chapters
        .expand<PageImageModel>(
          (chapter) => chapter.pages.map(PageImageModel.fromEntity),
        )
        .toList(growable: false);
    return _localDataSource.putManga(
      model,
      chapters: chapters,
      pages: pages,
      replaceChapters: true,
    );
  }

  @override
  Future<Manga?> getManga(String mangaId) async {
    final model = await _localDataSource.getManga(mangaId);
    if (model == null) {
      return null;
    }
    final progress = await _readingProgressDataSource.getProgressForManga(
      mangaId,
    );
    return _mapModelToEntity(model, progress);
  }

  @override
  Future<void> saveChapter(Chapter chapter) {
    final model = ChapterModel.fromEntity(chapter);
    final pages = chapter.pages
        .map<PageImageModel>(PageImageModel.fromEntity)
        .toList(growable: false);
    return _localDataSource.putChapter(model, pages: pages);
  }

  @override
  Future<Chapter?> getChapter(String chapterId) async {
    final model = await _localDataSource.getChapter(chapterId);
    if (model == null) {
      return null;
    }
    final pages = await _localDataSource.getPagesForChapter(chapterId);
    return model.toEntity(pages: pages);
  }

  @override
  Future<void> markMangaAsDownloaded(String mangaId) {
    return _localDataSource.markMangaAsDownloaded(mangaId);
  }

  @override
  Future<void> markChapterAsDownloaded(String chapterId) {
    return _localDataSource.markChapterAsDownloaded(chapterId);
  }

  @override
  Future<DownloadStatus?> getMangaDownloadStatus(String mangaId) {
    return _localDataSource.getMangaDownloadStatus(mangaId);
  }

  @override
  Future<DownloadStatus?> getChapterDownloadStatus(String chapterId) {
    return _localDataSource.getChapterDownloadStatus(chapterId);
  }

  @override
  Future<void> updateMangaCover({
    required String mangaId,
    String? coverImagePath,
  }) {
    return _localDataSource.updateMangaCover(
      referenceId: mangaId,
      coverImagePath: coverImagePath,
    );
  }

  @override
  Future<void> clearChapterDownload(String chapterId) {
    return _localDataSource.clearChapterDownload(chapterId);
  }

  @override
  Future<void> setMangaFollowed({
    required String mangaId,
    required bool isFollowed,
  }) {
    return _localDataSource.setMangaFollowed(mangaId, isFollowed);
  }

  int _countReadChapters(List<Chapter> chapters) {
    var total = 0;
    for (final chapter in chapters) {
      if ((chapter.lastReadPage ?? 0) > 0 || chapter.lastReadAt != null) {
        total += 1;
      }
    }
    return total;
  }

  Future<List<Manga>> _buildMangaEntities(
    List<MangaModel> models,
    List<ReadingProgressEntity> progress,
  ) async {
    if (models.isEmpty) {
      return const <Manga>[];
    }
    final progressByManga = <String, List<ReadingProgressEntity>>{};
    for (final entry in progress) {
      final list = progressByManga.putIfAbsent(
        entry.mangaId,
        () => <ReadingProgressEntity>[],
      );
      list.add(entry);
    }

    final result = <Manga>[];
    for (final model in models) {
      final mapped = await _mapModelToEntity(
        model,
        progressByManga[model.referenceId] ?? const <ReadingProgressEntity>[],
      );
      result.add(mapped);
    }
    return result;
  }

  Future<Manga> _mapModelToEntity(
    MangaModel model,
    List<ReadingProgressEntity> progress,
  ) async {
    final chapterModels = await _localDataSource.getChaptersForManga(
      model.referenceId,
    );
    final progressMap = <String, ReadingProgressEntity>{
      for (final entry in progress) entry.chapterId: entry,
    };

    final chapters = <Chapter>[];
    for (final chapterModel in chapterModels) {
      final pages = await _localDataSource.getPagesForChapter(
        chapterModel.referenceId,
      );
      var chapter = chapterModel.toEntity(pages: pages);
      final progressEntry = progressMap[chapter.id];
      if (progressEntry != null) {
        chapter = chapter.copyWith(
          lastReadPage: progressEntry.lastReadPage,
          lastReadAt: progressEntry.lastReadAt,
        );
      }
      chapters.add(chapter);
    }

    final readChapters = _countReadChapters(chapters);
    final totalChapters = model.totalChapters != 0
        ? model.totalChapters
        : chapters.length;

    return model.toEntity().copyWith(
      chapters: chapters,
      readChapters: readChapters,
      totalChapters: totalChapters,
    );
  }
}
