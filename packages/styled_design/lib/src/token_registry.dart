import 'package:flutter/widgets.dart';
import 'package:styled/styled.dart';
import 'package:styled_design_core/styled_design_core.dart';

/// The library's tokens plus a workspace's token document: overrides of
/// built-in tokens and new tokens.
///
/// A new token becomes `ThemeToken<T>(key, lightValue)`. Only designer presets
/// can use it until a developer promotes it into the library's token spec.
final class TokenRegistry implements StyleTokenLookup {
  final Map<String, ThemeToken<Object?>> _builtIn;
  final TokenDoc doc;
  final StyledTheme Function(String mode) _baseTheme;
  final Map<String, ThemeToken<Object?>> _created = {};

  /// [builtIn] is the library's token list (`OnboardingTokens.all`), and
  /// [baseTheme] its theme per mode (`OnboardingTokens.themeFor`).
  TokenRegistry(
    List<ThemeToken<Object?>> builtIn,
    this.doc, {
    StyledTheme Function(String mode)? baseTheme,
  }) : _builtIn = {for (final t in builtIn) t.key: t},
       _baseTheme = baseTheme ?? ((mode) => StyledTheme(const {}, {'mode': mode})) {
    for (final entry in doc.tokens.values) {
      if (_builtIn.containsKey(entry.key)) continue;
      final type = entry.type;
      if (type == null) throw DesignError("Token '${entry.key}' is not in the library, so it needs a 'type'.");
      final light = entry.values['light'];
      if (light == null) throw DesignError("New token '${entry.key}' needs a 'light' value.");
      _created[entry.key] = _newToken(entry.key, type, decodeTokenValue(type, light, entry.key));
    }
  }

  /// Every token key, built in and new.
  Iterable<String> get keys => {..._builtIn.keys, ..._created.keys};

  /// The token stored under [key], or null.
  @override
  ThemeToken<Object?>? token(String key) => _builtIn[key] ?? _created[key];

  /// The token stored under [key] as a `ThemeToken<T>`. Throws a
  /// [DesignError] for an unknown key or the wrong type.
  ThemeToken<T> typed<T>(String key) {
    final t = token(key);
    if (t == null) {
      throw DesignError("Unknown token '$key'.", [
        Diagnostic.of('E-token-unknown', "No token '$key'.", hint: switch (nearestName(key, keys)) {
          final n? => "Did you mean '$n'?",
          null => null,
        }),
      ]);
    }
    if (t is! ThemeToken<T>) throw DesignError("Token '$key' is ${tokenTypeOf(t)}, not $T.");
    return t;
  }

  /// The library's theme for [mode] with the document's values applied.
  ///
  /// A token's value in a mode other than light is the first that exists of:
  /// the document's value for that mode, the library's value for that mode,
  /// the document's light value, the library default.
  StyledTheme themeFor(String mode) {
    final base = _baseTheme(mode);
    final overrides = <String, Object?>{};
    for (final entry in doc.tokens.values) {
      final t = token(entry.key)!;
      final type = tokenTypeOf(t);
      final own = entry.values[mode];
      if (own != null) {
        overrides[entry.key] = decodeTokenValue(type, own, entry.key);
      } else if (mode != 'light' && base.has(t)) {
        continue;
      } else if (entry.values['light'] case final light?) {
        overrides[entry.key] = decodeTokenValue(type, light, entry.key);
      }
    }
    return overrides.isEmpty ? base : base.copyWith(overrides: overrides);
  }

  /// The token type name of [token], as tokens.json writes it.
  static String tokenTypeOf(ThemeToken<Object?> token) => switch (token) {
    ThemeToken<Color>() => 'color',
    ThemeToken<double>() => 'double',
    ThemeToken<Duration>() => 'duration',
    ThemeToken<FontWeight>() => 'fontWeight',
    ThemeToken<String>() => 'string',
    ThemeToken<ShadowLevel>() => 'shadow',
    _ => 'unknown',
  };

  static ThemeToken<Object?> _newToken(String key, String type, Object value) => switch (type) {
    'color' => ThemeToken<Color>(key, value as Color),
    'double' => ThemeToken<double>(key, value as double),
    'duration' => ThemeToken<Duration>(key, value as Duration),
    'fontWeight' => ThemeToken<FontWeight>(key, value as FontWeight),
    'string' => ThemeToken<String>(key, value as String),
    'shadow' => ThemeToken<ShadowLevel>(key, value as ShadowLevel),
    _ => throw DesignError("Token '$key' has unknown type '$type'."),
  };

  /// Decodes a token value from its JSON form. Throws a [DesignError] for a
  /// value that does not fit [type]: there is no silent fallback.
  static Object decodeTokenValue(String type, Object? json, String key) {
    Never bad(String expected) => throw DesignError("Token '$key' is $type, so its value must be $expected, not $json.");
    switch (type) {
      case 'color':
        if (json is! String || !RegExp(r'^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$').hasMatch(json)) bad('#RRGGBB or #AARRGGBB');
        final hex = json.substring(1);
        return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
      case 'double':
        if (json is! num) bad('a number');
        return json.toDouble();
      case 'duration':
        if (json is! int || json < 0) bad('whole milliseconds');
        return Duration(milliseconds: json);
      case 'fontWeight':
        final weight = const {
          'w100': FontWeight.w100,
          'w200': FontWeight.w200,
          'w300': FontWeight.w300,
          'w400': FontWeight.w400,
          'w500': FontWeight.w500,
          'w600': FontWeight.w600,
          'w700': FontWeight.w700,
          'w800': FontWeight.w800,
          'w900': FontWeight.w900,
        }[json];
        return weight ?? bad('w100 to w900');
      case 'string':
        if (json is! String) bad('text');
        return json;
      case 'shadow':
        if (json is! Map<String, Object?> || json['opacity'] is! num || json['blurRadius'] is! num) {
          bad('{opacity, blurRadius, dx?, dy?, spreadRadius?}');
        }
        double n(String k) => (json[k] as num?)?.toDouble() ?? 0;
        return ShadowLevel(
          opacity: n('opacity'),
          blurRadius: n('blurRadius'),
          spreadRadius: n('spreadRadius'),
          dx: n('dx'),
          dy: n('dy'),
        );
      default:
        throw DesignError("Token '$key' has unknown type '$type'.");
    }
  }
}
