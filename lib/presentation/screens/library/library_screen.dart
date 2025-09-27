import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/presentation/blocs/library/library_cubit.dart';
import 'package:manga_offline/presentation/screens/chapters/chapters_screen.dart';
import 'package:manga_offline/presentation/widgets/empty_state.dart';
import 'package:manga_offline/presentation/widgets/manga_library_tile.dart';

/// Screen that lists the user's offline manga library.
class LibraryScreen extends StatefulWidget {
  /// Creates a new [LibraryScreen].
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final TextEditingController _searchController;
  bool _isSyncingText = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
  }

  void _handleSearchChanged() {
    if (_isSyncingText) return;
    context.read<LibraryCubit>().updateSearchQuery(_searchController.text);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu biblioteca offline')),
      body: BlocListener<LibraryCubit, LibraryState>(
        listenWhen: (LibraryState prev, LibraryState curr) =>
            prev.searchQuery != curr.searchQuery,
        listener: (BuildContext context, LibraryState state) {
          if (_searchController.text == state.searchQuery) {
            return;
          }
          _isSyncingText = true;
          _searchController
            ..text = state.searchQuery
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: state.searchQuery.length),
            );
          _isSyncingText = false;
        },
        child: BlocBuilder<LibraryCubit, LibraryState>(
          builder: (BuildContext context, LibraryState state) {
            switch (state.status) {
              case LibraryStatus.initial:
              case LibraryStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case LibraryStatus.failure:
                return const EmptyState(
                  message:
                      'No pudimos cargar tu biblioteca. Intenta nuevamente en unos segundos.',
                );
              case LibraryStatus.success:
                return _LibrarySuccessBody(
                  searchController: _searchController,
                  state: state,
                );
            }
          },
        ),
      ),
    );
  }
}

class _LibrarySuccessBody extends StatelessWidget {
  const _LibrarySuccessBody({
    required this.searchController,
    required this.state,
  });

  final TextEditingController searchController;
  final LibraryState state;

  @override
  Widget build(BuildContext context) {
    final hasFiltersApplied =
        state.searchQuery.isNotEmpty || state.selectedSourceIds.isNotEmpty;
    final libraryCubit = context.read<LibraryCubit>();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Buscar por título o fuente',
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            textInputAction: TextInputAction.search,
          ),
        ),
        if (state.availableSources.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: state.availableSources.map((LibrarySourceInfo source) {
                final isSelected = state.selectedSourceIds.contains(source.id);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(source.name),
                    selected: isSelected,
                    onSelected: (_) =>
                        libraryCubit.toggleSourceFilter(source.id),
                  ),
                );
              }).toList(),
            ),
          ),
        if (hasFiltersApplied)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 8),
              child: TextButton.icon(
                onPressed: libraryCubit.resetFilters,
                icon: const Icon(Icons.clear),
                label: const Text('Limpiar filtros'),
              ),
            ),
          ),
        Expanded(
          child: Builder(
            builder: (BuildContext context) {
              if (state.allMangas.isEmpty) {
                return const EmptyState(
                  message:
                      'Aún no tienes mangas descargados. Activa una fuente en Ajustes para iniciar.',
                );
              }
              if (state.filteredMangas.isEmpty) {
                return const EmptyState(
                  message:
                      'No encontramos mangas con los filtros actuales. Ajusta la búsqueda o restablece los filtros.',
                );
              }
              return _LibraryList(mangas: state.filteredMangas);
            },
          ),
        ),
      ],
    );
  }
}

class _LibraryList extends StatelessWidget {
  const _LibraryList({required this.mangas});

  final List<Manga> mangas;

  void _openMangaDetail(BuildContext context, Manga manga) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChapterListScreen(initialManga: manga),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const PageStorageKey<String>('libraryList'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      itemBuilder: (BuildContext context, int index) {
        final manga = mangas[index];
        return MangaLibraryTile(
          manga: manga,
          onTap: () => _openMangaDetail(context, manga),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: mangas.length,
    );
  }
}
