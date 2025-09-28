import 'dart:async';

import 'package:isar/isar.dart';
import 'package:manga_offline/data/models/manga_source_model.dart';

/// Local data source that persists manga sources in Isar.
class SourceLocalDataSource {
  /// Creates a data source bound to the provided [isar] instance.
  SourceLocalDataSource(this.isar);

  /// Shared Isar database reference.
  final Isar isar;

  IsarCollection<MangaSourceModel> get _collection =>
      isar.collection<MangaSourceModel>();

  /// Returns whether at least one source is already persisted.
  Future<bool> hasAny() async {
    return (await _collection.count()) > 0;
  }

  /// Retrieves all persisted sources.
  Future<List<MangaSourceModel>> getAll() async {
    final query = _collection.buildQuery<MangaSourceModel>(
      whereClauses: const [IdWhereClause.any()],
    );
    return query.findAll();
  }

  /// Persists or replaces the provided [sources].
  Future<void> putSources(List<MangaSourceModel> sources) async {
    if (sources.isEmpty) {
      return;
    }
    for (final source in sources) {
      source.id ??= _hashString(source.referenceId);
    }
    await isar.writeTxn(() async {
      await _collection.putAll(sources);
    });
  }

  /// Stores or updates a single [source].
  Future<void> putSource(MangaSourceModel source) async {
    source.id ??= _hashString(source.referenceId);
    await isar.writeTxn(() async {
      await _collection.put(source);
    });
  }

  /// Updates the enable state for a given [sourceId].
  Future<void> setEnabled(String sourceId, bool isEnabled) async {
    final model = await getById(sourceId);
    if (model == null) {
      return;
    }
    model.isEnabled = isEnabled;
    await putSource(model);
  }

  /// Synchronises stored enable flags with the provided [enabledIds].
  Future<void> applyEnabledFlags(Set<String> enabledIds) async {
    final all = await getAll();
    var hasChanges = false;
    for (final source in all) {
      final shouldEnable = enabledIds.contains(source.referenceId);
      if (source.isEnabled != shouldEnable) {
        source.isEnabled = shouldEnable;
        source.id ??= _hashString(source.referenceId);
        hasChanges = true;
      }
    }
    if (!hasChanges) {
      return;
    }
    await isar.writeTxn(() async {
      await _collection.putAll(all);
    });
  }

  /// Watches source changes and emits snapshots.
  Stream<List<MangaSourceModel>> watchSources() {
    late StreamSubscription<void> subscription;
    final controller = StreamController<List<MangaSourceModel>>.broadcast();

    Future<void> emitSnapshot() async {
      final models = await getAll();
      controller.add(models);
    }

    void start() {
      subscription = _collection.watchLazy(fireImmediately: false).listen((_) {
        emitSnapshot();
      });
      emitSnapshot();
    }

    controller
      ..onListen = start
      ..onCancel = () async {
        await subscription.cancel();
      };

    return controller.stream;
  }

  /// Fetches a source by its [sourceId].
  Future<MangaSourceModel?> getById(String sourceId) {
    final query = _collection.buildQuery<MangaSourceModel>(
      filter: FilterCondition.equalTo(
        property: r'referenceId',
        value: sourceId,
      ),
      limit: 1,
    );
    return query.findFirst();
  }

  int _hashString(String value) => value.hashCode & 0x7fffffffffffffff;
}
