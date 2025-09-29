import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/repositories/download_repository.dart';
import 'package:manga_offline/domain/repositories/manga_repository.dart';

/// Removes offline assets for a chapter and refreshes local metadata.
class DeleteDownloadedChapter {
  /// Creates a new [DeleteDownloadedChapter] use case instance.
  const DeleteDownloadedChapter({
    required MangaRepository mangaRepository,
    required DownloadRepository downloadRepository,
  }) : _mangaRepository = mangaRepository,
       _downloadRepository = downloadRepository;

  final MangaRepository _mangaRepository;
  final DownloadRepository _downloadRepository;

  /// Executes the use case.
  Future<void> call(String chapterId) async {
    final chapter = await _mangaRepository.getChapter(chapterId);
    if (chapter == null) {
      return;
    }

    final shouldDeleteFiles =
        chapter.status == DownloadStatus.downloaded ||
        (chapter.localPath?.isNotEmpty ?? false) ||
        chapter.downloadedPages > 0;

    if (shouldDeleteFiles) {
      await _downloadRepository.deleteLocalChapterAssets(
        sourceId: chapter.sourceId,
        mangaId: chapter.mangaId,
        chapterId: chapter.id,
        localPath: chapter.localPath,
      );
    }

    await _mangaRepository.clearChapterDownload(chapter.id);
  }
}
