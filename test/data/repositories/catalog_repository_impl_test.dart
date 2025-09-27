import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:manga_offline/data/datasources/catalog_remote_datasource.dart';
import 'package:manga_offline/data/datasources/manga_local_datasource.dart';
import 'package:manga_offline/data/models/chapter_model.dart';
import 'package:manga_offline/data/models/manga_model.dart';
import 'package:manga_offline/data/repositories/catalog_repository_impl.dart';
import 'package:manga_offline/domain/entities/download_status.dart';

class _MockMangaLocalDataSource extends Mock implements MangaLocalDataSource {}

class _MockCatalogRemoteDataSource extends Mock
    implements CatalogRemoteDataSource {}

void main() {
  late _MockMangaLocalDataSource local;
  late _MockCatalogRemoteDataSource remote;
  late CatalogRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(
      MangaModel()
        ..referenceId = 'fallback'
        ..sourceId = 'source'
        ..title = 'Fallback'
        ..status = DownloadStatus.notDownloaded,
    );
    registerFallbackValue(<ChapterModel>[]);
  });

  setUp(() {
    local = _MockMangaLocalDataSource();
    remote = _MockCatalogRemoteDataSource();
    const sourceId = 'olympus';
    const sourceName = 'Olympus Biblioteca';
    when(() => remote.sourceId).thenReturn(sourceId);
    when(() => remote.sourceName).thenReturn(sourceName);
    when(
      () => remote.fetchAllChapters(mangaSlug: any(named: 'mangaSlug')),
    ).thenAnswer((_) async => const <RemoteChapterSummary>[]);
    repository = CatalogRepositoryImpl(
      localDataSource: local,
      remoteDataSources: {sourceId: remote},
    );
  });

  group('syncCatalog', () {
    test('stores remote summaries locally', () async {
      const sourceId = 'olympus';
      const summary = RemoteMangaSummary(
        externalId: '11',
        slug: 'academia-de-la-ascension',
        title: 'Academia de la Ascensión',
        chapterCount: 174,
        sourceId: sourceId,
        sourceName: 'Olympus Biblioteca',
        coverUrl: 'https://example.com/cover.webp',
        synopsis: null,
        status: 'Activo',
      );

      when(() => remote.fetchAllSeries()).thenAnswer((_) async => [summary]);
      when(
        () => local.putManga(
          any(),
          chapters: any(named: 'chapters'),
          replaceChapters: any(named: 'replaceChapters'),
        ),
      ).thenAnswer((_) async {});

      await repository.syncCatalog(sourceId: sourceId);

      final captured = verify(
        () => local.putManga(
          captureAny(),
          chapters: captureAny(named: 'chapters'),
          replaceChapters: captureAny(named: 'replaceChapters'),
        ),
      ).captured;

      final MangaModel stored = captured[0] as MangaModel;
      final bool replaceChapters = captured[2] as bool;

      expect(stored.referenceId, equals(summary.slug));
      expect(stored.title, equals(summary.title));
      expect(stored.totalChapters, equals(summary.chapterCount));
      expect(replaceChapters, isFalse);
    });
  });

  group('fetchCatalog', () {
    test('returns mapped mangas with chapters', () async {
      const sourceId = 'olympus';
      final mangaModel = MangaModel()
        ..referenceId = 'slug'
        ..sourceId = sourceId
        ..title = 'Sample'
        ..status = DownloadStatus.notDownloaded;
      final chapterModel = ChapterModel()
        ..referenceId = 'chapter-1'
        ..mangaReferenceId = 'slug'
        ..sourceId = sourceId
        ..title = 'Capítulo 1'
        ..number = 1
        ..status = DownloadStatus.notDownloaded;

      when(
        () => local.getMangasBySource(sourceId),
      ).thenAnswer((_) async => [mangaModel]);
      when(
        () => local.getChaptersForManga('slug'),
      ).thenAnswer((_) async => [chapterModel]);

      final result = await repository.fetchCatalog(sourceId: sourceId);

      expect(result, hasLength(1));
      expect(result.first.id, equals('slug'));
      expect(result.first.chapters, hasLength(1));
    });
  });

  group('fetchMangaDetail', () {
    test('updates local storage with remote chapters', () async {
      const sourceId = 'olympus';
      final mangaModel = MangaModel()
        ..referenceId = 'slug'
        ..sourceId = sourceId
        ..title = 'Sample'
        ..status = DownloadStatus.notDownloaded;
      final existingChapterModel = ChapterModel()
        ..referenceId = 'chapter-1'
        ..mangaReferenceId = 'slug'
        ..sourceId = sourceId
        ..title = 'Capítulo 1'
        ..number = 1
        ..status = DownloadStatus.downloaded
        ..downloadedPages = 10
        ..totalPages = 10;
      final remoteChapters = [
        const RemoteChapterSummary(
          externalId: 'chapter-1',
          mangaSlug: 'slug',
          name: '1',
          sourceId: sourceId,
          sourceName: 'Olympus Biblioteca',
          publishedAt: null,
        ),
        const RemoteChapterSummary(
          externalId: 'chapter-2',
          mangaSlug: 'slug',
          name: '2',
          sourceId: sourceId,
          sourceName: 'Olympus Biblioteca',
          publishedAt: null,
        ),
      ];

      when(() => local.getManga('slug')).thenAnswer((_) async => mangaModel);
      when(
        () => local.getChaptersForManga('slug'),
      ).thenAnswer((_) async => [existingChapterModel]);
      when(
        () => remote.fetchAllChapters(mangaSlug: 'slug'),
      ).thenAnswer((_) async => remoteChapters);
      when(
        () => local.putManga(
          any(),
          chapters: any(named: 'chapters'),
          replaceChapters: any(named: 'replaceChapters'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.fetchMangaDetail(
        sourceId: sourceId,
        mangaId: 'slug',
      );

      expect(result.chapters, hasLength(2));
      expect(result.chapters.first.id, equals('chapter-1'));
      expect(result.chapters.first.status, equals(DownloadStatus.downloaded));
      expect(result.chapters.last.id, equals('chapter-2'));

      verify(
        () => local.putManga(
          any(),
          chapters: any(named: 'chapters'),
          replaceChapters: true,
        ),
      ).called(1);
    });

    test('returns minimal manga when not cached locally', () async {
      const sourceId = 'olympus';
      when(() => local.getManga('missing')).thenAnswer((_) async => null);
      when(
        () => local.getChaptersForManga('missing'),
      ).thenAnswer((_) async => const <ChapterModel>[]);
      when(() => remote.fetchAllChapters(mangaSlug: 'missing')).thenAnswer(
        (_) async => const [
          RemoteChapterSummary(
            externalId: 'chapter-1',
            mangaSlug: 'missing',
            name: '1',
            sourceId: sourceId,
            sourceName: 'Olympus Biblioteca',
            publishedAt: null,
          ),
        ],
      );
      when(
        () => local.putManga(
          any(),
          chapters: any(named: 'chapters'),
          replaceChapters: any(named: 'replaceChapters'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.fetchMangaDetail(
        sourceId: sourceId,
        mangaId: 'missing',
      );

      expect(result.id, equals('missing'));
      expect(result.chapters, hasLength(1));
    });
  });
}
