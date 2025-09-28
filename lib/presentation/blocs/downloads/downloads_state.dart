part of 'downloads_cubit.dart';

/// Posibles estados del cubit de descargas.
enum DownloadsStatus { initial, loading, success, failure }

/// Estado inmutable expuesto por [DownloadsCubit].
class DownloadsState extends Equatable {
  /// Crea una instancia de [DownloadsState].
  const DownloadsState({required this.status, required this.downloadedMangas});

  /// Estado inicial antes de cargar datos.
  const DownloadsState.initial()
    : this(status: DownloadsStatus.initial, downloadedMangas: const <Manga>[]);

  /// Estado actual del flujo de descargas.
  final DownloadsStatus status;

  /// Mangas con al menos un capítulo descargado.
  final List<Manga> downloadedMangas;

  /// Crea una copia aplicando modificaciones.
  DownloadsState copyWith({
    DownloadsStatus? status,
    List<Manga>? downloadedMangas,
  }) {
    return DownloadsState(
      status: status ?? this.status,
      downloadedMangas: downloadedMangas != null
          ? List<Manga>.unmodifiable(downloadedMangas)
          : this.downloadedMangas,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, downloadedMangas];
}
