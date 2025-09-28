import 'package:flutter/material.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/presentation/screens/reader/chapter_reader_types.dart';
import 'package:manga_offline/presentation/screens/reader/offline_reader_screen.dart';
import 'package:manga_offline/presentation/screens/reader/online_reader_screen.dart';

/// Builds the appropriate reader route (online or offline) for the given chapter.
MaterialPageRoute<void> buildChapterReaderRoute({
  required Chapter chapter,
  required List<Chapter> chapters,
  required int chapterIndex,
  ChapterProgressCallback? onProgress,
  ChapterDownloadCallback? onDownload,
}) {
  final initialPage = (chapter.lastReadPage ?? 1) - 1;
  final normalizedPage = initialPage.clamp(0, 1 << 30);

  return MaterialPageRoute<void>(
    builder: (_) {
      if (chapter.status == DownloadStatus.downloaded) {
        return OfflineReaderScreen(
          sourceId: chapter.sourceId,
          mangaId: chapter.mangaId,
          chapterId: chapter.id,
          chapterTitle: chapter.title,
          initialPage: normalizedPage,
          chapters: chapters,
          chapterIndex: chapterIndex,
          onChapterProgress: onProgress,
          onDownloadChapter: onDownload,
        );
      }

      return OnlineReaderScreen(
        sourceId: chapter.sourceId,
        mangaId: chapter.mangaId,
        chapterId: chapter.id,
        chapterTitle: chapter.title,
        initialPage: normalizedPage,
        chapters: chapters,
        chapterIndex: chapterIndex,
        onChapterProgress: onProgress,
        onDownloadChapter: onDownload,
      );
    },
  );
}
