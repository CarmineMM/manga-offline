import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/entities/page_image.dart';

/// Lightweight summary returned by remote catalog sources.
class RemoteMangaSummary {
  const RemoteMangaSummary({
    required this.externalId,
    required this.slug,
    required this.title,
    required this.chapterCount,
    required this.sourceId,
    this.sourceName,
    this.synopsis,
    this.coverUrl,
    this.status,
  });

  /// Identifier provided by the remote API (usually numeric).
  final String externalId;

  /// Slug or permalink identifier for the remote resource.
  final String slug;

  /// Human readable title.
  final String title;

  /// Total chapters reported by the remote API.
  final int chapterCount;

  /// Identifier of the source that produced the summary.
  final String sourceId;

  /// Optional human readable name of the source.
  final String? sourceName;

  /// Optional synopsis or description.
  final String? synopsis;

  /// Remote cover image URL.
  final String? coverUrl;

  /// Optional status description as provided by the remote source.
  final String? status;

  /// Converts the remote summary into the domain [Manga] entity scaffold.
  Manga toDomain({DateTime? lastUpdated}) {
    return Manga(
      id: slug,
      sourceId: sourceId,
      sourceName: sourceName,
      title: title,
      synopsis: synopsis,
      coverImageUrl: coverUrl,
      status: DownloadStatus.notDownloaded,
      totalChapters: chapterCount,
      downloadedChapters: 0,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }
}

/// Lightweight summary returned by remote chapter endpoints.
class RemoteChapterSummary {
  const RemoteChapterSummary({
    required this.externalId,
    required this.mangaSlug,
    required this.name,
    required this.sourceId,
    this.sourceName,
    this.publishedAt,
  });

  /// External identifier provided by the remote API.
  final String externalId;

  /// Slug of the manga this chapter belongs to.
  final String mangaSlug;

  /// Name or label of the chapter (typically numeric).
  final String name;

  /// Identifier of the source producing the chapter.
  final String sourceId;

  /// Optional source name for display.
  final String? sourceName;

  /// Publication timestamp reported by the API.
  final DateTime? publishedAt;

  /// Converts the summary into the domain [Chapter] representation.
  Chapter toDomain({int? indexFallback}) {
    final parsedNumber = int.tryParse(name);
    final number = parsedNumber ?? (indexFallback ?? 0);

    return Chapter(
      id: externalId,
      mangaId: mangaSlug,
      sourceId: sourceId,
      sourceName: sourceName,
      title: 'Capítulo $name',
      number: number,
      releaseDate: publishedAt,
    );
  }
}

/// Remote representation for an individual page image belonging to a chapter.
class RemotePageImage {
  const RemotePageImage({
    required this.externalId,
    required this.chapterId,
    required this.pageNumber,
    required this.imageUrl,
    this.checksum,
  });

  /// Identifier provided by the remote API.
  final String externalId;

  /// Chapter identifier the page belongs to.
  final String chapterId;

  /// Position of the page within the chapter (1-indexed).
  final int pageNumber;

  /// Public URL that can be used to fetch the image while online.
  final String imageUrl;

  /// Optional checksum or hash string for integrity validations.
  final String? checksum;

  /// Maps the remote representation into the [PageImage] domain entity.
  PageImage toDomain() {
    final normalizedId = externalId.isEmpty
        ? '${chapterId}_$pageNumber'
        : externalId;
    return PageImage(
      id: normalizedId,
      chapterId: chapterId,
      pageNumber: pageNumber,
      remoteUrl: imageUrl,
    );
  }
}

/// Contract that all remote catalog data sources must implement.
abstract class CatalogRemoteDataSource {
  /// Identifier that maps to the domain source configuration.
  String get sourceId;

  /// Human readable name to persist alongside the items.
  String get sourceName;

  /// Retrieves all manga summaries for the remote source, handling pagination
  /// internally when required.
  Future<List<RemoteMangaSummary>> fetchAllSeries();

  /// Retrieves all chapter summaries for the manga identified by [mangaSlug].
  Future<List<RemoteChapterSummary>> fetchAllChapters({
    required String mangaSlug,
  });

  /// Retrieves the list of pages that compose a given chapter.
  Future<List<RemotePageImage>> fetchChapterPages({
    required String mangaSlug,
    required String chapterId,
  });
}
