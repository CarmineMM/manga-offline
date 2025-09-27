import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:manga_offline/data/repositories/download_repository_impl.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/download_task.dart';
import 'package:manga_offline/domain/entities/page_image.dart';
import 'package:manga_offline/domain/repositories/catalog_repository.dart';
import 'package:manga_offline/domain/repositories/manga_repository.dart';

class _MockCatalogRepository extends Mock implements CatalogRepository {}

class _MockMangaRepository extends Mock implements MangaRepository {}

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  late _MockCatalogRepository catalogRepository;
  late _MockMangaRepository mangaRepository;
  late _MockHttpClient httpClient;
  late Directory tempDirectory;
  late DownloadRepositoryImpl downloadRepository;

  setUpAll(() {
    registerFallbackValue(
      Chapter(
        id: 'chapter-1',
        mangaId: 'manga-1',
        sourceId: 'source-1',
        title: 'Capítulo 1',
        number: 1,
      ),
    );
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() async {
    catalogRepository = _MockCatalogRepository();
    mangaRepository = _MockMangaRepository();
    httpClient = _MockHttpClient();
    tempDirectory = await Directory.systemTemp.createTemp('download_repo_test');

    downloadRepository = DownloadRepositoryImpl(
      catalogRepository: catalogRepository,
      mangaRepository: mangaRepository,
      httpClient: httpClient,
      documentsDirectoryProvider: () async => tempDirectory,
    );
  });

  tearDown(() async {
    downloadRepository.dispose();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('enqueueChapterDownload saves pages and updates queue', () async {
    final chapter = Chapter(
      id: 'chapter-1',
      mangaId: 'manga-1',
      sourceId: 'source-1',
      title: 'Capítulo 1',
      number: 1,
    );

    final remotePages = <PageImage>[
      const PageImage(
        id: 'page-1',
        chapterId: 'chapter-1',
        pageNumber: 1,
        remoteUrl: 'https://example.com/page1.jpg',
      ),
      const PageImage(
        id: 'page-2',
        chapterId: 'chapter-1',
        pageNumber: 2,
        remoteUrl: 'https://example.com/page2.jpg',
      ),
    ];

    when(
      () => catalogRepository.fetchChapterPages(
        sourceId: any(named: 'sourceId'),
        mangaId: any(named: 'mangaId'),
        chapterId: any(named: 'chapterId'),
      ),
    ).thenAnswer((invocation) async => remotePages);

    when(
      () => mangaRepository.getChapter(any()),
    ).thenAnswer((_) async => chapter);

    final savedChapters = <Chapter>[];
    when(() => mangaRepository.saveChapter(captureAny())).thenAnswer((
      invocation,
    ) async {
      savedChapters.add(invocation.positionalArguments.first as Chapter);
    });

    when(() => httpClient.get(any())).thenAnswer((invocation) async {
      return http.Response.bytes(List<int>.filled(8, 1), 200);
    });

    final queueUpdates = <List<DownloadTask>>[];
    final subscription = downloadRepository.watchDownloadQueue().listen(
      queueUpdates.add,
    );

    await downloadRepository.enqueueChapterDownload(chapter);
    await Future<void>.delayed(Duration.zero);

    await subscription.cancel();

    expect(queueUpdates, isNotEmpty);
    final lastSnapshot = queueUpdates.last;
    expect(lastSnapshot, hasLength(1));
    expect(lastSnapshot.first.status, DownloadStatus.downloaded);
    expect(lastSnapshot.first.progress, 1);

    expect(savedChapters, isNotEmpty);
    final finalChapter = savedChapters.last;
    expect(finalChapter.status, DownloadStatus.downloaded);
    expect(finalChapter.pages.every((page) => page.localPath != null), isTrue);
    expect(finalChapter.downloadedPages, equals(remotePages.length));
  });
}
