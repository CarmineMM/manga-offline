import 'dart:io';

import 'package:flutter/material.dart';
import 'package:manga_offline/core/di/service_locator.dart';
import 'package:manga_offline/domain/repositories/download_repository.dart';

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
  });

  final String sourceId;
  final String mangaId;
  final String chapterId;
  final String chapterTitle;
  final int initialPage;

  @override
  State<OfflineReaderScreen> createState() => _OfflineReaderScreenState();
}

class _OfflineReaderScreenState extends State<OfflineReaderScreen> {
  final DownloadRepository _downloadRepository = serviceLocator();
  late PageController _controller;
  List<String> _paths = <String>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialPage);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final files = await _downloadRepository.listLocalChapterPages(
      sourceId: widget.sourceId,
      mangaId: widget.mangaId,
      chapterId: widget.chapterId,
    );
    setState(() {
      _paths = files;
      _loading = false;
    });
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
        ],
      ),
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _paths.isEmpty
          ? Center(
              child: Text(
                'No se encontraron páginas locales para este capítulo.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            )
          : PageView.builder(
              controller: _controller,
              itemCount: _paths.length,
              itemBuilder: (context, index) {
                final path = _paths[index];
                return InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 4,
                  child: Center(
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.broken_image,
                        color: Colors.white70,
                        size: 64,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
