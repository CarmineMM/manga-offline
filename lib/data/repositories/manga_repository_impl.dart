import 'dart:async';

import 'package:manga_offline/data/datasources/manga_local_datasource.dart';
import 'package:manga_offline/data/models/chapter_model.dart';
import 'package:manga_offline/data/models/manga_model.dart';
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
        final chapters = await _localDataSource.getChaptersForManga(
          model.referenceId,
        );
        result.add(model.toEntity(chapters: chapters));
      }
      return result;
    });
  }

  @override
  Future<void> saveManga(Manga manga) {
    final model = MangaModel.fromEntity(manga);
    final chapters = manga.chapters
        .map<ChapterModel>((chapter) => ChapterModel.fromEntity(chapter))
        .toList(growable: false);
    return _localDataSource.putManga(
      model,
      chapters: chapters,
      replaceChapters: true,
    );
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
}
