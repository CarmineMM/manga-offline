/// Shared application-wide constants.
///
/// Centralise repeated literal values here so they can be reused across
/// different layers without tight coupling between modules.
abstract final class AppConstants {
  static const String databaseName = 'manga_offline';
  static const int databaseSchemaVersion = 1;
}
