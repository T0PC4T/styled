import 'package:flutter/widgets.dart';

import '../core/style.dart';
import '../theme/styled_theme.dart';

/// An icon styled by the nearest [StyledBox] and, optionally, its own [style].
///
/// Only `style.icon` is used. Properties from [style] override the inherited ones.
class StyledIcon extends StatelessWidget {
  final IconData icon;
  final StyleResolver? style;
  final String? semanticLabel;

  const StyledIcon(this.icon, {super.key, this.style, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    var i = InheritedStyle.maybeStyleOf(context)?.icon ?? const IconStyle();
    if (style case final own?) {
      i = i.merge(own.resolve(context).resolveStates(const [], context: context).icon);
    }
    final theme = StyledTheme.of(context);
    return Icon(
      icon,
      size: theme.read(i.size),
      color: theme.read(i.color),
      fill: theme.read(i.fill),
      weight: theme.read(i.weight),
      grade: theme.read(i.grade),
      opticalSize: theme.read(i.opticalSize),
      shadows: theme.read(i.shadows),
      textDirection: i.textDirection,
      applyTextScaling: i.applyTextScaling,
      semanticLabel: semanticLabel,
    );
  }
}
