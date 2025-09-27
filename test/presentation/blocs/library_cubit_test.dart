import 'package:flutter_test/flutter_test.dart';
import 'package:manga_offline/data/stubs/in_memory_repositories.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/usecases/watch_downloaded_mangas.dart';
import 'package:manga_offline/presentation/blocs/library/library_cubit.dart';

void main() {
  group('LibraryCubit', () {
    late InMemoryMangaRepository repository;
    late LibraryCubit cubit;

    setUp(() {
      repository = InMemoryMangaRepository();
      repository.seedLibrary(const <Manga>[
        Manga(
          id: 'academia-de-la-ascension',
          sourceId: 'olympus',
          sourceName: 'Olympus Biblioteca',
          title: 'Academia de la Ascensión',
          status: DownloadStatus.downloaded,
        ),
        Manga(
          id: 'omega-knights',
          sourceId: 'eden-garden',
          sourceName: 'Eden Garden',
          title: 'Omega Knights',
          status: DownloadStatus.notDownloaded,
        ),
        Manga(
          id: 'mystic-lovers',
          sourceId: 'olympus',
          sourceName: 'Olympus Biblioteca',
          title: 'Mystic Lovers',
          status: DownloadStatus.notDownloaded,
        ),
      ]);
      cubit = LibraryCubit(WatchDownloadedMangas(repository));
    });

    tearDown(() async {
      await cubit.close();
    });

    test('loads library and applies search/source filters', () async {
      cubit.start();

      final loadedState = await cubit.stream.firstWhere(
        (LibraryState state) => state.status == LibraryStatus.success,
      );

      expect(loadedState.allMangas.length, 3);
      expect(loadedState.filteredMangas.length, 3);
      expect(
        loadedState.availableSources
            .map((LibrarySourceInfo e) => e.id)
            .toList(),
        <String>['eden-garden', 'olympus'],
      );

      cubit.updateSearchQuery('omega');
      expect(cubit.state.filteredMangas.length, 1);
      expect(cubit.state.filteredMangas.first.id, 'omega-knights');

      cubit.updateSearchQuery('');
      cubit.toggleSourceFilter('eden-garden');
      expect(
        cubit.state.filteredMangas.map((Manga m) => m.id).toList(),
        <String>['omega-knights'],
      );

      cubit.toggleSourceFilter('olympus');
      expect(cubit.state.filteredMangas.length, 3);

      cubit.resetFilters();
      expect(cubit.state.searchQuery, isEmpty);
      expect(cubit.state.selectedSourceIds, isEmpty);
      expect(cubit.state.filteredMangas.length, 3);
    });

    test('search matches source name as well as title', () async {
      cubit.start();
      await cubit.stream.firstWhere(
        (LibraryState state) => state.status == LibraryStatus.success,
      );

      cubit.updateSearchQuery('olympus');
      expect(cubit.state.filteredMangas.length, 2);

      cubit.updateSearchQuery('eden');
      expect(cubit.state.filteredMangas.length, 1);
      expect(cubit.state.filteredMangas.first.sourceId, 'eden-garden');
    });
  });
}
