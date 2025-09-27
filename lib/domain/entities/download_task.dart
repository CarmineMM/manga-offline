import 'package:manga_offline/domain/entities/download_status.dart';

/// Indicates the type of content the download task targets.
enum DownloadTargetType { manga, chapter }

/// Represents a queued download requested by the user.
class DownloadTask {
  /// Unique identifier for the download task.
  final String id;

  /// Identifier of the origin source responsible for serving assets.
  final String sourceId;

  /// Optional source display name to present in the UI.
  final String? sourceName;

  /// Type of content to download.
  final DownloadTargetType targetType;

  /// Identifier of the primary target (manga id or chapter id).
  final String targetId;

  /// Identifier of the parent manga when downloading a chapter.
  final String? mangaId;

  /// Current status of the download lifecycle.
  final DownloadStatus status;

  /// Progress between 0 and 1, if known.
  final double progress;

  /// Time when the task was created.
  final DateTime createdAt;

  /// Time when the task completed successfully.
  final DateTime? completedAt;

  /// Creates a new immutable [DownloadTask].
  const DownloadTask({
    required this.id,
    required this.sourceId,
    required this.targetType,
    required this.targetId,
    this.sourceName,
    this.mangaId,
    this.status = DownloadStatus.queued,
    this.progress = 0,
    required this.createdAt,
    this.completedAt,
  }) : assert(
         progress >= 0 && progress <= 1,
         'progress must be between 0 and 1',
       );

  /// Returns a copy of the task with selective overrides applied.
  DownloadTask copyWith({
    String? id,
    String? sourceId,
    String? sourceName,
    DownloadTargetType? targetType,
    String? targetId,
    String? mangaId,
    DownloadStatus? status,
    double? progress,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      mangaId: mangaId ?? this.mangaId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
