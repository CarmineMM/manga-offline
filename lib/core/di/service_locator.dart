import 'package:get_it/get_it.dart';
import 'dart:io';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manga_offline/data/datasources/cache/page_cache_datasource.dart';
import 'package:manga_offline/data/datasources/cache/reading_progress_datasource.dart';
import 'package:manga_offline/data/models/reading_progress_entity.g.dart';
import 'package:manga_offline/core/utils/reader_preferences.dart';
import 'package:manga_offline/core/utils/source_preferences.dart';

import 'package:manga_offline/data/repositories/download_repository_impl.dart';
import 'package:manga_offline/data/stubs/in_memory_repositories.dart';
import 'package:manga_offline/data/datasources/olympus_remote_datasource.dart';
import 'package:manga_offline/domain/repositories/catalog_repository.dart';
import 'package:manga_offline/domain/repositories/download_repository.dart';
import 'package:manga_offline/domain/repositories/manga_repository.dart';
import 'package:manga_offline/domain/repositories/source_repository.dart';
import 'package:manga_offline/domain/usecases/fetch_chapter_pages.dart';
import 'package:manga_offline/domain/usecases/fetch_manga_detail.dart';
import 'package:manga_offline/domain/usecases/get_available_sources.dart';
import 'package:manga_offline/domain/usecases/sync_source_catalog.dart';
import 'package:manga_offline/domain/usecases/update_source_selection.dart';
import 'package:manga_offline/domain/usecases/watch_available_sources.dart';
import 'package:manga_offline/domain/usecases/watch_download_queue.dart';
import 'package:manga_offline/domain/usecases/watch_downloaded_mangas.dart';
import 'package:manga_offline/domain/usecases/queue_chapter_download.dart';
import 'package:manga_offline/domain/usecases/queue_manga_download.dart';
import 'package:manga_offline/presentation/blocs/library/library_cubit.dart';
import 'package:manga_offline/presentation/blocs/manga_detail/manga_detail_cubit.dart';
import 'package:manga_offline/presentation/blocs/sources/sources_cubit.dart';

/// Global service locator instance.
final GetIt serviceLocator = GetIt.instance;

/// Registers shared dependencies for the application.
///
/// The function wires development-friendly implementations (in-memory
/// repositories and a `DownloadRepositoryImpl` writing to a temporary
/// directory). Call this early from `main()` in debug/development builds.
Future<void> configureDependencies() async {
  if (serviceLocator.isRegistered<MangaRepository>()) {
    await serviceLocator.reset();
  }

  // Inicializa Isar (persistencia local). Añadimos PageEntity para cache de páginas.
  final appDir = await getApplicationDocumentsDirectory();
  // Nota: PageEntitySchema se genera vía build_runner. Asegúrate de ejecutar
  // `flutter pub run build_runner build --delete-conflicting-outputs`
  // después de este cambio para evitar errores de símbolo no definido.
  late final Isar isar;
  try {
    isar = await Isar.open(
      [PageEntitySchema, ReadingProgressEntitySchema],
      directory: appDir.path,
      inspector: false,
    );
  } catch (e) {
    // En entorno de test sin generar aún el código, podemos re-lanzar para hacerlo visible.
    rethrow;
  }
  final pageCache = IsarPageCacheDataSource(isar);
  final readingProgressDs = ReadingProgressDataSource(isar);

  final inMemoryMangaRepository = InMemoryMangaRepository();
  final olympusRemote = OlympusRemoteDataSource();
  final inMemoryCatalogRepository = InMemoryCatalogRepository(
    inMemoryMangaRepository,
    remoteDataSources: {olympusRemote.sourceId: olympusRemote},
  );
  final tempDownloadsDir = await Directory.systemTemp.createTemp(
    'manga_offline_downloads',
  );
  final downloadRepository = DownloadRepositoryImpl(
    catalogRepository: inMemoryCatalogRepository,
    mangaRepository: inMemoryMangaRepository,
    documentsDirectoryProvider: () async => tempDownloadsDir,
  );

  final readerPrefs = await ReaderPreferences.create();
  final sourcePrefs = await SourcePreferences.create();
  final inMemorySourceRepository = InMemorySourceRepository(
    sourcePreferences: sourcePrefs,
  );

  serviceLocator
    ..registerSingleton<MangaRepository>(inMemoryMangaRepository)
    ..registerSingleton<CatalogRepository>(inMemoryCatalogRepository)
    ..registerSingleton<SourceRepository>(inMemorySourceRepository)
    ..registerSingleton<DownloadRepository>(downloadRepository)
    ..registerSingleton<PageCacheDataSource>(pageCache)
    ..registerSingleton<ReadingProgressDataSource>(readingProgressDs)
    ..registerSingleton<ReaderPreferences>(readerPrefs)
    ..registerSingleton<SourcePreferences>(sourcePrefs)
    ..registerLazySingleton(() => WatchDownloadedMangas(serviceLocator()))
    ..registerLazySingleton(() => WatchDownloadQueue(serviceLocator()))
    ..registerLazySingleton(() => FetchMangaDetail(serviceLocator()))
    ..registerLazySingleton(() => FetchChapterPages(serviceLocator()))
    ..registerLazySingleton(() => GetAvailableSources(serviceLocator()))
    ..registerLazySingleton(() => WatchAvailableSources(serviceLocator()))
    ..registerLazySingleton(() => UpdateSourceSelection(serviceLocator()))
    ..registerLazySingleton(() => SyncSourceCatalog(serviceLocator()))
    ..registerLazySingleton(() => QueueChapterDownload(serviceLocator()))
    ..registerLazySingleton(() => QueueMangaDownload(serviceLocator()))
    ..registerFactory(() => LibraryCubit(serviceLocator()))
    ..registerFactory(
      () => MangaDetailCubit(
        fetchMangaDetail: serviceLocator(),
        watchDownloadedMangas: serviceLocator(),
        queueChapterDownload: serviceLocator(),
        readingProgressDataSource: serviceLocator(),
      ),
    )
    ..registerFactory(
      () => SourcesCubit(
        watchAvailableSources: serviceLocator(),
        getAvailableSources: serviceLocator(),
        updateSourceSelection: serviceLocator(),
        syncSourceCatalog: serviceLocator(),
        sourcePreferences: serviceLocator<SourcePreferences>(),
      ),
    );
}
