import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/presentation/blocs/followed/followed_cubit.dart';
import 'package:manga_offline/presentation/screens/chapters/chapters_screen.dart';
import 'package:manga_offline/presentation/widgets/empty_state.dart';
import 'package:manga_offline/presentation/widgets/manga_library_tile.dart';

/// Pantalla que muestra los mangas seguidos por el usuario.
class FollowedScreen extends StatelessWidget {
  /// Crea una nueva instancia de [FollowedScreen].
  const FollowedScreen({super.key});

  void _openMangaDetail(BuildContext context, Manga manga) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChapterListScreen(initialManga: manga),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seguidos')),
      body: BlocBuilder<FollowedCubit, FollowedState>(
        builder: (BuildContext context, FollowedState state) {
          switch (state.status) {
            case FollowedStatus.initial:
            case FollowedStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case FollowedStatus.failure:
              return const EmptyState(
                message:
                    'No pudimos cargar tu lista de seguidos. Intenta de nuevo en unos segundos.',
              );
            case FollowedStatus.success:
              return RefreshIndicator(
                onRefresh: () => context.read<FollowedCubit>().refresh(),
                child: state.followedMangas.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 48,
                        ),
                        children: const <Widget>[
                          EmptyState(
                            message:
                                'Aún no sigues ningún manga. Abre un detalle y toca "Seguir" para agregarlo aquí.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 5,
                        ),
                        itemCount: state.followedMangas.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (BuildContext context, int index) {
                          final manga = state.followedMangas[index];
                          return MangaLibraryTile(
                            manga: manga,
                            showDownloadProgressDetails: true,
                            onTap: () => _openMangaDetail(context, manga),
                          );
                        },
                      ),
              );
          }
        },
      ),
    );
  }
}
