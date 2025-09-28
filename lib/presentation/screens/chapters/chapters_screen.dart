import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:manga_offline/core/di/service_locator.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/entities/download_status.dart';
import 'package:manga_offline/presentation/blocs/manga_detail/manga_detail_cubit.dart';
import 'package:manga_offline/presentation/widgets/chapter_list_tile.dart';
import 'package:manga_offline/presentation/screens/reader/chapter_reader_route.dart';
import 'package:manga_offline/presentation/widgets/cover_image_overrides.dart';

/// Displays the list of chapters for a given manga.
class ChapterListScreen extends StatelessWidget {
  /// Creates a new [ChapterListScreen] with a lightweight manga summary.
  const ChapterListScreen({super.key, required this.initialManga});

  /// Manga summary used for the initial UI while details are fetched.
  final Manga initialManga;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MangaDetailCubit>(
      create: (_) =>
          serviceLocator<MangaDetailCubit>()
            ..load(sourceId: initialManga.sourceId, mangaId: initialManga.id),
      child: _ChapterListView(initialManga: initialManga),
    );
  }
}

class _ChapterListView extends StatelessWidget {
  const _ChapterListView({required this.initialManga});

  final Manga initialManga;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MangaDetailCubit, MangaDetailState>(
      listener: (BuildContext context, MangaDetailState state) {
        final message = state.errorMessage;
        if (message != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          context.read<MangaDetailCubit>().clearError();
        }
      },
      builder: (BuildContext context, MangaDetailState state) {
        final manga = state.manga ?? initialManga;
        final loaded = state.status == MangaDetailStatus.success;
        final chapters = loaded ? state.visibleChapters : initialManga.chapters;
        final canToggleOrder = loaded && (state.visibleChapters.length > 1);
        final filterIcon = switch (state.filter) {
          ChapterFilter.all => Icons.filter_list,
          ChapterFilter.downloaded => Icons.download_done,
          ChapterFilter.notDownloaded => Icons.cloud_download_outlined,
        };
        final filterTooltip = switch (state.filter) {
          ChapterFilter.all => 'Mostrar solo descargados',
          ChapterFilter.downloaded => 'Mostrar pendientes de descarga',
          ChapterFilter.notDownloaded => 'Mostrar todos los capítulos',
        };

        return Scaffold(
          appBar: AppBar(
            title: Text(manga.title),
            actions: [
              if (loaded)
                IconButton(
                  icon: Icon(filterIcon),
                  tooltip: filterTooltip,
                  onPressed: () =>
                      context.read<MangaDetailCubit>().toggleChapterFilter(),
                ),
              if (canToggleOrder)
                IconButton(
                  icon: Icon(
                    state.sortOrder == ChapterSortOrder.ascending
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                  ),
                  tooltip: state.sortOrder == ChapterSortOrder.ascending
                      ? 'Ordenar descendente'
                      : 'Ordenar ascendente',
                  onPressed: () =>
                      context.read<MangaDetailCubit>().toggleChapterOrder(),
                ),
            ],
          ),
          body: _ChapterListBody(
            manga: manga,
            chapters: chapters,
            status: state.status,
            filter: state.filter,
          ),
        );
      },
    );
  }
}

class _ChapterListBody extends StatelessWidget {
  const _ChapterListBody({
    required this.manga,
    required this.chapters,
    required this.status,
    required this.filter,
  });

  final Manga manga;
  final List<Chapter> chapters;
  final MangaDetailStatus status;
  final ChapterFilter filter;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          sliver: SliverToBoxAdapter(child: _MangaHeader(manga: manga)),
        ),
        switch (status) {
          MangaDetailStatus.initial ||
          MangaDetailStatus.loading => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
          MangaDetailStatus.failure => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text('No pudimos cargar los capítulos en este momento.'),
            ),
          ),
          MangaDetailStatus.success => _buildChapterList(),
        },
      ],
    );
  }

  Widget _buildChapterList() {
    if (chapters.isEmpty) {
      final message = switch (filter) {
        ChapterFilter.all => 'Todavía no hay capítulos disponibles.',
        ChapterFilter.downloaded => 'No hay capítulos descargados aún.',
        ChapterFilter.notDownloaded =>
          'No hay capítulos pendientes de descarga.',
      };
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text(message)),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          final chapter = chapters[index];
          final detailCubit = context.read<MangaDetailCubit>();
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == chapters.length - 1 ? 0 : 12,
            ),
            child: ChapterListTile(
              chapter: chapter,
              onDownload: (Chapter selected) {
                unawaited(detailCubit.downloadChapter(selected));
                _showMessage(
                  context,
                  'Capítulo agregado a la cola de descargas.',
                );
              },
              onReadOnline: (Chapter selected) {
                detailCubit.markChapterAsRead(selected.id);
                Navigator.of(context).push(
                  buildChapterReaderRoute(
                    chapter: selected,
                    chapters: chapters,
                    chapterIndex: index,
                    onProgress: (chapter, pageIdx) =>
                        detailCubit.updateChapterProgress(
                          chapterId: chapter.id,
                          pageNumber: pageIdx,
                        ),
                    onDownload: (chapter) =>
                        detailCubit.downloadChapter(chapter),
                  ),
                );
              },
              onReadOffline: (Chapter selected) {
                if (selected.status == DownloadStatus.downloaded) {
                  detailCubit.markChapterAsRead(selected.id);
                  Navigator.of(context).push(
                    buildChapterReaderRoute(
                      chapter: selected,
                      chapters: chapters,
                      chapterIndex: index,
                      onProgress: (chapter, pageIdx) =>
                          detailCubit.updateChapterProgress(
                            chapterId: chapter.id,
                            pageNumber: pageIdx,
                          ),
                      onDownload: (chapter) =>
                          detailCubit.downloadChapter(chapter),
                    ),
                  );
                } else {
                  _showMessage(
                    context,
                    'Preparando el lector offline para ${selected.title}.',
                  );
                }
              },
              onReadStatusChanged: (Chapter selected, bool markAsRead) {
                if (markAsRead) {
                  detailCubit.markChapterAsRead(selected.id, complete: true);
                  _showMessage(context, 'Capítulo marcado como leído.');
                } else {
                  detailCubit.markChapterAsUnread(selected.id);
                  _showMessage(context, 'Capítulo marcado como no leído.');
                }
              },
            ),
          );
        }, childCount: chapters.length),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MangaHeader extends StatelessWidget {
  const _MangaHeader({required this.manga});

  final Manga manga;

  @override
  Widget build(BuildContext context) {
    final coverPath = manga.coverImagePath;
    final coverUrl = manga.coverImageUrl;

    return _MangaHeaderLayout(
      coverImagePath: coverPath,
      coverImageUrl: coverUrl,
      title: manga.title,
      sourceLabel: _resolveSourceLabel(manga),
      synopsis: manga.synopsis,
      totalChapters: manga.totalChapters,
    );
  }

  String _resolveSourceLabel(Manga manga) {
    final sourceName = manga.sourceName;
    if (sourceName != null && sourceName.isNotEmpty) {
      return 'Fuente: $sourceName';
    }
    return 'Fuente: ${manga.sourceId}';
  }
}

/// Internal layout widget for the manga header to keep build method clean.
class _MangaHeaderLayout extends StatefulWidget {
  const _MangaHeaderLayout({
    required this.coverImagePath,
    required this.coverImageUrl,
    required this.title,
    required this.sourceLabel,
    required this.synopsis,
    required this.totalChapters,
  });

  final String? coverImagePath;
  final String? coverImageUrl;
  final String title;
  final String sourceLabel;
  final String? synopsis;
  final int totalChapters;

  @override
  State<_MangaHeaderLayout> createState() => _MangaHeaderLayoutState();
}

class _MangaHeaderLayoutState extends State<_MangaHeaderLayout> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final hasSynopsis = widget.synopsis?.isNotEmpty == true;
    final synopsisText = widget.synopsis ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CoverImage(path: widget.coverImagePath, url: widget.coverImageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.title,
                    style: textTheme.headlineSmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.public,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.sourceLabel,
                          style: textTheme.labelLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (widget.totalChapters > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${widget.totalChapters} capítulos',
                        style: textTheme.labelLarge,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (hasSynopsis) ...<Widget>[
          const SizedBox(height: 12),
          _buildSynopsis(context, synopsisText, textTheme),
        ],
      ],
    );
  }

  Widget _buildSynopsis(
    BuildContext context,
    String synopsisText,
    TextTheme textTheme,
  ) {
    // Decide if we need a 'ver más' control
    // We'll use a LayoutBuilder to measure line overflow heuristically by character length.
    const collapsedMaxChars = 260; // approx 5-6 lines depending on device.
    final needsCollapse = synopsisText.length > collapsedMaxChars;
    final displayText = !_expanded && needsCollapse
        ? '${synopsisText.substring(0, collapsedMaxChars)}…'
        : synopsisText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(displayText, style: textTheme.bodyMedium),
        if (needsCollapse)
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(_expanded ? 'Ver menos' : 'Ver más'),
          ),
      ],
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.path, required this.url});

  final String? path;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(8);
    final placeholder = Container(
      width: 100,
      height: 150,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 40,
      ),
    );

    if (_canUseLocalImage(path)) {
      final override = debugLocalCoverBuilderOverride;
      if (override != null) {
        return ClipRRect(
          borderRadius: borderRadius,
          child: SizedBox(
            width: 100,
            height: 150,
            child: override(context, path!),
          ),
        );
      }
      return ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          width: 100,
          height: 150,
          child: Image.file(
            File(path!),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
          ),
        ),
      );
    }

    if (url == null || url!.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: 100,
        height: 150,
        child: Image.network(
          url!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            );
          },
        ),
      ),
    );
  }

  bool _canUseLocalImage(String? localPath) {
    if (localPath == null || localPath.isEmpty || kIsWeb) {
      return false;
    }
    return File(localPath).existsSync();
  }
}
