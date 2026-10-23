import 'package:build_test/build_test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:styled_generator/styled_generator.dart';
import 'package:test/test.dart';

void main() {
  group('StyledPresetGenerator', () {
    test('generates enum, class, named constructors, resolve, copyWith and equals', () async {
      final builder = PartBuilder([const StyledPresetGenerator()], '.styled.g.dart');

      await testBuilder(
        builder,
        {
          'styled_annotation|lib/styled_annotation.dart': '''
class StyledPreset {
  final String? name;
  final bool generateVariantsEnum;
  final bool mergeBase;
  const StyledPreset({this.name, this.generateVariantsEnum = true, this.mergeBase = true});
}
class Variant {
  final bool isDefault;
  final List<String> aliases;
  const Variant({this.isDefault = false, this.aliases = const []});
}
''',
          'a|lib/test_badge.dart': '''
import 'package:styled_annotation/styled_annotation.dart';

part 'test_badge.styled.g.dart';

class StyledTheme {}
class BuildContext {}
class Color {
  final int value;
  const Color(this.value);
}
class Style {
  const Style();
  Style merge(Style? other) => this;
}

@StyledPreset(name: 'StyleBadge')
abstract class _StyleBadgeSpec {
  static Style base(StyledTheme theme, {Color? customColor, bool isPill = false}) => const Style();

  @Variant(isDefault: true)
  static Style standard(StyledTheme theme, {Color? customColor, bool isPill = false}) => const Style();

  @Variant(aliases: ['danger'])
  static Style error(StyledTheme theme, {Color? customColor, bool isPill = false}) => const Style();
}
''',
        },
        outputs: {
          'a|lib/test_badge.styled.g.dart': decodedMatches(
            allOf([
              contains('enum BadgeVariant { standard, error }'),
              contains('class StyleBadge extends StyleResolver {'),
              contains('final BadgeVariant variant;'),
              contains('final Color? customColor;'),
              contains('final bool isPill;'),
              contains('const StyleBadge({'),
              contains('const StyleBadge.standard({'),
              contains('const StyleBadge.error({'),
              contains('const StyleBadge.danger({'),
              contains('const StyleBadge.fromVariant('),
              contains('Style resolve(BuildContext context) {'),
              contains('final baseStyle = _StyleBadgeSpec.base('),
              contains('BadgeVariant.standard => _StyleBadgeSpec.standard('),
              contains('BadgeVariant.error => _StyleBadgeSpec.error('),
              contains('return baseStyle.merge(variantStyle) as Style;'),
              contains('StyleBadge copyWith({'),
              contains('bool operator ==(Object other)'),
              contains('int get hashCode => Object.hash('),
            ]),
          ),
        },
      );
    });

    test('generates @Responsive breakpoint switching and propagates doc comments', () async {
      final builder = PartBuilder([const StyledPresetGenerator()], '.styled.g.dart');

      await testBuilder(
        builder,
        {
          'styled_annotation|lib/styled_annotation.dart': '''
class StyledPreset {
  final String? name;
  final bool generateVariantsEnum;
  final bool mergeBase;
  const StyledPreset({this.name, this.generateVariantsEnum = true, this.mergeBase = true});
}
class Variant {
  final bool isDefault;
  final List<String> aliases;
  const Variant({this.isDefault = false, this.aliases = const []});
}
class Responsive {
  final String? mobile;
  final String? tablet;
  final String? desktop;
  final bool attachStates;
  const Responsive({this.mobile, this.tablet, this.desktop, this.attachStates = false});
}
''',
          'a|lib/test_responsive.dart': '''
import 'package:styled_annotation/styled_annotation.dart';

part 'test_responsive.styled.g.dart';

class StyledTheme {}
class BuildContext {}
enum StyledScreen {
  mobile(650),
  tablet(1360),
  desktop(double.infinity);
  final double width;
  const StyledScreen(this.width);
  static ({StyledScreen screen, Object size}) fromContext(BuildContext context) =>
      (screen: StyledScreen.desktop, size: Object());
}

class Style {
  const Style();
  Style on(String token, {Style? style}) => this;
}

/// Flexible container preset for responsive layouts.
@StyledPreset(name: 'StyleLayout', mergeBase: false)
abstract class _StyleLayoutSpec {
  /// Horizontal layout for desktop.
  @Variant(isDefault: true)
  static Style row(StyledTheme theme) => const Style();

  /// Responsive flex switching between column on mobile/tablet and row on desktop.
  @Variant()
  @Responsive(mobile: 'colrowMobile', tablet: 'colrowTablet')
  static Style colrow(StyledTheme theme) => const Style();

  static Style colrowMobile(StyledTheme theme) => const Style();
  static Style colrowTablet(StyledTheme theme) => const Style();

  /// Card with states attached.
  @Variant()
  @Responsive(mobile: 'cardMobile', attachStates: true)
  static Style card(StyledTheme theme) => const Style();

  static Style cardMobile(StyledTheme theme) => const Style();

  /// Direct parameter injection of StyledScreen.
  @Variant()
  static Style screenDirect(StyledTheme theme, StyledScreen screen) => const Style();

  /// Convention-based responsive detection.
  @Variant()
  @Responsive()
  static Style autoNamed(StyledTheme theme) => const Style();

  static Style autoNamedMobile(StyledTheme theme) => const Style();
  static Style autoNamedTablet(StyledTheme theme) => const Style();
}
''',
        },
        outputs: {
          'a|lib/test_responsive.styled.g.dart': decodedMatches(
            allOf([
              contains('/// Flexible container preset for responsive layouts.'),
              contains('/// Reusable style preset generated from [_StyleLayoutSpec].'),
              contains('class StyleLayout extends StyleResolver {'),
              contains('/// Variant options for [StyleLayout].'),
              contains('enum LayoutVariant {'),
              contains('/// Horizontal layout for desktop.'),
              contains('row,'),
              contains('/// Responsive flex switching between column on mobile/tablet and row on desktop.'),
              contains('colrow,'),
              contains('card,'),
              contains('screenDirect,'),
              // Ensure delegate methods like colrowMobile/colrowTablet are NOT in LayoutVariant
              isNot(contains('colrowMobile,')),
              isNot(contains('colrowTablet,')),
              isNot(contains('cardMobile,')),
              // Verify constructors have propagated doc comments
              contains('/// Horizontal layout for desktop.'),
              contains('const StyleLayout() : variant = LayoutVariant.row;'),
              contains('const StyleLayout.row() : variant = LayoutVariant.row;'),
              contains('/// Responsive flex switching between column on mobile/tablet and row on desktop.'),
              contains('const StyleLayout.colrow() : variant = LayoutVariant.colrow;'),
              // Verify resolve method extracts screen and switches
              contains('final (screen: screen, size: _) = StyledScreen.fromContext(context);'),
              contains('LayoutVariant.row => _StyleLayoutSpec.row(theme),'),
              contains('LayoutVariant.colrow => switch (screen) {'),
              contains('StyledScreen.mobile => _StyleLayoutSpec.colrowMobile(theme),'),
              contains('StyledScreen.tablet => _StyleLayoutSpec.colrowTablet(theme),'),
              contains('StyledScreen.desktop => _StyleLayoutSpec.colrow(theme),'),
              // Verify attachStates: true attaches .on(...)
              contains('.on(StyledScreen.tablet.name, style: tabletStyle)'),
              contains('.on(StyledScreen.mobile.name, style: mobileStyle)'),
              // Verify direct screen parameter injection
              contains('LayoutVariant.screenDirect => _StyleLayoutSpec.screenDirect('),
              contains('screen,'),
              // Verify convention-based resolution
              isNot(contains('autoNamedMobile,')),
              isNot(contains('autoNamedTablet,')),
              contains('LayoutVariant.autoNamed => switch (screen) {'),
              contains('StyledScreen.mobile => _StyleLayoutSpec.autoNamedMobile(theme),'),
              contains('StyledScreen.tablet => _StyleLayoutSpec.autoNamedTablet(theme),'),
              contains('StyledScreen.desktop => _StyleLayoutSpec.autoNamed(theme),'),
            ]),
          ),
        },
      );
    });
  });
}
