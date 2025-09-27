````markdown
# manga_offline

An offline-first Flutter app prototype for browsing, downloading and reading
mangas locally. The project demonstrates a clean architecture split into
presentation, domain and data layers, uses in-memory fakes for quick local
development, and an example download pipeline for chapters and pages.

## Table of contents

-   What this project is
-   Quick start (run locally)
-   Project architecture
-   Key modules
-   Troubleshooting
-   Contributing

---

## What this project is

`manga_offline` is an app skeleton that showcases patterns for building a
mobile application which can fetch content from remote sources (scrapers or
APIs), persist metadata locally, and download assets (chapter images) so the
user can read content offline.

This repository intentionally includes in-memory repositories and a simple
download coordinator so you can iterate on UI and integration quickly without
a full backend.

## Quick start (development)

1. Install Flutter (see https://flutter.dev/docs/get-started/install).
2. From the project root run:

```powershell
flutter pub get
flutter run -d <device-or-emulator>
```
````

On Windows use PowerShell (pwsh) as shown. For release builds use `flutter build`.

If you modify native Android/iOS Gradle or Pod files do a full rebuild or
reinstall on device to avoid stale snapshots.

## Project architecture (short)

-   presentation/: Flutter UI, widgets and blocs (cubits).
-   domain/: Entities, repository interfaces and use-cases (business logic).
-   data/: Repository implementations, datasources and test stubs/fakes.
-   core/: app wiring, dependency injection and shared utilities.

The project favors small, testable modules and uses `GetIt` for simple
dependency injection in development mode.

## Key modules

-   `lib/presentation/widgets/manga_library_tile.dart` — tile used in the
    library list. Constrained to avoid unbounded AspectRatio issues in lists.
-   `lib/data/repositories/download_repository_impl.dart` — orchestrates download
    queue and per-page asset fetching; writes images to a documents directory.
-   `lib/data/stubs/in_memory_repositories.dart` — in-memory fake repositories
    used for quick local development and UI iteration.
-   `lib/presentation/blocs/library/library_cubit.dart` — cubit exposing the
    local library state and filters to the UI.
-   `lib/core/di/service_locator.dart` — development DI container wiring fakes
    and use-cases with `GetIt`.

## Troubleshooting

-   If you hit layout errors mentioning `RenderAspectRatio` or similar after
    changing widgets: stop the app and do a full reinstall. Hot reload may keep
    running older compiled widget state for structural widget changes.
-   Download hangs: in dev mode the downloader will use a small fallback image
    when remote pages fail; consult the debug logs for `DownloadRepository` to
    follow the queue lifecycle.

## Contributing

Small PRs that improve documentation, add tests or harden error handling are
welcome. Follow the existing architecture: keep presentation, domain and data
separated and prefer dependency injection for easy testing.

---

Generated on ${DateTime.now().toIso8601String()} by the local development
tooling.

```
# manga_offline

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
```
