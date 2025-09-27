import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/usecases/watch_downloaded_mangas.dart';

part 'library_state.dart';

/// Cubit responsible for exposing the offline library state to the UI.
class LibraryCubit extends Cubit<LibraryState> {
  /// Creates a cubit hooked to the [WatchDownloadedMangas] use case.
  LibraryCubit(this._watchDownloadedMangas)
    : super(const LibraryState.initial());

  final WatchDownloadedMangas _watchDownloadedMangas;
  StreamSubscription<List<Manga>>? _subscription;

  /// Starts listening to local library updates.
  void start() {
    emit(state.copyWith(status: LibraryStatus.loading));
    _subscription?.cancel();
    _subscription = _watchDownloadedMangas().listen(
      (mangas) =>
          emit(state.copyWith(status: LibraryStatus.success, mangas: mangas)),
      onError: (Object error, StackTrace stackTrace) {
        emit(state.copyWith(status: LibraryStatus.failure));
      },
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
