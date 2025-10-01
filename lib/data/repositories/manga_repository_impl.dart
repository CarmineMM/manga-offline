import 'dart:async';

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
  MangaRepositoryImpl({required MangaLocalDataSource localDataSource})
    : _localDataSource = localDataSource;

  final MangaLocalDataSource _localDataSource;

  @override
  Stream<List<Manga>> watchLocalLibrary() {
    return _localDataSource.watchMangas().asyncMap((models) async {
      final result = <Manga>[];
      for (final model in models) {
        final chapterModels = await _localDataSource.getChaptersForManga(
          model.referenceId,
        );
        final chapters = <Chapter>[];
        for (final chapterModel in chapterModels) {
          final pages = await _localDataSource.getPagesForChapter(
            chapterModel.referenceId,
          );
          chapters.add(chapterModel.toEntity(pages: pages));
        }

        final entity = model.toEntity().copyWith(chapters: chapters);
        result.add(entity);
      }
      return result;
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
    final chapterModels = await _localDataSource.getChaptersForManga(mangaId);
    final chapters = <Chapter>[];
    for (final chapterModel in chapterModels) {
      final pages = await _localDataSource.getPagesForChapter(
        chapterModel.referenceId,
      );
      chapters.add(chapterModel.toEntity(pages: pages));
    }
    return model.toEntity(chapters: chapterModels).copyWith(chapters: chapters);
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
}
