part of 'library_cubit.dart';

/// Possible statuses for the library state.
enum LibraryStatus { initial, loading, success, failure }

/// Immutable state exposed by [LibraryCubit].
class LibraryState extends Equatable {
  /// Creates a new state instance.
  const LibraryState({
    required this.status,
    required this.allMangas,
    required this.filteredMangas,
    required this.searchQuery,
    required this.selectedSourceIds,
    required this.availableSources,
  });

  /// Factory for the initial state before any data has loaded.
  const LibraryState.initial()
    : this(
        status: LibraryStatus.initial,
        allMangas: const <Manga>[],
        filteredMangas: const <Manga>[],
        searchQuery: '',
        selectedSourceIds: const <String>{},
        availableSources: const <LibrarySourceInfo>[],
      );

  /// Current request status.
  final LibraryStatus status;

  /// Full list of mangas downloaded locally.
  final List<Manga> allMangas;

  /// Mangas after applying the current filters.
  final List<Manga> filteredMangas;

  /// Current search query (matched against title/source name).
  final String searchQuery;

  /// Set of source identifiers selected as filters.
  final Set<String> selectedSourceIds;

  /// Unique sources available in the local library.
  final List<LibrarySourceInfo> availableSources;

  /// Creates a new state copying existing values and applying overrides.
  LibraryState copyWith({
    LibraryStatus? status,
    List<Manga>? allMangas,
    List<Manga>? filteredMangas,
    String? searchQuery,
    Set<String>? selectedSourceIds,
    List<LibrarySourceInfo>? availableSources,
  }) {
    return LibraryState(
      status: status ?? this.status,
      allMangas: allMangas != null
          ? List<Manga>.unmodifiable(allMangas)
          : this.allMangas,
      filteredMangas: filteredMangas != null
          ? List<Manga>.unmodifiable(filteredMangas)
          : this.filteredMangas,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedSourceIds: selectedSourceIds != null
          ? Set<String>.unmodifiable(selectedSourceIds)
          : this.selectedSourceIds,
      availableSources: availableSources != null
          ? List<LibrarySourceInfo>.unmodifiable(availableSources)
          : this.availableSources,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    allMangas,
    filteredMangas,
    searchQuery,
    selectedSourceIds,
    availableSources,
  ];
}

/// Value object representing a source option usable for filtering.
class LibrarySourceInfo extends Equatable {
  /// Creates a new [LibrarySourceInfo].
  const LibrarySourceInfo({required this.id, required this.name});

  /// Identifier of the source.
  final String id;

  /// Human readable label for the source.
  final String name;

  @override
  List<Object?> get props => <Object?>[id, name];
}
