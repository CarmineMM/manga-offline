import 'dart:async';
import 'dart:developer' as developer;

import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/entities/manga_source.dart';
import 'package:manga_offline/domain/entities/page_image.dart';
import 'package:manga_offline/domain/repositories/catalog_repository.dart';
import 'package:manga_offline/data/datasources/catalog_remote_datasource.dart';
import 'package:manga_offline/domain/repositories/manga_repository.dart';
import 'package:manga_offline/domain/repositories/source_repository.dart';
import 'package:manga_offline/data/datasources/cache/page_cache_datasource.dart';
import 'package:manga_offline/data/constants/default_sources.dart';

/// In-memory implementation of [MangaRepository].
///
/// Used during development and UI prototyping. Stores manga and chapter
/// metadata in memory and exposes `watchLocalLibrary()` as a broadcast stream.
/// This repository is intentionally simple and synchronous in behaviour so it
/// is easy to reason about in tests and demos.
class InMemoryMangaRepository implements MangaRepository {
  final Map<String, Manga> _mangas = <String, Manga>{};
  late final StreamController<List<Manga>> _controller;

  InMemoryMangaRepository() {
    _controller = StreamController<List<Manga>>.broadcast(onListen: _emit);
    _emit();
  }

  void _emit() {
    _controller.add(_mangas.values.toList(growable: false));
  }

  @override
  Stream<List<Manga>> watchLocalLibrary() => _controller.stream;

  @override
  Stream<List<Manga>> watchFollowedMangas() => _controller.stream.map(
    (mangas) =>
        mangas.where((manga) => manga.isFollowed).toList(growable: false),
  );

  @override
  Future<Manga?> getManga(String mangaId) async => _mangas[mangaId];

  @override
  Future<void> saveManga(Manga manga) async {
    final existing = _mangas[manga.id];
    final next = existing != null
        ? manga.copyWith(isFollowed: existing.isFollowed)
        : manga;
    _mangas[manga.id] = next;
    _emit();
  }

  @override
  Future<void> setMangaFollowed({
    required String mangaId,
    required bool isFollowed,
  }) async {
    final existing = _mangas[mangaId];
    if (existing == null) {
      return;
    }
    _mangas[mangaId] = existing.copyWith(isFollowed: isFollowed);
    _emit();
  }

  @override
  Future<void> saveChapter(Chapter chapter) async {
    final existing = _mangas[chapter.mangaId];
    if (existing == null) {
      final downloadedCount = chapter.status == DownloadStatus.downloaded
          ? 1
          : 0;
      _mangas[chapter.mangaId] = Manga(
        id: chapter.mangaId,
        sourceId: chapter.sourceId,
        title: chapter.mangaId,
        status: downloadedCount > 0
            ? DownloadStatus.downloaded
            : DownloadStatus.notDownloaded,
        totalChapters: 1,
        downloadedChapters: downloadedCount,
        chapters: [chapter],
      );
      _emit();
      return;
    }

    final chapters = existing.chapters.toList(growable: true);
    final index = chapters.indexWhere((item) => item.id == chapter.id);
    if (index >= 0) {
      chapters[index] = chapter;
    } else {
      chapters.add(chapter);
    }

    final downloadedCount = chapters
        .where((element) => element.status == DownloadStatus.downloaded)
        .length;

    final totalChapters = existing.totalChapters == 0
        ? chapters.length
        : existing.totalChapters;

    var status = DownloadStatus.notDownloaded;
    if (downloadedCount >= totalChapters && totalChapters > 0) {
      status = DownloadStatus.downloaded;
    } else if (downloadedCount > 0) {
      status = DownloadStatus.downloading;
    }

    _mangas[existing.id] = existing.copyWith(
      chapters: chapters,
      downloadedChapters: downloadedCount,
      status: status,
      totalChapters: totalChapters,
    );
    _emit();
  }

  @override
  Future<Chapter?> getChapter(String chapterId) async {
    for (final manga in _mangas.values) {
      final index = manga.chapters.indexWhere(
        (chapter) => chapter.id == chapterId,
      );
      if (index != -1) {
        return manga.chapters[index];
      }
    }
    return null;
  }

  @override
  Future<void> markMangaAsDownloaded(String mangaId) async {
    final existing = _mangas[mangaId];
    if (existing == null) return;
    final chapters = existing.chapters
        .map(
          (chapter) => chapter.copyWith(
            status: DownloadStatus.downloaded,
            downloadedPages: chapter.totalPages,
          ),
        )
        .toList(growable: false);
    _mangas[mangaId] = existing.copyWith(
      status: DownloadStatus.downloaded,
      downloadedChapters: chapters.length,
      chapters: chapters,
    );
    _emit();
  }

  @override
  Future<void> markChapterAsDownloaded(String chapterId) async {
    for (final entry in _mangas.entries) {
      final chapters = entry.value.chapters
          .map((chapter) {
            if (chapter.id == chapterId) {
              return chapter.copyWith(
                status: DownloadStatus.downloaded,
                downloadedPages: chapter.totalPages,
              );
            }
            return chapter;
          })
          .toList(growable: false);

      final downloadedCount = chapters
          .where((chapter) => chapter.status == DownloadStatus.downloaded)
          .length;

      _mangas[entry.key] = entry.value.copyWith(
        chapters: chapters,
        downloadedChapters: downloadedCount,
        status: downloadedCount == chapters.length && chapters.isNotEmpty
            ? DownloadStatus.downloaded
            : entry.value.status,
      );
    }
    _emit();
  }

  @override
  Future<DownloadStatus?> getMangaDownloadStatus(String mangaId) async {
    return _mangas[mangaId]?.status;
  }

  @override
  Future<DownloadStatus?> getChapterDownloadStatus(String chapterId) async {
    for (final manga in _mangas.values) {
      final match = manga.chapters.firstWhere(
        (chapter) => chapter.id == chapterId,
        orElse: () => const Chapter(
          id: '',
          mangaId: '',
          sourceId: '',
          title: '',
          number: 0,
        ),
      );
      if (match.id.isNotEmpty) {
        return match.status;
      }
    }
    return null;
  }

  @override
  Future<void> updateMangaCover({
    required String mangaId,
    String? coverImagePath,
  }) async {
    final existing = _mangas[mangaId];
    if (existing == null) {
      return;
    }
    _mangas[mangaId] = existing.copyWith(coverImagePath: coverImagePath);
    _emit();
  }

  @override
  Future<void> clearChapterDownload(String chapterId) async {
    var changed = false;
    for (final entry in _mangas.entries) {
      final chapters = <Chapter>[];
      var updated = false;
      for (final chapter in entry.value.chapters) {
        if (chapter.id == chapterId) {
          updated = true;
          changed = true;
          chapters.add(
            chapter.copyWith(
              status: DownloadStatus.notDownloaded,
              downloadedPages: 0,
              localPath: null,
              pages: const [],
            ),
          );
        } else {
          chapters.add(chapter);
        }
      }
      if (!updated) {
        continue;
      }

      final downloadedCount = chapters
          .where((chapter) => chapter.status == DownloadStatus.downloaded)
          .length;
      final totalChapters = entry.value.totalChapters == 0
          ? chapters.length
          : entry.value.totalChapters;

      var status = DownloadStatus.notDownloaded;
      if (downloadedCount == 0) {
        status = DownloadStatus.notDownloaded;
      } else if (totalChapters > 0 && downloadedCount >= totalChapters) {
        status = DownloadStatus.downloaded;
      } else {
        status = DownloadStatus.downloading;
      }

      _mangas[entry.key] = entry.value.copyWith(
        chapters: chapters,
        downloadedChapters: downloadedCount,
        status: status,
      );
    }

    if (changed) {
      _emit();
    }
  }

  /// Seeds the repository with placeholder content.
  void seedLibrary(List<Manga> mangas) {
    for (final manga in mangas) {
      _mangas[manga.id] = manga;
    }
    _emit();
  }
}

/// In-memory implementation of [CatalogRepository].
///
/// Produces deterministic, generated content suitable for demos. It also
/// forwards manga summaries into the provided [InMemoryMangaRepository] so
/// the presentation layer always has a record of available mangas.
class InMemoryCatalogRepository implements CatalogRepository {
  InMemoryCatalogRepository(
    this._mangaRepository, {
    Map<String, CatalogRemoteDataSource>? remoteDataSources,
    PageCacheDataSource? pageCache,
  }) : _remoteDataSources =
           remoteDataSources ?? const <String, CatalogRemoteDataSource>{},
       _pageCache = pageCache;

  final InMemoryMangaRepository _mangaRepository;
  final Map<String, CatalogRemoteDataSource> _remoteDataSources;
  final Map<String, List<Manga>> _catalogBySource = <String, List<Manga>>{};
  final Map<String, List<Chapter>> _chaptersByManga = <String, List<Chapter>>{};
  final Map<String, List<PageImage>> _pagesByChapter =
      <String, List<PageImage>>{};
  final PageCacheDataSource? _pageCache;
  bool? lastForceRefresh;

  @override
  Future<void> syncCatalog({required String sourceId}) async {
    developer.log(
      'syncCatalog start | sourceId=$sourceId',
      name: 'InMemoryCatalogRepository',
    );
    List<Manga> resolved = const <Manga>[];
    final remote = _remoteDataSources[sourceId];
    if (remote != null) {
      try {
        final summaries = await remote.fetchAllSeries();
        resolved = summaries
            .map((s) => s.toDomain(lastUpdated: DateTime.now()))
            .toList(growable: false);
        developer.log(
          'syncCatalog remote fetched=${resolved.length}',
          name: 'InMemoryCatalogRepository',
        );
      } catch (error, stack) {
        developer.log(
          'syncCatalog remote error falling back to samples',
          name: 'InMemoryCatalogRepository',
          error: error,
          stackTrace: stack,
        );
      }
    }
    if (resolved.isEmpty) {
      final samples = _sampleCatalog[sourceId] ?? const <Manga>[];
      resolved = samples;
    }
    _catalogBySource[sourceId] = resolved;
    for (final manga in resolved) {
      await _mangaRepository.saveManga(manga);
    }
    developer.log(
      'syncCatalog completed | sourceId=$sourceId, mangas=${resolved.length}',
      name: 'InMemoryCatalogRepository',
    );
  }

  @override
  Future<List<Manga>> fetchCatalog({required String sourceId}) async {
    developer.log(
      'fetchCatalog | sourceId=$sourceId',
      name: 'InMemoryCatalogRepository',
    );
    return List<Manga>.from(_catalogBySource[sourceId] ?? const <Manga>[]);
  }

  @override
  Future<Manga> fetchMangaDetail({
    required String sourceId,
    required String mangaId,
    bool forceRefresh = false,
  }) async {
    lastForceRefresh = forceRefresh;
    final cached = await _mangaRepository.getManga(mangaId);
    if (!forceRefresh && cached != null && cached.chapters.isNotEmpty) {
      return cached;
    }

    final list = _catalogBySource[sourceId] ?? const <Manga>[];
    final summary = list.firstWhere(
      (manga) => manga.id == mangaId,
      orElse: () =>
          Manga(id: mangaId, sourceId: sourceId, title: 'Manga desconocido'),
    );

    List<Chapter> chapters = const <Chapter>[];
    if (!forceRefresh) {
      chapters = _chaptersByManga[mangaId] ?? const <Chapter>[];
    }
    final remote = _remoteDataSources[sourceId];
    if (remote != null) {
      try {
        final remoteChapters = await remote.fetchAllChapters(
          mangaSlug: mangaId,
        );
        chapters = remoteChapters
            .map((c) => c.toDomain(indexFallback: remoteChapters.length))
            .toList(growable: false);
        developer.log(
          'fetchMangaDetail remote chapters=${chapters.length} manga=$mangaId',
          name: 'InMemoryCatalogRepository',
        );
      } catch (error, stack) {
        developer.log(
          'fetchMangaDetail remote chapters error fallback local',
          name: 'InMemoryCatalogRepository',
          error: error,
          stackTrace: stack,
        );
        if (chapters.isEmpty) {
          chapters =
              (cached?.chapters.isNotEmpty == true
                  ? cached!.chapters
                  : _chaptersByManga[mangaId]) ??
              _buildChaptersForManga(mangaId: mangaId, sourceId: sourceId);
        }
      }
    } else {
      if (chapters.isEmpty) {
        chapters =
            _chaptersByManga[mangaId] ??
            _buildChaptersForManga(mangaId: mangaId, sourceId: sourceId);
      }
    }

    _chaptersByManga[mangaId] = chapters;
    final detailed = summary.copyWith(
      chapters: chapters,
      totalChapters: chapters.length,
    );
    await _mangaRepository.saveManga(detailed);
    return detailed;
  }

  List<Chapter> _buildChaptersForManga({
    required String mangaId,
    required String sourceId,
  }) {
    return List<Chapter>.generate(8, (index) {
      final chapterNumber = index + 1;
      final id = '$mangaId-$chapterNumber';
      return Chapter(
        id: id,
        mangaId: mangaId,
        sourceId: sourceId,
        title: 'Capítulo $chapterNumber',
        number: chapterNumber,
        status: DownloadStatus.notDownloaded,
      );
    });
  }

  @override
  Future<List<PageImage>> fetchChapterPages({
    required String sourceId,
    required String mangaId,
    required String chapterId,
  }) async {
    // 1. Cache en memoria (rápido)
    final cache = _pagesByChapter[chapterId];
    if (cache != null) {
      developer.log(
        'fetchChapterPages cache hit chapter=$chapterId count=${cache.length}',
        name: 'InMemoryCatalogRepository',
      );
      return cache;
    }

    // 2. Cache persistente (Isar) si está disponible
    if (_pageCache != null) {
      try {
        final persisted = await _pageCache.getChapterPages(
          sourceId: sourceId,
          mangaSlug: mangaId,
          chapterId: chapterId,
        );
        if (persisted.isNotEmpty) {
          final mapped = persisted
              .map(
                (e) => PageImage(
                  id: '$chapterId-${e.pageNumber}',
                  chapterId: chapterId,
                  pageNumber: e.pageNumber,
                  remoteUrl: e.imageUrl,
                ),
              )
              .toList(growable: false);
          _pagesByChapter[chapterId] = mapped;
          developer.log(
            'fetchChapterPages persistent cache hit chapter=$chapterId pages=${mapped.length}',
            name: 'InMemoryCatalogRepository',
          );
          return mapped;
        }
      } catch (error, stack) {
        developer.log(
          'fetchChapterPages persistent cache error (ignored)',
          name: 'InMemoryCatalogRepository',
          error: error,
          stackTrace: stack,
        );
      }
    }

    final remote = _remoteDataSources[sourceId];
    if (remote != null) {
      try {
        final remotePages = await remote.fetchChapterPages(
          mangaSlug: mangaId,
          chapterId: chapterId,
        );
        final mapped = remotePages
            .map((p) => p.toDomain())
            .toList(growable: false);
        developer.log(
          'fetchChapterPages remote chapter=$chapterId pages=${mapped.length}',
          name: 'InMemoryCatalogRepository',
        );
        if (mapped.isNotEmpty) {
          _pagesByChapter[chapterId] = mapped;
          // Guardar en cache persistente (sólo si no es fallback)
          if (_pageCache != null) {
            try {
              await _pageCache.putChapterPages(
                sourceId: sourceId,
                mangaSlug: mangaId,
                chapterId: chapterId,
                pages: mapped
                    .map(
                      (p) => PageEntity()
                        ..pageNumber = p.pageNumber
                        ..imageUrl = p.remoteUrl ?? ''
                        ..checksum = null,
                    )
                    .toList(growable: false),
              );
              developer.log(
                'fetchChapterPages persisted chapter=$chapterId pages=${mapped.length}',
                name: 'InMemoryCatalogRepository',
              );
            } catch (error, stack) {
              developer.log(
                'fetchChapterPages persist error (ignored) chapter=$chapterId',
                name: 'InMemoryCatalogRepository',
                error: error,
                stackTrace: stack,
              );
            }
          }
          return mapped;
        } else {
          developer.log(
            'fetchChapterPages remote returned 0 pages (will fallback) chapter=$chapterId',
            name: 'InMemoryCatalogRepository',
          );
        }
      } catch (error, stack) {
        developer.log(
          'fetchChapterPages remote error fallback mock',
          name: 'InMemoryCatalogRepository',
          error: error,
          stackTrace: stack,
        );
      }
    }

    final mock = List<PageImage>.generate(5, (index) {
      final number = index + 1;
      return PageImage(
        id: '$chapterId-$number',
        chapterId: chapterId,
        pageNumber: number,
        remoteUrl: 'https://fallback.local/$chapterId/$number.png',
      );
    });
    _pagesByChapter[chapterId] = mock;
    developer.log(
      'fetchChapterPages mock chapter=$chapterId pages=${mock.length}',
      name: 'InMemoryCatalogRepository',
    );
    return mock;
  }
}

/// In-memory implementation of [SourceRepository].
///
/// Provides a small set of sample `MangaSource` entries and allows toggling
/// the selection state used by the UI. This is useful for development where
/// multiple sources may be simulated without network access.
class InMemorySourceRepository implements SourceRepository {
  InMemorySourceRepository({
    Set<String> initialEnabled = const <String>{},
    Map<String, DateTime?> initialLastSync = const <String, DateTime?>{},
  }) {
    _sources.updateAll(
      (key, value) => value.copyWith(
        isEnabled: initialEnabled.contains(key),
        lastSyncedAt: initialLastSync[key],
      ),
    );
    _emit();
  }

  final StreamController<List<MangaSource>> _controller =
      StreamController<List<MangaSource>>.broadcast();
  final Map<String, MangaSource> _sources = <String, MangaSource>{
    for (final source in kDefaultSources) source.id: source,
  };

  void _emit() {
    _controller.add(_sources.values.toList(growable: false));
  }

  @override
  Stream<List<MangaSource>> watchSources() => _controller.stream;

  @override
  Future<List<MangaSource>> loadSources() async {
    return _sources.values.toList(growable: false);
  }

  @override
  Future<void> updateSourceSelection({
    required String sourceId,
    required bool isEnabled,
  }) async {
    final existing = _sources[sourceId];
    if (existing == null) return;
    _sources[sourceId] = existing.copyWith(isEnabled: isEnabled);
    _emit();
  }

  @override
  Future<void> markSourceSynced({
    required String sourceId,
    DateTime? timestamp,
  }) async {
    final existing = _sources[sourceId];
    if (existing == null) return;
    _sources[sourceId] = existing.copyWith(
      lastSyncedAt: timestamp ?? DateTime.now(),
    );
    _emit();
  }

  @override
  Future<DateTime?> getSourceLastSync(String sourceId) async {
    return _sources[sourceId]?.lastSyncedAt;
  }
}

/// Sample catalog used by [InMemoryCatalogRepository].
///
/// The map keys are source identifiers. Each entry is a list of small
/// `Manga` objects used to exercise the UI and the download flow during
/// development. Replace or extend this map when adding additional demo
/// scenarios.
const Map<String, List<Manga>> _sampleCatalog = <String, List<Manga>>{
  'olympus': [
    Manga(
      id: 'academia-de-la-ascension',
      sourceId: 'olympus',
      sourceName: 'Olympus Biblioteca',
      title: 'Academia de la Ascensión',
      synopsis: 'Estudiantes con poderes extraordinarios luchan por graduarse.',
      coverImageUrl:
          'https://dashboard.olympusbiblioteca.com/storage/comics/covers/11/academia-lg.webp',
      totalChapters: 174,
      downloadedChapters: 0,
      status: DownloadStatus.notDownloaded,
    ),
    Manga(
      id: 'accidentalmente-me-hice-famoso',
      sourceId: 'olympus',
      sourceName: 'Olympus Biblioteca',
      title: 'Accidentalmente me hice famoso',
      synopsis:
          'Una aventura llena de comedia donde la fama llega sin esperarla.',
      coverImageUrl:
          'https://dashboard.olympusbiblioteca.com/storage/comics/covers/1279/Accidentalmente-lg.webp',
      totalChapters: 10,
      downloadedChapters: 0,
      status: DownloadStatus.notDownloaded,
    ),
    Manga(
      id: 'ecos-del-inframundo',
      sourceId: 'olympus',
      sourceName: 'Olympus Biblioteca',
      title: 'Ecos del Inframundo',
      synopsis:
          'Un grupo de exorcistas enfrenta criaturas ancestrales en ciudades modernas.',
      coverImageUrl:
          'https://dashboard.olympusbiblioteca.com/storage/comics/covers/1188/ecos_hero.webp',
      totalChapters: 64,
      downloadedChapters: 0,
      status: DownloadStatus.notDownloaded,
    ),
    Manga(
      id: 'vinculos-de-plata',
      sourceId: 'olympus',
      sourceName: 'Olympus Biblioteca',
      title: 'Vínculos de Plata',
      synopsis:
          'Dos hermanas descubren secretos familiares mientras dominan la alquimia.',
      coverImageUrl:
          'https://dashboard.olympusbiblioteca.com/storage/comics/covers/1203/vinculos-lg.webp',
      totalChapters: 38,
      downloadedChapters: 0,
      status: DownloadStatus.notDownloaded,
    ),
    Manga(
      id: 'ultimos-guerreros-del-zenith',
      sourceId: 'olympus',
      sourceName: 'Olympus Biblioteca',
      title: 'Últimos Guerreros del Zenith',
      synopsis:
          'Mercenarios espaciales defienden colonias perdidas contra imperios galácticos.',
      coverImageUrl:
          'https://dashboard.olympusbiblioteca.com/storage/comics/covers/1145/zenith-lg.webp',
      totalChapters: 52,
      downloadedChapters: 0,
      status: DownloadStatus.notDownloaded,
    ),
    Manga(
      id: 'cronicas-del-bosque-eter',
      sourceId: 'olympus',
      sourceName: 'Olympus Biblioteca',
      title: 'Crónicas del Bosque Éter',
      synopsis:
          'Guardianes mágicos protegen un bosque viviente de invasores tecnológicos.',
      coverImageUrl:
          'https://dashboard.olympusbiblioteca.com/storage/comics/covers/1122/eter-lg.webp',
      totalChapters: 21,
      downloadedChapters: 0,
      status: DownloadStatus.notDownloaded,
    ),
    Manga(
      id: 'reliquias-de-aurora',
      sourceId: 'olympus',
      sourceName: 'Olympus Biblioteca',
      title: 'Reliquias de Aurora',
      synopsis:
          'Un arqueólogo rebelde busca artefactos prohibidos que alteran el tiempo.',
      coverImageUrl:
          'https://dashboard.olympusbiblioteca.com/storage/comics/covers/1199/aurora-lg.webp',
      totalChapters: 47,
      downloadedChapters: 0,
      status: DownloadStatus.notDownloaded,
    ),
  ],
};
