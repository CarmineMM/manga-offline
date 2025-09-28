import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';

/// Contract for retrieving and managing manga entities across the app.
abstract interface class MangaRepository {
  /// Streams the locally stored mangas, keeping presentation layer reactive.
  Stream<List<Manga>> watchLocalLibrary();

  /// Persists downloaded manga metadata locally.
  Future<void> saveManga(Manga manga);

  /// Retrieves a manga by its identifier, if stored in the local cache.
  Future<Manga?> getManga(String mangaId);

  /// Persists the provided [chapter], ensuring metadata and related pages
  /// stay in sync with the parent manga record.
  Future<void> saveChapter(Chapter chapter);

  /// Retrieves a chapter by its [chapterId], if stored locally.
  Future<Chapter?> getChapter(String chapterId);

  /// Updates the download status of the given manga to [DownloadStatus.downloaded].
  Future<void> markMangaAsDownloaded(String mangaId);

  /// Updates the download status of the given chapter to [DownloadStatus.downloaded]
  /// and refreshes the parent manga counters accordingly.
  Future<void> markChapterAsDownloaded(String chapterId);

  /// Returns the current download status for the specified manga, if stored.
  Future<DownloadStatus?> getMangaDownloadStatus(String mangaId);

  /// Returns the current download status for the specified chapter, if stored.
  Future<DownloadStatus?> getChapterDownloadStatus(String chapterId);

  /// Updates persisted cover metadata for the given manga.
  Future<void> updateMangaCover({
    required String mangaId,
    String? coverImagePath,
  });
}
