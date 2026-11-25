import 'package:flutter/widgets.dart';
import 'package:styled/styled.dart';
import 'package:styled_design_core/styled_design_core.dart';

import 'build_context.dart';

/// Builds one component from a document node. Generated beside each
/// `@Designable` widget, or written by hand for irregular ones.
abstract class DesignDefinition {
  const DesignDefinition();

  /// What documents may write on this component.
  DesignComponent get spec;

  /// A [Widget], or for a value component the value object a slot holds.
  Object build(DesignBuildContext ctx);
}

/// Extra arguments of a preset reference, such as `StyleIconToken`'s size.
final class PresetArgs {
  final Map<String, Object?> values;
  final StyleValue<T>? Function<T>(String key) _token;

  const PresetArgs(this.values, this._token);

  static PresetArgs none = PresetArgs(const {}, <T>(_) => null);

  /// A token argument, resolved through the token registry.
  StyleValue<T>? token<T>(String name) => switch (values[name]) {
    final String key => _token<T>(key),
    _ => null,
  };

  Object? operator [](String name) => values[name];
}

/// Builds the built-in variant [variant] of a preset family.
typedef PresetFactory = StyleResolver Function(String variant, PresetArgs args);

/// Everything a library hands the engine: component definitions, preset
/// families, tokens, icons and formatters. Generated per library as
/// `<Library>Design.registry`.
final class DesignRegistry {
  final Map<String, DesignDefinition> definitions;

  /// Preset family name → factory: `'StyleButton': (v, a) => StyleButton.fromVariant(...)`.
  final Map<String, PresetFactory> presets;

  /// Each preset family's variants and arguments, for the catalog.
  final Map<String, CatalogPresetFamily> presetFamilies;

  /// Every built-in token, such as `OnboardingTokens.all`.
  final List<ThemeToken<Object?>> tokens;

  /// The group of each token key, for the catalog and a token editor.
  final Map<String, String> tokenGroups;

  /// The library's base theme for a mode, such as `OnboardingTokens.themeFor`.
  final StyledTheme Function(String mode) themeFor;

  /// Icon catalogue: name → glyph.
  final Map<String, IconData> icons;

  final DesignFormatters formatters;

  /// Library-wide lints for the catalog, such as the page root rule.
  final List<DesignRule> rules;

  /// The catalog version this registry implements. A bundle that requires a
  /// newer one is refused: it may use components this build does not have.
  final int catalogVersion;

  DesignRegistry({
    required Iterable<DesignDefinition> definitions,
    this.presets = const {},
    this.presetFamilies = const {},
    this.tokens = const [],
    this.tokenGroups = const {},
    StyledTheme Function(String mode)? themeFor,
    this.icons = const {},
    this.formatters = DesignFormatters.standard,
    this.rules = const [],
    this.catalogVersion = 1,
  }) : definitions = {for (final d in definitions) d.spec.type: d},
       themeFor = themeFor ?? ((mode) => StyledTheme(const {}, {'mode': mode}));

  /// This registry with [more] definitions added, such as the engine's own.
  DesignRegistry withDefinitions(Iterable<DesignDefinition> more) => DesignRegistry(
    definitions: [...definitions.values, ...more.where((d) => !definitions.containsKey(d.spec.type))],
    presets: presets,
    presetFamilies: presetFamilies,
    tokens: tokens,
    tokenGroups: tokenGroups,
    themeFor: themeFor,
    icons: icons,
    formatters: formatters,
    rules: rules,
    catalogVersion: catalogVersion,
  );

  DesignDefinition? operator [](String type) => definitions[type];
}
