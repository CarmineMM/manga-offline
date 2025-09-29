import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/usecases/watch_downloaded_mangas.dart';

part 'downloads_state.dart';

/// Cubit encargado de exponer los mangas con al menos un capítulo descargado.
class DownloadsCubit extends Cubit<DownloadsState> {
  /// Crea un nuevo [DownloadsCubit] basado en [WatchDownloadedMangas].
  DownloadsCubit(this._watchDownloadedMangas)
    : super(const DownloadsState.initial());

  final WatchDownloadedMangas _watchDownloadedMangas;
  StreamSubscription<List<Manga>>? _subscription;

  /// Comienza a observar los mangas descargados.
  void start() {
    emit(state.copyWith(status: DownloadsStatus.loading));
    _subscription?.cancel();
    _subscription = _watchDownloadedMangas().listen(
      _emitDownloaded,
      onError: _emitFailure,
    );
  }

  Future<void> refresh() async {
    try {
      final mangas = await _watchDownloadedMangas().first;
      _emitDownloaded(mangas);
    } catch (error, stackTrace) {
      _emitFailure(error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }

  void _emitDownloaded(List<Manga> mangas) {
    final downloaded = mangas
        .where((Manga manga) => manga.downloadedChapters > 0)
        .toList(growable: false);
    emit(
      state.copyWith(
        status: DownloadsStatus.success,
        downloadedMangas: downloaded,
      ),
    );
  }

  void _emitFailure([Object? error, StackTrace? stackTrace]) {
    emit(
      state.copyWith(
        status: DownloadsStatus.failure,
        downloadedMangas: const <Manga>[],
      ),
    );
  }
}
