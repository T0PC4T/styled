import 'package:build_test/build_test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:styled_generator/styled_generator.dart';
import 'package:test/test.dart';

String _squash(String s) => s.replaceAll(RegExp(r'[\s,]+'), '');

/// Matches generated source containing [snippet], ignoring formatting.
Matcher _has(String snippet) =>
    predicate<String>((source) => _squash(source).contains(_squash(snippet)), 'contains `$snippet`');

const _annotations = '''
class StyledTokens {
  final String? className;
  final String? extensionName;
  final bool generateDefaultMap;
  final String? prefix;
  const StyledTokens({this.className, this.extensionName, this.generateDefaultMap = true, this.prefix});
}
class Token {
  final String? key;
  final Object? dark;
  final Map<String, Object?> modes;
  const Token({this.key, this.dark, this.modes = const {}});
}
''';

Future<void> _build(String spec, Object output) => testBuilder(
      PartBuilder([const StyledTokensGenerator()], '.styled.g.dart'),
      {
        'styled_annotation|lib/styled_annotation.dart': _annotations,
        'a|lib/tokens.dart': '''
import 'package:styled_annotation/styled_annotation.dart';

part 'tokens.styled.g.dart';

class Color {
  final int value;
  const Color(this.value);
}

$spec
''',
      },
      outputs: {'a|lib/tokens.styled.g.dart': output},
    );

void main() {
  group('StyledTokensGenerator', () {
    test('generates tokens, list, default map, getters and typed overrides', () async {
      await _build(
        '''
@StyledTokens(className: 'AppTokens', extensionName: 'AppThemeExtension')
abstract final class _AppTokensSpec {
  /// Brand colour.
  static const primary = Color(0xFF2563EB);
  static const double padding = 16.0; // Standard content padding
  static const generalFontFamily = 'Inter';
  static const isDark = false;

  @Token(key: 'custom_radius')
  static const double radius = 8.0;
}
''',
        decodedMatches(allOf([
          _has('abstract final class AppTokens {'),
          _has("static const primary = ThemeToken<Color>('primary', Color(0xFF2563EB));"),
          _has("static const padding = ThemeToken<double>('padding', 16.0);"),
          _has("static const isDark = ThemeToken<bool>('isDark', false);"),
          _has("static const radius = ThemeToken<double>('custom_radius', 8.0);"),
          _has('static const all = <ThemeToken<dynamic>>['),
          _has('primary.key: primary.defaultValue,'),
          _has('extension AppThemeExtension on StyledTheme {'),
          _has('/// Brand colour.\n  Color get primary => get(AppTokens.primary);'),
          _has('/// Standard content padding\n  double get padding => get(AppTokens.padding);'),
          _has('extension AppTokensOverrides on StyledTheme {'),
          _has('StyledTheme withAppTokens({'),
          _has('Color? primary,'),
          _has('if (radius != null) AppTokens.radius.key: radius,'),
          _has('static Map<String, Object?> overridesFor(String mode) => const {};'),
          isNot(_has('static StyledTheme get dark')),
        ])),
      );
    });

    test('generates theme modes from @Token(dark:) and @Token(modes:)', () async {
      await _build(
        '''
@StyledTokens()
abstract final class _BrandTokensSpec {
  @Token(dark: Color(0xFF0B0F19), modes: {'contrast': Color(0xFF000000)})
  static const background = Color(0xFFF8FAFC);
  @Token(dark: Color(0xFFF8FAFC))
  static const onBackground = Color(0xFF0F172A);
  static const radius = 8.0;
}
''',
        decodedMatches(allOf([
          _has('abstract final class BrandTokens {'),
          _has("static const modeNames = <String>['dark', 'contrast'];"),
          _has("'dark' => {"),
          _has('background.key: const Color(0xFF0B0F19),'),
          _has('onBackground.key: const Color(0xFFF8FAFC),'),
          _has("'contrast' => {"),
          _has('background.key: const Color(0xFF000000),'),
          _has("static StyledTheme themeFor(String mode) => StyledTheme(overridesFor(mode), {'mode': mode});"),
          _has("static StyledTheme get dark => themeFor('dark');"),
          _has('extension BrandTokensExtension on StyledTheme {'),
        ])),
      );
    });

    test('prefixes keys', () async {
      await _build(
        '''
@StyledTokens(prefix: 'charts')
abstract final class _ChartTokensSpec {
  static const grid = Color(0xFFE2E8F0);
}
''',
        decodedMatches(_has("static const grid = ThemeToken<Color>('charts.grid', Color(0xFFE2E8F0));")),
      );
    });
  });
}
