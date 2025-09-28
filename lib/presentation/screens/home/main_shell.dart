import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:manga_offline/core/di/service_locator.dart';
import 'package:manga_offline/presentation/blocs/downloads/downloads_cubit.dart';
import 'package:manga_offline/presentation/blocs/library/library_cubit.dart';
import 'package:manga_offline/presentation/blocs/sources/sources_cubit.dart';
import 'package:manga_offline/presentation/screens/downloads/downloads_screen.dart';
import 'package:manga_offline/presentation/screens/library/library_screen.dart';
import 'package:manga_offline/presentation/screens/settings/settings_screen.dart';

/// Root shell of the application that hosts tab navigation.
class MainShell extends StatefulWidget {
  /// Creates a new [MainShell].
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      BlocProvider<LibraryCubit>(
        create: (_) => serviceLocator<LibraryCubit>()..start(),
        child: const LibraryScreen(),
      ),
      BlocProvider<DownloadsCubit>(
        create: (_) => serviceLocator<DownloadsCubit>()..start(),
        child: const DownloadsScreen(),
      ),
      BlocProvider<SourcesCubit>(
        create: (_) => serviceLocator<SourcesCubit>()..start(),
        child: const SettingsScreen(),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() => _currentIndex = index);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark),
            label: 'Biblioteca',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download),
            label: 'Descargas',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Fuentes',
          ),
        ],
      ),
    );
  }
}
