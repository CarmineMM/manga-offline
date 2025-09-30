import 'package:package_info_plus/package_info_plus.dart';

/// Immutable metadata describing the current application build.
class AppMetadata {
  /// Creates a new [AppMetadata] instance.
  const AppMetadata({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
  });

  /// Display name configured for the build.
  final String appName;

  /// Package identifier used on the current platform.
  final String packageName;

  /// Semantic version string (for example `1.2.3`).
  final String version;

  /// Platform-specific build number.
  final String buildNumber;

  /// Returns a human friendly version label combining version and build.
  String get formattedVersion => '$version ($buildNumber)';
}

/// Provides access to lazily-loaded [AppMetadata] details.
class AppMetadataProvider {
  Future<AppMetadata>? _cachedMetadata;

  /// Loads the current application metadata.
  Future<AppMetadata> load() {
    final cached = _cachedMetadata;
    if (cached != null) {
      return cached;
    }
    final future = _fetchMetadata();
    _cachedMetadata = future;
    return future;
  }

  Future<AppMetadata> _fetchMetadata() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return AppMetadata(
      appName: packageInfo.appName,
      packageName: packageInfo.packageName,
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
    );
  }
}
