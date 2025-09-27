import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/page_image.dart';

/// Domain entity describing a manga chapter and its offline status.
class Chapter {
  /// Unique identifier for the chapter across sources.
  final String id;

  /// Identifier of the manga this chapter belongs to.
  final String mangaId;

  /// Display title of the chapter.
  final String title;

  /// Sequential number of the chapter within the manga.
  final int number;

  /// Optional remote location to fetch the chapter content.
  final String? remoteUrl;

  /// Local folder path where the chapter is stored when downloaded.
  final String? localPath;

  /// Current download lifecycle state for the chapter.
  final DownloadStatus status;

  /// Total amount of pages that compose the chapter.
  final int totalPages;

  /// Pages already downloaded and available offline.
  final int downloadedPages;

  /// Timestamp representing the original release date.
  final DateTime? releaseDate;

  /// Timestamp for the last time the user opened the chapter.
  final DateTime? lastReadAt;

  /// The last page read by the user, if any.
  final int? lastReadPage;

  /// Images already known for this chapter.
  final List<PageImage> pages;

  /// Creates a new immutable [Chapter] instance.
  const Chapter({
    required this.id,
    required this.mangaId,
    required this.title,
    required this.number,
    this.remoteUrl,
    this.localPath,
    this.status = DownloadStatus.notDownloaded,
    this.totalPages = 0,
    this.downloadedPages = 0,
    this.releaseDate,
    this.lastReadAt,
    this.lastReadPage,
    this.pages = const [],
  });

  /// Returns a copy with selective overrides.
  Chapter copyWith({
    String? id,
    String? mangaId,
    String? title,
    int? number,
    String? remoteUrl,
    String? localPath,
    DownloadStatus? status,
    int? totalPages,
    int? downloadedPages,
    DateTime? releaseDate,
    DateTime? lastReadAt,
    int? lastReadPage,
    List<PageImage>? pages,
  }) {
    return Chapter(
      id: id ?? this.id,
      mangaId: mangaId ?? this.mangaId,
      title: title ?? this.title,
      number: number ?? this.number,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      localPath: localPath ?? this.localPath,
      status: status ?? this.status,
      totalPages: totalPages ?? this.totalPages,
      downloadedPages: downloadedPages ?? this.downloadedPages,
      releaseDate: releaseDate ?? this.releaseDate,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      lastReadPage: lastReadPage ?? this.lastReadPage,
      pages: pages ?? this.pages,
    );
  }
}
