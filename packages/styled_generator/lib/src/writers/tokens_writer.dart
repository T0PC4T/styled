import '../models/tokens_descriptor.dart';
import '../utils/doc_utils.dart';

/// Layer 3 Emitter: Writes the token class and `StyledTheme` extensions for
/// a [TokensDescriptor].
///
/// Emits:
/// 1. `abstract final class <Name>Tokens`: a `ThemeToken` constant per token,
///    `all`, `toDefaultMap`, and the theme modes (`modeNames`,
///    `overridesFor`, `themeFor`, and `dark` when declared).
/// 2. `extension <Name>TokensExtension on StyledTheme`: a typed getter per token.
/// 3. `extension <Name>TokensOverrides on StyledTheme`: `with<Name>Tokens(...)`
///    typed overrides.
class TokensWriter {
  /// Emits the Dart source for [descriptor].
  static String write(TokensDescriptor descriptor) {
    final out = StringBuffer();
    _writeTokensClass(out, descriptor);
    _writeGetters(out, descriptor);
    _writeOverrides(out, descriptor);
    return out.toString();
  }

  static void _writeTokensClass(StringBuffer out, TokensDescriptor d) {
    out.writeln('/// Typed token keys generated from [${d.specName}].');
    out.writeln('abstract final class ${d.className} {');
    for (final t in d.tokens) {
      writeDocComment(out, t.docComment, indent: '  ');
      out.writeln("  static const ${t.name} = ThemeToken<${t.typeName}>('${t.key}', ${t.initializer});");
    }
    out.writeln();
    out.writeln('  /// Every token in [${d.specName}].');
    out.writeln('  static const all = <ThemeToken<dynamic>>[${d.tokens.map((t) => t.name).join(', ')}];');

    if (d.generateDefaultMap) {
      out.writeln();
      out.writeln('  /// Token keys mapped to their default values.');
      out.writeln('  static Map<String, dynamic> toDefaultMap() => {');
      for (final t in d.tokens) {
        out.writeln('    ${t.name}.key: ${t.name}.defaultValue,');
      }
      out.writeln('  };');
    }

    _writeModes(out, d);
    out.writeln('}');
    out.writeln();
  }

  static void _writeModes(StringBuffer out, TokensDescriptor d) {
    final modeNames = d.modeNames;
    out.writeln();
    out.writeln('  /// Names of the theme modes declared with `@Token(dark:)` or `@Token(modes:)`.');
    out.writeln('  static const modeNames = <String>[${modeNames.map((m) => "'$m'").join(', ')}];');
    out.writeln();
    out.writeln('  /// Token overrides for [mode]. Unknown modes have none.');
    if (modeNames.isEmpty) {
      out.writeln('  static Map<String, Object?> overridesFor(String mode) => const {};');
    } else {
      out.writeln('  static Map<String, Object?> overridesFor(String mode) => switch (mode) {');
      for (final mode in modeNames) {
        out.writeln("    '$mode' => {");
        for (final t in d.tokens) {
          if (t.modes[mode] case final value?) out.writeln('      ${t.name}.key: ${_constify(value)},');
        }
        out.writeln('    },');
      }
      out.writeln('    _ => const {},');
      out.writeln('  };');
    }
    out.writeln();
    out.writeln('  /// A theme with the overrides for [mode] and `metadata[\'mode\']` set.');
    out.writeln("  static StyledTheme themeFor(String mode) => StyledTheme(overridesFor(mode), {'mode': mode});");
    if (modeNames.contains('dark')) {
      out.writeln();
      out.writeln('  /// The dark theme declared with `@Token(dark:)`.');
      out.writeln("  static StyledTheme get dark => themeFor('dark');");
    }
  }

  static void _writeGetters(StringBuffer out, TokensDescriptor d) {
    out.writeln('/// Typed token getters on [StyledTheme].');
    out.writeln('extension ${d.extensionName} on StyledTheme {');
    for (final t in d.tokens) {
      writeDocComment(out, t.docComment, indent: '  ');
      out.writeln('  ${t.typeName} get ${t.name} => get(${d.className}.${t.name});');
    }
    out.writeln('}');
    out.writeln();
  }

  static void _writeOverrides(StringBuffer out, TokensDescriptor d) {
    out.writeln('/// Typed token overrides on [StyledTheme].');
    out.writeln('extension ${d.className}Overrides on StyledTheme {');
    out.writeln('  /// A copy of this theme with the given tokens replaced.');
    out.writeln('  StyledTheme with${d.className}({');
    for (final t in d.tokens) {
      out.writeln('    ${t.nullableTypeName} ${t.name},');
    }
    out.writeln('  }) => copyWith(overrides: {');
    for (final t in d.tokens) {
      out.writeln('    if (${t.name} != null) ${d.className}.${t.name}.key: ${t.name},');
    }
    out.writeln('  });');
    out.writeln('}');
  }

  /// Annotation arguments are constant, so a bare constructor call can be
  /// emitted as `const` inside the (non-const) overrides map.
  static String _constify(String source) =>
      RegExp(r'^[A-Z]\w*(\.\w+)?\(').hasMatch(source) ? 'const $source' : source;
}
