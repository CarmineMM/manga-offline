import 'package:manga_offline/data/datasources/catalog_remote_datasource.dart';
import 'package:manga_offline/data/datasources/manga_local_datasource.dart';
import 'package:manga_offline/data/models/manga_model.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/repositories/catalog_repository.dart';

/// Implementation of [CatalogRepository] combining remote sources with Isar
/// persistence to keep the catalog available offline.
class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl({
    required MangaLocalDataSource localDataSource,
    required Map<String, CatalogRemoteDataSource> remoteDataSources,
  }) : _localDataSource = localDataSource,
       _remoteDataSources = remoteDataSources;

  final MangaLocalDataSource _localDataSource;
  final Map<String, CatalogRemoteDataSource> _remoteDataSources;

  CatalogRemoteDataSource _resolveRemote(String sourceId) {
    final remote = _remoteDataSources[sourceId];
    if (remote == null) {
      throw ArgumentError('No remote data source configured for $sourceId');
    }
    return remote;
  }

  @override
  Future<void> syncCatalog({required String sourceId}) async {
    final remote = _resolveRemote(sourceId);
    final summaries = await remote.fetchAllSeries();
    final timestamp = DateTime.now();

    for (final summary in summaries) {
      final manga = summary.toDomain(lastUpdated: timestamp);
      final model = MangaModel.fromEntity(manga);
      await _localDataSource.putManga(model, replaceChapters: false);
    }
  }

  @override
  Future<List<Manga>> fetchCatalog({required String sourceId}) async {
    final models = await _localDataSource.getMangasBySource(sourceId);
    final mangas = <Manga>[];
    for (final model in models) {
      final chapters = await _localDataSource.getChaptersForManga(
        model.referenceId,
      );
      mangas.add(model.toEntity(chapters: chapters));
    }
    return mangas;
  }

  @override
  Future<Manga> fetchMangaDetail({
    required String sourceId,
    required String mangaId,
  }) async {
    final model = await _localDataSource.getManga(mangaId);
    if (model == null) {
      throw StateError('Manga $mangaId not found for source $sourceId');
    }
    final chapters = await _localDataSource.getChaptersForManga(
      model.referenceId,
    );
    return model.toEntity(chapters: chapters);
  }
}
