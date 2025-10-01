import 'package:flutter_test/flutter_test.dart';
import 'package:manga_offline/data/stubs/in_memory_repositories.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/usecases/watch_followed_mangas.dart';
import 'package:manga_offline/presentation/blocs/followed/followed_cubit.dart';

void main() {
  group('FollowedCubit', () {
    late InMemoryMangaRepository repository;
    late FollowedCubit cubit;

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
          isFollowed: true,
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
      cubit = FollowedCubit(WatchFollowedMangas(repository));
    });

    tearDown(() async {
      await cubit.close();
    });

    test('emits mangas followed by the user', () async {
      final Future<FollowedState> loadFuture = cubit.stream.firstWhere(
        (FollowedState state) => state.status == FollowedStatus.success,
      );
      cubit.start();
      final FollowedState loadedState = await loadFuture;

      expect(loadedState.followedMangas.length, 1);
      expect(loadedState.followedMangas.first.id, 'omega-knights');
    });

    test('updates list when repository changes', () async {
      final Future<FollowedState> initialFuture = cubit.stream.firstWhere(
        (FollowedState state) => state.status == FollowedStatus.success,
      );
      cubit.start();
      await initialFuture;

      final Future<FollowedState> updateFuture = cubit.stream.firstWhere(
        (FollowedState state) => state.followedMangas.length == 2,
      );

      await repository.setMangaFollowed(
        mangaId: 'mystic-lovers',
        isFollowed: true,
      );

      final FollowedState updatedState = await updateFuture;

      expect(
        updatedState.followedMangas.map((Manga m) => m.id).toList(),
        containsAll(<String>['omega-knights', 'mystic-lovers']),
      );
    });

    test('refresh loads snapshot without active subscription', () async {
      await cubit.refresh();

      expect(cubit.state.status, FollowedStatus.success);
      expect(cubit.state.followedMangas.length, 1);
      expect(cubit.state.followedMangas.first.id, 'omega-knights');
    });
  });
}
