import 'package:flutter_test/flutter_test.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/manga.dart';

void main() {
  group('Manga read progress helpers', () {
    test('readChaptersCount counts chapters with progress', () {
      final manga = Manga(
        id: 'manga-1',
        sourceId: 'source-1',
        title: 'Sample',
        chapters: <Chapter>[
          Chapter(
            id: 'c1',
            mangaId: 'manga-1',
            sourceId: 'source-1',
            title: 'One',
            number: 1,
            lastReadPage: 12,
          ),
          const Chapter(
            id: 'c2',
            mangaId: 'manga-1',
            sourceId: 'source-1',
            title: 'Two',
            number: 2,
          ),
          Chapter(
            id: 'c3',
            mangaId: 'manga-1',
            sourceId: 'source-1',
            title: 'Three',
            number: 3,
            lastReadAt: DateTime(2024, 1, 1),
          ),
        ],
      );

      expect(manga.readChaptersCount, equals(2));
    });

    test('resolvedTotalChapters falls back to chapter count when zero', () {
      final manga = Manga(
        id: 'manga-1',
        sourceId: 'source-1',
        title: 'Sample',
        chapters: <Chapter>[
          const Chapter(
            id: 'c1',
            mangaId: 'manga-1',
            sourceId: 'source-1',
            title: 'One',
            number: 1,
          ),
          const Chapter(
            id: 'c2',
            mangaId: 'manga-1',
            sourceId: 'source-1',
            title: 'Two',
            number: 2,
          ),
        ],
      );

      expect(manga.resolvedTotalChapters, equals(2));
    });

    test('resolvedTotalChapters honours explicit total', () {
      final manga = Manga(
        id: 'manga-1',
        sourceId: 'source-1',
        title: 'Sample',
        totalChapters: 10,
        chapters: const <Chapter>[
          Chapter(
            id: 'c1',
            mangaId: 'manga-1',
            sourceId: 'source-1',
            title: 'One',
            number: 1,
          ),
        ],
      );

      expect(manga.resolvedTotalChapters, equals(10));
    });
  });
}
