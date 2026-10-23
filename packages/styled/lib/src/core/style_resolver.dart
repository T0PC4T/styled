import 'package:flutter/widgets.dart';

import 'style.dart';

export 'models.dart';
export 'tokens.dart';

/// Abstract base class for deferred style rules.
abstract class StyleResolver {
  const StyleResolver();

  /// Resolves the style given the current build context.
  Style resolve(BuildContext context);

  /// Merges another style after context resolution.
  StyleResolver merge(StyleResolver other) {
    return _ModifiedStyleResolver(this, (context, style) => style.merge(other.resolve(context)) as Style);
  }

  /// Adds specific style properties after context resolution.
  StyleResolver add({
    BoxStyle? box,
    StyledTextStyle? text,
    IconStyle? icon,
    FlexStyle? flex,
    ImageStyle? image,
    Map<String, Style>? states,
    Set<String>? tags,
  }) {
    return _ModifiedStyleResolver(
      this,
      (context, style) => style.add(
        box: box,
        text: text,
        icon: icon,
        flex: flex,
        image: image,
        states: states,
        tags: tags,
      ),
    );
  }

  /// Overwrites specific style properties after context resolution.
  StyleResolver overwrite({
    BoxStyle? box,
    StyledTextStyle? text,
    IconStyle? icon,
    FlexStyle? flex,
    ImageStyle? image,
    Map<String, Style>? states,
    Set<String>? tags,
  }) {
    return _ModifiedStyleResolver(
      this,
      (context, style) => style.overwrite(
        box: box,
        text: text,
        icon: icon,
        flex: flex,
        image: image,
        states: states,
        tags: tags,
      ),
    );
  }

  /// Attaches a state override for [token].
  StyleResolver on(
    String token, {
    BoxStyle? box,
    StyledTextStyle? text,
    IconStyle? icon,
    FlexStyle? flex,
    ImageStyle? image,
    Style? style,
  }) {
    return _ModifiedStyleResolver(
      this,
      (context, current) => current.on(
        token,
        box: box,
        text: text,
        icon: icon,
        flex: flex,
        image: image,
        style: style,
      ),
    );
  }

  /// Resolves active tokens into the final computed style.
  StyleResolver resolveTokens(Iterable<String> activeTokens) {
    return _ModifiedStyleResolver(this, (ctx, style) => style.resolveTokens(activeTokens));
  }

  // --- Specific Component Merge Functions ---

  /// Merges BoxStyle properties after context resolution.
  StyleResolver mergeBox({
    Clip? clip,
    Color? color,
    StyledBorder? border,
    BoxBorder? boxBorder,
    BorderRadius? borderRadius,
    List<BoxShadow>? boxShadow,
    Gradient? gradient,
    BoxShape? shape,
    double? width,
    double? height,
    BoxConstraints? constraints,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    AlignmentGeometry? alignment,
    bool? animates,
    Duration? animationDuration,
    String? networkImage,
  }) {
    return _ModifiedStyleResolver(
      this,
      (context, style) => style.add(
        box: BoxStyle(
          clip: clip,
          color: color,
          border: border,
          boxBorder: boxBorder,
          borderRadius: borderRadius,
          boxShadow: boxShadow,
          gradient: gradient,
          shape: shape,
          width: width,
          height: height,
          constraints: constraints,
          padding: padding,
          margin: margin,
          alignment: alignment,
          animates: animates,
          animationDuration: animationDuration,
          networkImage: networkImage,
        ),
      ),
    );
  }

  /// Merges TextStyle properties after context resolution.
  StyleResolver mergeText({
    Color? color,
    Color? backgroundColor,
    String? fontFamily,
    List<String>? fontFamilyFallback,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    double? height,
    TextBaseline? textBaseline,
    TextLeadingDistribution? leadingDistribution,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    List<FontVariation>? fontVariations,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    TextAlign? textAlign,
    TextOverflow? overflow,
    bool? softWrap,
    TextDirection? textDirection,
    TextScaler? textScaler,
    int? maxLines,
    TextWidthBasis? textWidthBasis,
    TextHeightBehavior? textHeightBehavior,
    Color? selectionColor,
  }) {
    return _ModifiedStyleResolver(
      this,
      (context, style) => style.add(
        text: StyledTextStyle(
          color: color,
          backgroundColor: backgroundColor,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          letterSpacing: letterSpacing,
          wordSpacing: wordSpacing,
          height: height,
          textBaseline: textBaseline,
          leadingDistribution: leadingDistribution,
          locale: locale,
          foreground: foreground,
          background: background,
          shadows: shadows,
          fontFeatures: fontFeatures,
          fontVariations: fontVariations,
          decoration: decoration,
          decorationColor: decorationColor,
          decorationStyle: decorationStyle,
          decorationThickness: decorationThickness,
          textAlign: textAlign,
          overflow: overflow,
          softWrap: softWrap,
          textDirection: textDirection,
          textScaler: textScaler,
          maxLines: maxLines,
          textWidthBasis: textWidthBasis,
          textHeightBehavior: textHeightBehavior,
          selectionColor: selectionColor,
        ),
      ),
    );
  }

  /// Merges IconStyle properties after context resolution.
  StyleResolver mergeIcon({
    Color? color,
    double? size,
    double? fill,
    double? weight,
    double? grade,
    double? opticalSize,
    List<Shadow>? shadows,
    TextDirection? textDirection,
    bool? applyTextScaling,
  }) {
    return _ModifiedStyleResolver(
      this,
      (context, style) => style.add(
        icon: IconStyle(
          color: color,
          size: size,
          fill: fill,
          weight: weight,
          grade: grade,
          opticalSize: opticalSize,
          shadows: shadows,
          textDirection: textDirection,
          applyTextScaling: applyTextScaling,
        ),
      ),
    );
  }

  /// Merges FlexStyle properties after context resolution.
  StyleResolver mergeFlex({
    MainAxisAlignment? mainAxisAlignment,
    MainAxisSize? mainAxisSize,
    CrossAxisAlignment? crossAxisAlignment,
    WrapAlignment? wrapAlignment,
    WrapCrossAlignment? wrapCrossAxisAlignment,
    WrapAlignment? runAlignment,
    VerticalDirection? verticalDirection,
    TextDirection? textDirection,
    TextBaseline? textBaseline,
    Clip? clipBehavior,
    double? spacing,
    double? runSpacing,
    Axis? direction,
  }) {
    return _ModifiedStyleResolver(
      this,
      (context, style) => style.add(
        flex: FlexStyle(
          mainAxisAlignment: mainAxisAlignment,
          mainAxisSize: mainAxisSize,
          crossAxisAlignment: crossAxisAlignment,
          wrapAlignment: wrapAlignment,
          wrapCrossAxisAlignment: wrapCrossAxisAlignment,
          runAlignment: runAlignment,
          verticalDirection: verticalDirection,
          textDirection: textDirection,
          textBaseline: textBaseline,
          clipBehavior: clipBehavior,
          spacing: spacing,
          runSpacing: runSpacing,
          direction: direction,
        ),
      ),
    );
  }

  /// Merges ImageStyle properties after context resolution.
  StyleResolver mergeImage({
    BoxFit? fit,
    AlignmentGeometry? alignment,
    double? width,
    double? height,
    Color? color,
    BlendMode? colorBlendMode,
    ImageRepeat? repeat,
    Rect? centerSlice,
    bool? matchTextDirection,
    bool? gaplessPlayback,
    bool? isAntiAlias,
    FilterQuality? filterQuality,
    double? opacity,
    double? scale,
    int? cacheWidth,
    int? cacheHeight,
    bool? invertColors,
  }) {
    return _ModifiedStyleResolver(
      this,
      (context, style) => style.add(
        image: ImageStyle(
          fit: fit,
          alignment: alignment,
          width: width,
          height: height,
          color: color,
          colorBlendMode: colorBlendMode,
          repeat: repeat,
          centerSlice: centerSlice,
          matchTextDirection: matchTextDirection,
          gaplessPlayback: gaplessPlayback,
          isAntiAlias: isAntiAlias,
          filterQuality: filterQuality,
          opacity: opacity,
          scale: scale,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          invertColors: invertColors,
        ),
      ),
    );
  }
}

/// A style resolver that immediately returns a fixed, precomputed [Style].
class StaticStyleResolver extends StyleResolver {
  final Style _style;
  const StaticStyleResolver(this._style);

  @override
  Style resolve(BuildContext context) => _style;
}

/// A helper class that defers style modifications until after the base style has resolved.
class _ModifiedStyleResolver extends StyleResolver {
  final StyleResolver _baseResolver;
  final Style Function(BuildContext context, Style style) _modifier;

  const _ModifiedStyleResolver(this._baseResolver, this._modifier);

  @override
  Style resolve(BuildContext context) {
    return _modifier(context, _baseResolver.resolve(context));
  }
}
