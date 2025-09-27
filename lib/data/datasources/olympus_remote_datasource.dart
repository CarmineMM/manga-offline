import 'dart:convert';

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
