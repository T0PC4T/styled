import 'package:meta/meta_meta.dart';

/// Generates a `StyleResolver` preset class from a spec class.
///
/// Spec members are static `Style` fields (preferred: `static const`) or
/// static methods returning `Style`. Styles reference tokens directly
/// (`AppTokens.primary`), so members never read the theme: a `StyledTheme`,
/// `BuildContext` or `Size` parameter is a build error. Methods may take named
/// parameters, which become fields on the preset, and `StyledScreen screen`,
/// which is injected.
///
/// Methods are classified by name and annotation:
///
/// | Member                         | Role                                             |
/// |--------------------------------|--------------------------------------------------|
/// | `@Variant()`                   | A variant: a constructor and an enum value        |
/// | `base`                         | Merged under every variant                        |
/// | `hovered`, `pressed`, `focused`, `disabled`, `error`, `mobile`, `tablet`, `desktop` | State override for every variant |
/// | `primaryHovered` (`${variant}${State}`) | State override for one variant           |
/// | `@On('selected')`              | Override for an application state                 |
/// | other public `Style` members   | A variant                                        |
///
/// ```dart
/// @StyledPreset()
/// abstract class _StyleButtonSpec {
///   static const base = Style(box: BoxStyle(padding: StyledEdgeInsets.all(AppTokens.padding)));
///   @Variant(isDefault: true)
///   static const primary = Style(box: BoxStyle(color: AppTokens.primary));
///   static const primaryHovered = Style(box: BoxStyle(color: AppTokens.primaryVariant));
///   static const disabled = Style(box: BoxStyle(color: AppTokens.disabledFill));
///   @On('selected')
///   static const selectedRing = Style(box: BoxStyle(border: StyledBorder(color: AppTokens.primary)));
/// }
/// ```
@Target({TargetKind.classType})
class StyledPreset {
  /// Name of the generated class. Defaults to the spec name without the
  /// leading `_` and trailing `Spec`, prefixed with `Style`.
  final String? name;

  /// Name of the generated variant enum. Defaults to the class name without
  /// `Style`, plus `Variant` (`StyleButton` → `ButtonVariant`).
  final String? variantEnumName;

  const StyledPreset({this.name, this.variantEnumName});
}

/// Marks a spec method or static field as a variant of a [StyledPreset].
@Target({TargetKind.method, TargetKind.field})
class Variant {
  /// Whether this variant backs the unnamed constructor.
  final bool isDefault;

  /// Extra constructor names for this variant (for example `['danger']`).
  final List<String> aliases;

  const Variant({this.isDefault = false, this.aliases = const []});
}

/// Marks a spec method as the override for an application state, such as
/// `selected` or `loading`.
///
/// Applies to every variant unless [variants] names some.
@Target({TargetKind.method, TargetKind.field})
class On {
  /// The state key, matching a `StyleState('...')` constant.
  final String state;

  /// Variant names this override applies to. Empty means all.
  final List<String> variants;

  const On(this.state, {this.variants = const []});
}

/// Generates token constants, theme getters, typed overrides and theme modes
/// from a spec class of `static const` values.
///
/// For `_AppTokensSpec` this generates:
/// - `AppTokens` with a `ThemeToken<T>` per field, `all`, and `toDefaultMap()`
/// - `extension AppTokensExtension on StyledTheme` with a getter per token
/// - `theme.withAppTokens(primary: ..., radius: ...)`, typed overrides
/// - `AppTokens.overridesFor(mode)`, `AppTokens.themeFor(mode)` and, when any
///   token declares a dark value, `AppTokens.dark`
@Target({TargetKind.classType})
class StyledTokens {
  /// Name of the tokens class. Defaults to the spec name without `_` and
  /// `Spec`, ending in `Tokens`.
  final String? className;

  /// Name of the getter extension. Defaults to `${className}Extension`.
  final String? extensionName;

  /// Whether to generate `toDefaultMap()`.
  final bool generateDefaultMap;

  /// Prefix for every token key, joined with a dot (`'analytics'` →
  /// `'analytics.primary'`). Keeps keys from colliding in a shared theme.
  final String? prefix;

  const StyledTokens({
    this.className,
    this.extensionName,
    this.generateDefaultMap = true,
    this.prefix,
  });
}

/// Customises one token field of a [StyledTokens] spec.
@Target({TargetKind.field})
class Token {
  /// Explicit key. Defaults to the field name.
  final String? key;

  /// Value used by the generated `dark` theme.
  final Object? dark;

  /// Values for other named modes, for example `{'highContrast': Color(0xFF000000)}`.
  final Map<String, Object?> modes;

  const Token({this.key, this.dark, this.modes = const {}});
}
