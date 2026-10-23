import 'package:build_test/build_test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:styled_generator/styled_generator.dart';
import 'package:test/test.dart';

void main() {
  group('StyledTokensGenerator', () {
    test('generates ThemeToken constants, list, default map and theme extension', () async {
      final builder = PartBuilder([const StyledTokensGenerator()], '.styled.g.dart');

      await testBuilder(
        builder,
        {
          'styled_annotation|lib/styled_annotation.dart': '''
class StyledTokens {
  final String? className;
  final String? extensionName;
  final bool generateDefaultMap;
  const StyledTokens({this.className, this.extensionName, this.generateDefaultMap = true});
}
class Token {
  final String? key;
  const Token({this.key});
}
''',
          'a|lib/test_tokens.dart': '''
import 'package:styled_annotation/styled_annotation.dart';

part 'test_tokens.styled.g.dart';

class Color {
  final int value;
  const Color(this.value);
}

@StyledTokens(className: 'AppTokens', extensionName: 'AppThemeExtension')
abstract final class _AppTokensSpec {
  static const primary = Color(0xFF2563EB);
  static const padding = 16.0;
  static const generalFontFamily = 'Inter';
  static const isDark = false;

  @Token(key: 'custom_radius')
  static const radius = 8.0;
}
''',
        },
        outputs: {
          'a|lib/test_tokens.styled.g.dart': decodedMatches(
            allOf([
              contains('abstract final class AppTokens {'),
              contains("static const primary = ThemeToken<Color>('primary', Color(0xFF2563EB));"),
              contains("static const padding = ThemeToken<double>('padding', 16.0);"),
              contains("static const generalFontFamily = ThemeToken<String>("),
              contains("'generalFontFamily',"),
              contains("'Inter',"),
              contains("static const isDark = ThemeToken<bool>('isDark', false);"),
              contains("static const radius = ThemeToken<double>('custom_radius', 8.0);"),
              contains('static const all = <ThemeToken<dynamic>>['),
              contains('static Map<String, dynamic> toDefaultMap() => {'),
              contains('primary.key: primary.defaultValue,'),
              contains('padding.key: padding.defaultValue,'),
              contains('extension AppThemeExtension on StyledTheme {'),
              contains('Color get primary => get(AppTokens.primary);'),
              contains('double get padding => get(AppTokens.padding);'),
              contains('String get generalFontFamily => get(AppTokens.generalFontFamily);'),
              contains('bool get isDark => get(AppTokens.isDark);'),
              contains('double get radius => get(AppTokens.radius);'),
            ]),
          ),
        },
      );
    });
  });
}
