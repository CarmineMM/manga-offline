part of 'library_cubit.dart';

/// Possible statuses for the library state.
enum LibraryStatus { initial, loading, success, failure }

/// Immutable state exposed by [LibraryCubit].
class LibraryState extends Equatable {
  /// Creates a new state instance.
  const LibraryState({required this.status, required this.mangas});

  /// Factory for the initial state before any data has loaded.
  const LibraryState.initial()
    : this(status: LibraryStatus.initial, mangas: const []);

  /// Current request status.
  final LibraryStatus status;

  /// Mangas currently available in the offline library.
  final List<Manga> mangas;

  /// Creates a new state copying existing values and applying overrides.
  LibraryState copyWith({LibraryStatus? status, List<Manga>? mangas}) {
    return LibraryState(
      status: status ?? this.status,
      mangas: mangas ?? this.mangas,
    );
  }

  @override
  List<Object?> get props => [status, mangas];
}
