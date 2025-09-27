import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:manga_offline/data/datasources/manga_local_datasource.dart';
import 'package:manga_offline/data/models/chapter_model.dart';
import 'package:manga_offline/data/models/manga_model.dart';
import 'package:manga_offline/data/repositories/manga_repository_impl.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/domain/entities/manga.dart';

class _MockMangaLocalDataSource extends Mock implements MangaLocalDataSource {}

void main() {
  late _MockMangaLocalDataSource local;
  late MangaRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(
      MangaModel()
        ..referenceId = 'fallback'
        ..sourceId = 'source'
        ..title = 'Fallback'
        ..status = DownloadStatus.notDownloaded,
    );
    registerFallbackValue(<ChapterModel>[]);
  });

  setUp(() {
    local = _MockMangaLocalDataSource();
    repository = MangaRepositoryImpl(localDataSource: local);
  });

  test('watchLocalLibrary emits mangas with their chapters', () async {
    final mangaModel = MangaModel()
      ..referenceId = 'manga-1'
      ..sourceId = 'source-1'
      ..title = 'Manga'
      ..status = DownloadStatus.notDownloaded;
    final chapterModel = ChapterModel()
      ..referenceId = 'chapter-1'
      ..mangaReferenceId = 'manga-1'
      ..sourceId = 'source-1'
      ..title = 'Capítulo 1'
      ..number = 1
      ..status = DownloadStatus.notDownloaded;

    when(
      () => local.watchMangas(),
    ).thenAnswer((_) => Stream.value([mangaModel]));
    when(
      () => local.getChaptersForManga('manga-1'),
    ).thenAnswer((_) async => [chapterModel]);

    await expectLater(
      repository.watchLocalLibrary(),
      emits(
        predicate<List<Manga>>((mangas) {
          return mangas.length == 1 && mangas.first.chapters.length == 1;
        }),
      ),
    );
  });

  test('saveManga persists model and chapters', () async {
    final chapter = Chapter(
      id: 'chapter-1',
      mangaId: 'manga-1',
      sourceId: 'source-1',
      title: 'Capítulo 1',
      number: 1,
      status: DownloadStatus.notDownloaded,
    );
    final manga = Manga(
      id: 'manga-1',
      sourceId: 'source-1',
      title: 'Manga 1',
      chapters: [chapter],
    );

    when(
      () => local.putManga(
        any(),
        chapters: any(named: 'chapters'),
        replaceChapters: any(named: 'replaceChapters'),
      ),
    ).thenAnswer((_) async {});

    await repository.saveManga(manga);

    final captured = verify(
      () => local.putManga(
        captureAny(),
        chapters: captureAny(named: 'chapters'),
        replaceChapters: captureAny(named: 'replaceChapters'),
      ),
    ).captured;

    final MangaModel stored = captured[0] as MangaModel;
    final List<ChapterModel> storedChapters = (captured[1] as List<dynamic>)
        .cast<ChapterModel>();
    final bool replaceChapters = captured[2] as bool;

    expect(stored.referenceId, equals('manga-1'));
    expect(storedChapters, hasLength(1));
    expect(storedChapters.first.referenceId, equals('chapter-1'));
    expect(replaceChapters, isTrue);
  });
}
