import 'package:manga_offline/data/datasources/cache/reading_progress_datasource.dart';

/// Simple in-memory implementation used only in tests to avoid Isar dependency.
class InMemoryReadingProgressDataSource implements ReadingProgressDataSource {
  final Map<String, ReadingProgressEntity> _byChapter = {};

  InMemoryReadingProgressDataSource();

  @override
  Future<void> upsertProgress({
    required String sourceId,
    required String mangaId,
    required String chapterId,
    required int lastReadPage,
  }) async {
    final existing = _byChapter[chapterId];
    if (existing != null) {
      existing.lastReadPage = lastReadPage;
      existing.lastReadAt = DateTime.now();
    } else {
      final e = ReadingProgressEntity()
        ..chapterId = chapterId
        ..mangaId = mangaId
        ..sourceId = sourceId
        ..lastReadPage = lastReadPage
        ..lastReadAt = DateTime.now();
      _byChapter[chapterId] = e;
    }
  }

  @override
  Future<ReadingProgressEntity?> getProgress(String chapterId) async {
    return _byChapter[chapterId];
  }

  @override
  Future<List<ReadingProgressEntity>> getProgressForManga(
    String mangaId,
  ) async {
    return _byChapter.values
        .where((e) => e.mangaId == mangaId)
        .toList(growable: false);
  }
}
