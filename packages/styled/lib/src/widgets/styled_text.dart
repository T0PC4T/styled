import 'package:flutter/widgets.dart';

import '../core/style.dart';
import 'styled_box.dart';

/// A text widget styled via [Style.text] or inherited from a parent [InheritedStyle].
class StyledText extends StatelessWidget {
  final String text;
  final StyleResolver? style;
  final String? semanticsLabel;

  const StyledText(
    this.text, {
    super.key,
    this.style,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    var inheritedStyle = InheritedStyle.of(context)?.style ?? const Style();
    if (style case StyleResolver styleResolver) {
      final resolvedStyle = styleResolver.resolve(context);
      inheritedStyle = inheritedStyle.merge(resolvedStyle) as Style;
    }

    return Text(
      text,
      style: inheritedStyle.textStyle,
      textAlign: inheritedStyle.text.textAlign,
      maxLines: inheritedStyle.text.maxLines,
      overflow: inheritedStyle.text.overflow,
      softWrap: inheritedStyle.text.softWrap,
      textDirection: inheritedStyle.text.textDirection,
      textScaler: inheritedStyle.text.textScaler,
      textWidthBasis: inheritedStyle.text.textWidthBasis,
      textHeightBehavior: inheritedStyle.text.textHeightBehavior,
      selectionColor: inheritedStyle.text.selectionColor,
      semanticsLabel: semanticsLabel,
    );
  }
}

/// A selectable text widget styled via [Style.text] or inherited from a parent [InheritedStyle].
class StyledSelectableText extends StatelessWidget {
  final String text;
  final StyleResolver? style;
  final String? semanticsLabel;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool showCursor;
  final double cursorWidth;
  final double? cursorHeight;
  final Radius? cursorRadius;
  final Color? cursorColor;
  final VoidCallback? onTap;

  const StyledSelectableText(
    this.text, {
    super.key,
    this.style,
    this.semanticsLabel,
    this.focusNode,
    this.autofocus = false,
    this.showCursor = false,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    var inheritedStyle = InheritedStyle.of(context)?.style ?? const Style();
    if (style case StyleResolver styleResolver) {
      final resolvedStyle = styleResolver.resolve(context);
      inheritedStyle = inheritedStyle.merge(resolvedStyle) as Style;
    }

    return GestureDetector(
      onTap: onTap,
      child: StyledText(
        text,
        style: StaticStyleResolver(inheritedStyle),
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}

/// An interactive text component responding to hover, press, focus, and disabled states.
class StyledPressableText extends StatelessWidget {
  final String text;
  final StyleResolver style;
  final bool animates;
  final Duration? animationDuration;
  final Curve? curve;
  final VoidCallback? onEnd;

  // Gestures
  final VoidCallback? onTap;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCallback? onTapCancel;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final ValueChanged<bool>? onHoverChange;
  final ValueChanged<bool>? onFocusChange;
  final ValueChanged<bool>? onPressedChange;
  final bool enableFeedback;

  // States
  final bool? disabled;
  final bool? focused;

  // Focus & Cursors
  final FocusNode? focusNode;
  final bool autofocus;
  final bool canRequestFocus;
  final HitTestBehavior behavior;
  final MouseCursor? cursor;
  final MouseCursor? disabledCursor;
  final String? semanticsLabel;
  final String? tooltip;

  const StyledPressableText(
    this.text, {
    super.key,
    required this.style,
    this.animates = false,
    this.animationDuration,
    this.curve,
    this.onEnd,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onHoverChange,
    this.onFocusChange,
    this.onPressedChange,
    this.enableFeedback = true,
    this.disabled,
    this.focused,
    this.focusNode,
    this.autofocus = false,
    this.canRequestFocus = true,
    this.behavior = HitTestBehavior.opaque,
    this.cursor,
    this.disabledCursor,
    this.semanticsLabel,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return StyledPressableBox(
      style: style,
      animates: animates,
      animationDuration: animationDuration,
      curve: curve,
      onEnd: onEnd,
      onTap: onTap,
      onTapDown: onTapDown,
      onTapUp: onTapUp,
      onTapCancel: onTapCancel,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onSecondaryTap: onSecondaryTap,
      onHoverChange: onHoverChange,
      onFocusChange: onFocusChange,
      onPressedChange: onPressedChange,
      enableFeedback: enableFeedback,
      disabled: disabled,
      focused: focused,
      focusNode: focusNode,
      autofocus: autofocus,
      canRequestFocus: canRequestFocus,
      behavior: behavior,
      cursor: cursor,
      disabledCursor: disabledCursor,
      semanticLabel: semanticsLabel,
      tooltip: tooltip,
      child: StyledText(text, semanticsLabel: semanticsLabel),
    );
  }
}
