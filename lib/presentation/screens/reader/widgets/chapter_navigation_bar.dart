import 'package:flutter/material.dart';

/// Bottom navigation bar with previous/next chapter actions.
class ChapterNavigationBar extends StatelessWidget {
  const ChapterNavigationBar({super.key, this.onPrevious, this.onNext});

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPrevious,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Anterior'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Siguiente'),
              style: FilledButton.styleFrom(
                backgroundColor: onNext != null
                    ? theme.colorScheme.primary
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
