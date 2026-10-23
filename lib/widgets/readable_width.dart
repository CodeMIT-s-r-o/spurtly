import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// How wide lists, forms and buttons get; on a tablet they stay this wide
/// and centered instead of stretching across the screen.
const readableWidth = 640.0;

/// Side padding that centers [readableWidth] of content in [width], and
/// keeps at least [gutter] on phones.
double readableInset(double width, {double gutter = 20}) =>
    math.max(gutter, (width - readableWidth) / 2);

/// Centers [child] in a column [readableWidth] wide plus 20 gutters on each
/// side, so children keep their usual 20 padding and line up with lists
/// padded by [readableInset].
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: readableWidth + 40),
        child: child,
      ),
    );
  }
}
