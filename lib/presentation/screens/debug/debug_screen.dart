import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:manga_offline/core/debug/debug_logger.dart';
import 'package:manga_offline/presentation/blocs/debug/debug_log_cubit.dart';

/// Simple console-like screen to inspect diagnostic events while the app is
/// running in release or profile mode.
class DebugScreen extends StatelessWidget {
  /// Creates a new [DebugScreen] instance.
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Herramientas de debug'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Limpiar eventos',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => context.read<DebugLogCubit>().clear(),
          ),
        ],
      ),
      body: BlocBuilder<DebugLogCubit, DebugLogState>(
        builder: (BuildContext context, DebugLogState state) {
          if (state.entries.isEmpty) {
            return const _EmptyDebugState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final entry = state.entries[index];
              return _DebugEntryCard(entry: entry);
            },
          );
        },
      ),
    );
  }
}

class _EmptyDebugState extends StatelessWidget {
  const _EmptyDebugState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          Icon(Icons.bug_report_outlined, size: 48),
          SizedBox(height: 12),
          Text(
            'No hay eventos registrados todavía. Usa la app y regresa para ver '
            'las peticiones y errores recientes.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DebugEntryCard extends StatelessWidget {
  const _DebugEntryCard({required this.entry});

  final DebugLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _resolveVisuals(entry.level, Theme.of(context));
    final timestamp = _formatTimestamp(entry.timestamp);

    return Card(
      elevation: 0,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Icon(icon, color: color),
        title: Text(entry.message),
        subtitle: Text('$timestamp · ${entry.category}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          if (entry.metadata.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Sin metadatos adicionales.'),
            )
          else
            ...entry.metadata.entries.map((MapEntry<String, Object?> item) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(item.key),
                subtitle: Text('${item.value ?? '-'}'),
              );
            }),
        ],
      ),
    );
  }

  (IconData, Color) _resolveVisuals(DebugLogLevel level, ThemeData theme) {
    switch (level) {
      case DebugLogLevel.info:
        return (Icons.info_outline, theme.colorScheme.primary);
      case DebugLogLevel.warning:
        return (Icons.warning_amber_outlined, theme.colorScheme.tertiary);
      case DebugLogLevel.error:
        return (Icons.error_outline, theme.colorScheme.error);
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final date =
        '${timestamp.day.toString().padLeft(2, '0')}/'
        '${timestamp.month.toString().padLeft(2, '0')}';
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}
