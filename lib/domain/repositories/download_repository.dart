import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_task.dart';
import 'package:manga_offline/domain/entities/manga.dart';

/// Contract abstracting the download queue orchestration.
abstract interface class DownloadRepository {
  /// Adds a new chapter download request to the queue.
  Future<void> enqueueChapterDownload(Chapter chapter);

  /// Adds a new manga download request (all chapters) to the queue.
  Future<void> enqueueMangaDownload(Manga manga);

  /// Watches the download queue, emitting updates as tasks progress.
  Stream<List<DownloadTask>> watchDownloadQueue();

  /// Lists local image file paths for a downloaded chapter. Returns empty if
  /// the chapter directory is missing or no files found.
  Future<List<String>> listLocalChapterPages({
    required String sourceId,
    required String mangaId,
    required String chapterId,
  });

  /// Deletes the local directory (and any assets) associated with a chapter
  /// download.
  Future<void> deleteLocalChapterAssets({
    required String sourceId,
    required String mangaId,
    required String chapterId,
    String? localPath,
  });
}
