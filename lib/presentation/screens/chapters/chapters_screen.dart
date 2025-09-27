import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:manga_offline/core/di/service_locator.dart';
import 'package:manga_offline/domain/entities/chapter.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/presentation/blocs/manga_detail/manga_detail_cubit.dart';
import 'package:manga_offline/presentation/widgets/chapter_list_tile.dart';

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
        final chapters = state.manga?.chapters ?? initialManga.chapters;

        return Scaffold(
          appBar: AppBar(title: Text(manga.title)),
          body: _ChapterListBody(
            manga: manga,
            chapters: chapters,
            status: state.status,
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
  });

  final Manga manga;
  final List<Chapter> chapters;
  final MangaDetailStatus status;

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
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('Todavía no hay capítulos disponibles.')),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((BuildContext context, int index) {
          final chapter = chapters[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == chapters.length - 1 ? 0 : 12,
            ),
            child: ChapterListTile(chapter: chapter),
          );
        }, childCount: chapters.length),
      ),
    );
  }
}

class _MangaHeader extends StatelessWidget {
  const _MangaHeader({required this.manga});

  final Manga manga;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(manga.title, style: textTheme.headlineSmall),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.public, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(_resolveSourceLabel(manga), style: textTheme.labelLarge),
            ],
          ),
        ),
        if (manga.synopsis?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(manga.synopsis!, style: textTheme.bodyMedium),
          ),
        if (manga.totalChapters > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${manga.totalChapters} capítulos encontrados',
              style: textTheme.labelLarge,
            ),
          ),
      ],
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
