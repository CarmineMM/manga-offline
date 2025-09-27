import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/download_task.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/entities/page_image.dart';
import 'package:manga_offline/domain/repositories/catalog_repository.dart';
import 'package:manga_offline/domain/repositories/download_repository.dart';
import 'package:manga_offline/domain/repositories/manga_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Returns the application documents directory.
///
/// This wrapper exists so tests and development code can inject an alternate
/// directory provider (for example a temporary folder) without touching the
/// repository implementation. In production it resolves to
/// [getApplicationDocumentsDirectory].
Future<Directory> _defaultDocumentsDirectory() =>
    getApplicationDocumentsDirectory();

final List<int> _fallbackImageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
);

/// Concrete implementation of [DownloadRepository].
///
/// Responsibilities:
///  * Maintain a simple FIFO queue of chapter download tasks.
///  * Fetch chapter pages via [CatalogRepository] and persist page assets to a
///    per-chapter directory under the provided documents directory.
///  * Emit queue snapshots through [watchDownloadQueue] so presentation layer
///    can display progress and status. The implementation is resilient to
///    individual page failures: when a page cannot be downloaded a small
///    fallback image is written instead and the chapter download continues.
///
/// Notes for contributors: keep the queue state updates frequent and avoid
/// long-running blocking operations on the main isolate; the repo uses a
/// private processing loop and writes files using dart:io.
class DownloadRepositoryImpl implements DownloadRepository {
  DownloadRepositoryImpl({
    required CatalogRepository catalogRepository,
    required MangaRepository mangaRepository,
    http.Client? httpClient,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _catalogRepository = catalogRepository,
       _mangaRepository = mangaRepository,
       _httpClient = httpClient ?? http.Client(),
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? _defaultDocumentsDirectory;

  final CatalogRepository _catalogRepository;
  final MangaRepository _mangaRepository;
  final http.Client _httpClient;
  final Future<Directory> Function() _documentsDirectoryProvider;

  final List<_DownloadJob> _jobs = <_DownloadJob>[];
  final StreamController<List<DownloadTask>> _queueController =
      StreamController<List<DownloadTask>>.broadcast();
  bool _isProcessing = false;

  @override
  Future<void> enqueueChapterDownload(Chapter chapter) async {
    _log(
      'Solicitud de descarga recibida para capítulo ${chapter.id}',
      payload: {'mangaId': chapter.mangaId, 'sourceId': chapter.sourceId},
    );
    final existing = _findJobByTarget(chapter.id);
    if (existing != null) {
      if (existing.task.status == DownloadStatus.failed) {
        existing
          ..task = existing.task.copyWith(
            status: DownloadStatus.queued,
            progress: 0,
            completedAt: null,
            createdAt: DateTime.now(),
          )
          ..chapter = chapter;
        _emitQueue();
        await _processQueue();
      }
      _log(
        'Capítulo ${chapter.id} ya estaba en cola (estado: ${existing.task.status})',
      );
      return;
    }

    final task = DownloadTask(
      id: 'chapter-${chapter.id}-${DateTime.now().millisecondsSinceEpoch}',
      sourceId: chapter.sourceId,
      sourceName: chapter.sourceName,
      targetType: DownloadTargetType.chapter,
      targetId: chapter.id,
      mangaId: chapter.mangaId,
      status: DownloadStatus.queued,
      progress: 0,
      createdAt: DateTime.now(),
    );

    _jobs.add(_DownloadJob(chapter: chapter, task: task));
    _emitQueue();
    _log('Capítulo ${chapter.id} encolado', payload: {'cola': _jobs.length});
    await _processQueue();
  }

  @override
  Future<void> enqueueMangaDownload(Manga manga) async {
    _log(
      'Encolando descarga completa de manga ${manga.id}',
      payload: {'capitulos': manga.chapters.length},
    );
    for (final chapter in manga.chapters) {
      await enqueueChapterDownload(chapter);
    }
  }

  @override
  Stream<List<DownloadTask>> watchDownloadQueue() {
    return _queueController.stream;
  }

  /// Releases resources associated with the repository.
  void dispose() {
    _queueController.close();
    _httpClient.close();
  }

  Future<void> _processQueue() async {
    if (_isProcessing) {
      return;
    }
    _isProcessing = true;
    _log('Procesamiento de cola iniciado', payload: {'jobs': _jobs.length});

    try {
      while (true) {
        final job = _nextQueuedJob();
        if (job == null) {
          _log('Procesamiento en pausa: sin trabajos pendientes');
          break;
        }
        _log('Descargando capítulo ${job.chapter.id}');
        await _executeChapterDownload(job);
      }
    } finally {
      _isProcessing = false;
      _log('Procesamiento de cola finalizado');
    }
  }

  Future<void> _executeChapterDownload(_DownloadJob job) async {
    _updateJob(job, job.task.copyWith(status: DownloadStatus.downloading));

    try {
      final currentChapter =
          await _mangaRepository.getChapter(job.chapter.id) ?? job.chapter;
      final pages = await _catalogRepository.fetchChapterPages(
        sourceId: currentChapter.sourceId,
        mangaId: currentChapter.mangaId,
        chapterId: currentChapter.id,
      );

      if (pages.isEmpty) {
        throw StateError('No se encontraron páginas para el capítulo.');
      }

      _log(
        'Preparando descarga de ${pages.length} páginas para ${job.chapter.id}',
      );

      final normalizedPages = pages
          .map((page) => page.copyWith(status: DownloadStatus.queued))
          .toList(growable: true);

      final targetDirectory = await _prepareChapterDirectory(currentChapter);
      var chapterSnapshot = currentChapter.copyWith(
        status: DownloadStatus.downloading,
        totalPages: normalizedPages.length,
        downloadedPages: 0,
        localPath: targetDirectory.path,
        pages: List<PageImage>.from(normalizedPages),
      );
      await _mangaRepository.saveChapter(chapterSnapshot);

      for (var index = 0; index < normalizedPages.length; index += 1) {
        final downloadedPage = await _downloadPage(
          normalizedPages[index],
          targetDirectory,
        );
        normalizedPages[index] = downloadedPage;
        chapterSnapshot = chapterSnapshot.copyWith(
          downloadedPages: index + 1,
          pages: List<PageImage>.from(normalizedPages),
        );
        await _mangaRepository.saveChapter(chapterSnapshot);
        _updateJob(
          job,
          job.task.copyWith(
            status: DownloadStatus.downloading,
            progress: (index + 1) / normalizedPages.length,
          ),
        );
      }

      final completedChapter = chapterSnapshot.copyWith(
        status: DownloadStatus.downloaded,
        downloadedPages: normalizedPages.length,
        pages: List<PageImage>.from(normalizedPages),
      );
      await _mangaRepository.saveChapter(completedChapter);
      _updateJob(
        job,
        job.task.copyWith(
          status: DownloadStatus.downloaded,
          progress: 1,
          completedAt: DateTime.now(),
        ),
      );
      _log('Capítulo ${job.chapter.id} descargado correctamente');
    } catch (error, stackTrace) {
      _updateJob(
        job,
        job.task.copyWith(status: DownloadStatus.failed, progress: 0),
      );
      _log(
        'Error al descargar el capítulo ${job.chapter.id}',
        error: error,
        stack: stackTrace,
      );
    }
  }

  Future<PageImage> _downloadPage(PageImage page, Directory directory) async {
    final remoteUrl = page.remoteUrl;
    List<int> payload;
    String extension = 'png';

    if (remoteUrl == null || remoteUrl.isEmpty) {
      _log('Página ${page.id} sin URL remota; se utilizará contenido simulado');
      payload = _fallbackImageBytes;
    } else {
      final uri = Uri.parse(remoteUrl);
      try {
        final response = await _httpClient.get(uri);
        if (response.statusCode == 200) {
          payload = response.bodyBytes;
          extension = _inferExtension(uri, response.headers['content-type']);
        } else {
          _log(
            'Respuesta ${response.statusCode} al descargar ${uri.toString()}, usando recurso simulado',
          );
          payload = _fallbackImageBytes;
        }
      } catch (error, stack) {
        _log(
          'Excepción al descargar ${uri.toString()}, usando recurso simulado',
          error: error,
          stack: stack,
        );
        payload = _fallbackImageBytes;
      }
    }

    final fileName = '${page.pageNumber.toString().padLeft(4, '0')}.$extension';
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(payload, flush: true);

    return page.copyWith(
      status: DownloadStatus.downloaded,
      localPath: file.path,
      fileSizeBytes: payload.length,
      downloadedAt: DateTime.now(),
    );
  }

  Future<Directory> _prepareChapterDirectory(Chapter chapter) async {
    final documents = await _documentsDirectoryProvider();
    final targetPath = p.join(
      documents.path,
      'manga_offline',
      chapter.sourceId,
      chapter.mangaId,
      chapter.id,
    );
    final directory = Directory(targetPath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
    return directory;
  }

  void _updateJob(_DownloadJob job, DownloadTask task) {
    job.task = task;
    _emitQueue();
  }

  void _emitQueue() {
    if (_queueController.isClosed) {
      return;
    }
    final snapshot = _jobs.map((job) => job.task).toList(growable: false);
    _queueController.add(snapshot);
  }

  _DownloadJob? _findJobByTarget(String chapterId) {
    for (final job in _jobs) {
      if (job.task.targetId == chapterId) {
        return job;
      }
    }
    return null;
  }

  _DownloadJob? _nextQueuedJob() {
    for (final job in _jobs) {
      if (job.task.status == DownloadStatus.queued) {
        return job;
      }
    }
    return null;
  }

  String _inferExtension(Uri uri, [String? contentType]) {
    final extension = p.extension(uri.path).replaceAll('.', '');
    if (extension.isNotEmpty) {
      return extension;
    }
    if (contentType != null) {
      if (contentType.contains('png')) {
        return 'png';
      }
      if (contentType.contains('webp')) {
        return 'webp';
      }
      if (contentType.contains('jpg') || contentType.contains('jpeg')) {
        return 'jpg';
      }
    }
    final fallback = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'image';
    if (fallback.contains('png')) {
      return 'png';
    }
    if (fallback.contains('webp')) {
      return 'webp';
    }
    if (fallback.contains('jpg') || fallback.contains('jpeg')) {
      return 'jpg';
    }
    return 'bin';
  }

  void _log(
    String message, {
    Map<String, Object?>? payload,
    Object? error,
    StackTrace? stack,
  }) {
    final suffix = payload == null || payload.isEmpty ? '' : ' | $payload';
    developer.log(
      '$message$suffix',
      name: 'DownloadRepository',
      error: error,
      stackTrace: stack,
    );
  }
}

class _DownloadJob {
  _DownloadJob({required this.chapter, required this.task});

  Chapter chapter;
  DownloadTask task;
}
