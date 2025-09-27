import 'package:flutter_test/flutter_test.dart';
import 'package:manga_offline/data/stubs/in_memory_repositories.dart';
import 'package:manga_offline/domain/usecases/get_available_sources.dart';
import 'package:manga_offline/domain/usecases/sync_source_catalog.dart';
import 'package:manga_offline/domain/usecases/update_source_selection.dart';
import 'package:manga_offline/domain/usecases/watch_available_sources.dart';
import 'package:manga_offline/presentation/blocs/sources/sources_cubit.dart';

void main() {
  group('SourcesCubit', () {
    late InMemoryMangaRepository mangaRepository;
    late InMemoryCatalogRepository catalogRepository;
    late InMemorySourceRepository sourceRepository;
    late SourcesCubit cubit;

    setUp(() {
      mangaRepository = InMemoryMangaRepository();
      catalogRepository = InMemoryCatalogRepository(mangaRepository);
      sourceRepository = InMemorySourceRepository();
      cubit = SourcesCubit(
        watchAvailableSources: WatchAvailableSources(sourceRepository),
        getAvailableSources: GetAvailableSources(sourceRepository),
        updateSourceSelection: UpdateSourceSelection(sourceRepository),
        syncSourceCatalog: SyncSourceCatalog(catalogRepository),
      );
    });

    tearDown(() async {
      await cubit.close();
    });

    test('loads sources on start', () async {
      await cubit.start();

      expect(cubit.state.status, SourcesStatus.ready);
      expect(cubit.state.sources, isNotEmpty);
    });

    test('enabling a source triggers catalog sync', () async {
      await cubit.start();

      final libraryFuture =
          mangaRepository.watchLocalLibrary().skip(1).first;

      await cubit.toggleSource(sourceId: 'olympus', isEnabled: true);

      final library = await libraryFuture;
      expect(library, isNotEmpty);
      final enabledSource = cubit.state.sources.firstWhere(
        (source) => source.id == 'olympus',
      );
      expect(enabledSource.isEnabled, isTrue);
      expect(cubit.state.syncingSources, isEmpty);
    });
  });
}
