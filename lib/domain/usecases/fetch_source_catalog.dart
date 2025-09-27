import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/repositories/catalog_repository.dart';

/// Retrieves the catalog snapshot for a given source.
class FetchSourceCatalog {
  /// Creates a new [FetchSourceCatalog] instance.
  const FetchSourceCatalog(this._repository);

  final CatalogRepository _repository;

  /// Executes the use case.
  Future<List<Manga>> call({required String sourceId}) {
    return _repository.fetchCatalog(sourceId: sourceId);
  }
}
