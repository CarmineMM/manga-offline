import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/repositories/download_repository.dart';

/// Queues an individual chapter for download.
class QueueChapterDownload {
  /// Creates a new [QueueChapterDownload] instance.
  const QueueChapterDownload(this._repository);

  final DownloadRepository _repository;

  /// Executes the use case.
  Future<void> call(Chapter chapter) {
    return _repository.enqueueChapterDownload(chapter);
  }
}
