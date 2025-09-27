import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';

/// Core domain entity representing a manga stored locally or available offline.
class Manga {
  /// Unique identifier across sources. May map to a slug or internal UUID.
  final String id;

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

  /// Timestamp of the last metadata update.
  final DateTime? lastUpdated;

  /// Flag to determine if the user marked the manga as favourite.
  final bool isFavorite;

  /// Chapters already fetched for the manga (may be partial data).
  final List<Chapter> chapters;

  /// Creates a new immutable [Manga] entity instance.
  const Manga({
    required this.id,
    required this.title,
    this.synopsis,
    this.coverImageUrl,
    this.coverImagePath,
    this.status = DownloadStatus.notDownloaded,
    this.totalChapters = 0,
    this.downloadedChapters = 0,
    this.lastUpdated,
    this.isFavorite = false,
    this.chapters = const [],
  });

  /// Convenience copy method to derive new variations while keeping immutability.
  Manga copyWith({
    String? id,
    String? title,
    String? synopsis,
    String? coverImageUrl,
    String? coverImagePath,
    DownloadStatus? status,
    int? totalChapters,
    int? downloadedChapters,
    DateTime? lastUpdated,
    bool? isFavorite,
    List<Chapter>? chapters,
  }) {
    return Manga(
      id: id ?? this.id,
      title: title ?? this.title,
      synopsis: synopsis ?? this.synopsis,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      status: status ?? this.status,
      totalChapters: totalChapters ?? this.totalChapters,
      downloadedChapters: downloadedChapters ?? this.downloadedChapters,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isFavorite: isFavorite ?? this.isFavorite,
      chapters: chapters ?? this.chapters,
    );
  }
}
