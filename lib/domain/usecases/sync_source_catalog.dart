import 'package:manga_offline/domain/repositories/catalog_repository.dart';

/// Forces a synchronization of the catalog for a selected source.
class SyncSourceCatalog {
  /// Creates a new [SyncSourceCatalog] instance.
  const SyncSourceCatalog(this._repository);

  final CatalogRepository _repository;

  /// Executes the use case.
  Future<void> call({required String sourceId}) {
    return _repository.syncCatalog(sourceId: sourceId);
  }
}
