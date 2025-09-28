import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:manga_offline/core/utils/source_preferences.dart';
import 'package:manga_offline/data/constants/default_sources.dart';
import 'package:manga_offline/data/datasources/source_local_datasource.dart';
import 'package:manga_offline/data/models/manga_source_model.dart';
import 'package:manga_offline/data/repositories/source_repository_impl.dart';
import 'package:manga_offline/domain/repositories/source_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSourceLocalDataSource localDataSource;
  late SourceRepository repository;
  late SourcePreferences sourcePreferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    localDataSource = FakeSourceLocalDataSource();
    sourcePreferences = await SourcePreferences.create();
    repository = SourceRepositoryImpl(
      localDataSource: localDataSource,
      legacyPreferences: sourcePreferences,
    );
  });

  tearDown(() async {
    await localDataSource.dispose();
  });

  test('loadSources seeds default entries', () async {
    final sources = await repository.loadSources();

    expect(sources, isNotEmpty);
    expect(sources.length, kDefaultSources.length);

    final stored = await localDataSource.getAll();
    expect(stored.length, kDefaultSources.length);
  });

  test('updateSourceSelection persists between repository instances', () async {
    final initial = await repository.loadSources();
    expect(initial.any((source) => source.isEnabled), isFalse);

    await repository.updateSourceSelection(
      sourceId: kDefaultSources.first.id,
      isEnabled: true,
    );

    // Simulate application restart with fresh preferences but persisted store.
    final persistedStore = localDataSource.fork();
    await localDataSource.dispose();
    localDataSource = persistedStore;

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final newPreferences = await SourcePreferences.create();
    repository = SourceRepositoryImpl(
      localDataSource: localDataSource,
      legacyPreferences: newPreferences,
    );

    final reloaded = await repository.loadSources();
    final target = reloaded.firstWhere(
      (source) => source.id == kDefaultSources.first.id,
    );
    expect(target.isEnabled, isTrue);
  });
}

class FakeSourceLocalDataSource implements SourceLocalDataSource {
  FakeSourceLocalDataSource([Map<String, MangaSourceModel>? seed])
    : _storage = <String, MangaSourceModel>{},
      _controller = StreamController<List<MangaSourceModel>>.broadcast() {
    if (seed != null && seed.isNotEmpty) {
      for (final entry in seed.entries) {
        _storage[entry.key] = _cloneStatic(entry.value);
      }
    }
    _controller.onListen = () => _emit();
  }

  final Map<String, MangaSourceModel> _storage;
  final StreamController<List<MangaSourceModel>> _controller;

  FakeSourceLocalDataSource fork() =>
      FakeSourceLocalDataSource(<String, MangaSourceModel>{
        for (final entry in _storage.entries)
          entry.key: _cloneStatic(entry.value),
      });

  @override
  Isar get isar => throw UnimplementedError('Not implemented in fake');

  @override
  Future<bool> hasAny() async => _storage.isNotEmpty;

  @override
  Future<List<MangaSourceModel>> getAll() async {
    return _storage.values.map(_clone).toList(growable: false);
  }

  @override
  Future<void> putSources(List<MangaSourceModel> sources) async {
    for (final source in sources) {
      _storage[source.referenceId] = _clone(source);
    }
    _emit();
  }

  @override
  Future<void> putSource(MangaSourceModel source) async {
    _storage[source.referenceId] = _clone(source);
    _emit();
  }

  @override
  Future<void> setEnabled(String sourceId, bool isEnabled) async {
    final existing = _storage[sourceId];
    if (existing == null) {
      return;
    }
    existing.isEnabled = isEnabled;
    _storage[sourceId] = _clone(existing);
    _emit();
  }

  @override
  Future<void> applyEnabledFlags(Set<String> enabledIds) async {
    var changed = false;
    for (final entry in _storage.entries) {
      final shouldEnable = enabledIds.contains(entry.key);
      if (entry.value.isEnabled != shouldEnable) {
        entry.value.isEnabled = shouldEnable;
        changed = true;
      }
    }
    if (changed) {
      _emit();
    }
  }

  @override
  Stream<List<MangaSourceModel>> watchSources() => _controller.stream;

  @override
  Future<MangaSourceModel?> getById(String sourceId) async {
    final existing = _storage[sourceId];
    return existing == null ? null : _clone(existing);
  }

  @override
  Future<void> setLastSyncedAt(String sourceId, DateTime? timestamp) async {
    final existing = _storage[sourceId];
    if (existing == null) {
      return;
    }
    existing.lastSyncedAt = timestamp;
    _storage[sourceId] = _clone(existing);
    _emit();
  }

  Future<void> dispose() async {
    await _controller.close();
  }

  void _emit() {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(_storage.values.map(_clone).toList(growable: false));
  }

  MangaSourceModel _clone(MangaSourceModel source) {
    return _cloneStatic(source);
  }

  static MangaSourceModel _cloneStatic(MangaSourceModel source) {
    return MangaSourceModel()
      ..id = source.id
      ..referenceId = source.referenceId
      ..name = source.name
      ..description = source.description
      ..baseUrl = source.baseUrl
      ..locale = source.locale
      ..iconUrl = source.iconUrl
      ..isEnabled = source.isEnabled
      ..capabilities = List<String>.from(source.capabilities)
      ..lastSyncedAt = source.lastSyncedAt;
  }
}
