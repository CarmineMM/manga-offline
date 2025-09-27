import 'package:get_it/get_it.dart';
import 'package:manga_offline/data/stubs/in_memory_repositories.dart';
import 'package:manga_offline/domain/repositories/catalog_repository.dart';
import 'package:manga_offline/domain/repositories/manga_repository.dart';
import 'package:manga_offline/domain/repositories/source_repository.dart';
import 'package:manga_offline/domain/usecases/fetch_manga_detail.dart';
import 'package:manga_offline/domain/usecases/get_available_sources.dart';
import 'package:manga_offline/domain/usecases/sync_source_catalog.dart';
import 'package:manga_offline/domain/usecases/update_source_selection.dart';
import 'package:manga_offline/domain/usecases/watch_available_sources.dart';
import 'package:manga_offline/domain/usecases/watch_downloaded_mangas.dart';
import 'package:manga_offline/presentation/blocs/library/library_cubit.dart';
import 'package:manga_offline/presentation/blocs/manga_detail/manga_detail_cubit.dart';
import 'package:manga_offline/presentation/blocs/sources/sources_cubit.dart';

/// Global service locator instance.
final GetIt serviceLocator = GetIt.instance;

/// Registers shared dependencies for the application.
Future<void> configureDependencies() async {
  if (serviceLocator.isRegistered<MangaRepository>()) {
    await serviceLocator.reset();
  }

  final inMemoryMangaRepository = InMemoryMangaRepository();

  serviceLocator
    ..registerSingleton<MangaRepository>(inMemoryMangaRepository)
    ..registerSingleton<CatalogRepository>(
      InMemoryCatalogRepository(inMemoryMangaRepository),
    )
    ..registerSingleton<SourceRepository>(InMemorySourceRepository())
    ..registerLazySingleton(() => WatchDownloadedMangas(serviceLocator()))
    ..registerLazySingleton(() => FetchMangaDetail(serviceLocator()))
    ..registerLazySingleton(() => GetAvailableSources(serviceLocator()))
    ..registerLazySingleton(() => WatchAvailableSources(serviceLocator()))
    ..registerLazySingleton(() => UpdateSourceSelection(serviceLocator()))
    ..registerLazySingleton(() => SyncSourceCatalog(serviceLocator()))
    ..registerFactory(() => LibraryCubit(serviceLocator()))
    ..registerFactory(() => MangaDetailCubit(serviceLocator()))
    ..registerFactory(
      () => SourcesCubit(
        watchAvailableSources: serviceLocator(),
        getAvailableSources: serviceLocator(),
        updateSourceSelection: serviceLocator(),
        syncSourceCatalog: serviceLocator(),
      ),
    );
}
