import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/pro.dart';
import '../theme.dart';

/// What Spurtly Pro adds and what it costs, with Buy, Restore purchase and
/// Redeem code. [reason] says why the sheet came up, e.g. the workout limit.
Future<void> showProSheet(
  BuildContext context,
  SpurtlyPro pro, {
  String? reason,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (context) => _ProSheet(pro: pro, reason: reason),
  );
}

enum _Action { buy, restore, redeem }

class _ProSheet extends StatefulWidget {
  const _ProSheet({required this.pro, this.reason});

  final SpurtlyPro pro;
  final String? reason;

  @override
  State<_ProSheet> createState() => _ProSheetState();
}

class _ProSheetState extends State<_ProSheet> {
  /// The action in progress; the other buttons wait for it.
  _Action? _busy;
  String? _message;

  static bool get _iOS => defaultTargetPlatform == TargetPlatform.iOS;
  static String get _storeName => _iOS ? 'App Store' : 'Google Play';
  static String get _account => _iOS ? 'Apple ID' : 'Google account';

  Future<void> _run(_Action action, Future<ProOutcome?> Function() run) async {
    setState(() {
      _busy = action;
      _message = null;
    });
    final outcome = await run();
    if (!mounted) return;
    if (outcome == ProOutcome.unlocked) {
      unawaited(HapticFeedback.mediumImpact());
    }
    setState(() {
      _busy = null;
      _message = switch (outcome) {
        ProOutcome.pending =>
          'Waiting for approval. Pro unlocks as soon as the purchase '
              'goes through.',
        ProOutcome.notFound => 'No earlier purchase found for this $_account.',
        ProOutcome.failed =>
          "Couldn't reach $_storeName. Check your connection and try again.",
        ProOutcome.unlocked || ProOutcome.canceled || null => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.pro,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: widget.pro.unlocked ? _buildUnlocked() : _buildOffer(),
      ),
    );
  }

  Widget _buildOffer() {
    final text = Theme.of(context).textTheme;
    final pro = widget.pro;
    final price = pro.price;
    final busy = _busy != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header(subtitle: 'One purchase, yours for good.'),
        if (widget.reason case final reason?) ...[
          const SizedBox(height: 20),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                reason,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const _Feature(
          icon: Icons.all_inclusive_rounded,
          title: 'Unlimited workouts',
          subtitle:
              'Save and duplicate as many as you like. The free version '
              'keeps ${SpurtlyPro.freeWorkouts}.',
        ),
        if (_iOS)
          const _Feature(
            icon: Icons.lock_clock_rounded,
            title: 'Lock-screen controls',
            subtitle:
                'The workout in a Live Activity and the Dynamic Island, '
                'with pause and skip.',
          )
        else
          const _Feature(
            icon: Icons.notifications_active_rounded,
            title: 'Notification controls',
            subtitle: 'Pause and skip right from the workout notification.',
          ),
        const _Feature(
          icon: Icons.favorite_rounded,
          title: 'No subscription, no ads',
          subtitle: 'Pay once and keep Pro on every device with this account.',
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: price == null || busy
              ? null
              : () => _run(_Action.buy, pro.buy),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
            textStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          child: _busy == _Action.buy
              ? const _Spinner()
              : Text(
                  price == null ? 'Unlock Spurtly Pro' : 'Unlock for $price',
                ),
        ),
        if (price == null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              "$_storeName isn't available right now. Check your connection "
              'and try again later.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: busy
                    ? null
                    : () => _run(_Action.restore, pro.restore),
                child: _busy == _Action.restore
                    ? const _Spinner()
                    : const Text('Restore purchase'),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: busy
                    ? null
                    : () => _run(_Action.redeem, () async {
                        await pro.redeemCode();
                        return null;
                      }),
                child: const Text('Redeem code'),
              ),
            ),
          ],
        ),
        if (_message case final message?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildUnlocked() {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header(subtitle: 'Unlocked. Thank you for supporting Spurtly!'),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
            textStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/images/logo.png',
            width: 76,
            height: 76,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Spurtly Pro',
          style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.stepper,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.coral),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: text.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 22,
    child: CircularProgressIndicator(strokeWidth: 2.5),
  );
}
