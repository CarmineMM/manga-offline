import 'package:manga_offline/data/datasources/cache/reading_progress_datasource.dart';

/// Backwards compatible alias used by existing tests. Prefer calling
/// [ReadingProgressDataSource.inMemory] directly in new suites.
class InMemoryReadingProgressDataSource extends ReadingProgressDataSource {
  InMemoryReadingProgressDataSource() : super.inMemory();
}
