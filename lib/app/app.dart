import 'package:flutter/material.dart';
import 'package:manga_offline/core/theme/app_theme.dart';
import 'package:manga_offline/presentation/screens/home/main_shell.dart';

/// Root widget for the Manga Offline application.
///
/// This widget wires base theme configuration and the initial navigation
/// endpoint. Feature-specific routes will be added as the app evolves.
class MangaOfflineApp extends StatelessWidget {
  /// Creates a new [MangaOfflineApp] instance.
  const MangaOfflineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manga Offline',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const MainShell(),
    );
  }
}
