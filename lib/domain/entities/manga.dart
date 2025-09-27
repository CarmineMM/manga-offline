/// Core domain entity representing a manga stored locally or available online.
class Manga {
  /// Unique identifier across sources. May map to a slug or internal UUID.
  final String id;

  /// Display title for the manga.
  final String title;

  /// Optional short description.
  final String? synopsis;

  /// Indicates if the manga has been fully downloaded for offline reading.
  final bool isDownloaded;

  /// Creates a new immutable [Manga] entity instance.
  const Manga({
    required this.id,
    required this.title,
    this.synopsis,
    this.isDownloaded = false,
  });

  /// Convenience copy method to derive new variations while keeping immutability.
  Manga copyWith({
    String? id,
    String? title,
    String? synopsis,
    bool? isDownloaded,
  }) {
    return Manga(
      id: id ?? this.id,
      title: title ?? this.title,
      synopsis: synopsis ?? this.synopsis,
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }
}
