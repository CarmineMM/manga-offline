import 'package:flutter_test/flutter_test.dart';
import 'package:manga_offline/data/stubs/in_memory_repositories.dart';
import 'package:manga_offline/domain/usecases/fetch_manga_detail.dart';
import 'package:manga_offline/presentation/blocs/manga_detail/manga_detail_cubit.dart';

void main() {
  group('MangaDetailCubit', () {
    late InMemoryMangaRepository mangaRepository;
    late InMemoryCatalogRepository catalogRepository;
    late FetchMangaDetail fetchMangaDetail;
    late MangaDetailCubit cubit;

    setUp(() {
      mangaRepository = InMemoryMangaRepository();
      catalogRepository = InMemoryCatalogRepository(mangaRepository);
      fetchMangaDetail = FetchMangaDetail(catalogRepository);
      cubit = MangaDetailCubit(fetchMangaDetail);
    });

    tearDown(() async {
      await cubit.close();
    });

    test('starts with initial status', () {
      expect(cubit.state.status, MangaDetailStatus.initial);
      expect(cubit.state.manga, isNull);
    });

    test('loads manga detail successfully', () async {
      await catalogRepository.syncCatalog(sourceId: 'olympus');

      await cubit.load(
        sourceId: 'olympus',
        mangaId: 'academia-de-la-ascension',
      );

      expect(cubit.state.status, MangaDetailStatus.success);
      expect(cubit.state.manga, isNotNull);
      expect(cubit.state.manga!.chapters, isNotEmpty);
    });
  });
}
