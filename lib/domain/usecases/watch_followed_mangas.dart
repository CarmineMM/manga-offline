import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/repositories/manga_repository.dart';

/// Use case that emits the mangas followed by the user.
class WatchFollowedMangas {
  /// Creates a new [WatchFollowedMangas] instance.
  const WatchFollowedMangas(this._repository);

  final MangaRepository _repository;

  /// Streams the current list of followed mangas.
  Stream<List<Manga>> call() => _repository.watchFollowedMangas();
}
