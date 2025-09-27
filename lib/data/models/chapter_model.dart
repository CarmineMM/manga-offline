import 'package:isar/isar.dart';
import 'package:manga_offline/data/models/page_image_model.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';

part 'chapter_model.g.dart';

/// Isar collection that persists chapter metadata and download states.
@collection
class ChapterModel {
  /// Auto-incrementing local identifier used by Isar.
  Id? id;

  /// External identifier shared with domain layer.
  @Index(unique: true)
  late String referenceId;

  /// Reference to the parent manga.
  late String mangaReferenceId;

  /// Title of the chapter.
  String? title;

  /// Numeric order of the chapter within the manga.
  int number = 0;

  /// Remote URL for fetching the chapter contents.
  String? remoteUrl;

  /// Local storage path for the chapter contents.
  String? localPath;

  /// Download lifecycle state for the chapter.
  @Enumerated(EnumType.name)
  late DownloadStatus status;

  /// Total and downloaded page counts.
  int totalPages = 0;
  int downloadedPages = 0;

  /// Metadata and reading progress.
  DateTime? releaseDate;
  DateTime? lastReadAt;
  int? lastReadPage;

  /// References to persisted page images.
  List<String> pageIds = [];

  /// Maps the model to the domain entity representation.
  Chapter toEntity({List<PageImageModel> pages = const <PageImageModel>[]}) {
    return Chapter(
      id: referenceId,
      mangaId: mangaReferenceId,
      title: title ?? 'Capítulo $number',
      number: number,
      remoteUrl: remoteUrl,
      localPath: localPath,
      status: status,
      totalPages: totalPages,
      downloadedPages: downloadedPages,
      releaseDate: releaseDate,
      lastReadAt: lastReadAt,
      lastReadPage: lastReadPage,
      pages: pages.map((image) => image.toEntity()).toList(),
    );
  }

  /// Creates a model object from a domain entity.
  static ChapterModel fromEntity(Chapter chapter) {
    final model = ChapterModel()
      ..referenceId = chapter.id
      ..mangaReferenceId = chapter.mangaId
      ..title = chapter.title
      ..number = chapter.number
      ..remoteUrl = chapter.remoteUrl
      ..localPath = chapter.localPath
      ..status = chapter.status
      ..totalPages = chapter.totalPages
      ..downloadedPages = chapter.downloadedPages
      ..releaseDate = chapter.releaseDate
      ..lastReadAt = chapter.lastReadAt
      ..lastReadPage = chapter.lastReadPage
      ..pageIds = chapter.pages.map((page) => page.id).toList();
    return model;
  }
}
