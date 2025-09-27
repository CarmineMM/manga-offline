import 'package:manga_offline/data/datasources/manga_local_datasource.dart';
import 'package:manga_offline/data/models/manga_model.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/repositories/manga_repository.dart';

/// Concrete implementation of [MangaRepository] backed by Isar.
class MangaRepositoryImpl implements MangaRepository {
  /// Creates the repository with its required [localDataSource].
  MangaRepositoryImpl({required MangaLocalDataSource localDataSource})
    : _localDataSource = localDataSource;

  final MangaLocalDataSource _localDataSource;

  @override
  Stream<List<Manga>> watchLocalLibrary() {
    return _localDataSource.watchMangas().map(
      (models) => models.map((model) => model.toEntity()).toList(),
    );
  }

  @override
  Future<void> saveManga(Manga manga) {
    final model = MangaModel.fromEntity(manga);
    return _localDataSource.putManga(model);
  }
}
