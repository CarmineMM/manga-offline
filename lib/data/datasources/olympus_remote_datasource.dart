import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:manga_offline/data/datasources/catalog_remote_datasource.dart';

/// Remote data source in charge of fetching catalog information from the
/// Olympus Biblioteca API.
class OlympusRemoteDataSource implements CatalogRemoteDataSource {
  OlympusRemoteDataSource({
    http.Client? httpClient,
    Uri? baseSeriesUri,
    Uri? baseChaptersUri,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseSeriesUri =
           baseSeriesUri ??
           Uri.parse('https://olympusbiblioteca.com/api/series'),
       _baseChaptersUri =
           baseChaptersUri ??
           Uri.parse('https://dashboard.olympusbiblioteca.com/api/series');

  final http.Client _httpClient;
  final Uri _baseSeriesUri;
  final Uri _baseChaptersUri;

  @override
  String get sourceId => 'olympus';

  @override
  String get sourceName => 'Olympus Biblioteca';

  @override
  Future<List<RemoteMangaSummary>> fetchAllSeries() async {
    final List<RemoteMangaSummary> catalog = [];
    var nextPage = 1;

    while (true) {
      final page = await _fetchSeriesPage(page: nextPage);
      catalog.addAll(page.items);

      if (page.currentPage >= page.lastPage) {
        break;
      }

      nextPage = page.currentPage + 1;
    }

    return catalog;
  }

  @override
  Future<List<RemoteChapterSummary>> fetchAllChapters({
    required String mangaSlug,
  }) async {
    final List<RemoteChapterSummary> chapters = [];
    var nextPage = 1;

    while (true) {
      final page = await _fetchChapterPage(slug: mangaSlug, page: nextPage);
      chapters.addAll(page.items);

      if (page.currentPage >= page.lastPage) {
        break;
      }

      nextPage = page.currentPage + 1;
    }

    return chapters;
  }

  @override
  Future<List<RemotePageImage>> fetchChapterPages({
    required String mangaSlug,
    required String chapterId,
  }) async {
    // Endpoint correcto para obtener páginas individuales del capítulo:
    // https://olympusbiblioteca.com/api/capitulo/{slug}/{chapterId}?type=comic
    final uri = Uri(
      scheme: 'https',
      host: 'olympusbiblioteca.com',
      path: '/api/capitulo/$mangaSlug/$chapterId',
      queryParameters: const {'type': 'comic'},
    );
    developer.log(
      'fetchChapterPages request slug=$mangaSlug chapter=$chapterId uri=${uri.toString()}',
      name: 'OlympusRemoteDataSource',
    );

    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      developer.log(
        'fetchChapterPages error status=${response.statusCode} slug=$mangaSlug chapter=$chapterId',
        name: 'OlympusRemoteDataSource',
      );
      throw http.ClientException(
        'Failed to fetch Olympus chapter $chapterId for $mangaSlug (status ${response.statusCode})',
        uri,
      );
    }

    final jsonPayload = jsonDecode(response.body);
    if (jsonPayload is! Map<String, dynamic>) {
      developer.log(
        'fetchChapterPages unexpected root JSON type=${jsonPayload.runtimeType}',
        name: 'OlympusRemoteDataSource',
      );
      return const <RemotePageImage>[];
    }

    developer.log(
      'fetchChapterPages raw keys=${jsonPayload.keys.toList()}',
      name: 'OlympusRemoteDataSource',
    );

    // Camino principal: chapter.pages (List<String>)
    final chapter = jsonPayload['chapter'];
    if (chapter is Map<String, dynamic>) {
      final pages = chapter['pages'];
      if (pages is List) {
        final stringUrls = pages.whereType<String>().toList();
        if (stringUrls.isNotEmpty) {
          final mapped = _mapStringPagesList(chapterId, stringUrls);
          developer.log(
            'fetchChapterPages parsed pages=${mapped.length} (chapter.pages strings) slug=$mangaSlug chapter=$chapterId',
            name: 'OlympusRemoteDataSource',
          );
          return mapped;
        }
      }
    }

    // Fallback: lógica anterior buscando listas de maps.
    final pagesPayload = _extractPagesPayload(jsonPayload);
    if (pagesPayload.isNotEmpty) {
      final mapped = _mapPageList(chapterId, pagesPayload);
      developer.log(
        'fetchChapterPages parsed pages=${mapped.length} (fallback structured) slug=$mangaSlug chapter=$chapterId',
        name: 'OlympusRemoteDataSource',
      );
      return mapped;
    }

    developer.log(
      'fetchChapterPages no pages found slug=$mangaSlug chapter=$chapterId',
      name: 'OlympusRemoteDataSource',
    );
    return const <RemotePageImage>[];
  }

  /// Releases resources associated with the underlying HTTP client.
  void dispose() {
    _httpClient.close();
  }

  Future<_SeriesPage> _fetchSeriesPage({required int page}) async {
    final uri = _baseSeriesUri.replace(
      queryParameters: <String, String>{
        'page': page.toString(),
        'direction': 'asc',
        'type': 'comic',
      },
    );

    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Failed to fetch Olympus series page $page (status ${response.statusCode})',
        uri,
      );
    }

    final jsonPayload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = jsonPayload['data'] as Map<String, dynamic>?;
    final series = data?['series'] as Map<String, dynamic>?;
    final currentPage = (series?['current_page'] as num?)?.toInt() ?? page;
    final lastPage = (series?['last_page'] as num?)?.toInt() ?? currentPage;
    final entries = (series?['data'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(_mapSeriesSummary)
        .toList(growable: false);

    return _SeriesPage(
      items: entries,
      currentPage: currentPage,
      lastPage: lastPage,
    );
  }

  RemoteMangaSummary _mapSeriesSummary(Map<String, dynamic> json) {
    final status = json['status'] as Map<String, dynamic>?;
    final slug = (json['slug'] as String?) ?? json['id'].toString();
    final name = (json['name'] as String?) ?? slug;
    final chapterCount = (json['chapter_count'] as num?)?.toInt() ?? 0;

    return RemoteMangaSummary(
      externalId: json['id'].toString(),
      slug: slug,
      title: name,
      chapterCount: chapterCount,
      sourceId: sourceId,
      sourceName: sourceName,
      synopsis: null,
      coverUrl: json['cover'] as String?,
      status: status?['name'] as String?,
    );
  }

  Future<_ChapterPage> _fetchChapterPage({
    required String slug,
    required int page,
  }) async {
    final uri = Uri(
      scheme: _baseChaptersUri.scheme,
      host: _baseChaptersUri.host,
      port: _baseChaptersUri.hasPort ? _baseChaptersUri.port : null,
      path: '${_baseChaptersUri.path}/$slug/chapters',
      queryParameters: <String, String>{
        'page': page.toString(),
        'direction': 'desc',
        'type': 'comic',
      },
    );

    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Failed to fetch Olympus chapters page $page for $slug (status ${response.statusCode})',
        uri,
      );
    }

    final jsonPayload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (jsonPayload['data'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map((json) => _mapChapterSummary(slug, json))
        .toList(growable: false);
    final meta = jsonPayload['meta'] as Map<String, dynamic>?;
    final currentPage = (meta?['current_page'] as num?)?.toInt() ?? page;
    final lastPage = (meta?['last_page'] as num?)?.toInt() ?? currentPage;

    return _ChapterPage(
      items: data,
      currentPage: currentPage,
      lastPage: lastPage,
    );
  }

  RemoteChapterSummary _mapChapterSummary(
    String slug,
    Map<String, dynamic> json,
  ) {
    final name = (json['name'] as String?)?.trim() ?? '';
    final publishedAtRaw = json['published_at'] as String?;
    final publishedAt = publishedAtRaw != null
        ? DateTime.tryParse(publishedAtRaw)
        : null;

    return RemoteChapterSummary(
      externalId: json['id'].toString(),
      mangaSlug: slug,
      name: name.isEmpty ? json['id'].toString() : name,
      sourceId: sourceId,
      sourceName: sourceName,
      publishedAt: publishedAt,
    );
  }

  Iterable<Map<String, dynamic>> _extractPagesPayload(
    Map<String, dynamic> json,
  ) {
    final Map<String, dynamic> candidates = <String, dynamic>{
      ...json,
      if (json['data'] is Map<String, dynamic>)
        ...(json['data'] as Map<String, dynamic>),
    };

    for (final key in ['pages', 'images', 'data']) {
      final value = candidates[key];
      if (value is List) {
        return value.whereType<Map<String, dynamic>>();
      }
    }

    return const Iterable<Map<String, dynamic>>.empty();
  }

  RemotePageImage? _mapPageImage(String chapterId, Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['uuid'] ?? json['key'];
    final rawNumber =
        json['page'] ?? json['number'] ?? json['order'] ?? json['index'];
    final number = (rawNumber as num?)?.toInt() ?? 0;

    final rawUrl =
        json['image'] ??
        json['url'] ??
        json['imageUrl'] ??
        json['image_url'] ??
        json['full_path'] ??
        json['path'];

    if (rawUrl == null || (rawUrl is String && rawUrl.isEmpty)) {
      return null;
    }

    final imageUrl = _resolveImageUrl(rawUrl.toString());
    final externalId = (rawId ?? '${chapterId}_$number').toString();

    return RemotePageImage(
      externalId: externalId,
      chapterId: chapterId,
      pageNumber: number <= 0 ? 1 : number,
      imageUrl: imageUrl,
      checksum: json['checksum'] as String?,
    );
  }

  String _resolveImageUrl(String url) {
    final parsed = Uri.tryParse(url);
    if (parsed == null) {
      return url;
    }
    if (parsed.hasScheme) {
      return url;
    }

    return Uri(
      scheme: _baseChaptersUri.scheme,
      host: _baseChaptersUri.host,
      port: _baseChaptersUri.hasPort ? _baseChaptersUri.port : null,
      path: url.startsWith('/') ? url : '${_baseChaptersUri.path}/$url',
    ).toString();
  }

  List<RemotePageImage> _mapPageList(
    String chapterId,
    Iterable<Map<String, dynamic>> entries,
  ) {
    final result = <RemotePageImage>[];
    for (final entry in entries) {
      final mapped = _mapPageImage(chapterId, entry);
      if (mapped != null) {
        result.add(mapped);
      }
    }
    // Normalize ordering by page number to avoid random order from API.
    result.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
    return result;
  }

  List<RemotePageImage> _mapStringPagesList(
    String chapterId,
    List<String> urls,
  ) {
    final List<RemotePageImage> result = [];
    for (var i = 0; i < urls.length; i++) {
      final url = urls[i];
      final resolved = _resolveImageUrl(url);
      result.add(
        RemotePageImage(
          externalId: '${chapterId}_${i + 1}',
          chapterId: chapterId,
          // Page numbers se enumeran empezando en 1.
          pageNumber: i + 1,
          imageUrl: resolved,
          checksum: null,
        ),
      );
    }
    return result;
  }
}

class _SeriesPage {
  const _SeriesPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  final List<RemoteMangaSummary> items;
  final int currentPage;
  final int lastPage;
}

class _ChapterPage {
  const _ChapterPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  final List<RemoteChapterSummary> items;
  final int currentPage;
  final int lastPage;
}
