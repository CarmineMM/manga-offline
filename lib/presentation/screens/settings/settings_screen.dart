import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:manga_offline/core/utils/app_metadata.dart';
import 'package:manga_offline/core/di/service_locator.dart';
import 'package:manga_offline/domain/entities/manga_source.dart';
import 'package:manga_offline/domain/entities/source_capability.dart';
import 'package:manga_offline/presentation/blocs/debug/debug_log_cubit.dart';
import 'package:manga_offline/presentation/blocs/sources/sources_cubit.dart';
import 'package:manga_offline/presentation/screens/debug/debug_screen.dart';

/// Screen responsible for managing source selection and syncing.
class SettingsScreen extends StatelessWidget {
  /// Creates a new [SettingsScreen].
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SourcesCubit, SourcesState>(
      listener: (BuildContext context, SourcesState state) {
        final message = state.errorMessage;
        if (message != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          context.read<SourcesCubit>().clearError();
        }
      },
      builder: (BuildContext context, SourcesState state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Ajustes de la aplicación')),
          body: _SettingsBody(state: state),
        );
      },
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.state});

  final SourcesState state;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case SourcesStatus.initial:
      case SourcesStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case SourcesStatus.failure:
        return const Center(
          child: Text('No se pudieron cargar las fuentes disponibles.'),
        );
      case SourcesStatus.ready:
        if (state.sources.isEmpty) {
          return const Center(
            child: Text('No hay fuentes configuradas por el momento.'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) {
              return const _SourcesIntroCard();
            }
            if (index == state.sources.length + 1) {
              return const _AppVersionTile();
            }
            if (index == state.sources.length + 2) {
              return const _DebugToolsTile();
            }
            final source = state.sources[index - 1];
            return _SourceTile(
              source: source,
              isProcessing: state.syncingSources.contains(source.id),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: state.sources.length + 3,
        );
    }
  }
}

class _SourcesIntroCard extends StatelessWidget {
  const _SourcesIntroCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            Text(
              'Activa una fuente para sincronizar su catálogo. '
              'Los mangas aparecerán en la biblioteca automáticamente.',
            ),
            SizedBox(height: 8),
            Text(
              'Puedes desactivar la fuente en cualquier momento; '
              'los mangas ya descargados permanecerán disponibles offline.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source, required this.isProcessing});

  final MangaSource source;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final capabilities = source.capabilities
        .map(_describeCapability)
        .whereType<String>()
        .join(' · ');
    final lastSync = source.lastSyncedAt;
    String lastSyncLabel = 'Nunca sincronizado';
    if (lastSync != null) {
      lastSyncLabel =
          'Última sync: '
          '${lastSync.day.toString().padLeft(2, '0')}/'
          '${lastSync.month.toString().padLeft(2, '0')} '
          '${lastSync.hour.toString().padLeft(2, '0')}:${lastSync.minute.toString().padLeft(2, '0')}';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        source.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (capabilities.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            capabilities,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          source.baseUrl,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          lastSyncLabel,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: Colors.green.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Switch.adaptive(
                      value: source.isEnabled,
                      onChanged: isProcessing
                          ? null
                          : (bool value) {
                              context.read<SourcesCubit>().toggleSource(
                                sourceId: source.id,
                                isEnabled: value,
                              );
                            },
                    ),
                    if (source.isEnabled)
                      TextButton.icon(
                        onPressed: isProcessing
                            ? null
                            : () => context.read<SourcesCubit>().forceResync(
                                source.id,
                              ),
                        icon: const Icon(Icons.sync),
                        label: const Text('Re-sync'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                  ],
                ),
                if (isProcessing)
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _describeCapability(SourceCapability capability) {
    switch (capability) {
      case SourceCapability.catalog:
        return 'Catálogo';
      case SourceCapability.detail:
        return 'Detalles';
      case SourceCapability.chapterDownload:
        return 'Descarga capítulo';
      case SourceCapability.fullDownload:
        return 'Descarga completa';
    }
  }
}

class _DebugToolsTile extends StatelessWidget {
  const _DebugToolsTile();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.bug_report_outlined),
        title: const Text('Panel de debug'),
        subtitle: const Text(
          'Consulta peticiones recientes, códigos de estado y errores.',
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BlocProvider<DebugLogCubit>(
                create: (_) => serviceLocator<DebugLogCubit>()..start(),
                child: const DebugScreen(),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Displays the currently installed application version.
class _AppVersionTile extends StatelessWidget {
  const _AppVersionTile();

  @override
  Widget build(BuildContext context) {
    final metadataFuture = serviceLocator<AppMetadataProvider>().load();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Versión de la app'),
        subtitle: FutureBuilder<AppMetadata>(
          future: metadataFuture,
          builder: (BuildContext context, AsyncSnapshot<AppMetadata> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('Cargando…');
            }
            if (snapshot.hasError) {
              return const Text('No disponible');
            }
            final metadata = snapshot.data;
            if (metadata == null) {
              return const Text('No disponible');
            }
            return Text(metadata.formattedVersion);
          },
        ),
      ),
    );
  }
}
