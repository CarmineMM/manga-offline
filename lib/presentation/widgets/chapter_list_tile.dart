import 'package:flutter/material.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';

/// Visual tile for presenting a chapter and its download status.
class ChapterListTile extends StatefulWidget {
  /// Creates a new [ChapterListTile].
  const ChapterListTile({
    super.key,
    required this.chapter,
    this.onDownload,
    this.onReadOnline,
    this.onReadOffline,
    this.onReadStatusChanged,
  });

  /// Chapter information rendered by the tile.
  final Chapter chapter;

  /// Callback triggered when the user requests a download.
  final void Function(Chapter chapter)? onDownload;

  /// Callback triggered when the user wants to read online.
  final void Function(Chapter chapter)? onReadOnline;

  /// Callback triggered when the user wants to read offline.
  final void Function(Chapter chapter)? onReadOffline;

  /// Callback triggered when the user toggles the read status.
  final void Function(Chapter chapter, bool markAsRead)? onReadStatusChanged;

  @override
  State<ChapterListTile> createState() => _ChapterListTileState();
}

class _ChapterListTileState extends State<ChapterListTile> {
  bool _isDownloadRequested = false;

  @override
  void didUpdateWidget(covariant ChapterListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chapter.id != oldWidget.chapter.id) {
      _isDownloadRequested = false;
      return;
    }
    if (_isDownloadRequested) {
      final status = widget.chapter.status;
      if (status != DownloadStatus.notDownloaded &&
          status != DownloadStatus.failed) {
        _isDownloadRequested = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapter;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final double? progress;
    if (chapter.totalPages > 0) {
      progress = (chapter.downloadedPages / chapter.totalPages).clamp(0.0, 1.0);
    } else {
      progress = null;
    }

    final isRead =
        chapter.lastReadAt != null || (chapter.lastReadPage ?? 0) > 0;
    final readTooltip = isRead ? 'Marcar como no leído' : 'Marcar como leído';
    final isDownloadLoading =
        _isDownloadRequested &&
        (chapter.status == DownloadStatus.notDownloaded ||
            chapter.status == DownloadStatus.failed);

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
                const SizedBox(width: 8),
                _ReadToggle(
                  isRead: isRead,
                  tooltip: readTooltip,
                  onChanged: widget.onReadStatusChanged != null
                      ? (bool value) =>
                            widget.onReadStatusChanged!(chapter, value)
                      : null,
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
                onRequestDownload: widget.onDownload != null
                    ? () {
                        setState(() => _isDownloadRequested = true);
                        widget.onDownload!(chapter);
                      }
                    : null,
                onReadOnline: widget.onReadOnline,
                onReadOffline: widget.onReadOffline,
                isDownloadLoading: isDownloadLoading,
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

class _ReadToggle extends StatelessWidget {
  const _ReadToggle({
    required this.isRead,
    required this.tooltip,
    this.onChanged,
  });

  final bool isRead;
  final String tooltip;
  final void Function(bool value)? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: isRead
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurfaceVariant,
      fontWeight: isRead ? FontWeight.w600 : FontWeight.w500,
    );

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isRead) ...<Widget>[
            Text('Leído', style: labelStyle),
            const SizedBox(width: 8),
          ],
          Checkbox(
            value: isRead,
            onChanged: onChanged != null
                ? (bool? value) => onChanged!(value ?? false)
                : null,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ChapterActions extends StatelessWidget {
  const _ChapterActions({
    required this.chapter,
    this.onRequestDownload,
    this.onReadOnline,
    this.onReadOffline,
    this.isDownloadLoading = false,
  });

  final Chapter chapter;
  final VoidCallback? onRequestDownload;
  final void Function(Chapter chapter)? onReadOnline;
  final void Function(Chapter chapter)? onReadOffline;
  final bool isDownloadLoading;

  @override
  Widget build(BuildContext context) {
    switch (chapter.status) {
      case DownloadStatus.notDownloaded:
      case DownloadStatus.failed:
        return _buildPendingActions(
          context,
          isRetry: chapter.status == DownloadStatus.failed,
          isLoading: isDownloadLoading,
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

  Widget _buildPendingActions(
    BuildContext context, {
    required bool isRetry,
    required bool isLoading,
  }) {
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
          onPressed: isLoading
              ? null
              : onRequestDownload ??
                    () => _showPendingMessage(
                      context,
                      'Estamos preparando el gestor de descargas.',
                    ),
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isRetry ? 'Reintentar descarga' : 'Descargar'),
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
