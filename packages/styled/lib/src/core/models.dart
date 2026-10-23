import 'package:flutter/widgets.dart';

/// Defines border styling attributes for a [BoxStyle].
@immutable
class StyledBorder {
  static const Color defaultColor = Color(0xFF000000);
  static const double defaultWidth = 1.0;
  static const BorderStyle defaultStyle = BorderStyle.solid;

  final Color? color;
  final double? width;
  final BorderStyle? style;
  final double radius;
  final BorderSide? top;
  final BorderSide? bottom;
  final BorderSide? left;
  final BorderSide? right;

  const StyledBorder({this.top, this.bottom, this.left, this.right, this.radius = 0})
      : color = null,
        width = null,
        style = null;

  const StyledBorder.all({this.color, this.width, this.style, this.radius = 0})
      : top = null,
        bottom = null,
        left = null,
        right = null;

  const StyledBorder.none({this.radius = 0})
      : color = const Color(0x00000000),
        width = 0.0,
        style = BorderStyle.none,
        top = null,
        bottom = null,
        left = null,
        right = null;

  BoxBorder? get borderBox {
    if ((color, width) case (Color c, double w)) {
      return Border.all(color: c, width: w, style: style ?? defaultStyle);
    } else if (top != null || bottom != null || left != null || right != null) {
      return Border(
        top: top ?? BorderSide.none,
        bottom: bottom ?? BorderSide.none,
        left: left ?? BorderSide.none,
        right: right ?? BorderSide.none,
      );
    } else {
      return null;
    }
  }

  StyledBorder copyWith({
    Color? color,
    double? width,
    BorderStyle? style,
    double? radius,
    BorderSide? top,
    BorderSide? bottom,
    BorderSide? left,
    BorderSide? right,
  }) {
    if (this.top != null ||
        this.bottom != null ||
        this.left != null ||
        this.right != null ||
        top != null ||
        bottom != null ||
        left != null ||
        right != null) {
      return StyledBorder(
        top: top ?? this.top,
        bottom: bottom ?? this.bottom,
        left: left ?? this.left,
        right: right ?? this.right,
        radius: radius ?? this.radius,
      );
    }
    return StyledBorder.all(
      color: color ?? this.color,
      width: width ?? this.width,
      style: style ?? this.style,
      radius: radius ?? this.radius,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StyledBorder &&
          runtimeType == other.runtimeType &&
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

/// Defines box decoration, layout constraints, padding, and animations.
@immutable
class BoxStyle {
  final Clip? clip;
  final Color? color;
  final StyledBorder? border;
  final BoxBorder? boxBorder;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;
  final BoxShape? shape;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final AlignmentGeometry? alignment;
  final bool? animates;
  final Duration? animationDuration;
  final Curve? curve;
  final DecorationImage? image;
  final String? networkImage;
  final Decoration? foregroundDecoration;
  final BlendMode? backgroundBlendMode;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;

  StyledBorder get borderStyle => border ?? const StyledBorder();
  BorderSide get borderSide =>
      BorderSide(color: borderStyle.color ?? const Color(0x00000000), width: borderStyle.width ?? 0, style: borderStyle.style ?? BorderStyle.solid);
  BoxBorder? get effectiveBorderBox => boxBorder ?? border?.borderBox;
  BorderRadius get circularRadius => borderRadius ?? BorderRadius.circular(border?.radius ?? 0);

  const BoxStyle({
    this.clip,
    this.color,
    this.border,
    this.boxBorder,
    this.borderRadius,
    this.boxShadow,
    this.gradient,
    this.shape,
    this.width,
    this.height,
    this.constraints,
    this.padding,
    this.margin,
    this.alignment,
    this.animates,
    this.animationDuration,
    this.curve,
    this.image,
    this.networkImage,
    this.foregroundDecoration,
    this.backgroundBlendMode,
    this.transform,
    this.transformAlignment,
  });

  BoxStyle copyWith({
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
    Curve? curve,
    DecorationImage? image,
    String? networkImage,
    Decoration? foregroundDecoration,
    BlendMode? backgroundBlendMode,
    Matrix4? transform,
    AlignmentGeometry? transformAlignment,
  }) {
    return BoxStyle(
      clip: clip ?? this.clip,
      color: color ?? this.color,
      border: border ?? this.border,
      boxBorder: boxBorder ?? this.boxBorder,
      borderRadius: borderRadius ?? this.borderRadius,
      boxShadow: boxShadow ?? this.boxShadow,
      gradient: gradient ?? this.gradient,
      shape: shape ?? this.shape,
      width: width ?? this.width,
      height: height ?? this.height,
      constraints: constraints ?? this.constraints,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
      alignment: alignment ?? this.alignment,
      animates: animates ?? this.animates,
      animationDuration: animationDuration ?? this.animationDuration,
      curve: curve ?? this.curve,
      image: image ?? this.image,
      networkImage: networkImage ?? this.networkImage,
      foregroundDecoration: foregroundDecoration ?? this.foregroundDecoration,
      backgroundBlendMode: backgroundBlendMode ?? this.backgroundBlendMode,
      transform: transform ?? this.transform,
      transformAlignment: transformAlignment ?? this.transformAlignment,
    );
  }

  BoxStyle merge(BoxStyle other) {
    return BoxStyle(
      clip: other.clip ?? clip,
      color: other.color ?? color,
      border: other.border ?? border,
      boxBorder: other.boxBorder ?? boxBorder,
      borderRadius: other.borderRadius ?? borderRadius,
      boxShadow: other.boxShadow ?? boxShadow,
      gradient: other.gradient ?? gradient,
      shape: other.shape ?? shape,
      width: other.width ?? width,
      height: other.height ?? height,
      constraints: other.constraints ?? constraints,
      padding: other.padding ?? padding,
      margin: other.margin ?? margin,
      alignment: other.alignment ?? alignment,
      animates: other.animates ?? animates,
      animationDuration: other.animationDuration ?? animationDuration,
      curve: other.curve ?? curve,
      image: other.image ?? image,
      networkImage: other.networkImage ?? networkImage,
      foregroundDecoration: other.foregroundDecoration ?? foregroundDecoration,
      backgroundBlendMode: other.backgroundBlendMode ?? backgroundBlendMode,
      transform: other.transform ?? transform,
      transformAlignment: other.transformAlignment ?? transformAlignment,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoxStyle &&
          runtimeType == other.runtimeType &&
          clip == other.clip &&
          color == other.color &&
          border == other.border &&
          boxBorder == other.boxBorder &&
          borderRadius == other.borderRadius &&
          _listEquals(boxShadow, other.boxShadow) &&
          gradient == other.gradient &&
          shape == other.shape &&
          width == other.width &&
          height == other.height &&
          constraints == other.constraints &&
          padding == other.padding &&
          margin == other.margin &&
          alignment == other.alignment &&
          animates == other.animates &&
          animationDuration == other.animationDuration &&
          curve == other.curve &&
          image == other.image &&
          networkImage == other.networkImage &&
          foregroundDecoration == other.foregroundDecoration &&
          backgroundBlendMode == other.backgroundBlendMode &&
          transform == other.transform &&
          transformAlignment == other.transformAlignment;

  @override
  int get hashCode => Object.hashAll([
        clip,
        color,
        border,
        boxBorder,
        borderRadius,
        if (boxShadow != null) Object.hashAll(boxShadow!) else null,
        gradient,
        shape,
        width,
        height,
        constraints,
        padding,
        margin,
        alignment,
        animates,
        animationDuration,
        curve,
        image,
        networkImage,
        foregroundDecoration,
        backgroundBlendMode,
        transform,
        transformAlignment,
      ]);
}

bool _listEquals<E>(List<E>? a, List<E>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Defines typography styling attributes for a [Style].
@immutable
class StyledTextStyle {
  final Color? color;
  final Color? backgroundColor;
  final String? fontFamily;
  final List<String>? fontFamilyFallback;
  final double? fontSize;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  final double? letterSpacing;
  final double? wordSpacing;
  final double? height;
  final TextBaseline? textBaseline;
  final TextLeadingDistribution? leadingDistribution;
  final Locale? locale;
  final Paint? foreground;
  final Paint? background;
  final List<Shadow>? shadows;
  final List<FontFeature>? fontFeatures;
  final List<FontVariation>? fontVariations;
  final TextDecoration? decoration;
  final Color? decorationColor;
  final TextDecorationStyle? decorationStyle;
  final double? decorationThickness;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextDirection? textDirection;
  final TextScaler? textScaler;
  final int? maxLines;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

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

  StyledTextStyle copyWith({
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
    return StyledTextStyle(
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontFamily: fontFamily ?? this.fontFamily,
      fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      wordSpacing: wordSpacing ?? this.wordSpacing,
      height: height ?? this.height,
      textBaseline: textBaseline ?? this.textBaseline,
      leadingDistribution: leadingDistribution ?? this.leadingDistribution,
      locale: locale ?? this.locale,
      foreground: foreground ?? this.foreground,
      background: background ?? this.background,
      shadows: shadows ?? this.shadows,
      fontFeatures: fontFeatures ?? this.fontFeatures,
      fontVariations: fontVariations ?? this.fontVariations,
      decoration: decoration ?? this.decoration,
      decorationColor: decorationColor ?? this.decorationColor,
      decorationStyle: decorationStyle ?? this.decorationStyle,
      decorationThickness: decorationThickness ?? this.decorationThickness,
      textAlign: textAlign ?? this.textAlign,
      overflow: overflow ?? this.overflow,
      softWrap: softWrap ?? this.softWrap,
      textDirection: textDirection ?? this.textDirection,
      textScaler: textScaler ?? this.textScaler,
      maxLines: maxLines ?? this.maxLines,
      textWidthBasis: textWidthBasis ?? this.textWidthBasis,
      textHeightBehavior: textHeightBehavior ?? this.textHeightBehavior,
      selectionColor: selectionColor ?? this.selectionColor,
    );
  }

  StyledTextStyle merge(StyledTextStyle other) {
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

  /// Converts this [StyledTextStyle] into a Flutter [TextStyle].
  TextStyle get textStyle {
    return TextStyle(
      color: color,
      backgroundColor: backgroundColor,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      leadingDistribution: leadingDistribution,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      fontVariations: fontVariations,
      decoration: decoration ?? TextDecoration.none,
      decorationColor: decorationColor ?? color,
      decorationThickness: decorationThickness,
      decorationStyle: decorationStyle,
      overflow: overflow,
    );
  }


  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StyledTextStyle &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          backgroundColor == other.backgroundColor &&
          fontFamily == other.fontFamily &&
          _listEquals(fontFamilyFallback, other.fontFamilyFallback) &&
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
          _listEquals(shadows, other.shadows) &&
          _listEquals(fontFeatures, other.fontFeatures) &&
          _listEquals(fontVariations, other.fontVariations) &&
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
        if (fontFamilyFallback != null) Object.hashAll(fontFamilyFallback!) else null,
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
        if (shadows != null) Object.hashAll(shadows!) else null,
        if (fontFeatures != null) Object.hashAll(fontFeatures!) else null,
        if (fontVariations != null) Object.hashAll(fontVariations!) else null,
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

/// Defines icon styling attributes for a [Style].
@immutable
class IconStyle {
  final Color? color;
  final double? size;
  final double? fill;
  final double? weight;
  final double? grade;
  final double? opticalSize;
  final List<Shadow>? shadows;
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

  IconStyle copyWith({
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
    return IconStyle(
      color: color ?? this.color,
      size: size ?? this.size,
      fill: fill ?? this.fill,
      weight: weight ?? this.weight,
      grade: grade ?? this.grade,
      opticalSize: opticalSize ?? this.opticalSize,
      shadows: shadows ?? this.shadows,
      textDirection: textDirection ?? this.textDirection,
      applyTextScaling: applyTextScaling ?? this.applyTextScaling,
    );
  }

  IconStyle merge(IconStyle other) {
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IconStyle &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          size == other.size &&
          fill == other.fill &&
          weight == other.weight &&
          grade == other.grade &&
          opticalSize == other.opticalSize &&
          _listEquals(shadows, other.shadows) &&
          textDirection == other.textDirection &&
          applyTextScaling == other.applyTextScaling;

  @override
  int get hashCode => Object.hashAll([
        color,
        size,
        fill,
        weight,
        grade,
        opticalSize,
        if (shadows != null) Object.hashAll(shadows!) else null,
        textDirection,
        applyTextScaling,
      ]);
}

/// Defines flex and wrap layout styling attributes for a [Style].
@immutable
class FlexStyle {
  final Axis? direction;
  final MainAxisAlignment? mainAxisAlignment;
  final MainAxisSize? mainAxisSize;
  final CrossAxisAlignment? crossAxisAlignment;
  final WrapAlignment? wrapAlignment;
  final WrapCrossAlignment? wrapCrossAxisAlignment;
  final WrapAlignment? runAlignment;
  final VerticalDirection? verticalDirection;
  final TextDirection? textDirection;
  final TextBaseline? textBaseline;
  final Clip? clipBehavior;
  final double? spacing;
  final double? runSpacing;

  const FlexStyle({
    this.direction,
    this.mainAxisAlignment,
    this.mainAxisSize,
    this.crossAxisAlignment,
    this.wrapAlignment,
    this.wrapCrossAxisAlignment,
    this.runAlignment,
    this.verticalDirection,
    this.textDirection,
    this.textBaseline,
    this.clipBehavior,
    this.spacing,
    this.runSpacing,
  });

  FlexStyle copyWith({
    Axis? direction,
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
  }) {
    return FlexStyle(
      direction: direction ?? this.direction,
      mainAxisAlignment: mainAxisAlignment ?? this.mainAxisAlignment,
      mainAxisSize: mainAxisSize ?? this.mainAxisSize,
      crossAxisAlignment: crossAxisAlignment ?? this.crossAxisAlignment,
      wrapAlignment: wrapAlignment ?? this.wrapAlignment,
      wrapCrossAxisAlignment: wrapCrossAxisAlignment ?? this.wrapCrossAxisAlignment,
      runAlignment: runAlignment ?? this.runAlignment,
      verticalDirection: verticalDirection ?? this.verticalDirection,
      textDirection: textDirection ?? this.textDirection,
      textBaseline: textBaseline ?? this.textBaseline,
      clipBehavior: clipBehavior ?? this.clipBehavior,
      spacing: spacing ?? this.spacing,
      runSpacing: runSpacing ?? this.runSpacing,
    );
  }

  FlexStyle merge(FlexStyle other) {
    return FlexStyle(
      direction: other.direction ?? direction,
      mainAxisAlignment: other.mainAxisAlignment ?? mainAxisAlignment,
      mainAxisSize: other.mainAxisSize ?? mainAxisSize,
      crossAxisAlignment: other.crossAxisAlignment ?? crossAxisAlignment,
      wrapAlignment: other.wrapAlignment ?? wrapAlignment,
      wrapCrossAxisAlignment: other.wrapCrossAxisAlignment ?? wrapCrossAxisAlignment,
      runAlignment: other.runAlignment ?? runAlignment,
      verticalDirection: other.verticalDirection ?? verticalDirection,
      textDirection: other.textDirection ?? textDirection,
      textBaseline: other.textBaseline ?? textBaseline,
      clipBehavior: other.clipBehavior ?? clipBehavior,
      spacing: other.spacing ?? spacing,
      runSpacing: other.runSpacing ?? runSpacing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlexStyle &&
          runtimeType == other.runtimeType &&
          direction == other.direction &&
          mainAxisAlignment == other.mainAxisAlignment &&
          mainAxisSize == other.mainAxisSize &&
          crossAxisAlignment == other.crossAxisAlignment &&
          wrapAlignment == other.wrapAlignment &&
          wrapCrossAxisAlignment == other.wrapCrossAxisAlignment &&
          runAlignment == other.runAlignment &&
          verticalDirection == other.verticalDirection &&
          textDirection == other.textDirection &&
          textBaseline == other.textBaseline &&
          clipBehavior == other.clipBehavior &&
          spacing == other.spacing &&
          runSpacing == other.runSpacing;

  @override
  int get hashCode => Object.hash(
        direction,
        mainAxisAlignment,
        mainAxisSize,
        crossAxisAlignment,
        wrapAlignment,
        wrapCrossAxisAlignment,
        runAlignment,
        verticalDirection,
        textDirection,
        textBaseline,
        clipBehavior,
        spacing,
        runSpacing,
      );
}

/// Defines image rendering styling attributes for a [Style].
@immutable
class ImageStyle {
  final BoxFit? fit;
  final AlignmentGeometry? alignment;
  final double? width;
  final double? height;
  final Color? color;
  final BlendMode? colorBlendMode;
  final ImageRepeat? repeat;
  final Rect? centerSlice;
  final bool? matchTextDirection;
  final bool? gaplessPlayback;
  final bool? isAntiAlias;
  final FilterQuality? filterQuality;
  final double? opacity;
  final double? scale;
  final int? cacheWidth;
  final int? cacheHeight;
  final bool? invertColors;

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
    this.scale,
    this.cacheWidth,
    this.cacheHeight,
    this.invertColors,
  });

  ImageStyle copyWith({
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
    return ImageStyle(
      fit: fit ?? this.fit,
      alignment: alignment ?? this.alignment,
      width: width ?? this.width,
      height: height ?? this.height,
      color: color ?? this.color,
      colorBlendMode: colorBlendMode ?? this.colorBlendMode,
      repeat: repeat ?? this.repeat,
      centerSlice: centerSlice ?? this.centerSlice,
      matchTextDirection: matchTextDirection ?? this.matchTextDirection,
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
      isAntiAlias: isAntiAlias ?? this.isAntiAlias,
      filterQuality: filterQuality ?? this.filterQuality,
      opacity: opacity ?? this.opacity,
      scale: scale ?? this.scale,
      cacheWidth: cacheWidth ?? this.cacheWidth,
      cacheHeight: cacheHeight ?? this.cacheHeight,
      invertColors: invertColors ?? this.invertColors,
    );
  }

  ImageStyle merge(ImageStyle other) {
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
      scale: other.scale ?? scale,
      cacheWidth: other.cacheWidth ?? cacheWidth,
      cacheHeight: other.cacheHeight ?? cacheHeight,
      invertColors: other.invertColors ?? invertColors,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageStyle &&
          runtimeType == other.runtimeType &&
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
          opacity == other.opacity &&
          scale == other.scale &&
          cacheWidth == other.cacheWidth &&
          cacheHeight == other.cacheHeight &&
          invertColors == other.invertColors;

  @override
  int get hashCode => Object.hashAll([
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
        scale,
        cacheWidth,
        cacheHeight,
        invertColors,
      ]);
}
