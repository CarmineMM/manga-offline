import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/repositories/catalog_repository.dart';

/// Fetches the detailed metadata of a manga from a given source.
class FetchMangaDetail {
  /// Creates a new [FetchMangaDetail] instance.
  const FetchMangaDetail(this._repository);

  final CatalogRepository _repository;

  /// Executes the use case.
  Future<Manga> call({
    required String sourceId,
    required String mangaId,
    bool forceRefresh = false,
  }) {
    return _repository.fetchMangaDetail(
      sourceId: sourceId,
      mangaId: mangaId,
      forceRefresh: forceRefresh,
    );
  }
}
