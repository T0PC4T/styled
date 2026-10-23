import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../core/style.dart';

/// A styled container widget that applies a resolved [Style.box] decoration and constraints.
class StyledBox extends StatelessWidget {
  final StyleResolver style;
  final Widget? child;
  final bool animates;
  final Duration? animationDuration;
  final Curve? curve;
  final VoidCallback? onEnd;
  final HitTestBehavior? behavior;
  final String? semanticLabel;

  const StyledBox({
    super.key,
    required this.style,
    this.child,
    this.animates = false,
    this.animationDuration,
    this.curve,
    this.onEnd,
    this.behavior,
    this.semanticLabel,
  });

  static Container getContainerFromBox(Style style, Widget? child) => Container(
        clipBehavior: style.box.clip ?? Clip.none,
        width: style.box.width,
        height: style.box.height,
        constraints: style.box.constraints,
        padding: style.box.padding,
        margin: style.box.margin,
        alignment: style.box.alignment,
        decoration: style.decoratedBoxStyle,
        foregroundDecoration: style.box.foregroundDecoration,
        transform: style.box.transform ??
            (style.states.values.any((s) => s.box.transform != null)
                ? Matrix4.identity()
                : null),
        transformAlignment: style.box.transformAlignment,
        child: child,
      );

  static AnimatedContainer animatedContainerFromBox(
    Style style,
    Widget? child, {
    Duration? duration,
    Curve? curve,
    VoidCallback? onEnd,
  }) =>
      AnimatedContainer(
        clipBehavior: style.box.clip ?? Clip.none,
        duration: duration ?? style.box.animationDuration ?? const Duration(milliseconds: 150),
        curve: curve ?? style.box.curve ?? Curves.linear,
        onEnd: onEnd,
        width: style.box.width,
        height: style.box.height,
        constraints: style.box.constraints,
        padding: style.box.padding,
        margin: style.box.margin,
        alignment: style.box.alignment,
        decoration: style.decoratedBoxStyle,
        foregroundDecoration: style.box.foregroundDecoration,
        transform: style.box.transform ?? Matrix4.identity(),
        transformAlignment: style.box.transformAlignment,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = style.resolve(context);

    var appliedStyle = resolvedStyle;
    final parentStyle = InheritedStyle.of(context)?.style;
    if (parentStyle != null) {
      appliedStyle = appliedStyle.overwrite(
        text: parentStyle.text.merge(appliedStyle.text),
        icon: parentStyle.icon.merge(appliedStyle.icon),
      );
    }

    Widget content = animates
        ? StyledBox.animatedContainerFromBox(
            appliedStyle,
            child,
            duration: animationDuration,
            curve: curve,
            onEnd: onEnd,
          )
        : StyledBox.getContainerFromBox(appliedStyle, child);

    if (semanticLabel != null) {
      content = Semantics(label: semanticLabel, container: true, child: content);
    }

    return InheritedStyle(style: appliedStyle, child: content);
  }
}

/// An interactive [StyledBox] responding to hover, press, focus, and disabled states.
class StyledPressableBox extends StatefulWidget {
  final StyleResolver style;
  final Widget child;
  final bool? animates;
  final Duration? animationDuration;
  final Curve? curve;
  final VoidCallback? onEnd;

  // Gesture Callbacks
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCallback? onTapCancel;
  final ValueChanged<bool>? onHoverChange;
  final ValueChanged<bool>? onFocusChange;
  final ValueChanged<bool>? onPressedChange;
  final bool enableFeedback;

  // Interaction & State Overrides
  final bool? disabled;
  final bool? focused;

  // Focus & Keyboard
  final FocusNode? focusNode;
  final bool autofocus;
  final bool canRequestFocus;

  // Cursors & Hit Testing
  final HitTestBehavior behavior;
  final MouseCursor? cursor;
  final MouseCursor? disabledCursor;

  // Accessibility & Tooltips
  final String? semanticLabel;
  final String? tooltip;

  const StyledPressableBox({
    super.key,
    required this.style,
    required this.child,
    this.animates,
    this.animationDuration,
    this.curve,
    this.onEnd,
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
  State<StyledPressableBox> createState() => _StyledPressableBoxState();
}

class _StyledPressableBoxState extends State<StyledPressableBox> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _descendantClaimedActivePointer = false;
  late FocusNode _focusNode;
  bool _internalFocusNode = false;

  void _claimPointerFromAncestors() {
    _StyledPressableBoxState? ancestor =
        context.findAncestorStateOfType<_StyledPressableBoxState>();
    while (ancestor != null) {
      ancestor._onDescendantClaimedPointer();
      ancestor =
          ancestor.context.findAncestorStateOfType<_StyledPressableBoxState>();
    }
  }

  void _onDescendantClaimedPointer() {
    _descendantClaimedActivePointer = true;
    if (_isPressed) {
      _handlePressed(false);
    }
  }

  void _scheduleReleaseDescendantPointerClaim() {
    scheduleMicrotask(() {
      if (!mounted) return;
      _descendantClaimedActivePointer = false;
      _StyledPressableBoxState? ancestor =
          context.findAncestorStateOfType<_StyledPressableBoxState>();
      while (ancestor != null) {
        ancestor._descendantClaimedActivePointer = false;
        ancestor = ancestor.context
            .findAncestorStateOfType<_StyledPressableBoxState>();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _focusNode = FocusNode();
      _internalFocusNode = true;
    } else {
      _focusNode = widget.focusNode!;
    }
  }

  @override
  void didUpdateWidget(StyledPressableBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      if (_internalFocusNode) {
        _focusNode.dispose();
        _internalFocusNode = false;
      }
      if (widget.focusNode == null) {
        _focusNode = FocusNode();
        _internalFocusNode = true;
      } else {
        _focusNode = widget.focusNode!;
      }
    }
  }

  @override
  void dispose() {
    if (_internalFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  bool get _isDisabled =>
      widget.disabled ??
      (widget.onTap == null &&
          widget.onDoubleTap == null &&
          widget.onLongPress == null &&
          widget.onSecondaryTap == null &&
          widget.onTapDown == null &&
          widget.onTapUp == null);

  bool get _isFocused => widget.focused ?? _focusNode.hasFocus;

  void _handleHover(bool hovering) {
    if (_isHovered != hovering) {
      setState(() => _isHovered = hovering);
      widget.onHoverChange?.call(hovering);
    }
  }

  void _handlePressed(bool pressed) {
    if (_isPressed != pressed) {
      setState(() => _isPressed = pressed);
      widget.onPressedChange?.call(pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = widget.style.resolve(context);
    var appliedStyle = resolvedStyle;

    final parentStyle = InheritedStyle.of(context)?.style;
    if (parentStyle != null) {
      appliedStyle = appliedStyle.overwrite(
        text: parentStyle.text.merge(appliedStyle.text),
        icon: parentStyle.icon.merge(appliedStyle.icon),
      );
    }

    final bool animates = widget.animates ?? appliedStyle.box.animates ?? false;

    final activeTokens = <String>{
      if (_isDisabled) StyledToken.disabled,
      if (_isFocused && !_isDisabled) StyledToken.focused,
      if (_isPressed && !_isDisabled) StyledToken.pressed,
      if (_isHovered && !_isDisabled) StyledToken.hovered,
    };

    final currentStyle = appliedStyle.resolveTokens(activeTokens);

    Widget box = animates
        ? StyledBox.animatedContainerFromBox(
            currentStyle,
            widget.child,
            duration: widget.animationDuration,
            curve: widget.curve,
            onEnd: widget.onEnd,
          )
        : StyledBox.getContainerFromBox(currentStyle, widget.child);

    final MouseCursor effectiveCursor = _isDisabled
        ? (widget.disabledCursor ?? SystemMouseCursors.basic)
        : (widget.cursor ?? SystemMouseCursors.click);

    Widget interactive = MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      cursor: effectiveCursor,
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        canRequestFocus: widget.canRequestFocus && !_isDisabled,
        onFocusChange: (hasFocus) {
          setState(() {});
          widget.onFocusChange?.call(hasFocus);
        },
        onKeyEvent: (node, event) {
          if (_isDisabled || !node.hasPrimaryFocus) return KeyEventResult.ignored;
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space)) {
            if (widget.enableFeedback) Feedback.forTap(context);
            widget.onTap?.call();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Listener(
          behavior: HitTestBehavior.deferToChild,
          onPointerDown: _isDisabled
              ? null
              : (_) {
                  if (!_descendantClaimedActivePointer) {
                    _claimPointerFromAncestors();
                  }
                },
          onPointerUp: _isDisabled
              ? null
              : (_) => _scheduleReleaseDescendantPointerClaim(),
          onPointerCancel: _isDisabled
              ? null
              : (_) => _scheduleReleaseDescendantPointerClaim(),
          child: GestureDetector(
            behavior: widget.behavior,
            onTapDown: _isDisabled
                ? null
                : (details) {
                    if (_descendantClaimedActivePointer) return;
                    _handlePressed(true);
                    if (widget.enableFeedback) Feedback.forTap(context);
                    widget.onTapDown?.call(details);
                  },
            onTapUp: _isDisabled
                ? null
                : (details) {
                    _handlePressed(false);
                    if (_descendantClaimedActivePointer) return;
                    widget.onTapUp?.call(details);
                  },
            onTapCancel: _isDisabled
                ? null
                : () {
                    _handlePressed(false);
                    if (_descendantClaimedActivePointer) return;
                    widget.onTapCancel?.call();
                  },
            onTap: _isDisabled
                ? null
                : () {
                    if (_descendantClaimedActivePointer) return;
                    widget.onTap?.call();
                  },
            onDoubleTap: _isDisabled
                ? null
                : (widget.onDoubleTap == null
                    ? null
                    : () {
                        if (_descendantClaimedActivePointer) return;
                        widget.onDoubleTap?.call();
                      }),
            onLongPress: _isDisabled
                ? null
                : (widget.onLongPress == null
                    ? null
                    : () {
                        if (_descendantClaimedActivePointer) return;
                        widget.onLongPress?.call();
                      }),
            onSecondaryTap: _isDisabled
                ? null
                : (widget.onSecondaryTap == null
                    ? null
                    : () {
                        if (_descendantClaimedActivePointer) return;
                        widget.onSecondaryTap?.call();
                      }),
            child: InheritedStyle(style: currentStyle, child: box),
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      interactive = Semantics(tooltip: widget.tooltip!, child: interactive);
    }

    if (widget.semanticLabel != null) {
      interactive = Semantics(
        label: widget.semanticLabel,
        button: true,
        enabled: !_isDisabled,
        child: interactive,
      );
    }

    return interactive;
  }
}
