/// Base exception type for recoverable domain errors within the app.
///
/// Custom exceptions should extend this class to communicate actionable
/// feedback to the presentation layer.
class AppException implements Exception {
  /// Message describing the exception cause.
  final String message;

  /// Optional identifier for logging or analytics correlation.
  final String? code;

  /// Creates a new [AppException].
  const AppException(this.message, {this.code});

  @override
  String toString() => 'AppException(message: $message, code: $code)';
}
