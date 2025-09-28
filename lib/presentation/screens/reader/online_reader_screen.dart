import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:manga_offline/core/di/service_locator.dart';
import 'package:manga_offline/core/utils/reader_preferences.dart';
import 'package:manga_offline/domain/entities/page_image.dart';
import 'package:manga_offline/domain/usecases/fetch_chapter_pages.dart';

/// Reader que carga páginas desde la red sin almacenarlas localmente.
class OnlineReaderScreen extends StatefulWidget {
  const OnlineReaderScreen({
    super.key,
    required this.sourceId,
    required this.mangaId,
    required this.chapterId,
    required this.chapterTitle,
    this.initialPage = 0,
    this.onProgress,
    this.onDownloadChapter,
  });

  final String sourceId;
  final String mangaId;
  final String chapterId;
  final String chapterTitle;
  final int initialPage;
  final void Function(int pageIndex)? onProgress;
  final VoidCallback? onDownloadChapter;

  @override
  State<OnlineReaderScreen> createState() => _OnlineReaderScreenState();
}

class _OnlineReaderScreenState extends State<OnlineReaderScreen> {
  final FetchChapterPages _fetchChapterPages = serviceLocator();
  final ReaderPreferences _readerPrefs = serviceLocator();
  late PageController _pageController;
  late final ScrollController _verticalController;
  bool _loading = true;
  bool _error = false;
  bool _verticalMode = true;
  List<PageImage> _pages = <PageImage>[];
  int _currentPage = 0;
  List<GlobalKey> _pageKeys = <GlobalKey>[];
  int? _pendingScrollIndex;
  int _scrollRetryCount = 0;
  bool _initialProgressDispatched = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialPage);
    _verticalController = ScrollController();
    _verticalMode = _readerPrefs.mode == ReaderMode.vertical;
    _load();
    _currentPage = widget.initialPage;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final pages = await _fetchChapterPages(
        sourceId: widget.sourceId,
        mangaId: widget.mangaId,
        chapterId: widget.chapterId,
      );
      pages.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
      if (!mounted) return;
      setState(() {
        _pages = pages;
        _pageKeys = List<GlobalKey>.generate(pages.length, (_) => GlobalKey());
        _loading = false;
      });
      _currentPage = widget.initialPage.clamp(
        0,
        _pages.isEmpty ? 0 : _pages.length - 1,
      );
      _initialProgressDispatched = false;
      if (_verticalMode) {
        _scheduleScrollToIndex(_currentPage);
      } else if (_pageController.hasClients && _pages.isNotEmpty) {
        _pageController.jumpToPage(_currentPage);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients && mounted && _pages.isNotEmpty) {
            _pageController.jumpToPage(_currentPage);
          }
        });
      }
      if (_pages.isNotEmpty) {
        _emitProgress(_currentPage);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.chapterTitle),
        actions: [
          if (widget.onDownloadChapter != null)
            IconButton(
              tooltip: 'Descargar capítulo',
              icon: const Icon(Icons.download),
              onPressed: widget.onDownloadChapter,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _load,
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
                } else if (_pageController.hasClients) {
                  _pageController.jumpToPage(_currentPage);
                }
              });
              await _readerPrefs.setMode(
                _verticalMode ? ReaderMode.vertical : ReaderMode.paged,
              );
            },
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error) {
      return _ErrorView(onRetry: _load);
    }
    if (_pages.isEmpty) {
      return const _EmptyView();
    }
    return _verticalMode ? _buildVerticalReader() : _buildHorizontalReader();
  }

  Widget _buildHorizontalReader() {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.horizontal,
      padEnds: false,
      onPageChanged: _emitProgress,
      itemCount: _pages.length,
      itemBuilder: (BuildContext context, int index) {
        final page = _pages[index];
        return _NetworkPageImage(
          page: page,
          enablePan: true,
          fit: BoxFit.contain,
        );
      },
    );
  }

  Widget _buildVerticalReader() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _tryApplyPendingScroll(),
    );
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: ListView.builder(
        controller: _verticalController,
        padding: EdgeInsets.zero,
        itemCount: _pages.length,
        itemBuilder: (BuildContext context, int index) {
          final page = _pages[index];
          return Container(
            key: _pageKeys[index],
            child: _NetworkPageImage(
              page: page,
              enablePan: false,
              fit: BoxFit.fitWidth,
            ),
          );
        },
      ),
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!_verticalMode || _pages.isEmpty) {
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

  void _scheduleScrollToIndex(int index) {
    if (!_verticalMode || index < 0 || index >= _pageKeys.length) {
      return;
    }
    _pendingScrollIndex = index;
    _scrollRetryCount = 0;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _tryApplyPendingScroll(),
    );
  }

  void _tryApplyPendingScroll() {
    if (!mounted) return;
    final targetIndex = _pendingScrollIndex;
    if (targetIndex == null) {
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
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _tryApplyPendingScroll(),
        );
      }
      return;
    }
    _pendingScrollIndex = null;
    _scrollRetryCount = 0;
    Scrollable.ensureVisible(context, alignment: 0.05, duration: Duration.zero);
  }

  void _emitProgress(int index) {
    if (index < 0 || (_pages.isNotEmpty && index >= _pages.length)) {
      return;
    }
    if (!_initialProgressDispatched || index != _currentPage) {
      _currentPage = index;
      _initialProgressDispatched = true;
      widget.onProgress?.call(index);
    }
  }

  @override
  void dispose() {
    // Último guardado de progreso
    widget.onProgress?.call(_currentPage);
    _pageController.dispose();
    _verticalController.dispose();
    super.dispose();
  }
}

class _NetworkPageImage extends StatelessWidget {
  const _NetworkPageImage({
    required this.page,
    required this.enablePan,
    required this.fit,
  });
  final PageImage page;
  final bool enablePan;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final url = page.remoteUrl;
    return InteractiveViewer(
      minScale: 0.7,
      maxScale: 4,
      panEnabled: enablePan,
      child: Center(
        child: url == null || url.isEmpty
            ? const Icon(Icons.broken_image, color: Colors.white70, size: 64)
            : Image.network(
                url,
                fit: fit,
                alignment: Alignment.topCenter,
                width: double.infinity,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 300,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  );
                },
                errorBuilder: (context, error, stack) => const Icon(
                  Icons.broken_image,
                  color: Colors.white70,
                  size: 64,
                ),
              ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.white70),
          const SizedBox(height: 12),
          const Text(
            'No pudimos cargar las páginas.\nRevisa tu conexión e intenta nuevamente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No hay páginas disponibles para este capítulo.',
        style: TextStyle(color: Colors.white70),
        textAlign: TextAlign.center,
      ),
    );
  }
}
