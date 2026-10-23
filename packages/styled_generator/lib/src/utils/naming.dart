/// Naming rules shared by the inspectors.
abstract final class Naming {
  /// [value], or null when it is null or empty.
  static String? nonEmpty(String? value) => value == null || value.isEmpty ? null : value;

  /// `_ButtonSpec` → `StyleButton`, `CardPreset` → `StyleCard`.
  static String presetClassName(String specName) {
    var name = _stripPrivate(specName);
    if (name.endsWith('Spec')) name = name.substring(0, name.length - 4);
    if (name.endsWith('Preset')) name = name.substring(0, name.length - 6);
    if (!name.startsWith('Style')) name = 'Style$name';
    return name;
  }

  /// `StyleButton` → `ButtonVariant`.
  static String variantEnumName(String className) =>
      '${className.startsWith('Style') ? className.substring(5) : className}Variant';

  /// `_AppSpec` → `AppTokens`, `_AnalyticsTokens` → `AnalyticsTokens`.
  static String tokensClassName(String specName) {
    var name = _stripPrivate(specName);
    if (name.endsWith('Spec')) name = name.substring(0, name.length - 4);
    if (!name.endsWith('Tokens')) name = '${name}Tokens';
    return name;
  }

  static String _stripPrivate(String name) => name.startsWith('_') ? name.substring(1) : name;
}
