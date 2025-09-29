import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manga_offline/core/debug/debug_logger.dart';
import 'package:manga_offline/core/utils/reader_preferences.dart';
import 'package:manga_offline/core/utils/source_preferences.dart';
import 'package:manga_offline/data/constants/default_sources.dart';
import 'package:manga_offline/data/datasources/cache/page_cache_datasource.dart';
import 'package:manga_offline/data/datasources/cache/reading_progress_datasource.dart';
import 'package:manga_offline/data/datasources/manga_local_datasource.dart';
import 'package:manga_offline/data/datasources/olympus_remote_datasource.dart';
import 'package:manga_offline/data/datasources/source_local_datasource.dart';
import 'package:manga_offline/data/models/chapter_model.dart';
import 'package:manga_offline/data/models/manga_model.dart';
import 'package:manga_offline/data/models/page_image_model.dart';
import 'package:manga_offline/data/models/manga_source_model.dart';
import 'package:manga_offline/data/repositories/catalog_repository_impl.dart';
import 'package:manga_offline/data/repositories/download_repository_impl.dart';
import 'package:manga_offline/data/repositories/manga_repository_impl.dart';
import 'package:manga_offline/data/repositories/source_repository_impl.dart';
import 'package:manga_offline/data/stubs/in_memory_repositories.dart';
import 'package:manga_offline/domain/repositories/catalog_repository.dart';
import 'package:manga_offline/domain/repositories/download_repository.dart';
import 'package:manga_offline/domain/repositories/manga_repository.dart';
import 'package:manga_offline/domain/repositories/source_repository.dart';
import 'package:manga_offline/domain/usecases/fetch_chapter_pages.dart';
import 'package:manga_offline/domain/usecases/fetch_manga_detail.dart';
import 'package:manga_offline/domain/usecases/fetch_source_catalog.dart';
import 'package:manga_offline/domain/usecases/get_available_sources.dart';
import 'package:manga_offline/domain/usecases/get_source_last_sync.dart';
import 'package:manga_offline/domain/usecases/delete_downloaded_chapter.dart';
import 'package:manga_offline/domain/usecases/mark_source_synced.dart';
import 'package:manga_offline/domain/usecases/sync_source_catalog.dart';
import 'package:manga_offline/domain/usecases/update_source_selection.dart';
import 'package:manga_offline/domain/usecases/watch_available_sources.dart';
import 'package:manga_offline/domain/usecases/watch_download_queue.dart';
import 'package:manga_offline/domain/usecases/watch_downloaded_mangas.dart';
import 'package:manga_offline/domain/usecases/queue_chapter_download.dart';
import 'package:manga_offline/domain/usecases/queue_manga_download.dart';
import 'package:manga_offline/presentation/blocs/debug/debug_log_cubit.dart';
import 'package:manga_offline/presentation/blocs/downloads/downloads_cubit.dart';
import 'package:manga_offline/presentation/blocs/library/library_cubit.dart';
import 'package:manga_offline/presentation/blocs/manga_detail/manga_detail_cubit.dart';
import 'package:manga_offline/presentation/blocs/sources/sources_cubit.dart';

/// Global service locator instance.
final GetIt serviceLocator = GetIt.instance;

/// Registers shared dependencies for the application.
///
/// The function wires persistent implementations backed by Isar whenever
/// available, with in-memory fallbacks to keep the app usable in environments
/// where local storage is not accessible (for example, widget tests).
Future<void> configureDependencies() async {
  if (serviceLocator.isRegistered<MangaRepository>()) {
    final existingIsar = Isar.getInstance('manga_offline');
    if (existingIsar != null && existingIsar.isOpen) {
      await existingIsar.close();
    }
    await serviceLocator.reset();
  }

  final debugLogger = DebugLogger();

  final Directory appDir = await getApplicationDocumentsDirectory();
  Isar? isar;
  try {
    isar =
        Isar.getInstance('manga_offline') ??
        await Isar.open(
          <CollectionSchema<dynamic>>[
            MangaModelSchema,
            ChapterModelSchema,
            PageImageModelSchema,
            MangaSourceModelSchema,
            PageEntitySchema,
            ReadingProgressEntitySchema,
          ],
          directory: appDir.path,
          name: 'manga_offline',
          inspector: false,
        );
  } catch (_) {
    isar = null;
  }

  late final PageCacheDataSource pageCache;
  late final ReadingProgressDataSource readingProgressDs;
  late final MangaRepository mangaRepository;
  late final CatalogRepository catalogRepository;
  late final SourceRepository sourceRepository;

  final olympusRemote = OlympusRemoteDataSource(debugLogger: debugLogger);
  final readerPrefs = await ReaderPreferences.create();
  final sourcePrefs = await SourcePreferences.create();

  if (isar != null) {
    pageCache = IsarPageCacheDataSource(isar);
    readingProgressDs = ReadingProgressDataSource(isar);
    final localDataSource = MangaLocalDataSource(isar);
    final sourceLocalDataSource = SourceLocalDataSource(isar);
    mangaRepository = MangaRepositoryImpl(localDataSource: localDataSource);
    catalogRepository = CatalogRepositoryImpl(
      localDataSource: localDataSource,
      remoteDataSources: {olympusRemote.sourceId: olympusRemote},
    );
    sourceRepository = SourceRepositoryImpl(
      localDataSource: sourceLocalDataSource,
      legacyPreferences: sourcePrefs,
    );
  } else {
    pageCache = InMemoryPageCacheDataSource();
    readingProgressDs = ReadingProgressDataSource.inMemory();
    final fallbackMangaRepository = InMemoryMangaRepository();
    mangaRepository = fallbackMangaRepository;
    catalogRepository = InMemoryCatalogRepository(
      fallbackMangaRepository,
      remoteDataSources: {olympusRemote.sourceId: olympusRemote},
      pageCache: pageCache,
    );
    final enabled = sourcePrefs.enabledSources();
    final legacySync = <String, DateTime?>{};
    for (final source in kDefaultSources) {
      final timestamp = sourcePrefs.lastSync(source.id);
      if (timestamp != null) {
        legacySync[source.id] = timestamp;
      }
    }
    for (final sourceId in enabled) {
      legacySync.putIfAbsent(sourceId, () => sourcePrefs.lastSync(sourceId));
    }
    sourceRepository = InMemorySourceRepository(
      initialEnabled: enabled,
      initialLastSync: legacySync,
    );
  }

  final downloadRepository = DownloadRepositoryImpl(
    catalogRepository: catalogRepository,
    mangaRepository: mangaRepository,
    documentsDirectoryProvider: () async => appDir,
  );

  serviceLocator
    ..registerSingleton<DebugLogger>(debugLogger)
    ..registerSingleton<MangaRepository>(mangaRepository)
    ..registerSingleton<CatalogRepository>(catalogRepository)
    ..registerSingleton<SourceRepository>(sourceRepository)
    ..registerSingleton<DownloadRepository>(downloadRepository)
    ..registerSingleton<PageCacheDataSource>(pageCache)
    ..registerSingleton<ReadingProgressDataSource>(readingProgressDs)
    ..registerSingleton<ReaderPreferences>(readerPrefs)
    ..registerLazySingleton(() => WatchDownloadedMangas(serviceLocator()))
    ..registerLazySingleton(() => WatchDownloadQueue(serviceLocator()))
    ..registerLazySingleton(() => FetchMangaDetail(serviceLocator()))
    ..registerLazySingleton(() => FetchChapterPages(serviceLocator()))
    ..registerLazySingleton(() => FetchSourceCatalog(serviceLocator()))
    ..registerLazySingleton(() => GetAvailableSources(serviceLocator()))
    ..registerLazySingleton(() => WatchAvailableSources(serviceLocator()))
    ..registerLazySingleton(() => UpdateSourceSelection(serviceLocator()))
    ..registerLazySingleton(() => SyncSourceCatalog(serviceLocator()))
    ..registerLazySingleton(() => MarkSourceSynced(serviceLocator()))
    ..registerLazySingleton(() => GetSourceLastSync(serviceLocator()))
    ..registerLazySingleton(() => QueueChapterDownload(serviceLocator()))
    ..registerLazySingleton(() => QueueMangaDownload(serviceLocator()))
    ..registerLazySingleton(
      () => DeleteDownloadedChapter(
        mangaRepository: serviceLocator(),
        downloadRepository: serviceLocator(),
      ),
    )
    ..registerFactory(() => DownloadsCubit(serviceLocator()))
    ..registerFactory(() => LibraryCubit(serviceLocator()))
    ..registerFactory(() => DebugLogCubit(serviceLocator()))
    ..registerFactory(
      () => MangaDetailCubit(
        fetchMangaDetail: serviceLocator(),
        watchDownloadedMangas: serviceLocator(),
        queueChapterDownload: serviceLocator(),
        deleteDownloadedChapter: serviceLocator(),
        readingProgressDataSource: serviceLocator(),
      ),
    )
    ..registerFactory(
      () => SourcesCubit(
        watchAvailableSources: serviceLocator(),
        getAvailableSources: serviceLocator(),
        updateSourceSelection: serviceLocator(),
        syncSourceCatalog: serviceLocator(),
        fetchSourceCatalog: serviceLocator(),
        markSourceSynced: serviceLocator(),
      ),
    );
}
