/// Lifecycle of the on-device Gemma model.
enum ModelState {
  /// Model file is not on disk yet.
  notDownloaded,

  /// Download in progress.
  downloading,

  /// Model is on disk and ready for inference.
  ready,

  /// Something went wrong (download/load). See [error message] in AppState.
  error,
}
