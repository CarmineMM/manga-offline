import 'package:flutter/material.dart';

/// Simple placeholder widget displayed when there is no data available yet.
class EmptyState extends StatelessWidget {
  /// Creates a new [EmptyState] widget.
  const EmptyState({super.key, required this.message});

  /// Message displayed to the user.
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium,
      ),
    );
  }
}
