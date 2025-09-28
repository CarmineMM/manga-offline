import 'package:manga_offline/domain/entities/manga_source.dart';

/// Contract responsible for managing available manga sources and their state.
abstract interface class SourceRepository {
  /// Watches the available sources and their enabled state.
  Stream<List<MangaSource>> watchSources();

  /// Loads the latest list of sources without subscribing to updates.
  Future<List<MangaSource>> loadSources();

  /// Updates the selection state of a source.
  Future<void> updateSourceSelection({
    required String sourceId,
    required bool isEnabled,
  });

  /// Stores the last synchronization timestamp for a source.
  Future<void> markSourceSynced({
    required String sourceId,
    DateTime? timestamp,
  });

  /// Retrieves the last synchronization timestamp for a source, if any.
  Future<DateTime?> getSourceLastSync(String sourceId);
}
