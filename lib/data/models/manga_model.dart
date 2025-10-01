import 'package:isar/isar.dart';
import 'package:manga_offline/data/models/chapter_model.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';

part 'manga_model.g.dart';

/// Data model representing persisted manga metadata in Isar.
@collection
class MangaModel {
  /// Auto-incrementing local identifier used by Isar.
  Id? id;

  /// External identifier shared with the domain layer.
  @Index(unique: true)
  late String referenceId;

  /// Identifier for the source providing the manga data.
  late String sourceId;

  /// Human readable name of the source.
  String? sourceName;

  /// Display title for the manga.
  late String title;

  /// Optional synopsis, persisted for offline views.
  String? synopsis;

  /// Remote cover image reference.
  String? coverImageUrl;

  /// Local cover image path when cached.
  String? coverImagePath;

  /// Tracks the current download lifecycle for the manga.
  @Enumerated(EnumType.name)
  late DownloadStatus status;

  /// Total chapters detected for the manga.
  int totalChapters = 0;

  /// Number of chapters already downloaded.
  int downloadedChapters = 0;

  /// Number of chapters with recorded reading progress.
  int readChapters = 0;

  /// Timestamp of the last metadata update.
  DateTime? lastUpdated;

  /// Marks if the user favourited the manga.
  bool isFavorite = false;

  /// Marks if the user is actively following the manga.
  bool isFollowed = false;

  /// Chapter references tied to this manga.
  List<String> chapterIds = [];

  /// Maps this model into the domain entity.
  Manga toEntity({List<ChapterModel> chapters = const <ChapterModel>[]}) =>
      Manga(
        id: referenceId,
        sourceId: sourceId,
        sourceName: sourceName,
        title: title,
        synopsis: synopsis,
        coverImageUrl: coverImageUrl,
        coverImagePath: coverImagePath,
        status: status,
        totalChapters: totalChapters,
        downloadedChapters: downloadedChapters,
        readChapters: readChapters,
        lastUpdated: lastUpdated,
        isFavorite: isFavorite,
        isFollowed: isFollowed,
        chapters: chapters.map((chapter) => chapter.toEntity()).toList(),
      );

  /// Creates a model object from the domain entity representation.
  static MangaModel fromEntity(Manga manga) {
    final model = MangaModel()
      ..referenceId = manga.id
      ..sourceId = manga.sourceId
      ..sourceName = manga.sourceName
      ..title = manga.title
      ..synopsis = manga.synopsis
      ..coverImageUrl = manga.coverImageUrl
      ..coverImagePath = manga.coverImagePath
      ..status = manga.status
      ..totalChapters = manga.totalChapters
      ..downloadedChapters = manga.downloadedChapters
      ..readChapters = manga.readChapters
      ..lastUpdated = manga.lastUpdated
      ..isFavorite = manga.isFavorite
      ..isFollowed = manga.isFollowed
      ..chapterIds = manga.chapters.map((chapter) => chapter.id).toList();
    return model;
  }
}
