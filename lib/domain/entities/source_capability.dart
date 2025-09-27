/// Enumerates operations a source can handle.
enum SourceCapability {
  /// Supports loading the global catalog listing.
  catalog,

  /// Supports fetching detailed information for a specific manga.
  detail,

  /// Supports downloading individual chapters.
  chapterDownload,

  /// Supports queuing entire manga downloads.
  fullDownload,
}
