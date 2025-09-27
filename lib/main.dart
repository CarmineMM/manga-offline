import 'package:flutter/material.dart';
import 'package:manga_offline/app/app.dart';
import 'package:manga_offline/core/di/service_locator.dart';

/// Entry point for the Manga Offline application.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const MangaOfflineApp());
}
