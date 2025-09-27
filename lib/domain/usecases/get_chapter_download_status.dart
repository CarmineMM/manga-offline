import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/repositories/manga_repository.dart';

/// Retrieves the download status of a stored chapter, if available.
class GetChapterDownloadStatus {
  /// Creates a new [GetChapterDownloadStatus] use case.
  const GetChapterDownloadStatus(this._repository);

  final MangaRepository _repository;

  /// Executes the use case.
  Future<DownloadStatus?> call(String chapterId) {
    return _repository.getChapterDownloadStatus(chapterId);
  }
}
