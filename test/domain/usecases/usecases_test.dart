import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_task.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/entities/manga_source.dart';
import 'package:manga_offline/domain/entities/page_image.dart';
import 'package:manga_offline/domain/entities/source_capability.dart';
import 'package:manga_offline/domain/repositories/catalog_repository.dart';
import 'package:manga_offline/domain/repositories/download_repository.dart';
import 'package:manga_offline/domain/repositories/manga_repository.dart';
import 'package:manga_offline/domain/repositories/source_repository.dart';
import 'package:manga_offline/domain/usecases/fetch_manga_detail.dart';
import 'package:manga_offline/domain/usecases/fetch_source_catalog.dart';
import 'package:manga_offline/domain/usecases/get_available_sources.dart';
import 'package:manga_offline/domain/usecases/get_chapter_download_status.dart';
import 'package:manga_offline/domain/usecases/get_manga_download_status.dart';
import 'package:manga_offline/domain/usecases/mark_chapter_downloaded.dart';
import 'package:manga_offline/domain/usecases/mark_manga_downloaded.dart';
import 'package:manga_offline/domain/usecases/queue_chapter_download.dart';
import 'package:manga_offline/domain/usecases/queue_manga_download.dart';
import 'package:manga_offline/domain/usecases/sync_source_catalog.dart';
import 'package:manga_offline/domain/usecases/update_source_selection.dart';
import 'package:manga_offline/domain/usecases/watch_available_sources.dart';
import 'package:manga_offline/domain/usecases/watch_download_queue.dart';
import 'package:manga_offline/domain/usecases/watch_downloaded_mangas.dart';

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
  List<PageImage> pages = const [];

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

  @override
  Future<List<PageImage>> fetchChapterPages({
    required String sourceId,
    required String mangaId,
    required String chapterId,
  }) async {
    return pages;
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

class _FakeMangaRepository implements MangaRepository {
  final StreamController<List<Manga>> _controller =
      StreamController<List<Manga>>.broadcast();
  final Map<String, Manga> _stored = {};
  final Map<String, DownloadStatus> _mangaStatuses = {};
  final Map<String, DownloadStatus> _chapterStatuses = {};
  String? lastMangaMarked;
  String? lastChapterMarked;

  void dispose() {
    _controller.close();
  }

  @override
  Stream<List<Manga>> watchLocalLibrary() => _controller.stream;

  @override
  Future<void> saveManga(Manga manga) async {
    _stored[manga.id] = manga;
    _mangaStatuses[manga.id] = manga.status;
    _controller.add(_stored.values.toList());
  }

  @override
  Future<void> saveChapter(Chapter chapter) async {
    final existing = _stored[chapter.mangaId];
    if (existing == null) {
      _stored[chapter.mangaId] = Manga(
        id: chapter.mangaId,
        sourceId: chapter.sourceId,
        title: chapter.mangaId,
        chapters: [chapter],
        totalChapters: 1,
        downloadedChapters: chapter.status == DownloadStatus.downloaded ? 1 : 0,
      );
    } else {
      final chapters = existing.chapters.toList();
      final index = chapters.indexWhere((c) => c.id == chapter.id);
      if (index >= 0) {
        chapters[index] = chapter;
      } else {
        chapters.add(chapter);
      }
      final downloadedCount = chapters
          .where((c) => c.status == DownloadStatus.downloaded)
          .length;
      _stored[existing.id] = existing.copyWith(
        chapters: chapters,
        downloadedChapters: downloadedCount,
      );
    }

    _chapterStatuses[chapter.id] = chapter.status;
    _controller.add(_stored.values.toList());
  }

  @override
  Future<Chapter?> getChapter(String chapterId) async {
    for (final manga in _stored.values) {
      final index = manga.chapters.indexWhere((c) => c.id == chapterId);
      if (index != -1) {
        return manga.chapters[index];
      }
    }
    return null;
  }

  @override
  Future<void> markMangaAsDownloaded(String mangaId) async {
    lastMangaMarked = mangaId;
    _mangaStatuses[mangaId] = DownloadStatus.downloaded;
  }

  @override
  Future<void> markChapterAsDownloaded(String chapterId) async {
    lastChapterMarked = chapterId;
    _chapterStatuses[chapterId] = DownloadStatus.downloaded;
  }

  @override
  Future<DownloadStatus?> getMangaDownloadStatus(String mangaId) async {
    return _mangaStatuses[mangaId];
  }

  @override
  Future<DownloadStatus?> getChapterDownloadStatus(String chapterId) async {
    return _chapterStatuses[chapterId];
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

  group('Manga download status use cases', () {
    late _FakeMangaRepository repository;

    setUp(() {
      repository = _FakeMangaRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('WatchDownloadedMangas forwards stream', () async {
      final useCase = WatchDownloadedMangas(repository);
      final items = [
        Manga(id: 'manga-1', sourceId: 'source-1', title: 'Manga 1'),
      ];

      final expectation = expectLater(useCase(), emits(items));

      await repository.saveManga(items.first);

      await expectation;
    });

    test('MarkMangaDownloaded updates repository', () async {
      final useCase = MarkMangaDownloaded(repository);

      await useCase('manga-1');

      expect(repository.lastMangaMarked, equals('manga-1'));
      final status = await repository.getMangaDownloadStatus('manga-1');
      expect(status, equals(DownloadStatus.downloaded));
    });

    test('MarkChapterDownloaded updates repository', () async {
      final useCase = MarkChapterDownloaded(repository);

      await useCase('chapter-1');

      expect(repository.lastChapterMarked, equals('chapter-1'));
      final status = await repository.getChapterDownloadStatus('chapter-1');
      expect(status, equals(DownloadStatus.downloaded));
    });

    test('GetMangaDownloadStatus reflects repository data', () async {
      repository._mangaStatuses['manga-1'] = DownloadStatus.downloading;
      final useCase = GetMangaDownloadStatus(repository);

      final status = await useCase('manga-1');

      expect(status, equals(DownloadStatus.downloading));
    });

    test('GetChapterDownloadStatus reflects repository data', () async {
      repository._chapterStatuses['chapter-1'] = DownloadStatus.failed;
      final useCase = GetChapterDownloadStatus(repository);

      final status = await useCase('chapter-1');

      expect(status, equals(DownloadStatus.failed));
    });
  });
}
