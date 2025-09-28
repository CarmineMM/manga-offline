import 'dart:async';

import 'package:manga_offline/core/utils/source_preferences.dart';
import 'package:manga_offline/data/constants/default_sources.dart';
import 'package:manga_offline/data/datasources/source_local_datasource.dart';
import 'package:manga_offline/data/models/manga_source_model.dart';
import 'package:manga_offline/domain/entities/manga_source.dart';
import 'package:manga_offline/domain/repositories/source_repository.dart';

/// Persistent implementation of [SourceRepository] backed by Isar.
class SourceRepositoryImpl implements SourceRepository {
  /// Creates a repository bound to the local data source and preferences.
  SourceRepositoryImpl({
    required SourceLocalDataSource localDataSource,
    SourcePreferences? legacyPreferences,
    List<MangaSource> seedSources = kDefaultSources,
  }) : _localDataSource = localDataSource,
       _legacyPreferences = legacyPreferences,
       _seedSources = seedSources;

  final SourceLocalDataSource _localDataSource;
  final SourcePreferences? _legacyPreferences;
  final List<MangaSource> _seedSources;

  bool _initialized = false;
  Completer<void>? _initCompleter;

  @override
  Stream<List<MangaSource>> watchSources() async* {
    await _ensureInitialized();
    yield* _localDataSource.watchSources().map(_mapModels);
  }

  @override
  Future<List<MangaSource>> loadSources() async {
    await _ensureInitialized();
    final models = await _localDataSource.getAll();
    return _mapModels(models);
  }

  @override
  Future<void> updateSourceSelection({
    required String sourceId,
    required bool isEnabled,
  }) async {
    await _ensureInitialized();
    final existing = await _localDataSource.getById(sourceId);
    if (existing != null) {
      await _localDataSource.setEnabled(sourceId, isEnabled);
    } else {
      final seed = _seedSources.firstWhere(
        (element) => element.id == sourceId,
        orElse: () => MangaSource(
          id: sourceId,
          name: sourceId,
          baseUrl: sourceId,
          locale: 'es-ES',
        ),
      );
      await _localDataSource.putSource(
        MangaSourceModel.fromEntity(seed.copyWith(isEnabled: isEnabled)),
      );
    }
  }

  @override
  Future<void> markSourceSynced({
    required String sourceId,
    DateTime? timestamp,
  }) async {
    await _ensureInitialized();
    await _localDataSource.setLastSyncedAt(
      sourceId,
      timestamp ?? DateTime.now(),
    );
  }

  @override
  Future<DateTime?> getSourceLastSync(String sourceId) async {
    await _ensureInitialized();
    final model = await _localDataSource.getById(sourceId);
    return model?.lastSyncedAt;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    final pending = _initCompleter;
    if (pending != null) {
      return pending.future;
    }
    final completer = Completer<void>();
    _initCompleter = completer;

    try {
      final hasAny = await _localDataSource.hasAny();
      if (!hasAny && _seedSources.isNotEmpty) {
        final enabledSet =
            _legacyPreferences?.enabledSources() ?? const <String>{};
        final legacySynced = <String, DateTime?>{};
        if (_legacyPreferences != null) {
          for (final source in _seedSources) {
            legacySynced[source.id] = _legacyPreferences.lastSync(source.id);
          }
        }
        final models = _seedSources
            .map(
              (source) => MangaSourceModel.fromEntity(
                source.copyWith(
                  isEnabled: enabledSet.contains(source.id) || source.isEnabled,
                  lastSyncedAt: legacySynced[source.id],
                ),
              ),
            )
            .toList(growable: false);
        await _localDataSource.putSources(models);
      }
      _initialized = true;
      completer.complete();
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      _initCompleter = null;
    }
  }

  List<MangaSource> _mapModels(List<MangaSourceModel> models) {
    final mapped =
        models.map((model) => model.toEntity()).toList(growable: true)..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    return List<MangaSource>.unmodifiable(mapped);
  }
}
