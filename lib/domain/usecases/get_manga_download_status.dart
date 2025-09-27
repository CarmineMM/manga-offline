import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/repositories/manga_repository.dart';

/// Retrieves the download status of a stored manga, if available.
class GetMangaDownloadStatus {
  /// Creates a new [GetMangaDownloadStatus] use case.
  const GetMangaDownloadStatus(this._repository);

  final MangaRepository _repository;

  /// Executes the use case.
  Future<DownloadStatus?> call(String mangaId) {
    return _repository.getMangaDownloadStatus(mangaId);
  }
}
