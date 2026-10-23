import 'package:flutter/widgets.dart';

import '../theme/styled_theme.dart';
import 'values.dart';

// Token-aware mirrors of Flutter's composite types. Each takes [StyleValue]s
// where Flutter takes raw numbers or colours, mirrors the Flutter class's
// constructor and parameter names, and resolves to the Flutter type against
// a theme. Each offers only the shapes the design system needs.

/// Default values used by the engine itself.
abstract final class StyledDefaults {
  /// Duration used by `Motion()` when none is given.
  static const motionDuration = ThemeToken<Duration>('styled.motionDuration', Duration(milliseconds: 150));
}

/// Token-aware [EdgeInsets].
///
/// ```dart
/// StyledEdgeInsets.symmetric(horizontal: AppTokens.paddingLg, vertical: AppTokens.paddingSm)
/// ```
@immutable
class StyledEdgeInsets {
  final StyleValue<double>? left;
  final StyleValue<double>? top;
  final StyleValue<double>? right;
  final StyleValue<double>? bottom;

  const StyledEdgeInsets.only({this.left, this.top, this.right, this.bottom});

  const StyledEdgeInsets.fromLTRB(this.left, this.top, this.right, this.bottom);

  const StyledEdgeInsets.all(StyleValue<double> value)
      : left = value,
        top = value,
        right = value,
        bottom = value;

  const StyledEdgeInsets.symmetric({StyleValue<double>? horizontal, StyleValue<double>? vertical})
      : left = horizontal,
        right = horizontal,
        top = vertical,
        bottom = vertical;

  /// No insets.
  static const zero = StyledEdgeInsets.only();

  EdgeInsets resolve(StyledTheme theme) => EdgeInsets.fromLTRB(
        theme.read(left) ?? 0,
        theme.read(top) ?? 0,
        theme.read(right) ?? 0,
        theme.read(bottom) ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StyledEdgeInsets && left == other.left && top == other.top && right == other.right && bottom == other.bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

/// Token-aware [BoxConstraints]. Unset minimums are 0 and unset maximums are
/// unbounded.
@immutable
class StyledBoxConstraints {
  final StyleValue<double>? minWidth;
  final StyleValue<double>? maxWidth;
  final StyleValue<double>? minHeight;
  final StyleValue<double>? maxHeight;

  const StyledBoxConstraints({this.minWidth, this.maxWidth, this.minHeight, this.maxHeight});

  /// Exactly [width] and [height], filling the available space on an axis
  /// that is not given, like [BoxConstraints.expand].
  const StyledBoxConstraints.expand({StyleValue<double>? width, StyleValue<double>? height})
      : minWidth = width ?? StyleValue.infinity,
        maxWidth = width ?? StyleValue.infinity,
        minHeight = height ?? StyleValue.infinity,
        maxHeight = height ?? StyleValue.infinity;

  /// Exactly [width] and [height], unconstrained on an axis that is not
  /// given, like [BoxConstraints.tightFor].
  const StyledBoxConstraints.tightFor({StyleValue<double>? width, StyleValue<double>? height})
      : minWidth = width,
        maxWidth = width,
        minHeight = height,
        maxHeight = height;

  BoxConstraints resolve(StyledTheme theme) => BoxConstraints(
        minWidth: theme.read(minWidth) ?? 0,
        maxWidth: theme.read(maxWidth) ?? double.infinity,
        minHeight: theme.read(minHeight) ?? 0,
        maxHeight: theme.read(maxHeight) ?? double.infinity,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StyledBoxConstraints &&
          minWidth == other.minWidth &&
          maxWidth == other.maxWidth &&
          minHeight == other.minHeight &&
          maxHeight == other.maxHeight;

  @override
  int get hashCode => Object.hash(minWidth, maxWidth, minHeight, maxHeight);
}

/// Token-aware [BorderSide].
@immutable
class StyledBorderSide {
  final StyleValue<Color>? color;
  final StyleValue<double>? width;
  final BorderStyle style;

  const StyledBorderSide({this.color, this.width, this.style = BorderStyle.solid});

  /// No side.
  static const none = StyledBorderSide(width: StyleValue.zero, style: BorderStyle.none);

  BorderSide resolve(StyledTheme theme) => BorderSide(
        color: theme.read(color) ?? const Color(0xFF000000),
        width: theme.read(width) ?? 1.0,
        style: style,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StyledBorderSide && color == other.color && width == other.width && style == other.style;

  @override
  int get hashCode => Object.hash(color, width, style);
}

/// Token-aware [BoxShadow]: a colour at a step of the shadow scale.
///
/// The opacity, blur, spread and offset come from a [ThemeToken<ShadowLevel>], so every
/// shadow in the app uses the same few levels:
///
/// ```dart
/// boxShadow: [StyledBoxShadow.level(AppTokens.primary, AppTokens.glowMd)]
/// ```
@immutable
class StyledBoxShadow {
  final StyleValue<Color> color;
  final ThemeToken<ShadowLevel> shadowLevel;

  /// [color] at the opacity, blur, spread and offset of [level].
  const StyledBoxShadow.level(this.color, ThemeToken<ShadowLevel> level) : shadowLevel = level;

  BoxShadow resolve(StyledTheme theme) {
    final level = theme.get(shadowLevel);
    return BoxShadow(
      color: color.resolve(theme).withValues(alpha: level.opacity),
      blurRadius: level.blurRadius,
      spreadRadius: level.spreadRadius,
      offset: Offset(level.dx, level.dy),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StyledBoxShadow && color == other.color && shadowLevel == other.shadowLevel;

  @override
  int get hashCode => Object.hash(color, shadowLevel);
}

/// Token-aware transform. Only translation is offered: the design system
/// moves things (hover lifts, pressed nudges) but does not rotate or skew them.
@immutable
class StyledTransform {
  final StyleValue<double>? x;
  final StyleValue<double>? y;

  const StyledTransform.translate({this.x, this.y});

  Matrix4 resolve(StyledTheme theme) => Matrix4.translationValues(theme.read(x) ?? 0, theme.read(y) ?? 0, 0);

  @override
  bool operator ==(Object other) => identical(this, other) || other is StyledTransform && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Implicit animation for a box: animate changes between resolved styles
/// over [duration] with [curve].
@immutable
class Motion {
  final StyleValue<Duration> duration;
  final Curve curve;

  const Motion([this.duration = StyledDefaults.motionDuration, this.curve = Curves.linear]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Motion && duration == other.duration && curve == other.curve;

  @override
  int get hashCode => Object.hash(duration, curve);

  @override
  String toString() => 'Motion($duration, $curve)';
}
