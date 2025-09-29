import 'dart:async';
import 'dart:math' as math;

import 'package:isar/isar.dart';
import 'package:manga_offline/data/models/chapter_model.dart';
import 'package:manga_offline/data/models/manga_model.dart';
import 'package:manga_offline/data/models/page_image_model.dart';
import 'package:manga_offline/domain/entities/download_status.dart';

/// Local data source responsible for persisting mangas in Isar.
class MangaLocalDataSource {
  /// Creates a new instance wired to the provided [isar] database.
  MangaLocalDataSource(this.isar);

  /// Shared database instance across the local data source operations.
  final Isar isar;

  IsarCollection<MangaModel> get _mangaCollection =>
      isar.collection<MangaModel>();

  IsarCollection<ChapterModel> get _chapterCollection =>
      isar.collection<ChapterModel>();

  IsarCollection<PageImageModel> get _pageCollection =>
      isar.collection<PageImageModel>();

  /// Persists manga metadata in the local database, optionally replacing
  /// associated chapters in a single transaction.
  Future<void> putManga(
    MangaModel model, {
    List<ChapterModel> chapters = const <ChapterModel>[],
    List<PageImageModel> pages = const <PageImageModel>[],
    bool replaceChapters = false,
  }) async {
    model.id ??= _hashString(model.referenceId);
    for (final chapter in chapters) {
      chapter.id ??= _chapterId(chapter.referenceId, chapter.sourceId);
    }

    for (final page in pages) {
      page.id ??= _pageId(page.referenceId);
    }

    final existingChapters = replaceChapters
        ? await getChaptersForManga(model.referenceId)
        : const <ChapterModel>[];

    await isar.writeTxn(() async {
      if (replaceChapters) {
        for (final chapter in existingChapters) {
          await _deletePagesForChapter(chapter.referenceId);
        }
        await _deleteChaptersForManga(model.referenceId);
      }

      await _mangaCollection.put(model);

      if (chapters.isNotEmpty) {
        await _chapterCollection.putAll(chapters);
      }

      if (pages.isNotEmpty) {
        await _pageCollection.putAll(pages);
      }
    });
  }

  /// Retrieves a manga by its external [referenceId].
  Future<MangaModel?> getManga(String referenceId) async {
    final query = _mangaCollection.buildQuery<MangaModel>(
      filter: FilterCondition.equalTo(
        property: r'referenceId',
        value: referenceId,
      ),
      limit: 1,
    );
    return query.findFirst();
  }

  /// Fetches every manga stored for the given [sourceId].
  Future<List<MangaModel>> getMangasBySource(String sourceId) {
    final query = _mangaCollection.buildQuery<MangaModel>(
      filter: FilterCondition.equalTo(property: r'sourceId', value: sourceId),
    );
    return query.findAll();
  }

  /// Returns every stored manga regardless of the source.
  Future<List<MangaModel>> getAllMangas() {
    final query = _mangaCollection.buildQuery<MangaModel>(
      whereClauses: const [IdWhereClause.any()],
    );
    return query.findAll();
  }

  /// Retrieves a chapter by its external [referenceId].
  Future<ChapterModel?> getChapter(String referenceId) {
    final query = _chapterCollection.buildQuery<ChapterModel>(
      filter: FilterCondition.equalTo(
        property: r'referenceId',
        value: referenceId,
      ),
      limit: 1,
    );
    return query.findFirst();
  }

  /// Loads the stored chapters belonging to the [mangaReferenceId].
  Future<List<ChapterModel>> getChaptersForManga(String mangaReferenceId) {
    final query = _chapterCollection.buildQuery<ChapterModel>(
      filter: FilterCondition.equalTo(
        property: r'mangaReferenceId',
        value: mangaReferenceId,
      ),
    );
    return query.findAll();
  }

  /// Retrieves the page images associated with a chapter.
  Future<List<PageImageModel>> getPagesForChapter(String chapterReferenceId) {
    final query = _pageCollection.buildQuery<PageImageModel>(
      filter: FilterCondition.equalTo(
        property: r'chapterReferenceId',
        value: chapterReferenceId,
      ),
    );
    return query.findAll();
  }

  /// Persists a single chapter and its related pages.
  Future<void> putChapter(
    ChapterModel model, {
    List<PageImageModel> pages = const <PageImageModel>[],
  }) async {
    model.id ??= _chapterId(model.referenceId, model.sourceId);
    for (final page in pages) {
      page.id ??= _pageId(page.referenceId);
    }

    await isar.writeTxn(() async {
      await _chapterCollection.put(model);
      if (pages.isNotEmpty) {
        await _deletePagesForChapter(model.referenceId);
        await _pageCollection.putAll(pages);
      }
      await _refreshMangaDownloadCounters(model.mangaReferenceId);
    });
  }

  /// Watches the collection for changes and emits the current list of mangas.
  Stream<List<MangaModel>> watchMangas() {
    StreamSubscription<void>? mangaSubscription;
    StreamSubscription<void>? chapterSubscription;
    var listenerCount = 0;
    final controller = StreamController<List<MangaModel>>.broadcast();

    Future<void> emitSnapshot() async {
      if (controller.isClosed) {
        return;
      }
      try {
        final mangas = await getAllMangas();
        if (!controller.isClosed) {
          controller.add(List<MangaModel>.unmodifiable(mangas));
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    }

    void ensureSubscriptions() {
      if (mangaSubscription != null && chapterSubscription != null) {
        return;
      }
      mangaSubscription ??= _mangaCollection
          .watchLazy(fireImmediately: true)
          .listen((_) => emitSnapshot(), onError: controller.addError);
      chapterSubscription ??= _chapterCollection
          .watchLazy(fireImmediately: true)
          .listen((_) => emitSnapshot(), onError: controller.addError);
      unawaited(emitSnapshot());
    }

    controller.onListen = () {
      listenerCount++;
      ensureSubscriptions();
    };

    controller.onCancel = () async {
      listenerCount = math.max(0, listenerCount - 1);
      if (listenerCount > 0) {
        return;
      }
      await mangaSubscription?.cancel();
      await chapterSubscription?.cancel();
      mangaSubscription = null;
      chapterSubscription = null;
    };

    return controller.stream;
  }

  /// Marks the given manga as downloaded and updates all persisted chapters.
  Future<void> markMangaAsDownloaded(String referenceId) async {
    final timestamp = DateTime.now();
    await isar.writeTxn(() async {
      final manga = await getManga(referenceId);
      if (manga == null) {
        return;
      }

      final chapters = await getChaptersForManga(referenceId);
      if (chapters.isNotEmpty) {
        for (final chapter in chapters) {
          chapter.status = DownloadStatus.downloaded;
          if (chapter.totalPages > 0) {
            chapter.downloadedPages = chapter.totalPages;
          }
          final pages = await getPagesForChapter(chapter.referenceId);
          if (pages.isNotEmpty) {
            for (final page in pages) {
              page.status = DownloadStatus.downloaded;
              page.downloadedAt ??= timestamp;
            }
            await _pageCollection.putAll(pages);
          }
        }
        await _chapterCollection.putAll(chapters);
      }

      manga.status = DownloadStatus.downloaded;
      manga.downloadedChapters = manga.totalChapters > 0
          ? manga.totalChapters
          : (chapters.isNotEmpty ? chapters.length : manga.downloadedChapters);
      manga.lastUpdated = timestamp;
      await _mangaCollection.put(manga);
    });
  }

  /// Marks the given chapter as downloaded and refreshes parent metadata.
  Future<void> markChapterAsDownloaded(String referenceId) async {
    final timestamp = DateTime.now();
    await isar.writeTxn(() async {
      final chapter = await getChapter(referenceId);
      if (chapter == null) {
        return;
      }

      chapter.status = DownloadStatus.downloaded;
      if (chapter.totalPages > 0) {
        chapter.downloadedPages = chapter.totalPages;
      }
      await _chapterCollection.put(chapter);

      final pages = await getPagesForChapter(chapter.referenceId);
      if (pages.isNotEmpty) {
        for (final page in pages) {
          page.status = DownloadStatus.downloaded;
          page.downloadedAt ??= timestamp;
        }
        await _pageCollection.putAll(pages);
      }

      final manga = await getManga(chapter.mangaReferenceId);
      if (manga == null) {
        return;
      }

      final chapters = await getChaptersForManga(chapter.mangaReferenceId);
      final downloadedChapters = chapters
          .where((element) => element.status == DownloadStatus.downloaded)
          .length;

      manga.downloadedChapters = downloadedChapters;
      if (manga.totalChapters > 0 &&
          downloadedChapters >= manga.totalChapters) {
        manga.status = DownloadStatus.downloaded;
      } else if (downloadedChapters > 0) {
        manga.status = DownloadStatus.downloading;
      }
      manga.lastUpdated = timestamp;
      await _mangaCollection.put(manga);
    });
  }

  /// Returns the download status of a stored manga, if available.
  Future<DownloadStatus?> getMangaDownloadStatus(String referenceId) async {
    final manga = await getManga(referenceId);
    return manga?.status;
  }

  /// Returns the download status of a stored chapter, if available.
  Future<DownloadStatus?> getChapterDownloadStatus(String referenceId) async {
    final chapter = await getChapter(referenceId);
    return chapter?.status;
  }

  /// Updates the stored cover path for a manga.
  Future<void> updateMangaCover({
    required String referenceId,
    String? coverImagePath,
  }) async {
    await isar.writeTxn(() async {
      final manga = await getManga(referenceId);
      if (manga == null) {
        return;
      }
      manga.coverImagePath = coverImagePath;
      manga.lastUpdated = DateTime.now();
      await _mangaCollection.put(manga);
    });
  }

  Future<void> _deleteChaptersForManga(String referenceId) async {
    final query = _chapterCollection.buildQuery<ChapterModel>(
      filter: FilterCondition.equalTo(
        property: r'mangaReferenceId',
        value: referenceId,
      ),
    );
    await query.deleteAll();
  }

  Future<void> _deletePagesForChapter(String chapterReferenceId) async {
    final query = _pageCollection.buildQuery<PageImageModel>(
      filter: FilterCondition.equalTo(
        property: r'chapterReferenceId',
        value: chapterReferenceId,
      ),
    );
    await query.deleteAll();
  }

  Future<void> _refreshMangaDownloadCounters(String mangaReferenceId) async {
    final manga = await getManga(mangaReferenceId);
    if (manga == null) {
      return;
    }

    final chapters = await getChaptersForManga(mangaReferenceId);
    final downloadedChapters = chapters
        .where((chapter) => chapter.status == DownloadStatus.downloaded)
        .length;

    if (downloadedChapters == 0) {
      manga.status = DownloadStatus.notDownloaded;
    } else if (manga.totalChapters > 0 &&
        downloadedChapters >= manga.totalChapters) {
      manga.status = DownloadStatus.downloaded;
    } else {
      manga.status = DownloadStatus.downloading;
    }

    manga.downloadedChapters = downloadedChapters;
    manga.lastUpdated = DateTime.now();
    await _mangaCollection.put(manga);
  }

  int _chapterId(String referenceId, String sourceId) {
    return _hashString('$sourceId::$referenceId');
  }

  int _pageId(String referenceId) => _hashString('page::$referenceId');

  int _hashString(String value) => value.hashCode & 0x7fffffffffffffff;
}
