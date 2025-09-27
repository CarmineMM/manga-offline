import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manga_offline/data/datasources/olympus_remote_datasource.dart';

void main() {
  test('fetchAllSeries aggregates every page', () async {
    final responses = <int, String>{
      1: _pagePayload(
        currentPage: 1,
        lastPage: 2,
        entries: [_seriesEntry(id: 11, slug: 'manga-1', name: 'Manga 1')],
      ),
      2: _pagePayload(
        currentPage: 2,
        lastPage: 2,
        entries: [_seriesEntry(id: 12, slug: 'manga-2', name: 'Manga 2')],
      ),
    };

    final client = MockClient((request) async {
      final page = int.parse(request.url.queryParameters['page'] ?? '1');
      final body = responses[page];
      if (body == null) {
        return http.Response('Not Found', 404);
      }
      return http.Response(body, 200);
    });

    final datasource = OlympusRemoteDataSource(httpClient: client);

    final series = await datasource.fetchAllSeries();

    expect(series, hasLength(2));
    expect(series.first.slug, equals('manga-1'));
    expect(series.last.slug, equals('manga-2'));
  });

  test('fetchAllSeries throws on non-success status codes', () async {
    final client = MockClient((request) async => http.Response('Error', 500));
    final datasource = OlympusRemoteDataSource(httpClient: client);

    expect(
      () => datasource.fetchAllSeries(),
      throwsA(isA<http.ClientException>()),
    );
  });
}

String _pagePayload({
  required int currentPage,
  required int lastPage,
  required List<Map<String, dynamic>> entries,
}) {
  return jsonEncode({
    'data': {
      'series': {
        'current_page': currentPage,
        'last_page': lastPage,
        'data': entries,
      },
    },
  });
}

Map<String, dynamic> _seriesEntry({
  required int id,
  required String slug,
  required String name,
}) {
  return {
    'id': id,
    'slug': slug,
    'name': name,
    'chapter_count': 1,
    'status': {'id': 1, 'name': 'Activo'},
  };
}
