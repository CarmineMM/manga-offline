import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:manga_offline/data/datasources/catalog_remote_datasource.dart';
import 'package:manga_offline/data/datasources/manga_local_datasource.dart';
import 'package:manga_offline/data/models/chapter_model.dart';
import 'package:manga_offline/data/models/manga_model.dart';
import 'package:manga_offline/data/models/page_image_model.dart';
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
    registerFallbackValue(<PageImageModel>[]);
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
    when(
      () => local.getPagesForChapter(any()),
    ).thenAnswer((_) async => const <PageImageModel>[]);
    when(
      () => local.findMangaBySlugAlias(
        sourceId: any(named: 'sourceId'),
        slug: any(named: 'slug'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => local.migrateMangaSlug(
        sourceId: any(named: 'sourceId'),
        fromSlug: any(named: 'fromSlug'),
        toSlug: any(named: 'toSlug'),
      ),
    ).thenAnswer((_) async => null);
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
      when(() => local.getManga(summary.slug)).thenAnswer((_) async => null);
      when(
        () => local.putManga(
          any(),
          chapters: any(named: 'chapters'),
          pages: any(named: 'pages'),
          replaceChapters: any(named: 'replaceChapters'),
        ),
      ).thenAnswer((_) async {});

      await repository.syncCatalog(sourceId: sourceId);

      final captured = verify(
        () => local.putManga(
          captureAny(),
          chapters: captureAny(named: 'chapters'),
          pages: captureAny(named: 'pages'),
          replaceChapters: captureAny(named: 'replaceChapters'),
        ),
      ).captured;

      final MangaModel stored = captured[0] as MangaModel;
      final List<PageImageModel> storedPages = (captured[2] as List<dynamic>)
          .cast<PageImageModel>();
      final bool replaceChapters = captured[3] as bool;

      expect(stored.referenceId, equals(summary.slug));
      expect(stored.title, equals(summary.title));
      expect(stored.totalChapters, equals(summary.chapterCount));
      expect(storedPages, isEmpty);
      expect(replaceChapters, isFalse);
    });

    test('migrates existing entries when slug suffix changes', () async {
      const sourceId = 'olympus';
      const oldSlug = 'el-creador-esta-en-hiatus-20250929-081438442';
      const newSlug = 'el-creador-esta-en-hiatus-20250929-095862134';
      const summary = RemoteMangaSummary(
        externalId: '77',
        slug: newSlug,
        title: 'El creador está en hiatus',
        chapterCount: 120,
        sourceId: sourceId,
        sourceName: 'Olympus Biblioteca',
        coverUrl: 'https://example.com/hiatus.webp',
        synopsis: 'Original synopsis',
        status: 'Activo',
      );

      final aliasModel = MangaModel()
        ..referenceId = oldSlug
        ..sourceId = sourceId
        ..title = 'El creador está en hiatus'
        ..status = DownloadStatus.downloaded
        ..downloadedChapters = 34
        ..coverImagePath = '/covers/hiatus.webp';
      final migratedModel = MangaModel()
        ..referenceId = newSlug
        ..sourceId = sourceId
        ..title = aliasModel.title
        ..status = DownloadStatus.downloaded
        ..downloadedChapters = aliasModel.downloadedChapters
        ..coverImagePath = aliasModel.coverImagePath;

      when(() => remote.fetchAllSeries()).thenAnswer((_) async => [summary]);
      when(() => local.getManga(newSlug)).thenAnswer((_) async => null);
      when(
        () => local.findMangaBySlugAlias(sourceId: sourceId, slug: newSlug),
      ).thenAnswer((_) async => aliasModel);
      when(
        () => local.migrateMangaSlug(
          sourceId: sourceId,
          fromSlug: oldSlug,
          toSlug: newSlug,
        ),
      ).thenAnswer((_) async => migratedModel);
      when(
        () => local.putManga(
          any(),
          chapters: any(named: 'chapters'),
          pages: any(named: 'pages'),
          replaceChapters: any(named: 'replaceChapters'),
        ),
      ).thenAnswer((_) async {});

      await repository.syncCatalog(sourceId: sourceId);

      verify(
        () => local.migrateMangaSlug(
          sourceId: sourceId,
          fromSlug: oldSlug,
          toSlug: newSlug,
        ),
      ).called(1);

      final captured = verify(
        () => local.putManga(
          captureAny(),
          chapters: captureAny(named: 'chapters'),
          pages: captureAny(named: 'pages'),
          replaceChapters: captureAny(named: 'replaceChapters'),
        ),
      ).captured;

      final MangaModel stored = captured[0] as MangaModel;
      expect(stored.referenceId, equals(newSlug));
      expect(stored.downloadedChapters, equals(aliasModel.downloadedChapters));
    });

    test('preserves download state for existing manga', () async {
      const sourceId = 'olympus';
      const summary = RemoteMangaSummary(
        externalId: '11',
        slug: 'academia-de-la-ascension',
        title: 'Academia de la Ascensión',
        chapterCount: 174,
        sourceId: sourceId,
        sourceName: 'Olympus Biblioteca',
        coverUrl: 'https://example.com/new-cover.webp',
        synopsis: null,
        status: 'Activo',
      );

      final existing = MangaModel()
        ..referenceId = summary.slug
        ..sourceId = sourceId
        ..title = 'Título previo'
        ..synopsis = 'Sinopsis almacenada'
        ..coverImageUrl = 'https://example.com/old-cover.webp'
        ..coverImagePath = '/data/covers/acad.webp'
        ..status = DownloadStatus.downloaded
        ..downloadedChapters = 12
        ..lastUpdated = DateTime(2024, 1, 1);

      when(() => remote.fetchAllSeries()).thenAnswer((_) async => [summary]);
      when(
        () => local.getManga(summary.slug),
      ).thenAnswer((_) async => existing);
      when(
        () => local.putManga(
          any(),
          chapters: any(named: 'chapters'),
          pages: any(named: 'pages'),
          replaceChapters: any(named: 'replaceChapters'),
        ),
      ).thenAnswer((_) async {});

      await repository.syncCatalog(sourceId: sourceId);

      final captured = verify(
        () => local.putManga(
          captureAny(),
          chapters: captureAny(named: 'chapters'),
          pages: captureAny(named: 'pages'),
          replaceChapters: captureAny(named: 'replaceChapters'),
        ),
      ).captured;

      final MangaModel stored = captured[0] as MangaModel;
      final bool replaceChapters = captured[3] as bool;

      expect(stored.status, equals(DownloadStatus.downloaded));
      expect(stored.downloadedChapters, equals(12));
      expect(stored.coverImagePath, equals('/data/covers/acad.webp'));
      expect(stored.coverImageUrl, equals(summary.coverUrl));
      expect(stored.synopsis, equals('Sinopsis almacenada'));
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
          pages: any(named: 'pages'),
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
          pages: any(named: 'pages'),
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
          pages: any(named: 'pages'),
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

    test('falls back to cached chapters when remote request fails', () async {
      const sourceId = 'olympus';
      final mangaModel = MangaModel()
        ..referenceId = 'slug'
        ..sourceId = sourceId
        ..title = 'Sample'
        ..status = DownloadStatus.downloaded
        ..totalChapters = 1;
      final chapterModel = ChapterModel()
        ..referenceId = 'chapter-1'
        ..mangaReferenceId = 'slug'
        ..sourceId = sourceId
        ..title = 'Capítulo 1'
        ..number = 1
        ..status = DownloadStatus.downloaded;

      when(() => local.getManga('slug')).thenAnswer((_) async => mangaModel);
      when(
        () => local.getChaptersForManga('slug'),
      ).thenAnswer((_) async => [chapterModel]);
      when(
        () => local.getPagesForChapter('chapter-1'),
      ).thenAnswer((_) async => const <PageImageModel>[]);
      when(
        () => remote.fetchAllChapters(mangaSlug: 'slug'),
      ).thenThrow(Exception('offline'));

      final result = await repository.fetchMangaDetail(
        sourceId: sourceId,
        mangaId: 'slug',
      );

      expect(result.id, equals('slug'));
      expect(result.chapters, hasLength(1));
      expect(result.chapters.single.id, equals('chapter-1'));
      verifyNever(
        () => local.putManga(
          any(),
          chapters: any(named: 'chapters'),
          pages: any(named: 'pages'),
          replaceChapters: any(named: 'replaceChapters'),
        ),
      );
    });
  });
}
