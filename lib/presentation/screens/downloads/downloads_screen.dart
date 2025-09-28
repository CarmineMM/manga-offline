import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/presentation/blocs/downloads/downloads_cubit.dart';
import 'package:manga_offline/presentation/screens/chapters/chapters_screen.dart';
import 'package:manga_offline/presentation/widgets/empty_state.dart';
import 'package:manga_offline/presentation/widgets/manga_library_tile.dart';

/// Pantalla que muestra los mangas con capítulos descargados.
class DownloadsScreen extends StatelessWidget {
  /// Crea una nueva instancia de [DownloadsScreen].
  const DownloadsScreen({super.key});

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
      appBar: AppBar(title: const Text('Descargas')),
      body: BlocBuilder<DownloadsCubit, DownloadsState>(
        builder: (BuildContext context, DownloadsState state) {
          switch (state.status) {
            case DownloadsStatus.initial:
            case DownloadsStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case DownloadsStatus.failure:
              return const EmptyState(
                message:
                    'No pudimos cargar tus descargas. Intenta de nuevo en unos segundos.',
              );
            case DownloadsStatus.success:
              if (state.downloadedMangas.isEmpty) {
                return const EmptyState(
                  message:
                      'Aún no tienes capítulos descargados. Descarga alguno desde la biblioteca.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                itemCount: state.downloadedMangas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) {
                  final manga = state.downloadedMangas[index];
                  return MangaLibraryTile(
                    manga: manga,
                    showDownloadProgressDetails: true,
                    onTap: () => _openMangaDetail(context, manga),
                  );
                },
              );
          }
        },
      ),
    );
  }
}
