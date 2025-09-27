import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/repositories/manga_repository.dart';

/// Use case that exposes the list of downloaded mangas as a stream.
class WatchDownloadedMangas {
  /// Repository dependency providing access to manga persistence.
  final MangaRepository repository;

  /// Creates a new [WatchDownloadedMangas] use case.
  const WatchDownloadedMangas(this.repository);

  /// Executes the use case and emits library updates.
  Stream<List<Manga>> call() => repository.watchLocalLibrary();
}
