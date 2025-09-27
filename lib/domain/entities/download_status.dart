/// Describes the download lifecycle of locally stored resources.
enum DownloadStatus {
  /// The resource hasn’t been downloaded and no tasks are scheduled.
  notDownloaded,

  /// The resource is queued and will start downloading shortly.
  queued,

  /// The resource is actively being downloaded.
  downloading,

  /// The resource finished downloading successfully and is available offline.
  downloaded,

  /// The download failed; additional action is required to retry.
  failed,
}
