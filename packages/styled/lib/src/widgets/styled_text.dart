import 'package:flutter/widgets.dart';

import '../core/style.dart';
import '../theme/styled_theme.dart';

/// Text styled by the nearest [StyledBox] and, optionally, its own [style].
///
/// Only `style.text` is used. Properties from [style] override the inherited ones.
class StyledText extends StatelessWidget {
  final String text;
  final StyleResolver? style;
  final String? semanticsLabel;

  const StyledText(this.text, {super.key, this.style, this.semanticsLabel});

  /// The text style in effect for [context], combining the inherited style with [own].
  static StyledTextStyle resolve(BuildContext context, StyleResolver? own) {
    final inherited = InheritedStyle.maybeStyleOf(context)?.text ?? const StyledTextStyle();
    if (own == null) return inherited;
    return inherited.merge(own.resolve(context).resolveStates(const [], context: context).text);
  }

  @override
  Widget build(BuildContext context) {
    final t = resolve(context, style);
    final theme = StyledTheme.of(context);
    return Text(
      text,
      style: t.toTextStyle(theme),
      textAlign: t.textAlign,
      maxLines: t.maxLines,
      overflow: t.overflow,
      softWrap: t.softWrap,
      textDirection: t.textDirection,
      textScaler: t.textScaler,
      textWidthBasis: t.textWidthBasis,
      textHeightBehavior: t.textHeightBehavior,
      selectionColor: theme.read(t.selectionColor),
      semanticsLabel: semanticsLabel,
    );
  }
}
