import 'package:manga_offline/domain/entities/manga.dart';

/// Contract for retrieving and managing manga entities across the app.
abstract interface class MangaRepository {
  /// Streams the locally stored mangas, keeping presentation layer reactive.
  Stream<List<Manga>> watchLocalLibrary();

  /// Persists downloaded manga metadata locally.
  Future<void> saveManga(Manga manga);
}
