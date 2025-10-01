import 'package:manga_offline/domain/repositories/manga_repository.dart';

/// Use case that updates whether a manga is followed by the user.
class SetMangaFollowed {
  /// Creates a new [SetMangaFollowed] use case.
  const SetMangaFollowed(this._repository);

  final MangaRepository _repository;

  /// Sets the follow flag for the provided [mangaId].
  Future<void> call({required String mangaId, required bool isFollowed}) {
    return _repository.setMangaFollowed(
      mangaId: mangaId,
      isFollowed: isFollowed,
    );
  }
}
