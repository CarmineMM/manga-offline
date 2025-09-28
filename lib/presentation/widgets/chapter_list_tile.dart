import 'package:flutter/material.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';

/// Visual tile for presenting a chapter and its download status.
class ChapterListTile extends StatelessWidget {
  /// Creates a new [ChapterListTile].
  const ChapterListTile({
    super.key,
    required this.chapter,
    this.onDownload,
    this.onReadOnline,
    this.onReadOffline,
  });

  /// Chapter information rendered by the tile.
  final Chapter chapter;

  /// Callback triggered when the user requests a download.
  final void Function(Chapter chapter)? onDownload;

  /// Callback triggered when the user wants to read online.
  final void Function(Chapter chapter)? onReadOnline;

  /// Callback triggered when the user wants to read offline.
  final void Function(Chapter chapter)? onReadOffline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final double? progress;
    if (chapter.totalPages > 0) {
      progress = (chapter.downloadedPages / chapter.totalPages).clamp(0.0, 1.0);
    } else {
      progress = null;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    chapter.number.toString(),
                    style: textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        chapter.title,
                        style: textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _StatusLabel(status: chapter.status),
                    ],
                  ),
                ),
              ],
            ),
            if (progress != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 4),
                    Text(
                      '${chapter.downloadedPages}/${chapter.totalPages} páginas',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _ChapterActions(
                chapter: chapter,
                onDownload: onDownload,
                onReadOnline: onReadOnline,
                onReadOffline: onReadOffline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final DownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = _resolve(theme.colorScheme);

    return Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(color: color),
    );
  }

  (String, Color) _resolve(ColorScheme colors) {
    switch (status) {
      case DownloadStatus.notDownloaded:
        return ('Sin descargar', colors.onSurfaceVariant);
      case DownloadStatus.queued:
        return ('En cola', colors.secondary);
      case DownloadStatus.downloading:
        return ('Descargando', colors.primary);
      case DownloadStatus.downloaded:
        return ('Disponible offline', colors.tertiary);
      case DownloadStatus.failed:
        return ('Error al descargar', colors.error);
    }
  }
}

class _ChapterActions extends StatelessWidget {
  const _ChapterActions({
    required this.chapter,
    this.onDownload,
    this.onReadOnline,
    this.onReadOffline,
  });

  final Chapter chapter;
  final void Function(Chapter chapter)? onDownload;
  final void Function(Chapter chapter)? onReadOnline;
  final void Function(Chapter chapter)? onReadOffline;

  @override
  Widget build(BuildContext context) {
    switch (chapter.status) {
      case DownloadStatus.notDownloaded:
      case DownloadStatus.failed:
        return _buildPendingActions(
          context,
          isRetry: chapter.status == DownloadStatus.failed,
        );
      case DownloadStatus.queued:
        return Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            onPressed: null,
            child: const Text('En cola'),
          ),
        );
      case DownloadStatus.downloading:
        return Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            onPressed: null,
            child: const Text('Descargando...'),
          ),
        );
      case DownloadStatus.downloaded:
        return Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: onReadOffline != null
                ? () => onReadOffline!(chapter)
                : () => _showPendingMessage(
                    context,
                    'Muy pronto podrás leer el capítulo offline desde aquí.',
                  ),
            child: const Text('Leer offline'),
          ),
        );
    }
  }

  Widget _buildPendingActions(BuildContext context, {required bool isRetry}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        TextButton(
          onPressed: onReadOnline != null
              ? () => onReadOnline!(chapter)
              : () => _showPendingMessage(
                  context,
                  'Conéctate a Internet para leer este capítulo en línea.',
                ),
          child: const Text('Leer en línea'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: onDownload != null
              ? () => onDownload!(chapter)
              : () => _showPendingMessage(
                  context,
                  'Estamos preparando el gestor de descargas.',
                ),
          child: Text(isRetry ? 'Reintentar descarga' : 'Descargar'),
        ),
      ],
    );
  }

  void _showPendingMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
