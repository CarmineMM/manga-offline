import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_task.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/entities/manga_source.dart';
import 'package:manga_offline/domain/entities/source_capability.dart';
import 'package:manga_offline/domain/repositories/catalog_repository.dart';
import 'package:manga_offline/domain/repositories/download_repository.dart';
import 'package:manga_offline/domain/repositories/source_repository.dart';
import 'package:manga_offline/domain/usecases/fetch_manga_detail.dart';
import 'package:manga_offline/domain/usecases/fetch_source_catalog.dart';
import 'package:manga_offline/domain/usecases/get_available_sources.dart';
import 'package:manga_offline/domain/usecases/queue_chapter_download.dart';
import 'package:manga_offline/domain/usecases/queue_manga_download.dart';
import 'package:manga_offline/domain/usecases/sync_source_catalog.dart';
import 'package:manga_offline/domain/usecases/update_source_selection.dart';
import 'package:manga_offline/domain/usecases/watch_available_sources.dart';
import 'package:manga_offline/domain/usecases/watch_download_queue.dart';

class _FakeSourceRepository implements SourceRepository {
  _FakeSourceRepository(this._sources);

  final List<MangaSource> _sources;
  String? updatedSource;
  bool? updatedValue;

  @override
  Future<List<MangaSource>> loadSources() async => _sources;

  @override
  Stream<List<MangaSource>> watchSources() => Stream.value(_sources);

  @override
  Future<void> updateSourceSelection({
    required String sourceId,
    required bool isEnabled,
  }) async {
    updatedSource = sourceId;
    updatedValue = isEnabled;
  }
}

class _FakeCatalogRepository implements CatalogRepository {
  String? lastSyncedSource;
  String? lastCatalogSource;
  String? lastDetailSource;
  String? lastDetailManga;
  List<Manga> catalog = const [];
  Manga? detail;

  @override
  Future<List<Manga>> fetchCatalog({required String sourceId}) async {
    lastCatalogSource = sourceId;
    return catalog;
  }

  @override
  Future<Manga> fetchMangaDetail({
    required String sourceId,
    required String mangaId,
  }) async {
    lastDetailSource = sourceId;
    lastDetailManga = mangaId;
    return detail!;
  }

  @override
  Future<void> syncCatalog({required String sourceId}) async {
    lastSyncedSource = sourceId;
  }
}

class _FakeDownloadRepository implements DownloadRepository {
  Chapter? lastChapter;
  Manga? lastManga;
  final StreamController<List<DownloadTask>> _controller =
      StreamController<List<DownloadTask>>.broadcast();

  @override
  Future<void> enqueueChapterDownload(Chapter chapter) async {
    lastChapter = chapter;
  }

  @override
  Future<void> enqueueMangaDownload(Manga manga) async {
    lastManga = manga;
  }

  @override
  Stream<List<DownloadTask>> watchDownloadQueue() => _controller.stream;

  void emitQueue(List<DownloadTask> queue) {
    _controller.add(queue);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('Source use cases', () {
    final sources = [
      MangaSource(
        id: 'source-1',
        name: 'Source 1',
        baseUrl: 'https://example.com',
        locale: 'es-ES',
        capabilities: const [SourceCapability.catalog, SourceCapability.detail],
        isEnabled: true,
      ),
    ];

    test('GetAvailableSources returns repository data', () async {
      final repository = _FakeSourceRepository(sources);
      final useCase = GetAvailableSources(repository);

      final result = await useCase();

      expect(result, equals(sources));
    });

    test('WatchAvailableSources emits repository stream', () async {
      final repository = _FakeSourceRepository(sources);
      final useCase = WatchAvailableSources(repository);

      await expectLater(useCase(), emits(sources));
    });

    test('UpdateSourceSelection forwards parameters', () async {
      final repository = _FakeSourceRepository(sources);
      final useCase = UpdateSourceSelection(repository);

      await useCase(sourceId: 'source-1', isEnabled: false);

      expect(repository.updatedSource, equals('source-1'));
      expect(repository.updatedValue, isFalse);
    });
  });

  group('Catalog use cases', () {
    late _FakeCatalogRepository repository;
    setUp(() {
      repository = _FakeCatalogRepository();
      repository.catalog = [
        Manga(
          id: 'manga-1',
          sourceId: 'source-1',
          sourceName: 'Source 1',
          title: 'Manga 1',
        ),
      ];
      repository.detail = Manga(
        id: 'manga-1',
        sourceId: 'source-1',
        sourceName: 'Source 1',
        title: 'Manga 1',
      );
    });

    test('SyncSourceCatalog delegates to repository', () async {
      final useCase = SyncSourceCatalog(repository);

      await useCase(sourceId: 'source-1');

      expect(repository.lastSyncedSource, equals('source-1'));
    });

    test('FetchSourceCatalog returns data', () async {
      final useCase = FetchSourceCatalog(repository);

      final result = await useCase(sourceId: 'source-1');

      expect(repository.lastCatalogSource, equals('source-1'));
      expect(result, equals(repository.catalog));
    });

    test('FetchMangaDetail returns data', () async {
      final useCase = FetchMangaDetail(repository);

      final result = await useCase(sourceId: 'source-1', mangaId: 'manga-1');

      expect(repository.lastDetailSource, equals('source-1'));
      expect(repository.lastDetailManga, equals('manga-1'));
      expect(result.id, equals('manga-1'));
    });
  });

  group('Download use cases', () {
    late _FakeDownloadRepository repository;

    setUp(() {
      repository = _FakeDownloadRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('QueueChapterDownload enqueues repository call', () async {
      final useCase = QueueChapterDownload(repository);
      final chapter = Chapter(
        id: 'chapter-1',
        mangaId: 'manga-1',
        sourceId: 'source-1',
        title: 'Capítulo 1',
        number: 1,
      );

      await useCase(chapter);

      expect(repository.lastChapter, equals(chapter));
    });

    test('QueueMangaDownload enqueues repository call', () async {
      final useCase = QueueMangaDownload(repository);
      final manga = Manga(
        id: 'manga-1',
        sourceId: 'source-1',
        title: 'Manga 1',
      );

      await useCase(manga);

      expect(repository.lastManga, equals(manga));
    });

    test('WatchDownloadQueue exposes stream updates', () async {
      final useCase = WatchDownloadQueue(repository);
      final task = DownloadTask(
        id: 'task-1',
        sourceId: 'source-1',
        targetType: DownloadTargetType.chapter,
        targetId: 'chapter-1',
        mangaId: 'manga-1',
        createdAt: DateTime(2024, 1, 1),
      );

      final expectation = expectLater(
        useCase(),
        emitsInOrder([
          [],
          [task],
        ]),
      );

      repository.emitQueue([]);
      repository.emitQueue([task]);

      await expectation;
    });
  });
}
