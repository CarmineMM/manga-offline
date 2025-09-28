import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/presentation/widgets/manga_library_tile.dart';

void main() {
  testWidgets('shows remaining chapters when downloads are pending', (
    tester,
  ) async {
    const manga = Manga(
      id: 'sample-manga',
      sourceId: 'olympus',
      title: 'Sample Manga',
      status: DownloadStatus.downloading,
      downloadedChapters: 2,
      totalChapters: 5,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MangaLibraryTile(
            manga: manga,
            showDownloadProgressDetails: true,
          ),
        ),
      ),
    );

    expect(find.text('3 capítulos pendientes por descargar'), findsOneWidget);
    expect(find.text('2/5 capítulos listos'), findsOneWidget);
  });

  testWidgets('shows completed label when everything is downloaded', (
    tester,
  ) async {
    const manga = Manga(
      id: 'complete-manga',
      sourceId: 'eden',
      title: 'Complete Manga',
      status: DownloadStatus.downloaded,
      downloadedChapters: 4,
      totalChapters: 4,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MangaLibraryTile(
            manga: manga,
            showDownloadProgressDetails: true,
          ),
        ),
      ),
    );

    expect(find.text('4/4 capítulos listos'), findsOneWidget);
    expect(
      find.text('Todos los capítulos están disponibles offline'),
      findsOneWidget,
    );
  });
}
