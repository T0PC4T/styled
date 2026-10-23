import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../core/style.dart';
import 'styled_box.dart';

/// An image widget styled via [Style.image] or inherited from a parent [InheritedStyle].
class StyledImage extends StatelessWidget {
  final ImageProvider imageProvider;
  final StyleResolver? style;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final ImageFrameBuilder? frameBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  /// Creates a [StyledImage] from an [ImageProvider].
  const StyledImage(
    this.imageProvider, {
    super.key,
    this.style,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.frameBuilder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  /// Creates a [StyledImage] from a network URL.
  StyledImage.network(
    String src, {
    super.key,
    this.style,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.errorBuilder,
    this.loadingBuilder,
    this.frameBuilder,
    Map<String, String>? headers,
    double scale = 1.0,
  }) : imageProvider = NetworkImage(src, headers: headers, scale: scale);

  /// Creates a [StyledImage] from an asset bundle path.
  StyledImage.asset(
    String name, {
    super.key,
    this.style,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.errorBuilder,
    this.frameBuilder,
    AssetBundle? bundle,
    String? package,
  })  : imageProvider = AssetImage(name, bundle: bundle, package: package),
        loadingBuilder = null;

  /// Creates a [StyledImage] from memory bytes.
  StyledImage.memory(
    Uint8List bytes, {
    super.key,
    this.style,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.errorBuilder,
    this.frameBuilder,
    double scale = 1.0,
  })  : imageProvider = MemoryImage(bytes, scale: scale),
        loadingBuilder = null;

  @override
  Widget build(BuildContext context) {
    var inheritedStyle = InheritedStyle.of(context)?.style ?? const Style();
    if (style case StyleResolver styleResolver) {
      final resolvedStyle = styleResolver.resolve(context);
      inheritedStyle = inheritedStyle.merge(resolvedStyle) as Style;
    }

    final img = inheritedStyle.image;

    return Image(
      image: imageProvider,
      fit: img.fit,
      alignment: img.alignment ?? Alignment.center,
      width: img.width,
      height: img.height,
      color: img.color,
      colorBlendMode: img.colorBlendMode,
      repeat: img.repeat ?? ImageRepeat.noRepeat,
      centerSlice: img.centerSlice,
      matchTextDirection: img.matchTextDirection ?? false,
      gaplessPlayback: img.gaplessPlayback ?? false,
      isAntiAlias: img.isAntiAlias ?? false,
      filterQuality: img.filterQuality ?? FilterQuality.low,
      opacity: img.opacity != null ? AlwaysStoppedAnimation(img.opacity!) : null,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      frameBuilder: frameBuilder,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
    );
  }
}

/// An interactive image component responding to hover, press, focus, and disabled states.
class StyledPressableImage extends StatelessWidget {
  final ImageProvider imageProvider;
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
  final bool excludeFromSemantics;
  final String? tooltip;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageFrameBuilder? frameBuilder;

  const StyledPressableImage(
    this.imageProvider, {
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
    this.excludeFromSemantics = false,
    this.tooltip,
    this.errorBuilder,
    this.loadingBuilder,
    this.frameBuilder,
  });

  StyledPressableImage.network(
    String src, {
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
    this.excludeFromSemantics = false,
    this.tooltip,
    this.errorBuilder,
    this.loadingBuilder,
    this.frameBuilder,
    Map<String, String>? headers,
    double scale = 1.0,
  }) : imageProvider = NetworkImage(src, headers: headers, scale: scale);

  StyledPressableImage.asset(
    String name, {
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
    this.excludeFromSemantics = false,
    this.tooltip,
    this.errorBuilder,
    this.frameBuilder,
    AssetBundle? bundle,
    String? package,
  })  : imageProvider = AssetImage(name, bundle: bundle, package: package),
        loadingBuilder = null;

  StyledPressableImage.memory(
    Uint8List bytes, {
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
    this.excludeFromSemantics = false,
    this.tooltip,
    this.errorBuilder,
    this.frameBuilder,
    double scale = 1.0,
  })  : imageProvider = MemoryImage(bytes, scale: scale),
        loadingBuilder = null;

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
      child: StyledImage(
        imageProvider,
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics,
        frameBuilder: frameBuilder,
        loadingBuilder: loadingBuilder,
        errorBuilder: errorBuilder,
      ),
    );
  }
}
