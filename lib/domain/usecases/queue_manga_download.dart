import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/repositories/download_repository.dart';

/// Queues an entire manga (all chapters) for download.
class QueueMangaDownload {
  /// Creates a new [QueueMangaDownload] instance.
  const QueueMangaDownload(this._repository);

  final DownloadRepository _repository;

  /// Executes the use case.
  Future<void> call(Manga manga) {
    return _repository.enqueueMangaDownload(manga);
  }
}
