import 'package:manga_offline/domain/entities/page_image.dart';
import 'package:manga_offline/domain/repositories/catalog_repository.dart';

/// Fetches the remote page listing for a given chapter.
class FetchChapterPages {
  /// Creates a new [FetchChapterPages] use case.
  const FetchChapterPages(this._repository);

  final CatalogRepository _repository;

  /// Executes the use case.
  Future<List<PageImage>> call({
    required String sourceId,
    required String mangaId,
    required String chapterId,
  }) {
    return _repository.fetchChapterPages(
      sourceId: sourceId,
      mangaId: mangaId,
      chapterId: chapterId,
    );
  }
}
