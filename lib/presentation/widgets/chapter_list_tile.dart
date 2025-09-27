import 'package:flutter/material.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/download_status.dart';

/// Visual tile for presenting a chapter and its download status.
class ChapterListTile extends StatelessWidget {
  /// Creates a new [ChapterListTile].
  const ChapterListTile({super.key, required this.chapter});

  /// Chapter information rendered by the tile.
  final Chapter chapter;

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
