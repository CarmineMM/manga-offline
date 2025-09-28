import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/presentation/widgets/chapter_list_tile.dart';

Chapter _buildChapter({DateTime? lastReadAt, int? lastReadPage}) {
  return Chapter(
    id: 'chapter-1',
    mangaId: 'manga-1',
    sourceId: 'source-1',
    title: 'Capítulo 1',
    number: 1,
    status: DownloadStatus.downloaded,
    totalPages: 20,
    downloadedPages: 20,
    lastReadAt: lastReadAt,
    lastReadPage: lastReadPage,
  );
}

void main() {
  testWidgets('shows read indicator and toggles to unread', (tester) async {
    final chapter = _buildChapter(lastReadAt: DateTime.now(), lastReadPage: 20);
    Chapter? toggledChapter;
    bool? markAsRead;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChapterListTile(
            chapter: chapter,
            onReadStatusChanged: (selected, value) {
              toggledChapter = selected;
              markAsRead = value;
            },
          ),
        ),
      ),
    );

    expect(find.text('Leído'), findsOneWidget);
    final Checkbox checkbox = tester.widget(find.byType(Checkbox));
    expect(checkbox.value, isTrue);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(toggledChapter?.id, chapter.id);
    expect(markAsRead, isFalse);
  });

  testWidgets('invokes callback to mark as read when unread', (tester) async {
    final chapter = _buildChapter();
    Chapter? toggledChapter;
    bool? markAsRead;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChapterListTile(
            chapter: chapter,
            onReadStatusChanged: (selected, value) {
              toggledChapter = selected;
              markAsRead = value;
            },
          ),
        ),
      ),
    );

    expect(find.text('Leído'), findsNothing);
    final Checkbox checkbox = tester.widget(find.byType(Checkbox));
    expect(checkbox.value, isFalse);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(toggledChapter?.id, chapter.id);
    expect(markAsRead, isTrue);
  });

  testWidgets('shows loader while download request is pending', (tester) async {
    final baseChapter = _buildChapter().copyWith(
      status: DownloadStatus.notDownloaded,
      downloadedPages: 0,
      totalPages: 0,
    );
    Chapter? requested;

    Widget buildWithChapter(Chapter chapter) {
      return MaterialApp(
        home: Scaffold(
          body: ChapterListTile(
            key: const ValueKey('chapter-tile'),
            chapter: chapter,
            onDownload: (selected) => requested = selected,
          ),
        ),
      );
    }

    await tester.pumpWidget(buildWithChapter(baseChapter));

    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Descargar'));
    await tester.pump();

    expect(requested, isNotNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final queuedChapter = baseChapter.copyWith(status: DownloadStatus.queued);
    await tester.pumpWidget(buildWithChapter(queuedChapter));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.widgetWithText(FilledButton, 'En cola'), findsOneWidget);
  });
}
