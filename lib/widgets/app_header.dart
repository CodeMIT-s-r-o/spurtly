import 'package:flutter/material.dart';

import '../theme.dart';

/// Logo, "Spurtly" and "Interval timer", with [trailing] on the right.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.trailing});

  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Image.asset(
            'assets/images/logo.png',
            width: 56,
            height: 56,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spurtly',
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Interval timer',
                style: text.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}
