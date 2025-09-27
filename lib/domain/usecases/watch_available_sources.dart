import 'package:manga_offline/domain/entities/manga_source.dart';
import 'package:manga_offline/domain/repositories/source_repository.dart';

/// Provides a stream of the currently available and selected sources.
class WatchAvailableSources {
  /// Creates a new [WatchAvailableSources] instance.
  const WatchAvailableSources(this._repository);

  final SourceRepository _repository;

  /// Executes the use case.
  Stream<List<MangaSource>> call() => _repository.watchSources();
}
