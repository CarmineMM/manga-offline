import 'package:flutter_test/flutter_test.dart';
import 'package:manga_offline/data/stubs/in_memory_repositories.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_task.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/repositories/download_repository.dart';
import 'package:manga_offline/domain/usecases/fetch_manga_detail.dart';
import 'package:manga_offline/domain/usecases/queue_chapter_download.dart';
import 'package:manga_offline/domain/usecases/watch_downloaded_mangas.dart';
import 'package:manga_offline/presentation/blocs/manga_detail/manga_detail_cubit.dart';
import '../../data/in_memory_reading_progress_datasource.dart';

class _FakeDownloadRepository implements DownloadRepository {
  @override
  Future<void> enqueueChapterDownload(Chapter chapter) async {}

  @override
  Future<void> enqueueMangaDownload(Manga manga) async {}

  @override
  Stream<List<DownloadTask>> watchDownloadQueue() => const Stream.empty();

  @override
  Future<List<String>> listLocalChapterPages({
    required String chapterId,
    required String mangaId,
    required String sourceId,
  }) async {
    // Return an empty list for tests; adjust to match expected return type if needed.
    return const <String>[];
  }
}

void main() {
  group('MangaDetailCubit', () {
    late InMemoryMangaRepository mangaRepository;
    late InMemoryCatalogRepository catalogRepository;
    late FetchMangaDetail fetchMangaDetail;
    late WatchDownloadedMangas watchDownloadedMangas;
    late QueueChapterDownload queueChapterDownload;
    late MangaDetailCubit cubit;

    setUp(() {
      mangaRepository = InMemoryMangaRepository();
      catalogRepository = InMemoryCatalogRepository(mangaRepository);
      fetchMangaDetail = FetchMangaDetail(catalogRepository);
      watchDownloadedMangas = WatchDownloadedMangas(mangaRepository);
      queueChapterDownload = QueueChapterDownload(_FakeDownloadRepository());
      cubit = MangaDetailCubit(
        fetchMangaDetail: fetchMangaDetail,
        watchDownloadedMangas: watchDownloadedMangas,
        queueChapterDownload: queueChapterDownload,
        readingProgressDataSource: InMemoryReadingProgressDataSource(),
      );
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
