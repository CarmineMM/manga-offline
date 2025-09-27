part of 'manga_detail_cubit.dart';

/// Possible statuses for the manga detail screen.
enum MangaDetailStatus { initial, loading, success, failure }

/// State emitted by [MangaDetailCubit].
class MangaDetailState extends Equatable {
  /// Creates a new [MangaDetailState].
  const MangaDetailState({required this.status, this.manga, this.errorMessage});

  /// Convenience factory for the initial state.
  const MangaDetailState.initial()
    : status = MangaDetailStatus.initial,
      manga = null,
      errorMessage = null;

  /// Current loading status.
  final MangaDetailStatus status;

  /// Loaded manga detail, available when [status] is [MangaDetailStatus.success].
  final Manga? manga;

  /// Optional error message in case of failures.
  final String? errorMessage;

  /// Creates a copy with updated fields.
  MangaDetailState copyWith({
    MangaDetailStatus? status,
    Manga? manga,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MangaDetailState(
      status: status ?? this.status,
      manga: manga ?? this.manga,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[status, manga, errorMessage];
}
