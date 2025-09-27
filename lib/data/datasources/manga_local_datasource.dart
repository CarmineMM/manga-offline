import 'dart:async';

import 'package:isar/isar.dart';
import 'package:manga_offline/data/models/chapter_model.dart';
import 'package:manga_offline/data/models/manga_model.dart';
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

  /// Persists manga metadata in the local database, optionally replacing
  /// associated chapters in a single transaction.
  Future<void> putManga(
    MangaModel model, {
    List<ChapterModel> chapters = const <ChapterModel>[],
    bool replaceChapters = false,
  }) async {
    model.id ??= _hashString(model.referenceId);
    for (final chapter in chapters) {
      chapter.id ??= _chapterId(chapter.referenceId, chapter.sourceId);
    }

    await isar.writeTxn(() async {
      if (replaceChapters) {
        await _deleteChaptersForManga(model.referenceId);
      }

      await _mangaCollection.put(model);

      if (chapters.isNotEmpty) {
        await _chapterCollection.putAll(chapters);
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

  /// Watches the collection for changes and emits the current list of mangas.
  Stream<List<MangaModel>> watchMangas() {
    late StreamSubscription<void> subscription;
    final controller = StreamController<List<MangaModel>>.broadcast();

    Future<void> emitSnapshot() async {
      final mangas = await getAllMangas();
      controller.add(mangas);
    }

    void start() {
      subscription = _mangaCollection.watchLazy(fireImmediately: false).listen((
        _,
      ) {
        emitSnapshot();
      });
      emitSnapshot();
    }

    controller.onListen = start;
    controller.onCancel = () async {
      await subscription.cancel();
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

  Future<void> _deleteChaptersForManga(String referenceId) async {
    final query = _chapterCollection.buildQuery<ChapterModel>(
      filter: FilterCondition.equalTo(
        property: r'mangaReferenceId',
        value: referenceId,
      ),
    );
    await query.deleteAll();
  }

  int _chapterId(String referenceId, String sourceId) {
    return _hashString('$sourceId::$referenceId');
  }

  int _hashString(String value) => value.hashCode & 0x7fffffffffffffff;
}
