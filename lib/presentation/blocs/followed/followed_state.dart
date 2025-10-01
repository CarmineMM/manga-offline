part of 'followed_cubit.dart';

/// Posibles estados del cubit de seguidos.
enum FollowedStatus { initial, loading, success, failure }

/// Estado inmutable expuesto por [FollowedCubit].
class FollowedState extends Equatable {
  /// Crea una instancia de [FollowedState].
  const FollowedState({required this.status, required this.followedMangas});

  /// Estado inicial antes de cargar datos.
  const FollowedState.initial()
    : this(status: FollowedStatus.initial, followedMangas: const <Manga>[]);

  /// Estado actual del flujo de seguidos.
  final FollowedStatus status;

  /// Mangas que el usuario sigue.
  final List<Manga> followedMangas;

  /// Crea una copia aplicando modificaciones.
  FollowedState copyWith({
    FollowedStatus? status,
    List<Manga>? followedMangas,
  }) {
    return FollowedState(
      status: status ?? this.status,
      followedMangas: followedMangas != null
          ? List<Manga>.unmodifiable(followedMangas)
          : this.followedMangas,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, followedMangas];
}
