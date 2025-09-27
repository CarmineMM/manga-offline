import 'package:manga_offline/data/datasources/catalog_remote_datasource.dart';
import 'package:manga_offline/data/datasources/manga_local_datasource.dart';
import 'package:manga_offline/data/models/chapter_model.dart';
import 'package:manga_offline/data/models/manga_model.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/repositories/catalog_repository.dart';

/// Implementation of [CatalogRepository] combining remote sources with Isar
/// persistence to keep the catalog available offline.
class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl({
    required MangaLocalDataSource localDataSource,
    required Map<String, CatalogRemoteDataSource> remoteDataSources,
  }) : _localDataSource = localDataSource,
       _remoteDataSources = remoteDataSources;

  final MangaLocalDataSource _localDataSource;
  final Map<String, CatalogRemoteDataSource> _remoteDataSources;

  CatalogRemoteDataSource _resolveRemote(String sourceId) {
    final remote = _remoteDataSources[sourceId];
    if (remote == null) {
      throw ArgumentError('No remote data source configured for $sourceId');
    }
    return remote;
  }

  @override
  Future<void> syncCatalog({required String sourceId}) async {
    final remote = _resolveRemote(sourceId);
    final summaries = await remote.fetchAllSeries();
    final timestamp = DateTime.now();

    for (final summary in summaries) {
      final manga = summary.toDomain(lastUpdated: timestamp);
      final model = MangaModel.fromEntity(manga);
      await _localDataSource.putManga(model, replaceChapters: false);
    }
  }

  @override
  Future<List<Manga>> fetchCatalog({required String sourceId}) async {
    final models = await _localDataSource.getMangasBySource(sourceId);
    final mangas = <Manga>[];
    for (final model in models) {
      final chapters = await _localDataSource.getChaptersForManga(
        model.referenceId,
      );
      mangas.add(model.toEntity(chapters: chapters));
    }
    return mangas;
  }

  @override
  Future<Manga> fetchMangaDetail({
    required String sourceId,
    required String mangaId,
  }) async {
    final remote = _resolveRemote(sourceId);
    final remoteChapters = await remote.fetchAllChapters(mangaSlug: mangaId);
    final existingModel = await _localDataSource.getManga(mangaId);
    final existingChapterModels = await _localDataSource.getChaptersForManga(
      mangaId,
    );
    final existingChaptersById = {
      for (final model in existingChapterModels)
        model.referenceId: model.toEntity(),
    };

    if (remoteChapters.isEmpty) {
      if (existingModel != null) {
        return existingModel.toEntity(chapters: existingChapterModels);
      }
      return Manga(
        id: mangaId,
        sourceId: sourceId,
        sourceName: remote.sourceName,
        title: mangaId,
        status: DownloadStatus.notDownloaded,
      );
    }

    final baseManga = existingModel != null
        ? existingModel.toEntity(chapters: existingChapterModels)
        : Manga(
            id: mangaId,
            sourceId: sourceId,
            sourceName: remote.sourceName,
            title: mangaId,
            status: DownloadStatus.notDownloaded,
          );

    final chapterEntities = <Chapter>[];
    for (var index = 0; index < remoteChapters.length; index += 1) {
      final summary = remoteChapters[index];
      final baseChapter = existingChaptersById[summary.externalId];
      final chapter = summary.toDomain(
        indexFallback: remoteChapters.length - index,
      );
      if (baseChapter != null) {
        chapterEntities.add(
          chapter.copyWith(
            remoteUrl: baseChapter.remoteUrl,
            localPath: baseChapter.localPath,
            status: baseChapter.status,
            totalPages: baseChapter.totalPages,
            downloadedPages: baseChapter.downloadedPages,
            lastReadAt: baseChapter.lastReadAt,
            lastReadPage: baseChapter.lastReadPage,
            pages: baseChapter.pages,
          ),
        );
      } else {
        chapterEntities.add(chapter);
      }
    }

    chapterEntities.sort((a, b) => a.number.compareTo(b.number));

    final updatedManga = baseManga.copyWith(
      chapters: chapterEntities,
      totalChapters: chapterEntities.length,
      lastUpdated: DateTime.now(),
    );

    final mangaModel = MangaModel.fromEntity(updatedManga);
    final chapterModels = chapterEntities
        .map((chapter) => ChapterModel.fromEntity(chapter))
        .toList(growable: false);

    await _localDataSource.putManga(
      mangaModel,
      chapters: chapterModels,
      replaceChapters: true,
    );

    return updatedManga;
  }
}
