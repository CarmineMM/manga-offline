import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/presentation/widgets/cover_image_overrides.dart';

/// A compact card used in the library list to present a single [Manga].
///
/// This widget intentionally keeps layout constraints strict for the cover
/// thumbnail (fixed width / aspect ratio) to avoid unbounded constraints
/// when used inside scrolling containers (e.g., `ListView`). It displays the
/// title, optional source name, a short synopsis, a small progress indicator
/// for downloaded chapters and a status chip.
class MangaLibraryTile extends StatelessWidget {
  /// Creates a new [MangaLibraryTile].
  const MangaLibraryTile({
    super.key,
    required this.manga,
    this.onTap,
    this.showDownloadProgressDetails = false,
  });

  /// Manga information to display.
  final Manga manga;

  /// Callback triggered when the tile is tapped.
  final VoidCallback? onTap;

  /// Whether to display extended download progress information.
  final bool showDownloadProgressDetails;

  @override
  Widget build(BuildContext context) {
    // Debug marker to verify this build method is executed in the device logs.
    // Remove after debugging.
    debugPrint('MANGA_LIBRARY_TILE: build() v2');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = _computeProgress();
    final readChapters = manga.readChaptersCount;
    final totalChapters = manga.resolvedTotalChapters;
    final showReadSummary = totalChapters > 0 || readChapters > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _CoverThumbnail(
                imagePath: manga.coverImagePath,
                imageUrl: manga.coverImageUrl,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      manga.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (manga.sourceName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          manga.sourceName!,
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                    if (manga.synopsis?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          manga.synopsis!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 12),
                    _DownloadStatusChip(status: manga.status),
                    if (showReadSummary)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Capítulos leídos: $readChapters/$totalChapters',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    if (manga.totalChapters > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            LinearProgressIndicator(value: progress),
                            const SizedBox(height: 4),
                            Text(
                              '${manga.downloadedChapters}/${manga.totalChapters} capítulos listos',
                              style: theme.textTheme.bodySmall,
                            ),
                            // if (showDownloadProgressDetails)
                            //   Padding(
                            //     padding: const EdgeInsets.only(top: 2),
                            //     child: Text(
                            //       _remainingChaptersLabel(),
                            //       style: theme.textTheme.bodySmall,
                            //     ),
                            //   ),
                          ],
                        ),
                      )
                    else if (showDownloadProgressDetails &&
                        manga.downloadedChapters > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Capítulos descargados: ${manga.downloadedChapters}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double? _computeProgress() {
    if (manga.totalChapters <= 0) {
      return null;
    }
    if (manga.downloadedChapters <= 0) {
      return 0.0;
    }
    return (manga.downloadedChapters / manga.totalChapters).clamp(0.0, 1.0);
  }

  String _remainingChaptersLabel() {
    if (manga.totalChapters <= 0) {
      return 'Capítulos descargados: ${manga.downloadedChapters}';
    }
    final remaining = (manga.totalChapters - manga.downloadedChapters).clamp(
      0,
      manga.totalChapters,
    );
    if (remaining == 0) {
      return 'Todos los capítulos están disponibles offline';
    }
    return '$remaining capítulos pendientes por descargar';
  }
}

class _CoverThumbnail extends StatelessWidget {
  const _CoverThumbnail({this.imagePath, this.imageUrl});

  static const double _coverAspectRatio = 3 / 4;
  static const double _coverWidth = 96;
  static const double _coverHeight = _coverWidth / _coverAspectRatio;

  final String? imagePath;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    // Debug marker to verify thumbnail build on device.
    // Remove after debugging.
    debugPrint(
      'COVER_THUMBNAIL: build() v3 path=${imagePath ?? '<null>'} url=${imageUrl ?? '<null>'}',
    );
    final theme = Theme.of(context);

    Widget child;
    if (_canUseLocalImage(imagePath)) {
      final override = debugLocalCoverBuilderOverride;
      if (override != null) {
        child = override(context, imagePath!);
      } else {
        child = Image.file(
          File(imagePath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _PlaceholderIcon(theme: theme),
        );
      }
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      child = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _PlaceholderIcon(theme: theme),
        loadingBuilder:
            (BuildContext context, Widget image, ImageChunkEvent? progress) {
              if (progress == null) {
                return image;
              }
              return const Center(child: CircularProgressIndicator());
            },
      );
    } else {
      child = _PlaceholderIcon(theme: theme);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(
        width: _coverWidth,
        height: _coverHeight,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          child: child,
        ),
      ),
    );
  }

  bool _canUseLocalImage(String? path) {
    if (path == null || path.isEmpty || kIsWeb) {
      return false;
    }
    return File(path).existsSync();
  }
}

class _PlaceholderIcon extends StatelessWidget {
  const _PlaceholderIcon({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.menu_book_outlined,
        size: 32,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _DownloadStatusChip extends StatelessWidget {
  const _DownloadStatusChip({required this.status});

  final DownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (label, background, foreground) = _resolveColors(colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(color: foreground),
      ),
    );
  }

  (String, Color, Color) _resolveColors(ColorScheme colors) {
    switch (status) {
      case DownloadStatus.notDownloaded:
        return (
          'Sin descargar',
          colors.surfaceContainerHighest,
          colors.onSurface,
        );
      case DownloadStatus.queued:
        return (
          'En cola',
          colors.secondaryContainer,
          colors.onSecondaryContainer,
        );
      case DownloadStatus.downloading:
        return (
          'Descargando',
          colors.tertiaryContainer,
          colors.onTertiaryContainer,
        );
      case DownloadStatus.downloaded:
        return (
          'Disponible offline',
          colors.primaryContainer,
          colors.onPrimaryContainer,
        );
      case DownloadStatus.failed:
        return ('Error', colors.errorContainer, colors.onErrorContainer);
    }
  }
}
