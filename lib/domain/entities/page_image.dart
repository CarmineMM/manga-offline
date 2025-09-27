import 'package:manga_offline/domain/entities/download_status.dart';

/// Domain entity describing a page image within a chapter.
class PageImage {
  /// Unique identifier for the image across sources.
  final String id;

  /// Identifier of the chapter the image belongs to.
  final String chapterId;

  /// Page order within the chapter, starting at 1.
  final int pageNumber;

  /// Remote URL to fetch the image when online.
  final String? remoteUrl;

  /// Local path to the cached image on disk.
  final String? localPath;

  /// Download lifecycle state for the image asset.
  final DownloadStatus status;

  /// File size in bytes once downloaded.
  final int? fileSizeBytes;

  /// Timestamp of when the file was stored locally.
  final DateTime? downloadedAt;

  /// Creates a new immutable [PageImage] instance.
  const PageImage({
    required this.id,
    required this.chapterId,
    required this.pageNumber,
    this.remoteUrl,
    this.localPath,
    this.status = DownloadStatus.notDownloaded,
    this.fileSizeBytes,
    this.downloadedAt,
  });

  /// Returns a copy with selected overrides applied.
  PageImage copyWith({
    String? id,
    String? chapterId,
    int? pageNumber,
    String? remoteUrl,
    String? localPath,
    DownloadStatus? status,
    int? fileSizeBytes,
    DateTime? downloadedAt,
  }) {
    return PageImage(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      pageNumber: pageNumber ?? this.pageNumber,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      localPath: localPath ?? this.localPath,
      status: status ?? this.status,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      downloadedAt: downloadedAt ?? this.downloadedAt,
    );
  }
}
