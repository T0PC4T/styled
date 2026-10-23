import 'package:flutter/widgets.dart';

import '../core/style.dart';
import 'styled_box.dart';

/// A flex container (Row/Column) styled via [Style.flex].
class StyledFlex extends StatelessWidget {
  final StyleResolver style;
  final List<Widget> children;
  final bool animates;
  final Duration? animationDuration;
  final Curve? curve;
  final VoidCallback? onEnd;
  final HitTestBehavior? behavior;
  final String? semanticLabel;

  const StyledFlex({
    super.key,
    required this.style,
    required this.children,
    this.animates = false,
    this.animationDuration,
    this.curve,
    this.onEnd,
    this.behavior,
    this.semanticLabel,
  });

  Flex getFlex(Style style) {
    return Flex(
      direction: style.flex.direction ?? Axis.vertical,
      mainAxisAlignment: style.flex.mainAxisAlignment ?? MainAxisAlignment.start,
      mainAxisSize: style.flex.mainAxisSize ?? MainAxisSize.max,
      crossAxisAlignment: style.flex.crossAxisAlignment ?? CrossAxisAlignment.center,
      verticalDirection: style.flex.verticalDirection ?? VerticalDirection.down,
      textDirection: style.flex.textDirection,
      textBaseline: style.flex.textBaseline,
      clipBehavior: style.flex.clipBehavior ?? Clip.none,
      spacing: style.flex.spacing ?? 0.0,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = style.resolve(context);
    return StyledBox(
      style: StaticStyleResolver(resolvedStyle),
      animates: animates,
      animationDuration: animationDuration,
      curve: curve,
      onEnd: onEnd,
      behavior: behavior,
      semanticLabel: semanticLabel,
      child: getFlex(resolvedStyle),
    );
  }
}

/// A horizontally directed [StyledFlex].
class StyledRow extends StatelessWidget {
  final StyleResolver style;
  final List<Widget> children;
  final bool animates;
  final Duration? animationDuration;
  final Curve? curve;
  final VoidCallback? onEnd;
  final HitTestBehavior? behavior;
  final String? semanticLabel;

  const StyledRow({
    super.key,
    required this.style,
    required this.children,
    this.animates = false,
    this.animationDuration,
    this.curve,
    this.onEnd,
    this.behavior,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return StyledFlex(
      style: style.mergeFlex(direction: Axis.horizontal),
      animates: animates,
      animationDuration: animationDuration,
      curve: curve,
      onEnd: onEnd,
      behavior: behavior,
      semanticLabel: semanticLabel,
      children: children,
    );
  }
}

/// A vertically directed [StyledFlex].
class StyledColumn extends StatelessWidget {
  final StyleResolver style;
  final List<Widget> children;
  final bool animates;
  final Duration? animationDuration;
  final Curve? curve;
  final VoidCallback? onEnd;
  final HitTestBehavior? behavior;
  final String? semanticLabel;

  const StyledColumn({
    super.key,
    required this.style,
    required this.children,
    this.animates = false,
    this.animationDuration,
    this.curve,
    this.onEnd,
    this.behavior,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return StyledFlex(
      style: style.mergeFlex(direction: Axis.vertical),
      animates: animates,
      animationDuration: animationDuration,
      curve: curve,
      onEnd: onEnd,
      behavior: behavior,
      semanticLabel: semanticLabel,
      children: children,
    );
  }
}

/// A multi-line wrapping flex container styled via [Style.flex].
class StyledWrap extends StatelessWidget {
  final StyleResolver style;
  final List<Widget> children;
  final bool animates;
  final Duration? animationDuration;
  final Curve? curve;
  final VoidCallback? onEnd;
  final HitTestBehavior? behavior;
  final String? semanticLabel;

  const StyledWrap({
    super.key,
    required this.style,
    required this.children,
    this.animates = false,
    this.animationDuration,
    this.curve,
    this.onEnd,
    this.behavior,
    this.semanticLabel,
  });

  Wrap getWrap(Style style) {
    return Wrap(
      direction: style.flex.direction ?? Axis.horizontal,
      alignment: style.flex.wrapAlignment ?? WrapAlignment.start,
      spacing: style.flex.spacing ?? 0.0,
      runAlignment: style.flex.runAlignment ?? WrapAlignment.start,
      runSpacing: style.flex.runSpacing ?? 0.0,
      crossAxisAlignment: style.flex.wrapCrossAxisAlignment ?? WrapCrossAlignment.start,
      textDirection: style.flex.textDirection,
      verticalDirection: style.flex.verticalDirection ?? VerticalDirection.down,
      clipBehavior: style.flex.clipBehavior ?? Clip.none,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = style.resolve(context);
    return StyledBox(
      style: StaticStyleResolver(resolvedStyle),
      animates: animates,
      animationDuration: animationDuration,
      curve: curve,
      onEnd: onEnd,
      behavior: behavior,
      semanticLabel: semanticLabel,
      child: getWrap(resolvedStyle),
    );
  }
}

/// An interactive [StyledFlex] responding to hover, press, focus, and disabled states.
class StyledPressableFlex extends StatelessWidget {
  final StyleResolver style;
  final List<Widget> children;
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

  const StyledPressableFlex({
    super.key,
    required this.style,
    required this.children,
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

  Flex getFlex(Style style) {
    return Flex(
      direction: style.flex.direction ?? Axis.vertical,
      mainAxisAlignment: style.flex.mainAxisAlignment ?? MainAxisAlignment.start,
      mainAxisSize: style.flex.mainAxisSize ?? MainAxisSize.max,
      crossAxisAlignment: style.flex.crossAxisAlignment ?? CrossAxisAlignment.center,
      verticalDirection: style.flex.verticalDirection ?? VerticalDirection.down,
      textDirection: style.flex.textDirection,
      textBaseline: style.flex.textBaseline,
      clipBehavior: style.flex.clipBehavior ?? Clip.none,
      spacing: style.flex.spacing ?? 0.0,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = style.resolve(context);

    return StyledPressableBox(
      style: StaticStyleResolver(resolvedStyle),
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
      child: getFlex(resolvedStyle),
    );
  }
}

/// An interactive horizontally directed [StyledPressableFlex].
class StyledPressableRow extends StatelessWidget {
  final StyleResolver style;
  final List<Widget> children;
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

  const StyledPressableRow({
    super.key,
    required this.style,
    required this.children,
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
    return StyledPressableFlex(
      style: style.mergeFlex(direction: Axis.horizontal),
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
      children: children,
    );
  }
}

/// An interactive vertically directed [StyledPressableFlex].
class StyledPressableColumn extends StatelessWidget {
  final StyleResolver style;
  final List<Widget> children;
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

  const StyledPressableColumn({
    super.key,
    required this.style,
    required this.children,
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
    return StyledPressableFlex(
      style: style.mergeFlex(direction: Axis.vertical),
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
      children: children,
    );
  }
}

/// An interactive multi-line wrapping flex container.
class StyledPressableWrap extends StatelessWidget {
  final StyleResolver style;
  final List<Widget> children;
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

  const StyledPressableWrap({
    super.key,
    required this.style,
    required this.children,
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

  Wrap getWrap(Style style) {
    return Wrap(
      direction: style.flex.direction ?? Axis.horizontal,
      alignment: style.flex.wrapAlignment ?? WrapAlignment.start,
      spacing: style.flex.spacing ?? 0.0,
      runAlignment: style.flex.runAlignment ?? WrapAlignment.start,
      runSpacing: style.flex.runSpacing ?? 0.0,
      crossAxisAlignment: style.flex.wrapCrossAxisAlignment ?? WrapCrossAlignment.start,
      textDirection: style.flex.textDirection,
      verticalDirection: style.flex.verticalDirection ?? VerticalDirection.down,
      clipBehavior: style.flex.clipBehavior ?? Clip.none,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = style.resolve(context);

    return StyledPressableBox(
      style: StaticStyleResolver(resolvedStyle),
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
      child: getWrap(resolvedStyle),
    );
  }
}
