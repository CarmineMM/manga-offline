import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_offline/core/di/service_locator.dart';
import 'package:manga_offline/core/utils/reader_preferences.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/entities/page_image.dart';
import 'package:manga_offline/domain/repositories/catalog_repository.dart';
import 'package:manga_offline/domain/usecases/fetch_chapter_pages.dart';
import 'package:manga_offline/presentation/screens/reader/online_reader_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubCatalogRepository implements CatalogRepository {
  _StubCatalogRepository(this.pages);
  final List<PageImage> pages;

  @override
  Future<List<PageImage>> fetchChapterPages({
    required String sourceId,
    required String mangaId,
    required String chapterId,
  }) async {
    return pages;
  }

  @override
  Future<Manga> fetchMangaDetail({
    required String sourceId,
    required String mangaId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Manga>> fetchCatalog({required String sourceId}) {
    throw UnimplementedError();
  }

  @override
  Future<void> syncCatalog({required String sourceId}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await serviceLocator.reset();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'reader.mode': 'vertical',
    });
    final readerPrefs = await ReaderPreferences.create();
    serviceLocator
      ..registerSingleton<ReaderPreferences>(readerPrefs)
      ..registerSingleton<FetchChapterPages>(
        FetchChapterPages(
          _StubCatalogRepository(
            List<PageImage>.generate(
              4,
              (int index) => PageImage(
                id: 'page-${index + 1}',
                chapterId: 'chapter-1',
                pageNumber: index + 1,
                remoteUrl: null,
              ),
            ),
          ),
        ),
      );
  });

  tearDown(() async {
    await serviceLocator.reset();
  });

  testWidgets('online reader scrolls vertically in continuous mode', (
    WidgetTester tester,
  ) async {
    final List<int> progressEvents = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: OnlineReaderScreen(
          sourceId: 'olympus',
          mangaId: 'manga-1',
          chapterId: 'chapter-1',
          chapterTitle: 'Chapter 1',
          onProgress: progressEvents.add,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
    expect(progressEvents, isNotEmpty);
    expect(progressEvents.first, 0);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
  });
}
