import 'dart:developer' as developer;

import 'package:manga_offline/data/datasources/catalog_remote_datasource.dart';
import 'package:manga_offline/data/datasources/manga_local_datasource.dart';
import 'package:manga_offline/data/models/chapter_model.dart';
import 'package:manga_offline/data/models/manga_model.dart';
import 'package:manga_offline/data/models/page_image_model.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/entities/page_image.dart';
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
      final existing = await _localDataSource.getManga(summary.slug);
      if (existing == null) {
        final manga = summary.toDomain(lastUpdated: timestamp);
        final model = MangaModel.fromEntity(manga);
        await _localDataSource.putManga(model, replaceChapters: false);
        continue;
      }

      existing
        ..title = summary.title
        ..sourceName = summary.sourceName ?? existing.sourceName
        ..synopsis = summary.synopsis ?? existing.synopsis
        ..coverImageUrl = summary.coverUrl ?? existing.coverImageUrl
        ..totalChapters = summary.chapterCount
        ..lastUpdated = timestamp;

      await _localDataSource.putManga(existing, replaceChapters: false);
    }
  }

  @override
  Future<List<Manga>> fetchCatalog({required String sourceId}) async {
    final models = await _localDataSource.getMangasBySource(sourceId);
    final mangas = <Manga>[];
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
      mangas.add(entity);
    }
    return mangas;
  }

  @override
  Future<Manga> fetchMangaDetail({
    required String sourceId,
    required String mangaId,
  }) async {
    final remote = _resolveRemote(sourceId);
    final existingModel = await _localDataSource.getManga(mangaId);
    final existingChapterModels = await _localDataSource.getChaptersForManga(
      mangaId,
    );
    final existingChaptersById = <String, Chapter>{};
    for (final model in existingChapterModels) {
      final pages = await _localDataSource.getPagesForChapter(
        model.referenceId,
      );
      existingChaptersById[model.referenceId] = model.toEntity(pages: pages);
    }

    List<RemoteChapterSummary> remoteChapters = const <RemoteChapterSummary>[];
    Object? remoteError;
    StackTrace? remoteStackTrace;
    try {
      remoteChapters = await remote.fetchAllChapters(mangaSlug: mangaId);
    } catch (error, stackTrace) {
      remoteError = error;
      remoteStackTrace = stackTrace;
      developer.log(
        'fetchMangaDetail remote fetch failed for $mangaId from $sourceId',
        name: 'CatalogRepositoryImpl',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (remoteError != null) {
      if (existingModel != null) {
        final base = existingModel.toEntity();
        final cachedChapters = existingChaptersById.values.toList(
          growable: false,
        );
        return base.copyWith(
          chapters: cachedChapters,
          totalChapters: base.totalChapters != 0
              ? base.totalChapters
              : cachedChapters.length,
        );
      }
      if (remoteStackTrace != null) {
        Error.throwWithStackTrace(remoteError, remoteStackTrace);
      }
      throw remoteError;
    }

    if (remoteChapters.isEmpty) {
      if (existingModel != null) {
        final base = existingModel.toEntity();
        return base.copyWith(
          chapters: existingChaptersById.values.toList(growable: false),
        );
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
        ? existingModel.toEntity().copyWith(
            chapters: existingChaptersById.values.toList(growable: false),
          )
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
    final pageModels = chapterEntities
        .expand<PageImageModel>(
          (chapter) => chapter.pages.map(PageImageModel.fromEntity),
        )
        .toList(growable: false);

    await _localDataSource.putManga(
      mangaModel,
      chapters: chapterModels,
      pages: pageModels,
      replaceChapters: true,
    );

    return updatedManga;
  }

  @override
  Future<List<PageImage>> fetchChapterPages({
    required String sourceId,
    required String mangaId,
    required String chapterId,
  }) async {
    final remote = _resolveRemote(sourceId);
    final remotePages = await remote.fetchChapterPages(
      mangaSlug: mangaId,
      chapterId: chapterId,
    );

    if (remotePages.isNotEmpty) {
      return remotePages.map((page) => page.toDomain()).toList(growable: false);
    }

    final pageModels = await _localDataSource.getPagesForChapter(chapterId);
    if (pageModels.isEmpty) {
      return const <PageImage>[];
    }
    return pageModels.map((model) => model.toEntity()).toList(growable: false);
  }
}
