import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/entities/page_image.dart';

/// Contract providing access to catalog data retrieved from remote sources.
abstract interface class CatalogRepository {
  /// Triggers a full synchronization of the catalog for the given [sourceId].
  Future<void> syncCatalog({required String sourceId});

  /// Retrieves the current catalog snapshot for the given [sourceId].
  Future<List<Manga>> fetchCatalog({required String sourceId});

  /// Fetches detailed information for a specific manga from a source.
  Future<Manga> fetchMangaDetail({
    required String sourceId,
    required String mangaId,
  });

  /// Fetches the list of page images for a specific chapter.
  Future<List<PageImage>> fetchChapterPages({
    required String sourceId,
    required String mangaId,
    required String chapterId,
  });
}
