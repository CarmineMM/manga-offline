import 'dart:async';

import 'package:isar/isar.dart';

part 'reading_progress_datasource.g.dart';

/// Persists last read page and timestamp per chapter.
@collection
class ReadingProgressEntity {
  Id id = Isar.autoIncrement; // surrogate
  late String chapterId; // unique
  late String mangaId;
  late String sourceId;
  int lastReadPage = 0; // 1-based
  DateTime? lastReadAt;
}

/// DataSource for reading progress.
class ReadingProgressDataSource {
  ReadingProgressDataSource(Isar isar)
    : _isar = isar,
      _memoryStore = null,
      _memoryController = null;

  ReadingProgressDataSource.inMemory()
    : _isar = null,
      _memoryStore = <String, ReadingProgressEntity>{},
      _memoryController =
          StreamController<List<ReadingProgressEntity>>.broadcast() {
    _memoryController!.onListen = _emitMemorySnapshot;
  }

  final Isar? _isar;
  final Map<String, ReadingProgressEntity>? _memoryStore;
  final StreamController<List<ReadingProgressEntity>>? _memoryController;

  Stream<List<ReadingProgressEntity>> watchAll() {
    final isar = _isar;
    if (isar != null) {
      return isar.readingProgressEntitys
          .watchLazy(fireImmediately: true)
          .asyncMap((_) => isar.readingProgressEntitys.where().findAll());
    }
    final controller = _memoryController!;
    _emitMemorySnapshot();
    return controller.stream;
  }

  Future<void> upsertProgress({
    required String sourceId,
    required String mangaId,
    required String chapterId,
    required int lastReadPage, // 1-based
  }) async {
    final isar = _isar;
    if (isar != null) {
      await isar.writeTxn(() async {
        final existing = await isar.readingProgressEntitys
            .filter()
            .chapterIdEqualTo(chapterId)
            .findFirst();
        if (existing != null) {
          existing.lastReadPage = lastReadPage;
          existing.lastReadAt = DateTime.now();
          await isar.readingProgressEntitys.put(existing);
        } else {
          final e = ReadingProgressEntity()
            ..chapterId = chapterId
            ..mangaId = mangaId
            ..sourceId = sourceId
            ..lastReadPage = lastReadPage
            ..lastReadAt = DateTime.now();
          await isar.readingProgressEntitys.put(e);
        }
      });
      return;
    }

    final store = _memoryStore!;
    final existing = store[chapterId];
    final entity =
        existing ??
        (ReadingProgressEntity()
          ..id = store.length + 1
          ..chapterId = chapterId
          ..mangaId = mangaId
          ..sourceId = sourceId);
    entity.lastReadPage = lastReadPage;
    entity.lastReadAt = DateTime.now();
    store[chapterId] = entity;
    _emitMemorySnapshot();
  }

  Future<ReadingProgressEntity?> getProgress(String chapterId) {
    final isar = _isar;
    if (isar != null) {
      return isar.readingProgressEntitys
          .filter()
          .chapterIdEqualTo(chapterId)
          .findFirst();
    }
    return Future<ReadingProgressEntity?>.value(_memoryStore![chapterId]);
  }

  Future<List<ReadingProgressEntity>> getProgressForManga(String mangaId) {
    final isar = _isar;
    if (isar != null) {
      return isar.readingProgressEntitys
          .filter()
          .mangaIdEqualTo(mangaId)
          .findAll();
    }
    final result = _memoryStore!.values
        .where((entity) => entity.mangaId == mangaId)
        .toList(growable: false);
    return Future<List<ReadingProgressEntity>>.value(result);
  }

  Future<void> deleteProgress(String chapterId) async {
    final isar = _isar;
    if (isar != null) {
      await isar.writeTxn(() async {
        final existing = await isar.readingProgressEntitys
            .filter()
            .chapterIdEqualTo(chapterId)
            .findFirst();
        if (existing != null) {
          await isar.readingProgressEntitys.delete(existing.id);
        }
      });
      return;
    }
    _memoryStore?.remove(chapterId);
    _emitMemorySnapshot();
  }

  void _emitMemorySnapshot() {
    final controller = _memoryController;
    final store = _memoryStore;
    if (controller == null || store == null || controller.isClosed) {
      return;
    }
    controller.add(store.values.toList(growable: false));
  }
}
