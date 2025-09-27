import 'package:flutter/material.dart';
import 'package:manga_offline/presentation/widgets/empty_state.dart';

/// Root placeholder screen that will list downloaded and available mangas.
///
/// Replace this widget with the actual implementation once the data and
/// presentation layers are ready to serve real content.
class LibraryScreen extends StatelessWidget {
  /// Creates a new [LibraryScreen].
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu biblioteca offline')),
      body: const EmptyState(
        message: '¡Bienvenido! Aquí aparecerán tus mangas descargados.',
      ),
    );
  }
}
