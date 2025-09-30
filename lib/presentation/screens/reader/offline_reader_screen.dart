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
  static const double _kAutoHideThreshold = 120;
  static const Duration _kSlideDuration = Duration(milliseconds: 220);
  static const Duration _kFadeDuration = Duration(milliseconds: 150);

  final DownloadRepository _downloadRepository = serviceLocator();
  final ReaderPreferences _readerPrefs = serviceLocator();
  late PageController _controller;
  late final ScrollController _verticalController;
  List<String> _paths = <String>[];
  List<GlobalKey> _pageKeys = <GlobalKey>[];
  bool _loading = true;
  bool _verticalMode = true;
  int _currentPage = 0;
  bool _initialProgressDispatched = false;
  bool _uiVisible = true;
  double _scrollOffsetAccumulator = 0;

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
    if (!_verticalMode) {
      if (_controller.hasClients && _paths.isNotEmpty) {
        _controller.jumpToPage(_currentPage);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_controller.hasClients && mounted && _paths.isNotEmpty) {
            _controller.jumpToPage(_currentPage);
          }
        });
      }
    }
    if (_paths.isNotEmpty) {
      _emitProgress(_currentPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      extendBody: true,
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
                if (!_verticalMode && _controller.hasClients) {
                  _controller.jumpToPage(_currentPage);
                }
              });
              _scrollOffsetAccumulator = 0;
              _showUi();
              await _readerPrefs.setMode(
                _verticalMode ? ReaderMode.vertical : ReaderMode.paged,
              );
            },
          ),
        ],
      ),
      body: _buildBody(context, theme),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme) {
    final media = MediaQuery.of(context);
    final showNavigation = !_loading && widget.chapters.length > 1;
    final EdgeInsets readerPadding = EdgeInsets.only(
      bottom:
          media.padding.bottom +
          (showNavigation ? (_uiVisible ? 104 : 24) : 24),
    );

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
          ? _buildVerticalReader(readerPadding)
          : _buildHorizontalReader(readerPadding);
    }

    final bool allowImmersiveGestures = !_loading && _paths.isNotEmpty;
    final Widget interactiveContent = allowImmersiveGestures
        ? GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _toggleUiVisibility,
            child: content,
          )
        : content;

    return Stack(
      children: <Widget>[
        Positioned.fill(child: interactiveContent),
        if (showNavigation) _buildBottomBar(theme),
      ],
    );
  }

  Widget _buildHorizontalReader(EdgeInsets padding) {
    return Padding(
      padding: padding,
      child: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padEnds: false,
        onPageChanged: _emitProgress,
        itemCount: _paths.length,
        itemBuilder: (BuildContext context, int index) {
          final path = _paths[index];
          return _PageImageView(
            path: path,
            enablePan: true,
            fit: BoxFit.contain,
          );
        },
      ),
    );
  }

  Widget _buildVerticalReader(EdgeInsets padding) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: ListView.builder(
        controller: _verticalController,
        padding: padding,
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

  Widget _buildBottomBar(ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !_uiVisible,
        child: AnimatedSlide(
          duration: _kSlideDuration,
          curve: Curves.easeOut,
          offset: _uiVisible ? Offset.zero : const Offset(0, 1.1),
          child: AnimatedOpacity(
            duration: _kFadeDuration,
            opacity: _uiVisible ? 1 : 0,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              child: ChapterNavigationBar(
                onPrevious: _hasPrevious ? () => _openSiblingChapter(-1) : null,
                onNext: _hasNext ? () => _openSiblingChapter(1) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleUiVisibility() {
    setState(() {
      _uiVisible = !_uiVisible;
    });
    _scrollOffsetAccumulator = 0;
  }

  void _showUi() {
    if (_uiVisible) {
      _scrollOffsetAccumulator = 0;
      return;
    }
    setState(() {
      _uiVisible = true;
    });
    _scrollOffsetAccumulator = 0;
  }

  void _hideUi() {
    if (!_uiVisible) {
      return;
    }
    setState(() {
      _uiVisible = false;
    });
    _scrollOffsetAccumulator = 0;
  }

  void _handleAutoHide(ScrollNotification notification) {
    if (!_verticalMode || _paths.isEmpty) {
      return;
    }
    if (notification.metrics.axis != Axis.vertical) {
      return;
    }
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta == 0) {
        return;
      }
      _scrollOffsetAccumulator += delta;
      if (_scrollOffsetAccumulator >= _kAutoHideThreshold) {
        _hideUi();
        _scrollOffsetAccumulator = 0;
      } else if (_scrollOffsetAccumulator <= -_kAutoHideThreshold) {
        _showUi();
        _scrollOffsetAccumulator = 0;
      }
    } else if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.idle) {
      _scrollOffsetAccumulator = 0;
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!_verticalMode || _paths.isEmpty) {
      return false;
    }
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    _handleAutoHide(notification);
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
