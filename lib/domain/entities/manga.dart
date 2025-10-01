import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';

/// Core domain entity representing a manga stored locally or available offline.
class Manga {
  /// Unique identifier across sources. May map to a slug or internal UUID.
  final String id;

  /// Identifier of the source responsible for providing the manga data.
  final String sourceId;

  /// Human readable name of the source.
  final String? sourceName;

  /// Display title for the manga.
  final String title;

  /// Optional short description.
  final String? synopsis;

  /// Remote cover image reference.
  final String? coverImageUrl;

  /// Local cover image path, if the asset is cached on disk.
  final String? coverImagePath;

  /// Tracks the current download lifecycle for the whole manga.
  final DownloadStatus status;

  /// Total number of chapters detected for the manga.
  final int totalChapters;

  /// Number of chapters that are fully downloaded and available offline.
  final int downloadedChapters;

  /// Number of chapters where the user has recorded reading progress.
  final int readChapters;

  /// Timestamp of the last metadata update.
  final DateTime? lastUpdated;

  /// Flag to determine if the user marked the manga as favourite.
  final bool isFavorite;

  /// Flag indicating whether the user is following this manga to track updates.
  final bool isFollowed;

  /// Chapters already fetched for the manga (may be partial data).
  final List<Chapter> chapters;

  /// Creates a new immutable [Manga] entity instance.
  const Manga({
    required this.id,
    required this.sourceId,
    this.sourceName,
    required this.title,
    this.synopsis,
    this.coverImageUrl,
    this.coverImagePath,
    this.status = DownloadStatus.notDownloaded,
    this.totalChapters = 0,
    this.downloadedChapters = 0,
    this.readChapters = 0,
    this.lastUpdated,
    this.isFavorite = false,
    this.isFollowed = false,
    this.chapters = const [],
  });

  /// Convenience copy method to derive new variations while keeping immutability.
  Manga copyWith({
    String? id,
    String? sourceId,
    String? sourceName,
    String? title,
    String? synopsis,
    String? coverImageUrl,
    String? coverImagePath,
    DownloadStatus? status,
    int? totalChapters,
    int? downloadedChapters,
    int? readChapters,
    DateTime? lastUpdated,
    bool? isFavorite,
    bool? isFollowed,
    List<Chapter>? chapters,
  }) {
    return Manga(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      title: title ?? this.title,
      synopsis: synopsis ?? this.synopsis,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      status: status ?? this.status,
      totalChapters: totalChapters ?? this.totalChapters,
      downloadedChapters: downloadedChapters ?? this.downloadedChapters,
      readChapters: readChapters ?? this.readChapters,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isFavorite: isFavorite ?? this.isFavorite,
      isFollowed: isFollowed ?? this.isFollowed,
      chapters: chapters ?? this.chapters,
    );
  }

  /// Counts the chapters marked as read either by timestamp or stored page.
  int get readChaptersCount {
    if (readChapters > 0) {
      return readChapters;
    }
    var total = 0;
    for (final chapter in chapters) {
      if ((chapter.lastReadPage ?? 0) > 0 || chapter.lastReadAt != null) {
        total += 1;
      }
    }
    return total;
  }

  /// Resolves a non-zero total chapter count using known chapters as fallback.
  int get resolvedTotalChapters {
    if (totalChapters > 0) {
      return totalChapters;
    }
    if (chapters.isNotEmpty) {
      return chapters.length;
    }
    return 0;
  }
}
