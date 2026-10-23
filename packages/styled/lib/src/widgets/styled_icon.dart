import 'package:flutter/widgets.dart';

import '../core/style.dart';
import 'styled_box.dart';

/// An icon widget styled via [Style.icon] or inherited from a parent [InheritedStyle].
class StyledIcon extends StatelessWidget {
  final IconData icon;
  final StyleResolver? style;
  final String? semanticLabel;

  const StyledIcon(
    this.icon, {
    super.key,
    this.style,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    var inheritedStyle = InheritedStyle.of(context)?.style ?? const Style();
    if (style case StyleResolver styleResolver) {
      final resolvedStyle = styleResolver.resolve(context);
      inheritedStyle = inheritedStyle.merge(resolvedStyle) as Style;
    }

    return Icon(
      icon,
      size: inheritedStyle.icon.size,
      color: inheritedStyle.icon.color,
      fill: inheritedStyle.icon.fill,
      weight: inheritedStyle.icon.weight,
      grade: inheritedStyle.icon.grade,
      opticalSize: inheritedStyle.icon.opticalSize,
      shadows: inheritedStyle.icon.shadows,
      textDirection: inheritedStyle.icon.textDirection,
      applyTextScaling: inheritedStyle.icon.applyTextScaling,
      semanticLabel: semanticLabel,
    );
  }
}

/// An interactive icon component responding to hover, press, focus, and disabled states.
class StyledPressableIcon extends StatelessWidget {
  final IconData icon;
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
  final String? semanticLabel;
  final String? tooltip;

  const StyledPressableIcon(
    this.icon, {
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
    this.semanticLabel,
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
      semanticLabel: semanticLabel,
      tooltip: tooltip,
      child: StyledIcon(icon, semanticLabel: semanticLabel),
    );
  }
}
