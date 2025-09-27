part of 'sources_cubit.dart';

/// Possible state statuses for [SourcesCubit].
enum SourcesStatus { initial, loading, ready, failure }

/// State used by [SourcesCubit].
class SourcesState extends Equatable {
  /// Creates a new [SourcesState] instance.
  const SourcesState({
    required this.status,
    required this.sources,
    required this.syncingSources,
    this.errorMessage,
  });

  /// Convenience factory for the initial state.
  const SourcesState.initial()
    : status = SourcesStatus.initial,
      sources = const <MangaSource>[],
      syncingSources = const <String>{},
      errorMessage = null;

  /// Current status of the cubit.
  final SourcesStatus status;

  /// Sources currently available to the user.
  final List<MangaSource> sources;

  /// Source identifiers that are being toggled/synced at the moment.
  final Set<String> syncingSources;

  /// Optional error message to display.
  final String? errorMessage;

  /// Creates a copy of this state with optional overrides.
  SourcesState copyWith({
    SourcesStatus? status,
    List<MangaSource>? sources,
    Set<String>? syncingSources,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SourcesState(
      status: status ?? this.status,
      sources: sources ?? this.sources,
      syncingSources: syncingSources ?? this.syncingSources,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    sources,
    syncingSources,
    errorMessage,
  ];
}
