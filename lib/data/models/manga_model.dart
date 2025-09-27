import 'package:isar/isar.dart';
import 'package:manga_offline/domain/entities/manga.dart';

part 'manga_model.g.dart';

/// Data model representing persisted manga metadata in Isar.
@collection
class MangaModel {
  /// Auto-incrementing local identifier used by Isar.
  Id? id;

  /// External identifier shared with the domain layer.
  late String referenceId;

  /// Display title for the manga.
  late String title;

  /// Optional synopsis, persisted for offline views.
  String? synopsis;

  /// Maps this model into the domain entity.
  Manga toEntity() => Manga(
    id: referenceId,
    title: title,
    synopsis: synopsis,
    isDownloaded: true,
  );

  /// Creates a model object from the domain entity representation.
  static MangaModel fromEntity(Manga manga) {
    final model = MangaModel()
      ..referenceId = manga.id
      ..title = manga.title
      ..synopsis = manga.synopsis;
    return model;
  }
}
