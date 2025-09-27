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
  ReadingProgressDataSource(this._isar);
  final Isar _isar;

  Future<void> upsertProgress({
    required String sourceId,
    required String mangaId,
    required String chapterId,
    required int lastReadPage, // 1-based
  }) async {
    await _isar.writeTxn(() async {
      final existing = await _isar.readingProgressEntitys
          .filter()
          .chapterIdEqualTo(chapterId)
          .findFirst();
      if (existing != null) {
        existing.lastReadPage = lastReadPage;
        existing.lastReadAt = DateTime.now();
        await _isar.readingProgressEntitys.put(existing);
      } else {
        final e = ReadingProgressEntity()
          ..chapterId = chapterId
          ..mangaId = mangaId
          ..sourceId = sourceId
          ..lastReadPage = lastReadPage
          ..lastReadAt = DateTime.now();
        await _isar.readingProgressEntitys.put(e);
      }
    });
  }

  Future<ReadingProgressEntity?> getProgress(String chapterId) {
    return _isar.readingProgressEntitys
        .filter()
        .chapterIdEqualTo(chapterId)
        .findFirst();
  }

  Future<List<ReadingProgressEntity>> getProgressForManga(String mangaId) {
    return _isar.readingProgressEntitys
        .filter()
        .mangaIdEqualTo(mangaId)
        .findAll();
  }
}
