import 'package:manga_offline/domain/entities/manga_source.dart';
import 'package:manga_offline/domain/repositories/source_repository.dart';

/// Retrieves the list of manga sources available in the application.
class GetAvailableSources {
  /// Creates a new [GetAvailableSources] instance.
  const GetAvailableSources(this._repository);

  final SourceRepository _repository;

  /// Executes the use case.
  Future<List<MangaSource>> call() => _repository.loadSources();
}
