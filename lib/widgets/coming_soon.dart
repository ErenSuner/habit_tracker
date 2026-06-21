import 'package:flutter/material.dart';

// Henuz yapilmamis ekranlar icin ortak "yapim asamasinda" gostergesi.
class ComingSoon extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const ComingSoon({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: c.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
