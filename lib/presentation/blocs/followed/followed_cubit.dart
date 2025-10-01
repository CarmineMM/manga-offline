import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/usecases/watch_followed_mangas.dart';

part 'followed_state.dart';

/// Cubit encargado de exponer los mangas que el usuario sigue.
class FollowedCubit extends Cubit<FollowedState> {
  /// Crea una nueva instancia basada en [WatchFollowedMangas].
  FollowedCubit(this._watchFollowedMangas)
    : super(const FollowedState.initial());

  final WatchFollowedMangas _watchFollowedMangas;
  StreamSubscription<List<Manga>>? _subscription;

  /// Comienza a observar los mangas seguidos.
  void start() {
    emit(state.copyWith(status: FollowedStatus.loading));
    _subscription?.cancel();
    _subscription = _watchFollowedMangas().listen(
      _emitFollowed,
      onError: _emitFailure,
    );
  }

  /// Fuerza la recarga de la lista de mangas seguidos.
  Future<void> refresh() async {
    try {
      final mangas = await _watchFollowedMangas().first;
      _emitFollowed(mangas);
    } catch (error, stackTrace) {
      _emitFailure(error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }

  void _emitFollowed(List<Manga> mangas) {
    emit(
      state.copyWith(status: FollowedStatus.success, followedMangas: mangas),
    );
  }

  void _emitFailure([Object? error, StackTrace? stackTrace]) {
    emit(
      state.copyWith(
        status: FollowedStatus.failure,
        followedMangas: const <Manga>[],
      ),
    );
  }
}
