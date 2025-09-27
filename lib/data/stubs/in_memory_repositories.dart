import 'dart:async';

import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/entities/manga_source.dart';
import 'package:manga_offline/domain/entities/page_image.dart';
import 'package:manga_offline/domain/entities/source_capability.dart';
import 'package:manga_offline/domain/repositories/catalog_repository.dart';
import 'package:manga_offline/domain/repositories/manga_repository.dart';
import 'package:manga_offline/domain/repositories/source_repository.dart';

/// Simple in-memory implementation of [MangaRepository] to unblock the
/// presentation layer while the real persistence stack is wired.
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
  Future<void> saveManga(Manga manga) async {
    _mangas[manga.id] = manga;
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

  /// Seeds the repository with placeholder content.
  void seedLibrary(List<Manga> mangas) {
    for (final manga in mangas) {
      _mangas[manga.id] = manga;
    }
    _emit();
  }
}

/// In-memory catalog repository producing deterministic content for demos.
class InMemoryCatalogRepository implements CatalogRepository {
  InMemoryCatalogRepository(this._mangaRepository);

  final InMemoryMangaRepository _mangaRepository;
  final Map<String, List<Manga>> _catalogBySource = <String, List<Manga>>{};
  final Map<String, List<Chapter>> _chaptersByManga = <String, List<Chapter>>{};
  final Map<String, List<PageImage>> _pagesByChapter =
      <String, List<PageImage>>{};

  @override
  Future<void> syncCatalog({required String sourceId}) async {
    final samples = _sampleCatalog[sourceId] ?? const <Manga>[];
    _catalogBySource[sourceId] = samples;
    for (final manga in samples) {
      await _mangaRepository.saveManga(manga);
    }
  }

  @override
  Future<List<Manga>> fetchCatalog({required String sourceId}) async {
    return List<Manga>.from(_catalogBySource[sourceId] ?? const <Manga>[]);
  }

  @override
  Future<Manga> fetchMangaDetail({
    required String sourceId,
    required String mangaId,
  }) async {
    final summary = (_catalogBySource[sourceId] ?? const <Manga>[]).firstWhere(
      (manga) => manga.id == mangaId,
      orElse: () =>
          Manga(id: mangaId, sourceId: sourceId, title: 'Manga desconocido'),
    );

    final chapters =
        _chaptersByManga[mangaId] ??
        _buildChaptersForManga(mangaId: mangaId, sourceId: sourceId);
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
    final existing = _pagesByChapter[chapterId];
    if (existing != null) {
      return existing;
    }

    final pages = List<PageImage>.generate(15, (index) {
      final number = index + 1;
      return PageImage(
        id: '$chapterId-$number',
        chapterId: chapterId,
        pageNumber: number,
        remoteUrl: 'https://example.com/$chapterId/$number.jpg',
      );
    });
    _pagesByChapter[chapterId] = pages;
    return pages;
  }
}

/// In-memory implementation of [SourceRepository].
class InMemorySourceRepository implements SourceRepository {
  final StreamController<List<MangaSource>> _controller =
      StreamController<List<MangaSource>>.broadcast();
  final Map<String, MangaSource> _sources = <String, MangaSource>{
    'olympus': const MangaSource(
      id: 'olympus',
      name: 'Olympus Biblioteca',
      baseUrl: 'https://olympusbiblioteca.com',
      locale: 'es-ES',
      capabilities: [SourceCapability.catalog, SourceCapability.detail],
    ),
  };

  InMemorySourceRepository() {
    _emit();
  }

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
}

/// Sample catalog used by [InMemoryCatalogRepository].
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
  ],
};
