import 'package:flutter_test/flutter_test.dart';
import 'package:manga_offline/data/datasources/cache/reading_progress_datasource.dart';
import 'package:manga_offline/data/stubs/in_memory_repositories.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_task.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/repositories/download_repository.dart';
import 'package:manga_offline/domain/usecases/fetch_manga_detail.dart';
import 'package:manga_offline/domain/usecases/queue_chapter_download.dart';
import 'package:manga_offline/domain/usecases/delete_downloaded_chapter.dart';
import 'package:manga_offline/domain/usecases/watch_downloaded_mangas.dart';
import 'package:manga_offline/presentation/blocs/manga_detail/manga_detail_cubit.dart';

class _FakeDownloadRepository implements DownloadRepository {
  @override
  Future<void> enqueueChapterDownload(Chapter chapter) async {}

  @override
  Future<void> enqueueMangaDownload(Manga manga) async {}

  @override
  Stream<List<DownloadTask>> watchDownloadQueue() => const Stream.empty();

  @override
  Future<List<String>> listLocalChapterPages({
    required String sourceId,
    required String mangaId,
    required String chapterId,
  }) async {
    // Return an empty list for tests; adjust to match expected return type if needed.
    return const <String>[];
  }

  @override
  Future<void> deleteLocalChapterAssets({
    required String sourceId,
    required String mangaId,
    required String chapterId,
    String? localPath,
  }) async {}
}

void main() {
  group('MangaDetailCubit', () {
    late InMemoryMangaRepository mangaRepository;
    late InMemoryCatalogRepository catalogRepository;
    late FetchMangaDetail fetchMangaDetail;
    late WatchDownloadedMangas watchDownloadedMangas;
    late QueueChapterDownload queueChapterDownload;
    late DeleteDownloadedChapter deleteDownloadedChapter;
    late _FakeDownloadRepository downloadRepository;
    late ReadingProgressDataSource progressDataSource;
    late MangaDetailCubit cubit;

    setUp(() {
      mangaRepository = InMemoryMangaRepository();
      catalogRepository = InMemoryCatalogRepository(mangaRepository);
      fetchMangaDetail = FetchMangaDetail(catalogRepository);
      watchDownloadedMangas = WatchDownloadedMangas(mangaRepository);
      downloadRepository = _FakeDownloadRepository();
      queueChapterDownload = QueueChapterDownload(downloadRepository);
      deleteDownloadedChapter = DeleteDownloadedChapter(
        mangaRepository: mangaRepository,
        downloadRepository: downloadRepository,
      );
      progressDataSource = ReadingProgressDataSource.inMemory();
      cubit = MangaDetailCubit(
        fetchMangaDetail: fetchMangaDetail,
        watchDownloadedMangas: watchDownloadedMangas,
        queueChapterDownload: queueChapterDownload,
        deleteDownloadedChapter: deleteDownloadedChapter,
        readingProgressDataSource: progressDataSource,
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

    test('markChapterAsRead updates state and persists progress', () async {
      await catalogRepository.syncCatalog(sourceId: 'olympus');
      await cubit.load(
        sourceId: 'olympus',
        mangaId: 'academia-de-la-ascension',
      );

      final chapter = cubit.state.manga!.chapters.first;
      cubit.markChapterAsRead(chapter.id, complete: true);

      final updated = cubit.state.manga!.chapters.firstWhere(
        (c) => c.id == chapter.id,
      );
      expect(updated.lastReadAt, isNotNull);
      expect(updated.lastReadPage, isNotNull);
      expect(updated.lastReadPage, greaterThan(0));

      final stored = await progressDataSource.getProgress(chapter.id);
      expect(stored, isNotNull);
      expect(stored!.lastReadPage, equals(updated.lastReadPage));
    });

    test('markChapterAsUnread clears progress information', () async {
      await catalogRepository.syncCatalog(sourceId: 'olympus');
      await cubit.load(
        sourceId: 'olympus',
        mangaId: 'academia-de-la-ascension',
      );

      final chapter = cubit.state.manga!.chapters.first;
      cubit.markChapterAsRead(chapter.id, complete: true);
      cubit.markChapterAsUnread(chapter.id);

      final updated = cubit.state.manga!.chapters.firstWhere(
        (c) => c.id == chapter.id,
      );
      expect(updated.lastReadAt, isNull);
      expect(updated.lastReadPage, isNull);

      final stored = await progressDataSource.getProgress(chapter.id);
      expect(stored, isNull);
    });

    test(
      'library updates preserve persisted read status when merging progress',
      () async {
        await catalogRepository.syncCatalog(sourceId: 'olympus');
        await cubit.load(
          sourceId: 'olympus',
          mangaId: 'academia-de-la-ascension',
        );

        final downloadedCount = cubit.state.manga!.chapters.length;
        await mangaRepository.saveManga(
          cubit.state.manga!.copyWith(
            status: DownloadStatus.downloaded,
            downloadedChapters: downloadedCount,
          ),
        );
        await cubit.stream.firstWhere(
          (MangaDetailState state) =>
              (state.manga?.downloadedChapters ?? 0) == downloadedCount,
        );

        final chapter = cubit.state.manga!.chapters.first;
        cubit.markChapterAsRead(chapter.id, complete: true);
        final persisted = cubit.state.manga!.chapters.firstWhere(
          (c) => c.id == chapter.id,
        );
        final expectedPage = persisted.lastReadPage;
        expect(expectedPage, isNotNull);

        final strippedChapters = cubit.state.manga!.chapters
            .map(
              (c) => c.id == chapter.id
                  ? c.copyWith(lastReadAt: null, lastReadPage: null)
                  : c,
            )
            .toList(growable: false);

        await mangaRepository.saveManga(
          cubit.state.manga!.copyWith(
            chapters: strippedChapters,
            downloadedChapters: downloadedCount,
            status: DownloadStatus.downloaded,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        final refreshedChapter = cubit.state.manga!.chapters.firstWhere(
          (c) => c.id == chapter.id,
        );
        expect(refreshedChapter.lastReadPage, expectedPage);
        expect(refreshedChapter.lastReadAt, isNotNull);
      },
    );
  });
}
