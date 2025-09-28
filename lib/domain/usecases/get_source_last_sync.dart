import 'package:manga_offline/domain/repositories/source_repository.dart';

/// Retrieves the last synchronization timestamp for a source.
class GetSourceLastSync {
  /// Creates a new [GetSourceLastSync] use case.
  const GetSourceLastSync(this._repository);

  final SourceRepository _repository;

  /// Executes the use case.
  Future<DateTime?> call(String sourceId) {
    return _repository.getSourceLastSync(sourceId);
  }
}
