import 'package:flutter/material.dart';
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
  bool _loading = true;
  bool _error = false;
  bool _verticalMode = true;
  List<PageImage> _pages = <PageImage>[];
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialPage);
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
        _loading = false;
      });
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
              setState(() => _verticalMode = !_verticalMode);
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
    // Unificamos ambas modalidades usando PageView para tener onPageChanged y registrar progreso.
    return PageView.builder(
      scrollDirection: _verticalMode ? Axis.vertical : Axis.horizontal,
      controller: _pageController,
      onPageChanged: (index) {
        _currentPage = index;
        widget.onProgress?.call(index);
      },
      itemCount: _pages.length,
      itemBuilder: (context, index) => _NetworkPageImage(page: _pages[index]),
    );
  }

  @override
  void dispose() {
    // Último guardado de progreso
    widget.onProgress?.call(_currentPage);
    _pageController.dispose();
    super.dispose();
  }
}

class _NetworkPageImage extends StatelessWidget {
  const _NetworkPageImage({required this.page});
  final PageImage page;
  @override
  Widget build(BuildContext context) {
    final url = page.remoteUrl;
    return InteractiveViewer(
      minScale: 0.7,
      maxScale: 4,
      child: Center(
        child: url == null || url.isEmpty
            ? const Icon(Icons.broken_image, color: Colors.white70, size: 64)
            : Image.network(
                url,
                fit: BoxFit.contain,
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
