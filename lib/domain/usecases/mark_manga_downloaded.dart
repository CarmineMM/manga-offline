import 'package:manga_offline/domain/repositories/manga_repository.dart';

/// Marks a manga as fully downloaded.
class MarkMangaDownloaded {
  /// Creates a new [MarkMangaDownloaded] use case.
  const MarkMangaDownloaded(this._repository);

  final MangaRepository _repository;

  /// Executes the use case.
  Future<void> call(String mangaId) {
    return _repository.markMangaAsDownloaded(mangaId);
  }
}
