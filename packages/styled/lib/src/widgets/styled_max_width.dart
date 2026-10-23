import 'package:flutter/widgets.dart';

import '../core/tokens.dart';

/// A layout widget that constrains its child to a maximum width on desktop screens.
///
/// This prevents UI elements from spreading too wide on large desktop displays,
/// aligning the content to the top-center.
class StyledMaxWidth extends StatelessWidget {
  /// The widget to be constrained.
  final Widget child;

  /// The maximum width constraint on desktop screens (default: 1400.0).
  final double maxWidth;

  /// Creates a [StyledMaxWidth] widget.
  const StyledMaxWidth({
    super.key,
    required this.child,
    this.maxWidth = 1400.0,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isDesktop) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
    }

    return child;
  }
}
