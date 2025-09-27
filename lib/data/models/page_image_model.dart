import 'package:isar/isar.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/page_image.dart';

part 'page_image_model.g.dart';

/// Isar collection holding image metadata for chapter pages.
@collection
class PageImageModel {
  /// Auto-incrementing local identifier used by Isar.
  Id? id;

  /// External identifier shared with domain layer.
  @Index(unique: true)
  late String referenceId;

  /// Reference to the parent chapter.
  late String chapterReferenceId;

  /// Order of the page within the chapter.
  int pageNumber = 0;

  /// Remote URL for the image asset.
  String? remoteUrl;

  /// Local path to the stored image.
  String? localPath;

  /// Current download lifecycle for the image asset.
  @Enumerated(EnumType.name)
  late DownloadStatus status;

  /// File metadata.
  int? fileSizeBytes;
  DateTime? downloadedAt;

  /// Maps the model to its domain counterpart.
  PageImage toEntity() {
    return PageImage(
      id: referenceId,
      chapterId: chapterReferenceId,
      pageNumber: pageNumber,
      remoteUrl: remoteUrl,
      localPath: localPath,
      status: status,
      fileSizeBytes: fileSizeBytes,
      downloadedAt: downloadedAt,
    );
  }

  /// Creates a model from a domain entity.
  static PageImageModel fromEntity(PageImage image) {
    final model = PageImageModel()
      ..referenceId = image.id
      ..chapterReferenceId = image.chapterId
      ..pageNumber = image.pageNumber
      ..remoteUrl = image.remoteUrl
      ..localPath = image.localPath
      ..status = image.status
      ..fileSizeBytes = image.fileSizeBytes
      ..downloadedAt = image.downloadedAt;
    return model;
  }
}
