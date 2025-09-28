import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_offline/core/di/service_locator.dart';
import 'package:manga_offline/core/utils/reader_preferences.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_task.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/repositories/download_repository.dart';
import 'package:manga_offline/presentation/screens/reader/offline_reader_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubDownloadRepository implements DownloadRepository {
  _StubDownloadRepository(this.pages);

  final List<String> pages;

  @override
  Future<void> enqueueChapterDownload(Chapter chapter) async {}

  @override
  Future<void> enqueueMangaDownload(Manga manga) async {}

  @override
  Stream<List<DownloadTask>> watchDownloadQueue() =>
      const Stream<List<DownloadTask>>.empty();

  @override
  Future<List<String>> listLocalChapterPages({
    required String sourceId,
    required String mangaId,
    required String chapterId,
  }) async {
    return pages;
  }
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
      ..registerSingleton<DownloadRepository>(
        _StubDownloadRepository(<String>[
          '/tmp/page1.png',
          '/tmp/page2.png',
          '/tmp/page3.png',
        ]),
      );
  });

  tearDown(() async {
    await serviceLocator.reset();
  });

  testWidgets('renders continuous vertical list and reports progress', (
    WidgetTester tester,
  ) async {
    final List<int> progressEvents = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: OfflineReaderScreen(
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
