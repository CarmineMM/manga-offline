import 'package:manga_offline/domain/repositories/source_repository.dart';

/// Updates the selection state of a given source.
class UpdateSourceSelection {
  /// Creates a new [UpdateSourceSelection] instance.
  const UpdateSourceSelection(this._repository);

  final SourceRepository _repository;

  /// Executes the use case by toggling selection for [sourceId].
  Future<void> call({required String sourceId, required bool isEnabled}) {
    return _repository.updateSourceSelection(
      sourceId: sourceId,
      isEnabled: isEnabled,
    );
  }
}
