import 'package:flutter_test/flutter_test.dart';
import 'package:manga_offline/data/models/chapter_model.dart';
import 'package:manga_offline/data/models/manga_model.dart';
import 'package:manga_offline/data/models/page_image_model.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/entities/page_image.dart';

void main() {
  group('Data models conversions', () {
    test('MangaModel.fromEntity maps key fields and references', () {
      final chapter = Chapter(
        id: 'chapter-1',
        mangaId: 'manga-1',
        title: 'Capítulo 1',
        number: 1,
        status: DownloadStatus.downloaded,
        totalPages: 10,
        downloadedPages: 10,
      );
      final manga = Manga(
        id: 'manga-1',
        title: 'Manga Test',
        synopsis: 'A sample synopsis',
        coverImageUrl: 'https://example.com/cover.jpg',
        coverImagePath: '/covers/manga-1.jpg',
        status: DownloadStatus.downloaded,
        totalChapters: 20,
        downloadedChapters: 1,
        isFavorite: true,
        chapters: [chapter],
      );

      final model = MangaModel.fromEntity(manga);

      expect(model.referenceId, equals(manga.id));
      expect(model.title, equals(manga.title));
      expect(model.synopsis, equals(manga.synopsis));
      expect(model.coverImageUrl, equals(manga.coverImageUrl));
      expect(model.coverImagePath, equals(manga.coverImagePath));
      expect(model.status, equals(DownloadStatus.downloaded));
      expect(model.totalChapters, equals(20));
      expect(model.downloadedChapters, equals(1));
      expect(model.isFavorite, isTrue);
      expect(model.chapterIds, containsAll(['chapter-1']));
    });

    test('ChapterModel converts to entity with page metadata', () {
      final page = PageImage(
        id: 'page-1',
        chapterId: 'chapter-1',
        pageNumber: 1,
        remoteUrl: 'https://example.com/page-1.jpg',
        localPath: '/pages/page-1.jpg',
        status: DownloadStatus.downloaded,
        fileSizeBytes: 1024,
      );
      final chapter = Chapter(
        id: 'chapter-1',
        mangaId: 'manga-1',
        title: 'Capítulo 1',
        number: 1,
        remoteUrl: 'https://example.com/chapter-1',
        localPath: '/chapters/chapter-1',
        status: DownloadStatus.downloaded,
        totalPages: 1,
        downloadedPages: 1,
        pages: [page],
      );

      final pageModel = PageImageModel.fromEntity(page);
      final chapterModel = ChapterModel.fromEntity(chapter);

      expect(chapterModel.pageIds, contains('page-1'));
      expect(chapterModel.status, equals(DownloadStatus.downloaded));

      final restoredChapter = chapterModel.toEntity(pages: [pageModel]);
      expect(restoredChapter.id, equals(chapter.id));
      expect(restoredChapter.pages.length, equals(1));
      expect(restoredChapter.pages.first.localPath, equals(page.localPath));
    });

    test('MangaModel.toEntity restores chapter metadata', () {
      final chapterModel = ChapterModel()
        ..referenceId = 'chapter-1'
        ..mangaReferenceId = 'manga-1'
        ..title = 'Capítulo 1'
        ..number = 1
        ..status = DownloadStatus.notDownloaded;

      final mangaModel = MangaModel()
        ..referenceId = 'manga-1'
        ..title = 'Manga Test'
        ..status = DownloadStatus.notDownloaded
        ..chapterIds = ['chapter-1'];

      final entity = mangaModel.toEntity(chapters: [chapterModel]);

      expect(entity.id, equals('manga-1'));
      expect(entity.title, equals('Manga Test'));
      expect(entity.chapters, hasLength(1));
      expect(entity.chapters.first.id, equals('chapter-1'));
    });
  });
}
