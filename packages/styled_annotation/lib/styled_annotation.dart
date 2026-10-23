import 'package:meta/meta_meta.dart';

/// Annotation for generating a [StyleResolver] preset class and variants.
///
/// Annotate a specification class (e.g. `_StyleBadgeSpec`) to generate:
/// - A typed [StyleResolver] class (e.g. `StyleBadge`)
/// - A variant enum (e.g. `BadgeVariant`)
/// - `const` default and named variant constructors
/// - Context resolution with automatic theme token injection and base style merging
/// - `copyWith`, `operator ==`, and `hashCode` implementations
@Target({TargetKind.classType})
class StyledPreset {
  /// Custom name for the generated StyleResolver class.
  /// If null, derived from the annotated spec class (e.g. `_StyleBadgeSpec` -> `StyleBadge`).
  final String? name;

  /// Whether to generate an enum containing all variant names (e.g. `BadgeVariant`).
  final bool generateVariantsEnum;

  /// Whether each variant automatically merges on top of the base style.
  /// Defaults to `true` if a `base` method is defined.
  final bool mergeBase;

  const StyledPreset({
    this.name,
    this.generateVariantsEnum = true,
    this.mergeBase = true,
  });
}

/// Annotation for marking variant methods on a [@StyledPreset] spec.
@Target({TargetKind.method})
class Variant {
  /// Whether this variant serves as the default constructor `StyleX()`.
  final bool isDefault;

  /// Alternative named constructor aliases (e.g. `['danger']` for an `error` variant).
  final List<String> aliases;

  const Variant({
    this.isDefault = false,
    this.aliases = const [],
  });
}

/// Annotation for configuring responsive breakpoint resolution on a [@Variant] method.
///
/// Can specify method names for different screen sizes:
/// - [mobile]: Name of the static method to call for mobile viewports (< 650px).
/// - [tablet]: Name of the static method to call for tablet viewports (< 1360px).
/// - [desktop]: Name of the static method to call for desktop viewports (>= 1360px).
///   If not specified, the annotated method itself is used for desktop (and as fallback).
/// - [attachStates]: Whether to also attach responsive styles as states via `.on('mobile', ...)`
///   and `.on('tablet', ...)`. Defaults to `false`.
@Target({TargetKind.method, TargetKind.classType})
class Responsive {
  /// Name of the static method for mobile breakpoint.
  final String? mobile;

  /// Name of the static method for tablet breakpoint.
  final String? tablet;

  /// Name of the static method for desktop breakpoint.
  final String? desktop;

  /// Whether to also register breakpoint styles as `.on(...)` states on the returned Style.
  final bool attachStates;

  const Responsive({
    this.mobile,
    this.tablet,
    this.desktop,
    this.attachStates = false,
  });
}

/// Annotation for generating design token classes and [StyledTheme] extension getters.
///
/// Annotate a specification class (e.g. `_AnalyticsTokensSpec`) to generate:
/// - A tokens class with typed `ThemeToken<T>` constants (e.g. `AnalyticsTokens`)
/// - A [StyledTheme] extension with typed getters (`theme.primary`, `theme.padding`)
/// - A `toDefaultMap()` helper on the tokens class
@Target({TargetKind.classType})
class StyledTokens {
  /// Custom name for the generated tokens container class.
  /// If null, derived from the annotated spec class (e.g. `_AnalyticsTokensSpec` -> `AnalyticsTokens`).
  final String? className;

  /// Custom name for the generated StyledTheme extension.
  /// If null, defaults to `${className}Extension`.
  final String? extensionName;

  /// Whether to generate a `toDefaultMap()` helper on the tokens class.
  final bool generateDefaultMap;

  const StyledTokens({
    this.className,
    this.extensionName,
    this.generateDefaultMap = true,
  });
}

/// Annotation for customizing individual token key names.
@Target({TargetKind.field})
class Token {
  /// Explicit key name for the token. If null, the field name is used.
  final String? key;

  const Token({this.key});
}
