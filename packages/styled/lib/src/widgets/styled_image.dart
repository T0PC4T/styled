import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../core/style.dart';
import '../theme/styled_theme.dart';

/// An image rendered from `style.image`, inheriting from the nearest [StyledBox].
///
/// For a tappable image, put it inside a `StyledBox` with an `Interaction`.
class StyledImage extends StatelessWidget {
  final ImageProvider image;
  final StyleResolver? style;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final ImageFrameBuilder? frameBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  const StyledImage(
    this.image, {
    super.key,
    this.style,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.frameBuilder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  StyledImage.network(
    String src, {
    super.key,
    this.style,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.frameBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    Map<String, String>? headers,
    double scale = 1.0,
  }) : image = NetworkImage(src, headers: headers, scale: scale);

  StyledImage.asset(
    String name, {
    super.key,
    this.style,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.frameBuilder,
    this.errorBuilder,
    AssetBundle? bundle,
    String? package,
  })  : image = AssetImage(name, bundle: bundle, package: package),
        loadingBuilder = null;

  StyledImage.memory(
    Uint8List bytes, {
    super.key,
    this.style,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.frameBuilder,
    this.errorBuilder,
    double scale = 1.0,
  })  : image = MemoryImage(bytes, scale: scale),
        loadingBuilder = null;

  @override
  Widget build(BuildContext context) {
    var img = InheritedStyle.maybeStyleOf(context)?.image ?? const ImageStyle();
    if (style case final own?) {
      img = img.merge(own.resolve(context).resolveStates(const [], context: context).image);
    }
    final theme = StyledTheme.of(context);
    final opacity = theme.read(img.opacity);
    return Image(
      image: image,
      fit: img.fit,
      alignment: img.alignment ?? Alignment.center,
      width: theme.read(img.width),
      height: theme.read(img.height),
      color: theme.read(img.color),
      colorBlendMode: img.colorBlendMode,
      repeat: img.repeat ?? ImageRepeat.noRepeat,
      centerSlice: img.centerSlice,
      matchTextDirection: img.matchTextDirection ?? false,
      gaplessPlayback: img.gaplessPlayback ?? false,
      isAntiAlias: img.isAntiAlias ?? false,
      filterQuality: img.filterQuality ?? FilterQuality.low,
      opacity: opacity == null ? null : AlwaysStoppedAnimation(opacity),
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      frameBuilder: frameBuilder,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
    );
  }
}
