import 'package:manga_offline/domain/entities/chapter.dart';

/// Callback invoked whenever the reader reports progress for a chapter.
typedef ChapterProgressCallback = void Function(Chapter chapter, int pageIndex);

/// Callback used to request a download for a chapter when reading online.
typedef ChapterDownloadCallback = Future<void> Function(Chapter chapter);
