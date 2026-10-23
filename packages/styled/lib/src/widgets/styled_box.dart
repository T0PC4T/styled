import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/style.dart';
import '../theme/styled_theme.dart';

/// Gesture, focus and cursor behaviour for an interactive [StyledBox].
///
/// A box with an [Interaction] tracks hover, press and focus and activates
/// the matching [StyleState]s. A box is visually disabled only when
/// [enabled] is false; a box without handlers is simply not clickable.
@immutable
class Interaction {
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCancelCallback? onTapCancel;
  final ValueChanged<bool>? onHoverChange;
  final ValueChanged<bool>? onFocusChange;
  final ValueChanged<bool>? onPressedChange;

  /// When false, gestures are ignored and [StyleState.disabled] is active.
  final bool enabled;

  /// Forces the focused state on or off instead of following [focusNode].
  final bool? focused;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool canRequestFocus;
  final bool enableFeedback;
  final HitTestBehavior behavior;

  /// Cursor while clickable. Defaults to [SystemMouseCursors.click].
  final MouseCursor? cursor;

  /// Cursor while disabled or without handlers. Defaults to [SystemMouseCursors.basic].
  final MouseCursor? disabledCursor;

  /// Tooltip text exposed to assistive technology.
  final String? tooltip;

  const Interaction({
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.onHoverChange,
    this.onFocusChange,
    this.onPressedChange,
    this.enabled = true,
    this.focused,
    this.focusNode,
    this.autofocus = false,
    this.canRequestFocus = true,
    this.enableFeedback = true,
    this.behavior = HitTestBehavior.opaque,
    this.cursor,
    this.disabledCursor,
    this.tooltip,
  });

  /// Whether any tap or press handler is set.
  bool get hasHandlers =>
      onTap != null ||
      onDoubleTap != null ||
      onLongPress != null ||
      onSecondaryTap != null ||
      onTapDown != null ||
      onTapUp != null;

  /// Whether the box responds to taps.
  bool get isActive => enabled && hasHandlers;

  Interaction copyWith({bool? enabled, bool? canRequestFocus, String? tooltip}) => Interaction(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        onSecondaryTap: onSecondaryTap,
        onTapDown: onTapDown,
        onTapUp: onTapUp,
        onTapCancel: onTapCancel,
        onHoverChange: onHoverChange,
        onFocusChange: onFocusChange,
        onPressedChange: onPressedChange,
        enabled: enabled ?? this.enabled,
        focused: focused,
        focusNode: focusNode,
        autofocus: autofocus,
        canRequestFocus: canRequestFocus ?? this.canRequestFocus,
        enableFeedback: enableFeedback,
        behavior: behavior,
        cursor: cursor,
        disabledCursor: disabledCursor,
        tooltip: tooltip ?? this.tooltip,
      );
}

/// The single styled container: decoration, size, layout and interaction.
///
/// - With [child], it is a decorated box.
/// - With [children], it lays them out from `style.flex` (a [Flex], or a
///   [Wrap] when `flex.wrap` is true).
/// - With [interaction], it tracks hover, press and focus.
/// - [states] activates application states such as `selected` or `loading`.
///
/// Motion comes from `style.box.motion`. Text and icon properties cascade
/// to descendant [StyledText] and [StyledIcon] widgets.
class StyledBox extends StatelessWidget {
  final StyleResolver style;
  final Widget? child;
  final List<Widget>? children;
  final Interaction? interaction;

  /// Application states to activate, lowest precedence first. Interaction
  /// states always take precedence over these.
  final Iterable<StyleState> states;
  final String? semanticLabel;

  /// Called when an implicit animation finishes.
  final VoidCallback? onEnd;

  const StyledBox({
    super.key,
    this.style = const Style(),
    this.child,
    this.children,
    this.interaction,
    this.states = const [],
    this.semanticLabel,
    this.onEnd,
  }) : assert(child == null || children == null, 'Pass either child or children, not both.');

  @override
  Widget build(BuildContext context) {
    final resolved = style.resolve(context).inheritFrom(InheritedStyle.maybeStyleOf(context));
    if (interaction case final interaction?) {
      return _InteractiveBox(
        style: resolved,
        interaction: interaction,
        states: states,
        semanticLabel: semanticLabel,
        onEnd: onEnd,
        child: child,
        children: children,
      );
    }
    final theme = StyledTheme.of(context);
    final applied = resolved.resolveStates(states, context: context);
    Widget content = _paint(
      applied,
      _content(applied, child, children, theme),
      theme,
      keepTransform: _hasStateTransform(resolved),
      onEnd: onEnd,
    );
    if (semanticLabel != null) {
      content = Semantics(label: semanticLabel, container: true, child: content);
    }
    return content;
  }
}

/// A [StyledBox] whose children run horizontally.
class StyledRow extends StatelessWidget {
  final StyleResolver style;
  final List<Widget> children;
  final Interaction? interaction;
  final Iterable<StyleState> states;
  final String? semanticLabel;

  const StyledRow({
    super.key,
    this.style = const Style(),
    required this.children,
    this.interaction,
    this.states = const [],
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) => StyledBox(
        style: style.map((s) => s.add(flex: const FlexStyle(direction: Axis.horizontal))),
        interaction: interaction,
        states: states,
        semanticLabel: semanticLabel,
        children: children,
      );
}

/// A [StyledBox] whose children run vertically.
class StyledColumn extends StatelessWidget {
  final StyleResolver style;
  final List<Widget> children;
  final Interaction? interaction;
  final Iterable<StyleState> states;
  final String? semanticLabel;

  const StyledColumn({
    super.key,
    this.style = const Style(),
    required this.children,
    this.interaction,
    this.states = const [],
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) => StyledBox(
        style: style.map((s) => s.add(flex: const FlexStyle(direction: Axis.vertical))),
        interaction: interaction,
        states: states,
        semanticLabel: semanticLabel,
        children: children,
      );
}

Widget? _content(Style style, Widget? child, List<Widget>? children, StyledTheme theme) =>
    children != null ? style.flex.build(children, theme) : child;

bool _hasStateTransform(Style style) =>
    style.box.transform != null || style.states.values.any((s) => s.box.transform != null);

/// Paints [style.box] around [child] in [theme] and publishes [style] to descendants.
Widget _paint(Style style, Widget? child, StyledTheme theme, {required bool keepTransform, VoidCallback? onEnd}) {
  final box = style.box;
  final width = theme.read(box.width);
  final height = theme.read(box.height);
  final constraints = box.constraints?.resolve(theme);
  final padding = box.padding?.resolve(theme);
  final margin = box.margin?.resolve(theme);
  final decoration = box.decoration(theme);
  final foreground = theme.read(box.foregroundDecoration);
  final transform = box.transform?.resolve(theme);
  final Widget container;
  if (box.motion case final motion?) {
    container = AnimatedContainer(
      duration: motion.duration.resolve(theme),
      curve: motion.curve,
      onEnd: onEnd,
      clipBehavior: box.clip ?? Clip.none,
      width: width,
      height: height,
      constraints: constraints,
      padding: padding,
      margin: margin,
      alignment: box.alignment,
      decoration: decoration,
      foregroundDecoration: foreground,
      transform: transform ?? Matrix4.identity(),
      transformAlignment: box.transformAlignment,
      child: child,
    );
  } else {
    container = Container(
      clipBehavior: box.clip ?? Clip.none,
      width: width,
      height: height,
      constraints: constraints,
      padding: padding,
      margin: margin,
      alignment: box.alignment,
      decoration: decoration,
      foregroundDecoration: foreground,
      // Keep a Transform in the tree when any state uses one, so toggling
      // the state does not rebuild (and reset) the subtree.
      transform: transform ?? (keepTransform ? Matrix4.identity() : null),
      transformAlignment: box.transformAlignment,
      child: child,
    );
  }
  return InheritedStyle(style: style, child: container);
}

class _InteractiveBox extends StatefulWidget {
  final Style style;
  final Interaction interaction;
  final Iterable<StyleState> states;
  final String? semanticLabel;
  final VoidCallback? onEnd;
  final Widget? child;
  final List<Widget>? children;

  const _InteractiveBox({
    required this.style,
    required this.interaction,
    required this.states,
    this.semanticLabel,
    this.onEnd,
    this.child,
    this.children,
  });

  @override
  State<_InteractiveBox> createState() => _InteractiveBoxState();
}

class _InteractiveBoxState extends State<_InteractiveBox> {
  bool _hovered = false;
  bool _pressed = false;
  bool _descendantClaimedPointer = false;
  FocusNode? _internalFocusNode;

  Interaction get _i => widget.interaction;
  FocusNode get _focusNode => _i.focusNode ?? (_internalFocusNode ??= FocusNode());
  bool get _disabled => !_i.enabled;
  bool get _active => _i.isActive;
  bool get _focused => _i.focused ?? _focusNode.hasFocus;

  @override
  void didUpdateWidget(_InteractiveBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_i.focusNode != null && _internalFocusNode != null) {
      _internalFocusNode!.dispose();
      _internalFocusNode = null;
    }
    if (!_active && _pressed) _pressed = false;
  }

  @override
  void dispose() {
    _internalFocusNode?.dispose();
    super.dispose();
  }

  // Nested interactive boxes: the innermost one that receives a pointer down
  // owns the gesture, and its ancestors drop their pressed state.
  Iterable<_InteractiveBoxState> get _ancestors sync* {
    var ancestor = context.findAncestorStateOfType<_InteractiveBoxState>();
    while (ancestor != null) {
      yield ancestor;
      ancestor = ancestor.context.findAncestorStateOfType<_InteractiveBoxState>();
    }
  }

  void _claimPointer() {
    for (final ancestor in _ancestors) {
      ancestor._descendantClaimedPointer = true;
      if (ancestor._pressed) ancestor._setPressed(false);
    }
  }

  void _releasePointerClaim() {
    scheduleMicrotask(() {
      if (!mounted) return;
      _descendantClaimedPointer = false;
      for (final ancestor in _ancestors) {
        ancestor._descendantClaimedPointer = false;
      }
    });
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    _i.onHoverChange?.call(value);
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
    _i.onPressedChange?.call(value);
  }

  VoidCallback? _guard(VoidCallback? callback) =>
      !_active || callback == null ? null : () => _descendantClaimedPointer ? null : callback();

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final applied = style.resolveStates([
      ...widget.states,
      if (_hovered && !_disabled) StyleState.hovered,
      if (_focused && !_disabled) StyleState.focused,
      if (_pressed && _active) StyleState.pressed,
      if (_disabled) StyleState.disabled,
    ], context: context);

    final theme = StyledTheme.of(context);
    final painted = _paint(
      applied,
      _content(applied, widget.child, widget.children, theme),
      theme,
      keepTransform: _hasStateTransform(style),
      onEnd: widget.onEnd,
    );

    Widget result = MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      cursor: _active
          ? (_i.cursor ?? SystemMouseCursors.click)
          : (_i.disabledCursor ?? SystemMouseCursors.basic),
      child: Focus(
        focusNode: _focusNode,
        autofocus: _i.autofocus,
        canRequestFocus: _i.canRequestFocus && _active,
        onFocusChange: (hasFocus) {
          setState(() {});
          _i.onFocusChange?.call(hasFocus);
        },
        onKeyEvent: (node, event) {
          if (!_active || !node.hasPrimaryFocus) return KeyEventResult.ignored;
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space)) {
            if (_i.enableFeedback) Feedback.forTap(context);
            _i.onTap?.call();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Listener(
          behavior: HitTestBehavior.deferToChild,
          onPointerDown: _active ? (_) => _descendantClaimedPointer ? null : _claimPointer() : null,
          onPointerUp: _active ? (_) => _releasePointerClaim() : null,
          onPointerCancel: _active ? (_) => _releasePointerClaim() : null,
          child: GestureDetector(
            behavior: _i.behavior,
            onTapDown: _active
                ? (details) {
                    if (_descendantClaimedPointer) return;
                    _setPressed(true);
                    if (_i.enableFeedback) Feedback.forTap(context);
                    _i.onTapDown?.call(details);
                  }
                : null,
            onTapUp: _active
                ? (details) {
                    _setPressed(false);
                    if (!_descendantClaimedPointer) _i.onTapUp?.call(details);
                  }
                : null,
            onTapCancel: _active
                ? () {
                    _setPressed(false);
                    if (!_descendantClaimedPointer) _i.onTapCancel?.call();
                  }
                : null,
            onTap: _guard(_i.onTap ?? () {}),
            onDoubleTap: _guard(_i.onDoubleTap),
            onLongPress: _guard(_i.onLongPress),
            onSecondaryTap: _guard(_i.onSecondaryTap),
            child: painted,
          ),
        ),
      ),
    );

    if (_i.tooltip case final tooltip? when tooltip.isNotEmpty) {
      result = Semantics(tooltip: tooltip, child: result);
    }
    if (widget.semanticLabel != null) {
      result = Semantics(
        label: widget.semanticLabel,
        button: _i.hasHandlers,
        enabled: !_disabled,
        child: result,
      );
    }
    return result;
  }
}
