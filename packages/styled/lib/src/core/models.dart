import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import '../theme/styled_theme.dart';
import 'values.dart';
import 'wrappers.dart';

export 'values.dart';
export 'wrappers.dart';

/// Border sides and corner radius for a [BoxStyle].
///
/// Fields merge one by one, so a state style can change only the colour:
///
/// ```dart
/// base:    StyledBorder.all(color: border, width: 1, radius: 8)
/// hovered: StyledBorder.all(color: borderFocus)   // keeps width 1, radius 8
/// ```
///
/// A uniform border is drawn when both [color] and [width] are known. Any
/// explicit side ([top], [bottom], [left], [right]) replaces the uniform side
/// on that edge.
@immutable
class StyledBorder {
  final StyleValue<Color>? color;
  final StyleValue<double>? width;
  final BorderStyle? style;

  /// Uniform corner radius.
  final StyleValue<double>? radius;

  final StyledBorderSide? top;
  final StyledBorderSide? bottom;
  final StyledBorderSide? left;
  final StyledBorderSide? right;

  const StyledBorder({
    this.color,
    this.width,
    this.style,
    this.radius,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  /// The same border on every side.
  const StyledBorder.all({this.color, this.width, this.style, this.radius})
      : top = null,
        bottom = null,
        left = null,
        right = null;

  /// The same [side] on every edge, like [Border.fromBorderSide].
  const StyledBorder.fromBorderSide(StyledBorderSide side, {this.radius})
      : top = side,
        bottom = side,
        left = side,
        right = side,
        color = null,
        width = null,
        style = null;

  /// [vertical] on the left and right edges and [horizontal] on the top and
  /// bottom, like [Border.symmetric].
  const StyledBorder.symmetric({
    StyledBorderSide vertical = StyledBorderSide.none,
    StyledBorderSide horizontal = StyledBorderSide.none,
    this.radius,
  })  : left = vertical,
        right = vertical,
        top = horizontal,
        bottom = horizontal,
        color = null,
        width = null,
        style = null;

  /// No visible border, keeping an optional [radius].
  const StyledBorder.none({this.radius})
      : color = null,
        width = StyleValue.zero,
        style = BorderStyle.none,
        top = null,
        bottom = null,
        left = null,
        right = null;

  bool get _hasSides => top != null || bottom != null || left != null || right != null;

  /// The Flutter border to paint in [theme], or null when nothing is drawn.
  BoxBorder? boxBorder(StyledTheme theme) {
    final uniform = (color != null && width != null)
        ? BorderSide(color: color!.resolve(theme), width: width!.resolve(theme), style: style ?? BorderStyle.solid)
        : null;
    if (!_hasSides) return uniform == null ? null : Border.fromBorderSide(uniform);
    final fallback = uniform ?? BorderSide.none;
    return Border(
      top: top?.resolve(theme) ?? fallback,
      bottom: bottom?.resolve(theme) ?? fallback,
      left: left?.resolve(theme) ?? fallback,
      right: right?.resolve(theme) ?? fallback,
    );
  }

  /// Corner radius in [theme].
  BorderRadius borderRadius(StyledTheme theme) => BorderRadius.circular(theme.read(radius) ?? 0);

  /// Field-by-field merge where [other] wins.
  StyledBorder merge(StyledBorder? other) {
    if (other == null) return this;
    return StyledBorder(
      color: other.color ?? color,
      width: other.width ?? width,
      style: other.style ?? style,
      radius: other.radius ?? radius,
      top: other.top ?? top,
      bottom: other.bottom ?? bottom,
      left: other.left ?? left,
      right: other.right ?? right,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StyledBorder &&
          color == other.color &&
          width == other.width &&
          style == other.style &&
          radius == other.radius &&
          top == other.top &&
          bottom == other.bottom &&
          left == other.left &&
          right == other.right;

  @override
  int get hashCode => Object.hash(color, width, style, radius, top, bottom, left, right);
}

/// Decoration, size, spacing, transform and motion of a box.
@immutable
class BoxStyle {
  final StyleValue<Color>? color;
  final StyleValue<Gradient>? gradient;

  /// A background image. Images are content, so this is a plain value.
  final DecorationImage? image;
  final StyledBorder? border;
  final List<StyledBoxShadow>? boxShadow;
  final BoxShape? shape;
  final BlendMode? backgroundBlendMode;
  final StyleValue<Decoration>? foregroundDecoration;
  final StyleValue<double>? width;
  final StyleValue<double>? height;
  final StyledBoxConstraints? constraints;
  final StyledEdgeInsets? padding;
  final StyledEdgeInsets? margin;
  final AlignmentGeometry? alignment;
  final Clip? clip;
  final StyledTransform? transform;
  final AlignmentGeometry? transformAlignment;

  /// Animate changes between resolved styles. Null means no animation.
  final Motion? motion;

  const BoxStyle({
    this.color,
    this.gradient,
    this.image,
    this.border,
    this.boxShadow,
    this.shape,
    this.backgroundBlendMode,
    this.foregroundDecoration,
    this.width,
    this.height,
    this.constraints,
    this.padding,
    this.margin,
    this.alignment,
    this.clip,
    this.transform,
    this.transformAlignment,
    this.motion,
  });

  /// The [BoxDecoration] this style paints in [theme].
  BoxDecoration decoration(StyledTheme theme) {
    final currentShape = shape ?? BoxShape.rectangle;
    return BoxDecoration(
      color: theme.read(color),
      gradient: theme.read(gradient),
      image: image,
      border: border?.boxBorder(theme),
      borderRadius: currentShape == BoxShape.circle ? null : border?.borderRadius(theme),
      boxShadow: boxShadow?.map((s) => s.resolve(theme)).toList(),
      shape: currentShape,
      backgroundBlendMode: backgroundBlendMode,
    );
  }

  /// Merge where [other]'s non-null fields win. Borders merge field by field.
  BoxStyle merge(BoxStyle? other) {
    if (other == null) return this;
    return BoxStyle(
      color: other.color ?? color,
      gradient: other.gradient ?? gradient,
      image: other.image ?? image,
      border: border?.merge(other.border) ?? other.border,
      boxShadow: other.boxShadow ?? boxShadow,
      shape: other.shape ?? shape,
      backgroundBlendMode: other.backgroundBlendMode ?? backgroundBlendMode,
      foregroundDecoration: other.foregroundDecoration ?? foregroundDecoration,
      width: other.width ?? width,
      height: other.height ?? height,
      constraints: other.constraints ?? constraints,
      padding: other.padding ?? padding,
      margin: other.margin ?? margin,
      alignment: other.alignment ?? alignment,
      clip: other.clip ?? clip,
      transform: other.transform ?? transform,
      transformAlignment: other.transformAlignment ?? transformAlignment,
      motion: other.motion ?? motion,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoxStyle &&
          color == other.color &&
          gradient == other.gradient &&
          image == other.image &&
          border == other.border &&
          listEquals(boxShadow, other.boxShadow) &&
          shape == other.shape &&
          backgroundBlendMode == other.backgroundBlendMode &&
          foregroundDecoration == other.foregroundDecoration &&
          width == other.width &&
          height == other.height &&
          constraints == other.constraints &&
          padding == other.padding &&
          margin == other.margin &&
          alignment == other.alignment &&
          clip == other.clip &&
          transform == other.transform &&
          transformAlignment == other.transformAlignment &&
          motion == other.motion;

  @override
  int get hashCode => Object.hashAll([
        color,
        gradient,
        image,
        border,
        boxShadow == null ? null : Object.hashAll(boxShadow!),
        shape,
        backgroundBlendMode,
        foregroundDecoration,
        width,
        height,
        constraints,
        padding,
        margin,
        alignment,
        clip,
        transform,
        transformAlignment,
        motion,
      ]);
}

/// Typography and paragraph layout.
@immutable
class StyledTextStyle {
  final StyleValue<Color>? color;
  final StyleValue<Color>? backgroundColor;
  final StyleValue<String>? fontFamily;
  final List<String>? fontFamilyFallback;
  final StyleValue<double>? fontSize;
  final StyleValue<FontWeight>? fontWeight;
  final FontStyle? fontStyle;
  final StyleValue<double>? letterSpacing;
  final StyleValue<double>? wordSpacing;
  final StyleValue<double>? height;
  final TextBaseline? textBaseline;
  final TextLeadingDistribution? leadingDistribution;
  final Locale? locale;
  final Paint? foreground;
  final Paint? background;
  final StyleValue<List<Shadow>>? shadows;
  final List<FontFeature>? fontFeatures;
  final List<FontVariation>? fontVariations;
  final TextDecoration? decoration;
  final StyleValue<Color>? decorationColor;
  final TextDecorationStyle? decorationStyle;
  final StyleValue<double>? decorationThickness;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextDirection? textDirection;
  final TextScaler? textScaler;
  final int? maxLines;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final StyleValue<Color>? selectionColor;

  const StyledTextStyle({
    this.color,
    this.backgroundColor,
    this.fontFamily,
    this.fontFamilyFallback,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.letterSpacing,
    this.wordSpacing,
    this.height,
    this.textBaseline,
    this.leadingDistribution,
    this.locale,
    this.foreground,
    this.background,
    this.shadows,
    this.fontFeatures,
    this.fontVariations,
    this.decoration,
    this.decorationColor,
    this.decorationStyle,
    this.decorationThickness,
    this.textAlign,
    this.overflow,
    this.softWrap,
    this.textDirection,
    this.textScaler,
    this.maxLines,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  StyledTextStyle merge(StyledTextStyle? other) {
    if (other == null) return this;
    return StyledTextStyle(
      color: other.color ?? color,
      backgroundColor: other.backgroundColor ?? backgroundColor,
      fontFamily: other.fontFamily ?? fontFamily,
      fontFamilyFallback: other.fontFamilyFallback ?? fontFamilyFallback,
      fontSize: other.fontSize ?? fontSize,
      fontWeight: other.fontWeight ?? fontWeight,
      fontStyle: other.fontStyle ?? fontStyle,
      letterSpacing: other.letterSpacing ?? letterSpacing,
      wordSpacing: other.wordSpacing ?? wordSpacing,
      height: other.height ?? height,
      textBaseline: other.textBaseline ?? textBaseline,
      leadingDistribution: other.leadingDistribution ?? leadingDistribution,
      locale: other.locale ?? locale,
      foreground: other.foreground ?? foreground,
      background: other.background ?? background,
      shadows: other.shadows ?? shadows,
      fontFeatures: other.fontFeatures ?? fontFeatures,
      fontVariations: other.fontVariations ?? fontVariations,
      decoration: other.decoration ?? decoration,
      decorationColor: other.decorationColor ?? decorationColor,
      decorationStyle: other.decorationStyle ?? decorationStyle,
      decorationThickness: other.decorationThickness ?? decorationThickness,
      textAlign: other.textAlign ?? textAlign,
      overflow: other.overflow ?? overflow,
      softWrap: other.softWrap ?? softWrap,
      textDirection: other.textDirection ?? textDirection,
      textScaler: other.textScaler ?? textScaler,
      maxLines: other.maxLines ?? maxLines,
      textWidthBasis: other.textWidthBasis ?? textWidthBasis,
      textHeightBehavior: other.textHeightBehavior ?? textHeightBehavior,
      selectionColor: other.selectionColor ?? selectionColor,
    );
  }

  /// The Flutter [TextStyle] for these properties in [theme].
  TextStyle toTextStyle(StyledTheme theme) {
    final resolvedColor = theme.read(color);
    return TextStyle(
      color: resolvedColor,
      backgroundColor: theme.read(backgroundColor),
      fontFamily: theme.read(fontFamily),
      fontFamilyFallback: fontFamilyFallback,
      fontSize: theme.read(fontSize),
      fontWeight: theme.read(fontWeight),
      fontStyle: fontStyle,
      letterSpacing: theme.read(letterSpacing),
      wordSpacing: theme.read(wordSpacing),
      textBaseline: textBaseline,
      height: theme.read(height),
      leadingDistribution: leadingDistribution,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: theme.read(shadows),
      fontFeatures: fontFeatures,
      fontVariations: fontVariations,
      decoration: decoration ?? TextDecoration.none,
      decorationColor: theme.read(decorationColor) ?? resolvedColor,
      decorationThickness: theme.read(decorationThickness),
      decorationStyle: decorationStyle,
      overflow: overflow,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StyledTextStyle &&
          color == other.color &&
          backgroundColor == other.backgroundColor &&
          fontFamily == other.fontFamily &&
          listEquals(fontFamilyFallback, other.fontFamilyFallback) &&
          fontSize == other.fontSize &&
          fontWeight == other.fontWeight &&
          fontStyle == other.fontStyle &&
          letterSpacing == other.letterSpacing &&
          wordSpacing == other.wordSpacing &&
          height == other.height &&
          textBaseline == other.textBaseline &&
          leadingDistribution == other.leadingDistribution &&
          locale == other.locale &&
          foreground == other.foreground &&
          background == other.background &&
          shadows == other.shadows &&
          listEquals(fontFeatures, other.fontFeatures) &&
          listEquals(fontVariations, other.fontVariations) &&
          decoration == other.decoration &&
          decorationColor == other.decorationColor &&
          decorationStyle == other.decorationStyle &&
          decorationThickness == other.decorationThickness &&
          textAlign == other.textAlign &&
          overflow == other.overflow &&
          softWrap == other.softWrap &&
          textDirection == other.textDirection &&
          textScaler == other.textScaler &&
          maxLines == other.maxLines &&
          textWidthBasis == other.textWidthBasis &&
          textHeightBehavior == other.textHeightBehavior &&
          selectionColor == other.selectionColor;

  @override
  int get hashCode => Object.hashAll([
        color,
        backgroundColor,
        fontFamily,
        fontFamilyFallback == null ? null : Object.hashAll(fontFamilyFallback!),
        fontSize,
        fontWeight,
        fontStyle,
        letterSpacing,
        wordSpacing,
        height,
        textBaseline,
        leadingDistribution,
        locale,
        foreground,
        background,
        shadows,
        fontFeatures == null ? null : Object.hashAll(fontFeatures!),
        fontVariations == null ? null : Object.hashAll(fontVariations!),
        decoration,
        decorationColor,
        decorationStyle,
        decorationThickness,
        textAlign,
        overflow,
        softWrap,
        textDirection,
        textScaler,
        maxLines,
        textWidthBasis,
        textHeightBehavior,
        selectionColor,
      ]);
}

/// Icon rendering.
@immutable
class IconStyle {
  final StyleValue<Color>? color;
  final StyleValue<double>? size;
  final StyleValue<double>? fill;
  final StyleValue<double>? weight;
  final StyleValue<double>? grade;
  final StyleValue<double>? opticalSize;
  final StyleValue<List<Shadow>>? shadows;
  final TextDirection? textDirection;
  final bool? applyTextScaling;

  const IconStyle({
    this.color,
    this.size,
    this.fill,
    this.weight,
    this.grade,
    this.opticalSize,
    this.shadows,
    this.textDirection,
    this.applyTextScaling,
  });

  IconStyle merge(IconStyle? other) {
    if (other == null) return this;
    return IconStyle(
      color: other.color ?? color,
      size: other.size ?? size,
      fill: other.fill ?? fill,
      weight: other.weight ?? weight,
      grade: other.grade ?? grade,
      opticalSize: other.opticalSize ?? opticalSize,
      shadows: other.shadows ?? shadows,
      textDirection: other.textDirection ?? textDirection,
      applyTextScaling: other.applyTextScaling ?? applyTextScaling,
    );
  }

  /// The Flutter [IconThemeData] for these properties in [theme].
  IconThemeData toIconTheme(StyledTheme theme) => IconThemeData(
        color: theme.read(color),
        size: theme.read(size),
        fill: theme.read(fill),
        weight: theme.read(weight),
        grade: theme.read(grade),
        opticalSize: theme.read(opticalSize),
        shadows: theme.read(shadows),
        applyTextScaling: applyTextScaling,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IconStyle &&
          color == other.color &&
          size == other.size &&
          fill == other.fill &&
          weight == other.weight &&
          grade == other.grade &&
          opticalSize == other.opticalSize &&
          shadows == other.shadows &&
          textDirection == other.textDirection &&
          applyTextScaling == other.applyTextScaling;

  @override
  int get hashCode => Object.hash(
        color,
        size,
        fill,
        weight,
        grade,
        opticalSize,
        shadows,
        textDirection,
        applyTextScaling,
      );
}

/// How a box lays out its `children`: as a [Flex] or, when [wrap] is true, a [Wrap].
@immutable
class FlexStyle {
  /// Lay children out with [Wrap] instead of [Flex].
  final bool? wrap;
  final Axis? direction;
  final MainAxisAlignment? mainAxisAlignment;
  final MainAxisSize? mainAxisSize;
  final CrossAxisAlignment? crossAxisAlignment;

  /// Gap between children ([Flex.spacing] or [Wrap.spacing]).
  final StyleValue<double>? spacing;

  /// Gap between runs when [wrap] is true.
  final StyleValue<double>? runSpacing;
  final WrapAlignment? wrapAlignment;
  final WrapCrossAlignment? wrapCrossAxisAlignment;
  final WrapAlignment? runAlignment;
  final VerticalDirection? verticalDirection;
  final TextDirection? textDirection;
  final TextBaseline? textBaseline;
  final Clip? clipBehavior;

  const FlexStyle({
    this.wrap,
    this.direction,
    this.mainAxisAlignment,
    this.mainAxisSize,
    this.crossAxisAlignment,
    this.spacing,
    this.runSpacing,
    this.wrapAlignment,
    this.wrapCrossAxisAlignment,
    this.runAlignment,
    this.verticalDirection,
    this.textDirection,
    this.textBaseline,
    this.clipBehavior,
  });

  FlexStyle merge(FlexStyle? other) {
    if (other == null) return this;
    return FlexStyle(
      wrap: other.wrap ?? wrap,
      direction: other.direction ?? direction,
      mainAxisAlignment: other.mainAxisAlignment ?? mainAxisAlignment,
      mainAxisSize: other.mainAxisSize ?? mainAxisSize,
      crossAxisAlignment: other.crossAxisAlignment ?? crossAxisAlignment,
      spacing: other.spacing ?? spacing,
      runSpacing: other.runSpacing ?? runSpacing,
      wrapAlignment: other.wrapAlignment ?? wrapAlignment,
      wrapCrossAxisAlignment: other.wrapCrossAxisAlignment ?? wrapCrossAxisAlignment,
      runAlignment: other.runAlignment ?? runAlignment,
      verticalDirection: other.verticalDirection ?? verticalDirection,
      textDirection: other.textDirection ?? textDirection,
      textBaseline: other.textBaseline ?? textBaseline,
      clipBehavior: other.clipBehavior ?? clipBehavior,
    );
  }

  /// Builds the layout widget for [children] in [theme].
  Widget build(List<Widget> children, StyledTheme theme) {
    final spacing = theme.read(this.spacing);
    final runSpacing = theme.read(this.runSpacing);
    if (wrap ?? false) {
      return Wrap(
        direction: direction ?? Axis.horizontal,
        alignment: wrapAlignment ?? WrapAlignment.start,
        spacing: spacing ?? 0.0,
        runAlignment: runAlignment ?? WrapAlignment.start,
        runSpacing: runSpacing ?? 0.0,
        crossAxisAlignment: wrapCrossAxisAlignment ?? WrapCrossAlignment.start,
        textDirection: textDirection,
        verticalDirection: verticalDirection ?? VerticalDirection.down,
        clipBehavior: clipBehavior ?? Clip.none,
        children: children,
      );
    }
    return Flex(
      direction: direction ?? Axis.vertical,
      mainAxisAlignment: mainAxisAlignment ?? MainAxisAlignment.start,
      mainAxisSize: mainAxisSize ?? MainAxisSize.max,
      crossAxisAlignment: crossAxisAlignment ?? CrossAxisAlignment.center,
      verticalDirection: verticalDirection ?? VerticalDirection.down,
      textDirection: textDirection,
      textBaseline: textBaseline,
      clipBehavior: clipBehavior ?? Clip.none,
      spacing: spacing ?? 0.0,
      children: children,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlexStyle &&
          wrap == other.wrap &&
          direction == other.direction &&
          mainAxisAlignment == other.mainAxisAlignment &&
          mainAxisSize == other.mainAxisSize &&
          crossAxisAlignment == other.crossAxisAlignment &&
          spacing == other.spacing &&
          runSpacing == other.runSpacing &&
          wrapAlignment == other.wrapAlignment &&
          wrapCrossAxisAlignment == other.wrapCrossAxisAlignment &&
          runAlignment == other.runAlignment &&
          verticalDirection == other.verticalDirection &&
          textDirection == other.textDirection &&
          textBaseline == other.textBaseline &&
          clipBehavior == other.clipBehavior;

  @override
  int get hashCode => Object.hash(
        wrap,
        direction,
        mainAxisAlignment,
        mainAxisSize,
        crossAxisAlignment,
        spacing,
        runSpacing,
        wrapAlignment,
        wrapCrossAxisAlignment,
        runAlignment,
        verticalDirection,
        textDirection,
        textBaseline,
        clipBehavior,
      );
}

/// Image rendering for `StyledImage`.
@immutable
class ImageStyle {
  final BoxFit? fit;
  final AlignmentGeometry? alignment;
  final StyleValue<double>? width;
  final StyleValue<double>? height;
  final StyleValue<Color>? color;
  final BlendMode? colorBlendMode;
  final ImageRepeat? repeat;
  final Rect? centerSlice;
  final bool? matchTextDirection;
  final bool? gaplessPlayback;
  final bool? isAntiAlias;
  final FilterQuality? filterQuality;
  final StyleValue<double>? opacity;

  const ImageStyle({
    this.fit,
    this.alignment,
    this.width,
    this.height,
    this.color,
    this.colorBlendMode,
    this.repeat,
    this.centerSlice,
    this.matchTextDirection,
    this.gaplessPlayback,
    this.isAntiAlias,
    this.filterQuality,
    this.opacity,
  });

  ImageStyle merge(ImageStyle? other) {
    if (other == null) return this;
    return ImageStyle(
      fit: other.fit ?? fit,
      alignment: other.alignment ?? alignment,
      width: other.width ?? width,
      height: other.height ?? height,
      color: other.color ?? color,
      colorBlendMode: other.colorBlendMode ?? colorBlendMode,
      repeat: other.repeat ?? repeat,
      centerSlice: other.centerSlice ?? centerSlice,
      matchTextDirection: other.matchTextDirection ?? matchTextDirection,
      gaplessPlayback: other.gaplessPlayback ?? gaplessPlayback,
      isAntiAlias: other.isAntiAlias ?? isAntiAlias,
      filterQuality: other.filterQuality ?? filterQuality,
      opacity: other.opacity ?? opacity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageStyle &&
          fit == other.fit &&
          alignment == other.alignment &&
          width == other.width &&
          height == other.height &&
          color == other.color &&
          colorBlendMode == other.colorBlendMode &&
          repeat == other.repeat &&
          centerSlice == other.centerSlice &&
          matchTextDirection == other.matchTextDirection &&
          gaplessPlayback == other.gaplessPlayback &&
          isAntiAlias == other.isAntiAlias &&
          filterQuality == other.filterQuality &&
          opacity == other.opacity;

  @override
  int get hashCode => Object.hash(
        fit,
        alignment,
        width,
        height,
        color,
        colorBlendMode,
        repeat,
        centerSlice,
        matchTextDirection,
        gaplessPlayback,
        isAntiAlias,
        filterQuality,
        opacity,
      );
}
