import 'package:manga_offline/domain/entities/download_task.dart';
import 'package:manga_offline/domain/repositories/download_repository.dart';

/// Streams download queue updates to keep the UI in sync.
class WatchDownloadQueue {
  /// Creates a new [WatchDownloadQueue] instance.
  const WatchDownloadQueue(this._repository);

  final DownloadRepository _repository;

  /// Executes the use case.
  Stream<List<DownloadTask>> call() => _repository.watchDownloadQueue();
}
