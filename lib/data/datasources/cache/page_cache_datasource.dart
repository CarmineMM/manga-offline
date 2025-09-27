import 'package:isar/isar.dart';

part 'page_cache_datasource.g.dart';

/// Entity persisted locally representing a single page image metadata.
@collection
class PageEntity {
  Id id = Isar.autoIncrement; // internal PK

  /// Source identifier (e.g. 'olympus'). Indexed for quick lookups by source.
  @Index()
  late String sourceId;

  /// Slug del manga.
  @Index()
  late String mangaSlug;

  /// External chapter id (string for uniformity).
  @Index()
  late String chapterId;

  /// Número de página (1-based).
  @Index()
  late int pageNumber;

  /// URL remota original (para revalidación o redescarga si es necesario).
  late String imageUrl;

  /// Checksum opcional si el backend la aporta.
  String? checksum;

  /// Timestamp de creación para políticas de expiración futuras.
  @Index()
  late DateTime createdAt;
}

/// Simple abstraction for a page cache.
abstract interface class PageCacheDataSource {
  Future<List<PageEntity>> getChapterPages({
    required String sourceId,
    required String mangaSlug,
    required String chapterId,
  });

  Future<void> putChapterPages({
    required String sourceId,
    required String mangaSlug,
    required String chapterId,
    required List<PageEntity> pages,
  });

  Future<void> clearChapterPages({
    required String sourceId,
    required String mangaSlug,
    required String chapterId,
  });
}

class IsarPageCacheDataSource implements PageCacheDataSource {
  IsarPageCacheDataSource(this._isar);

  final Isar _isar;

  @override
  Future<List<PageEntity>> getChapterPages({
    required String sourceId,
    required String mangaSlug,
    required String chapterId,
  }) async {
    return _isar.pageEntitys
        .filter()
        .sourceIdEqualTo(sourceId)
        .mangaSlugEqualTo(mangaSlug)
        .chapterIdEqualTo(chapterId)
        .sortByPageNumber()
        .findAll();
  }

  @override
  Future<void> putChapterPages({
    required String sourceId,
    required String mangaSlug,
    required String chapterId,
    required List<PageEntity> pages,
  }) async {
    if (pages.isEmpty) return;
    // Ensure required metadata present.
    final now = DateTime.now();
    for (final p in pages) {
      p.sourceId = sourceId;
      p.mangaSlug = mangaSlug;
      p.chapterId = chapterId;
      p.createdAt = now;
    }
    await _isar.writeTxn(() async {
      await _isar.pageEntitys.putAll(pages);
    });
  }

  @override
  Future<void> clearChapterPages({
    required String sourceId,
    required String mangaSlug,
    required String chapterId,
  }) async {
    final existing = await _isar.pageEntitys
        .filter()
        .sourceIdEqualTo(sourceId)
        .mangaSlugEqualTo(mangaSlug)
        .chapterIdEqualTo(chapterId)
        .findAll();
    if (existing.isEmpty) return;
    await _isar.writeTxn(() async {
      await _isar.pageEntitys.deleteAll(existing.map((e) => e.id).toList());
    });
  }
}
