import 'package:flutter_test/flutter_test.dart';
import 'package:manga_offline/data/stubs/in_memory_repositories.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/usecases/watch_downloaded_mangas.dart';
import 'package:manga_offline/presentation/blocs/downloads/downloads_cubit.dart';

void main() {
  group('DownloadsCubit', () {
    late InMemoryMangaRepository repository;
    late DownloadsCubit cubit;

    setUp(() {
      repository = InMemoryMangaRepository();
      repository.seedLibrary(const <Manga>[
        Manga(
          id: 'omega-knights',
          sourceId: 'eden-garden',
          sourceName: 'Eden Garden',
          title: 'Omega Knights',
          status: DownloadStatus.downloading,
          downloadedChapters: 2,
          totalChapters: 5,
        ),
        Manga(
          id: 'mystic-lovers',
          sourceId: 'olympus',
          sourceName: 'Olympus Biblioteca',
          title: 'Mystic Lovers',
          status: DownloadStatus.notDownloaded,
          downloadedChapters: 0,
        ),
      ]);
      cubit = DownloadsCubit(WatchDownloadedMangas(repository));
    });

    tearDown(() async {
      await cubit.close();
    });

    test('emits mangas with downloaded chapters', () async {
      final Future<DownloadsState> loadFuture = cubit.stream.firstWhere(
        (DownloadsState state) => state.status == DownloadsStatus.success,
      );
      cubit.start();
      final DownloadsState loadedState = await loadFuture;

      expect(loadedState.downloadedMangas.length, 1);
      expect(loadedState.downloadedMangas.first.id, 'omega-knights');
    });

    test('updates list when repository changes', () async {
      final Future<DownloadsState> initialFuture = cubit.stream.firstWhere(
        (DownloadsState state) => state.status == DownloadsStatus.success,
      );
      cubit.start();
      await initialFuture;

      final Future<DownloadsState> updateFuture = cubit.stream.firstWhere(
        (DownloadsState state) => state.downloadedMangas.length == 2,
      );

      await repository.saveManga(
        const Manga(
          id: 'mystic-lovers',
          sourceId: 'olympus',
          sourceName: 'Olympus Biblioteca',
          title: 'Mystic Lovers',
          status: DownloadStatus.downloading,
          downloadedChapters: 1,
        ),
      );

      final DownloadsState updatedState = await updateFuture;

      expect(
        updatedState.downloadedMangas.map((Manga m) => m.id).toList(),
        containsAll(<String>['omega-knights', 'mystic-lovers']),
      );
    });

    test('refresh loads snapshot without active subscription', () async {
      await cubit.refresh();

      expect(cubit.state.status, DownloadsStatus.success);
      expect(cubit.state.downloadedMangas.length, 1);
      expect(cubit.state.downloadedMangas.first.id, 'omega-knights');
    });
  });
}
