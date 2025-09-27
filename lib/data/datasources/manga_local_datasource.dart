import 'package:isar/isar.dart';
import 'package:manga_offline/data/models/manga_model.dart';

/// Local data source responsible for persisting mangas in Isar.
class MangaLocalDataSource {
  /// Creates a new instance wired to the provided [isar] database.
  MangaLocalDataSource(this.isar);

  /// Shared database instance across the local data source operations.
  final Isar isar;

  /// Opens the Isar instance configured for the application.
  ///
  /// The actual schema wiring will be provided once code generation is set up.
  static Future<Isar> open() async {
    throw UnimplementedError('Schema registration pending build_runner setup.');
  }

  /// Persists manga metadata in the local database.
  Future<void> putManga(MangaModel model) async {
    // TODO(copilot): Implement once the schema and repositories are wired.
    throw UnimplementedError('Local persistence not implemented yet.');
  }

  /// Watches the collection for changes and emits the current list of mangas.
  Stream<List<MangaModel>> watchMangas() {
    // TODO(copilot): Replace with Isar query once implemented.
    return const Stream.empty();
  }
}
