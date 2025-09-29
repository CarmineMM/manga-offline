import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:manga_offline/core/di/service_locator.dart';
import 'package:manga_offline/core/utils/reader_preferences.dart';
import 'package:manga_offline/domain/repositories/download_repository.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/presentation/screens/reader/chapter_reader_route.dart';
import 'package:manga_offline/presentation/screens/reader/chapter_reader_types.dart';
import 'package:manga_offline/presentation/screens/reader/widgets/chapter_navigation_bar.dart';

/// Simple offline reader that displays the already downloaded image files for
/// a given chapter in a [PageView].
class OfflineReaderScreen extends StatefulWidget {
  const OfflineReaderScreen({
    super.key,
    required this.sourceId,
    required this.mangaId,
    required this.chapterId,
    required this.chapterTitle,
    this.initialPage = 0,
    required this.chapters,
    required this.chapterIndex,
    this.onChapterProgress,
    this.onDownloadChapter,
  });

  final String sourceId;
  final String mangaId;
  final String chapterId;
  final String chapterTitle;
  final int initialPage;
  final List<Chapter> chapters;
  final int chapterIndex;
  final ChapterProgressCallback? onChapterProgress;
  final ChapterDownloadCallback? onDownloadChapter;

  @override
  State<OfflineReaderScreen> createState() => _OfflineReaderScreenState();
}

class _OfflineReaderScreenState extends State<OfflineReaderScreen> {
  final DownloadRepository _downloadRepository = serviceLocator();
  final ReaderPreferences _readerPrefs = serviceLocator();
  late PageController _controller;
  late final ScrollController _verticalController;
  List<String> _paths = <String>[];
  List<GlobalKey> _pageKeys = <GlobalKey>[];
  bool _loading = true;
  bool _verticalMode = true;
  int _currentPage = 0;
  int? _pendingScrollIndex;
  int _scrollRetryCount = 0;
  int _pendingScrollGeneration = 0;
  bool _initialProgressDispatched = false;

  bool get _hasPrevious => widget.chapterIndex > 0;
  bool get _hasNext => widget.chapterIndex < widget.chapters.length - 1;
  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialPage);
    _verticalController = ScrollController();
    _verticalMode = _readerPrefs.mode == ReaderMode.vertical;
    _load();
    _currentPage = widget.initialPage;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final files = await _downloadRepository.listLocalChapterPages(
      sourceId: widget.sourceId,
      mangaId: widget.mangaId,
      chapterId: widget.chapterId,
    );
    if (!mounted) return;
    setState(() {
      _paths = files;
      _pageKeys = List<GlobalKey>.generate(files.length, (_) => GlobalKey());
      _loading = false;
    });
    _currentPage = widget.initialPage.clamp(
      0,
      _paths.isEmpty ? 0 : _paths.length - 1,
    );
    _initialProgressDispatched = false;
    if (_verticalMode) {
      _scheduleScrollToIndex(
        _currentPage,
        delay: const Duration(milliseconds: 1500),
      );
    } else if (_controller.hasClients && _paths.isNotEmpty) {
      _controller.jumpToPage(_currentPage);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients && mounted && _paths.isNotEmpty) {
          _controller.jumpToPage(_currentPage);
        }
      });
    }
    if (_paths.isNotEmpty) {
      _emitProgress(_currentPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chapterTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Recargar',
          ),
          IconButton(
            icon: Icon(_verticalMode ? Icons.view_agenda : Icons.view_day),
            tooltip: _verticalMode
                ? 'Cambiar a paginado'
                : 'Cambiar a vertical',
            onPressed: () async {
              setState(() {
                _verticalMode = !_verticalMode;
                if (_verticalMode) {
                  _scheduleScrollToIndex(_currentPage);
                } else if (_controller.hasClients) {
                  _controller.jumpToPage(_currentPage);
                }
              });
              await _readerPrefs.setMode(
                _verticalMode ? ReaderMode.vertical : ReaderMode.paged,
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    Widget content;
    if (_loading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_paths.isEmpty) {
      content = Center(
        child: Text(
          'No se encontraron páginas locales para este capítulo.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      content = _verticalMode
          ? _buildVerticalReader()
          : _buildHorizontalReader();
    }

    final showNavigation = !_loading && widget.chapters.length > 1;
    if (!showNavigation) {
      return content;
    }

    return Column(
      children: <Widget>[
        Expanded(child: content),
        ChapterNavigationBar(
          onPrevious: _hasPrevious ? () => _openSiblingChapter(-1) : null,
          onNext: _hasNext ? () => _openSiblingChapter(1) : null,
        ),
      ],
    );
  }

  Widget _buildHorizontalReader() {
    return PageView.builder(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      padEnds: false,
      onPageChanged: _emitProgress,
      itemCount: _paths.length,
      itemBuilder: (BuildContext context, int index) {
        final path = _paths[index];
        return _PageImageView(path: path, enablePan: true, fit: BoxFit.contain);
      },
    );
  }

  Widget _buildVerticalReader() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _tryApplyPendingScroll(_pendingScrollGeneration),
    );
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: ListView.builder(
        controller: _verticalController,
        padding: EdgeInsets.zero,
        itemCount: _paths.length,
        itemBuilder: (BuildContext context, int index) {
          final path = _paths[index];
          return Container(
            key: _pageKeys[index],
            child: _PageImageView(
              path: path,
              enablePan: false,
              fit: BoxFit.fitWidth,
            ),
          );
        },
      ),
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!_verticalMode || _paths.isEmpty) {
      return false;
    }
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification ||
        notification is UserScrollNotification) {
      final index = _visibleIndexForMetrics(notification.metrics);
      if (index != null) {
        _emitProgress(index);
      }
    }
    return false;
  }

  int? _visibleIndexForMetrics(ScrollMetrics metrics) {
    double bestDistance = double.infinity;
    int? bestIndex;
    for (var i = 0; i < _pageKeys.length; i++) {
      final context = _pageKeys[i].currentContext;
      if (context == null) continue;
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox) continue;
      final viewport = RenderAbstractViewport.of(renderObject);
      final offset = viewport.getOffsetToReveal(renderObject, 0.5).offset;
      final distance = (offset - metrics.pixels).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  void _scheduleScrollToIndex(int index, {Duration delay = Duration.zero}) {
    if (!_verticalMode || index < 0 || index >= _pageKeys.length) {
      return;
    }
    _pendingScrollIndex = index;
    _scrollRetryCount = 0;
    final token = ++_pendingScrollGeneration;

    void queueAttempt() {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && token == _pendingScrollGeneration) {
          _tryApplyPendingScroll(token);
        }
      });
    }

    if (delay > Duration.zero) {
      Future<void>.delayed(delay, () {
        if (!mounted) return;
        if (token != _pendingScrollGeneration) return;
        queueAttempt();
      });
    } else {
      queueAttempt();
    }
  }

  void _tryApplyPendingScroll(int token) {
    if (!mounted) return;
    final targetIndex = _pendingScrollIndex;
    if (targetIndex == null) {
      return;
    }
    if (token != _pendingScrollGeneration) {
      return;
    }
    if (targetIndex < 0 || targetIndex >= _pageKeys.length) {
      _pendingScrollIndex = null;
      return;
    }
    final context = _pageKeys[targetIndex].currentContext;
    if (context == null) {
      if (_scrollRetryCount < 5) {
        _scrollRetryCount += 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && token == _pendingScrollGeneration) {
            _tryApplyPendingScroll(token);
          }
        });
      }
      return;
    }
    _pendingScrollIndex = null;
    _scrollRetryCount = 0;
    Scrollable.ensureVisible(context, alignment: 0.05, duration: Duration.zero);
  }

  void _emitProgress(int index) {
    if (index < 0 || (_paths.isNotEmpty && index >= _paths.length)) {
      return;
    }
    if (!_initialProgressDispatched || index != _currentPage) {
      _currentPage = index;
      _initialProgressDispatched = true;
      final chapter = widget.chapters[widget.chapterIndex];
      widget.onChapterProgress?.call(chapter, index);
    }
  }

  @override
  void dispose() {
    final chapter = widget.chapters[widget.chapterIndex];
    widget.onChapterProgress?.call(chapter, _currentPage);
    _controller.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _openSiblingChapter(int delta) {
    final targetIndex = widget.chapterIndex + delta;
    if (targetIndex < 0 || targetIndex >= widget.chapters.length) {
      return;
    }
    final target = widget.chapters[targetIndex];
    final route = buildChapterReaderRoute(
      chapter: target,
      chapters: widget.chapters,
      chapterIndex: targetIndex,
      onProgress: widget.onChapterProgress,
      onDownload: widget.onDownloadChapter,
    );
    Navigator.of(context).pushReplacement(route);
  }
}

class _PageImageView extends StatelessWidget {
  const _PageImageView({
    required this.path,
    required this.enablePan,
    required this.fit,
  });

  final String path;
  final bool enablePan;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.7,
      maxScale: 4,
      panEnabled: enablePan,
      child: Center(
        child: Image.file(
          File(path),
          fit: fit,
          alignment: Alignment.topCenter,
          width: double.infinity,
          errorBuilder: (c, e, s) =>
              const Icon(Icons.broken_image, color: Colors.white70, size: 64),
        ),
      ),
    );
  }
}
