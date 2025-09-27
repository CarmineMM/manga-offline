import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:manga_offline/domain/entities/manga.dart';
import 'package:manga_offline/domain/usecases/fetch_manga_detail.dart';

part 'manga_detail_state.dart';

/// Cubit that loads and exposes a single manga detail.
class MangaDetailCubit extends Cubit<MangaDetailState> {
  /// Creates a new cubit configured with the [FetchMangaDetail] use case.
  MangaDetailCubit(this._fetchMangaDetail)
    : super(const MangaDetailState.initial());

  final FetchMangaDetail _fetchMangaDetail;

  /// Loads the detail for [mangaId] from the provided [sourceId].
  Future<void> load({required String sourceId, required String mangaId}) async {
    emit(state.copyWith(status: MangaDetailStatus.loading));
    try {
      final manga = await _fetchMangaDetail(
        sourceId: sourceId,
        mangaId: mangaId,
      );
      emit(
        state.copyWith(
          status: MangaDetailStatus.success,
          manga: manga,
          errorMessage: null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: MangaDetailStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  /// Clears the current error (if any).
  void clearError() {
    if (state.errorMessage != null) {
      emit(state.copyWith(clearError: true));
    }
  }
}
