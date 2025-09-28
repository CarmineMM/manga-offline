import 'package:manga_offline/domain/repositories/source_repository.dart';

/// Persists the last synchronization timestamp for a given source.
class MarkSourceSynced {
  /// Creates a new [MarkSourceSynced] use case.
  const MarkSourceSynced(this._repository);

  final SourceRepository _repository;

  /// Executes the use case.
  Future<void> call({required String sourceId, DateTime? timestamp}) {
    return _repository.markSourceSynced(
      sourceId: sourceId,
      timestamp: timestamp,
    );
  }
}
