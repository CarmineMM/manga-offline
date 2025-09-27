import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';

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

/// Contract that all remote catalog data sources must implement.
abstract class CatalogRemoteDataSource {
  /// Identifier that maps to the domain source configuration.
  String get sourceId;

  /// Human readable name to persist alongside the items.
  String get sourceName;

  /// Retrieves all manga summaries for the remote source, handling pagination
  /// internally when required.
  Future<List<RemoteMangaSummary>> fetchAllSeries();
}
