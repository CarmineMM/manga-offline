import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/presentation/widgets/cover_image_overrides.dart';
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

  testWidgets('uses local cover image when cached path exists', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('cover-test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final coverFile = File('${tempDir.path}/cover.png');
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
    );
    coverFile.writeAsBytesSync(bytes, flush: true);

    addTearDown(() => debugLocalCoverBuilderOverride = null);
    debugLocalCoverBuilderOverride = (context, path) {
      return Container(
        key: const Key('cover-local-override'),
        alignment: Alignment.center,
        child: Text(path),
      );
    };

    final manga = Manga(
      id: 'local-cover',
      sourceId: 'olympus',
      title: 'Local Cover',
      coverImagePath: coverFile.path,
      coverImageUrl: 'https://example.com/remote.png',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MangaLibraryTile(manga: manga)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('cover-local-override')), findsOneWidget);
  });
}
