import 'package:flutter/material.dart';

import '../theme.dart';

/// A small "PRO" tag next to features that need Spurtly Pro.
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.coral,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          'PRO',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.onCoral,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
