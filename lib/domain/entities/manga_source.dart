import 'package:manga_offline/domain/entities/source_capability.dart';

/// Describes a provider capable of supplying manga data.
class MangaSource {
  /// Unique identifier used to reference the source internally.
  final String id;

  /// Human readable name displayed to the user.
  final String name;

  /// Optional short description of the source.
  final String? description;

  /// Base URL of the remote site or API.
  final String baseUrl;

  /// ISO locale supported by the source (e.g. `es-ES`).
  final String locale;

  /// Icon or logo reference to display in the UI.
  final String? iconUrl;

  /// Indicates whether the source is enabled for scraping workflows.
  final bool isEnabled;

  /// Capabilities supported by the source (catalog sync, downloads, etc.).
  final List<SourceCapability> capabilities;

  /// Timestamp of the last successful catalog synchronisation.
  final DateTime? lastSyncedAt;

  /// Creates a new immutable [MangaSource] instance.
  const MangaSource({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.locale,
    this.description,
    this.iconUrl,
    this.isEnabled = false,
    this.capabilities = const [
      SourceCapability.catalog,
      SourceCapability.detail,
    ],
    this.lastSyncedAt,
  });

  /// Returns a copy of this source with selective overrides.
  MangaSource copyWith({
    String? id,
    String? name,
    String? description,
    String? baseUrl,
    String? locale,
    String? iconUrl,
    bool? isEnabled,
    List<SourceCapability>? capabilities,
    DateTime? lastSyncedAt,
  }) {
    return MangaSource(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      baseUrl: baseUrl ?? this.baseUrl,
      locale: locale ?? this.locale,
      iconUrl: iconUrl ?? this.iconUrl,
      isEnabled: isEnabled ?? this.isEnabled,
      capabilities: capabilities ?? this.capabilities,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
