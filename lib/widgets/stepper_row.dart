import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// A labelled value with − / + buttons that auto-repeat while held.
class StepperRow extends StatelessWidget {
  const StepperRow({
    super.key,
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    this.enabled = true,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String value;

  /// `null` disables the button (value at its limit).
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  /// Dims the row and disables both buttons when the setting has no effect.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final row = Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: text.labelLarge?.copyWith(color: AppColors.muted),
                ),
                Text(
                  value,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          _RepeatButton(
            icon: Icons.remove,
            tooltip: 'Decrease $label',
            onPressed: enabled ? onDecrement : null,
          ),
          const SizedBox(width: 8),
          _RepeatButton(
            icon: Icons.add,
            tooltip: 'Increase $label',
            onPressed: enabled ? onIncrement : null,
          ),
        ],
      ),
    );
    return enabled ? row : Opacity(opacity: 0.4, child: row);
  }
}

class _RepeatButton extends StatefulWidget {
  const _RepeatButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  State<_RepeatButton> createState() => _RepeatButtonState();
}

class _RepeatButtonState extends State<_RepeatButton> {
  Timer? _repeat;

  void _startRepeat() {
    _repeat?.cancel();
    _repeat = Timer.periodic(const Duration(milliseconds: 90), (_) {
      final onPressed = widget.onPressed;
      onPressed == null ? _stopRepeat() : onPressed();
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void didUpdateWidget(_RepeatButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null) _stopRepeat();
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onLongPressStart: enabled ? (_) => _startRepeat() : null,
      onLongPressEnd: (_) => _stopRepeat(),
      onLongPressCancel: _stopRepeat,
      // No tooltip: on mobile it would claim the long press used for repeat.
      child: IconButton.filledTonal(
        icon: Icon(widget.icon, semanticLabel: widget.tooltip),
        iconSize: 22,
        onPressed: widget.onPressed,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.stepper,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.stepper.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white24,
        ),
      ),
    );
  }
}
