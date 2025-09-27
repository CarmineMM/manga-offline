import 'package:manga_offline/domain/repositories/manga_repository.dart';

/// Marks a chapter as downloaded and refreshes parent manga information.
class MarkChapterDownloaded {
  /// Creates a new [MarkChapterDownloaded] use case.
  const MarkChapterDownloaded(this._repository);

  final MangaRepository _repository;

  /// Executes the use case.
  Future<void> call(String chapterId) {
    return _repository.markChapterAsDownloaded(chapterId);
  }
}
