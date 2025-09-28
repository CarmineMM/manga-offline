part of 'manga_detail_cubit.dart';

/// Possible statuses for the manga detail screen.
enum MangaDetailStatus { initial, loading, success, failure }

/// Supported chapter sorting orders.
enum ChapterSortOrder { ascending, descending }

/// State emitted by [MangaDetailCubit].
class MangaDetailState extends Equatable {
  /// Creates a new [MangaDetailState].
  const MangaDetailState({
    required this.status,
    this.manga,
    this.errorMessage,
    this.sortOrder = ChapterSortOrder.ascending,
    this.visibleChapters = const <Chapter>[],
  });

  /// Convenience factory for the initial state.
  const MangaDetailState.initial()
    : status = MangaDetailStatus.initial,
      manga = null,
      errorMessage = null,
      sortOrder = ChapterSortOrder.ascending,
      visibleChapters = const <Chapter>[];

  /// Current loading status.
  final MangaDetailStatus status;

  /// Loaded manga detail, available when [status] is [MangaDetailStatus.success].
  final Manga? manga;

  /// Optional error message in case of failures.
  final String? errorMessage;

  /// Current sorting order applied to the chapter list.
  final ChapterSortOrder sortOrder;

  /// Chapters exposed to the presentation layer using [sortOrder].
  final List<Chapter> visibleChapters;

  /// Creates a copy with updated fields.
  MangaDetailState copyWith({
    MangaDetailStatus? status,
    Manga? manga,
    String? errorMessage,
    bool clearError = false,
    ChapterSortOrder? sortOrder,
    List<Chapter>? visibleChapters,
  }) {
    return MangaDetailState(
      status: status ?? this.status,
      manga: manga ?? this.manga,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      sortOrder: sortOrder ?? this.sortOrder,
      visibleChapters: visibleChapters ?? this.visibleChapters,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    manga,
    errorMessage,
    sortOrder,
    visibleChapters,
  ];
}
