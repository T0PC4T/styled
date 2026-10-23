import 'package:build_test/build_test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:styled_generator/styled_generator.dart';
import 'package:test/test.dart';

String _squash(String s) => s.replaceAll(RegExp(r'[\s,]+'), '');

/// Matches generated source containing [snippet], ignoring formatting.
Matcher _has(String snippet) =>
    predicate<String>((source) => _squash(source).contains(_squash(snippet)), 'contains `$snippet`');

const _annotations = '''
class StyledPreset {
  final String? name;
  final String? variantEnumName;
  const StyledPreset({this.name, this.variantEnumName});
}
class Variant {
  final bool isDefault;
  final List<String> aliases;
  const Variant({this.isDefault = false, this.aliases = const []});
}
class On {
  final String state;
  final List<String> variants;
  const On(this.state, {this.variants = const []});
}
''';

const _stubs = '''
class StyledTheme {}
enum StyledScreen { mobile, tablet, desktop }
class BuildContext {}
class Color {
  final int value;
  const Color(this.value);
}
class Style {
  const Style();
  Style merge(Style? other) => this;
}
''';

Future<TestBuilderResult> _build(String spec, {Object? output, void Function(String)? onError}) => testBuilder(
      PartBuilder([const StyledPresetGenerator()], '.styled.g.dart'),
      {
        'styled_annotation|lib/styled_annotation.dart': _annotations,
        'a|lib/spec.dart': '''
import 'package:styled_annotation/styled_annotation.dart';

part 'spec.styled.g.dart';

$_stubs
$spec
''',
      },
      outputs: output == null ? null : {'a|lib/spec.styled.g.dart': output},
      onLog: (log) {
        if (log.level.value >= 1000) onError?.call(log.message);
      },
    );

void main() {
  group('StyledPresetGenerator', () {
    test('generates enum, constructors, base merge, copyWith, equality and toString', () async {
      await _build(
        '''
/// Badge presets.
@StyledPreset(name: 'StyleBadge')
abstract class _StyleBadgeSpec {
  static Style base({Color? customColor, bool isPill = false}) => const Style();

  /// The neutral badge.
  @Variant(isDefault: true)
  static Style standard({Color? customColor}) => const Style();

  @Variant(aliases: ['danger'])
  static Style error() => const Style();
}
''',
        output: decodedMatches(allOf([
          _has('enum BadgeVariant {'),
          _has('/// The neutral badge.'),
          _has('/// Badge presets.'),
          _has('class StyleBadge extends StyleResolver {'),
          _has('final Color? customColor;'),
          _has('final bool isPill;'),
          _has('const StyleBadge({'),
          _has('this.isPill = false,'),
          _has('const StyleBadge.standard({'),
          _has('const StyleBadge.danger({'),
          _has('}) : variant = BadgeVariant.error;'),
          _has('const StyleBadge.fromVariant('),
          isNot(_has('context.theme')),
          _has('final base = _StyleBadgeSpec.base(customColor: customColor, isPill: isPill);'),
          _has('BadgeVariant.standard => base.merge(_StyleBadgeSpec.standard(customColor: customColor)),'),
          _has('BadgeVariant.error => base.merge(_StyleBadgeSpec.error()),'),
          _has('StyleBadge copyWith({'),
          _has('int get hashCode => Object.hash(variant, customColor, isPill);'),
          _has(r"String toString() => 'StyleBadge.${variant.name}(customColor: $customColor, isPill: $isPill)';"),
          isNot(_has(' as Style')),
        ])),
      );
    });

    test('attaches convention-named and @On states', () async {
      await _build(
        '''
@StyledPreset(variantEnumName: 'Kind')
abstract class _StyleButtonSpec {
  @Variant(isDefault: true)
  static Style primary() => const Style();
  @Variant()
  static Style ghost() => const Style();

  static Style primaryHovered() => const Style();
  static Style disabled() => const Style();
  static Style mobile() => const Style();

  @On('selected', variants: ['ghost'])
  static Style ghostSelected() => const Style();
}
''',
        output: decodedMatches(allOf([
          _has('enum Kind { primary, ghost }'),
          _has('final base = const Style()'
              '.on(StyleState.disabled, style: _StyleButtonSpec.disabled())'
              '.on(StyledScreen.mobile.state, style: _StyleButtonSpec.mobile());'),
          _has('Kind.primary => base.merge(_StyleButtonSpec.primary())'
              '.on(StyleState.hovered, style: _StyleButtonSpec.primaryHovered()),'),
          _has("Kind.ghost => base.merge(_StyleButtonSpec.ghost())"
              ".on(const StyleState('selected'), style: _StyleButtonSpec.ghostSelected()),"),
          _has(r"String toString() => 'StyleButton.${variant.name}';"),
        ])),
      );
    });

    test('injects the screen tier', () async {
      await _build(
        '''
@StyledPreset()
abstract class _StylePageSpec {
  static Style normal(StyledScreen screen) => const Style();
}
''',
        output: decodedMatches(allOf([
          _has('final screen = StyledScreen.of(context);'),
          _has('PageVariant.normal => _StylePageSpec.normal(screen),'),
        ])),
      );
    });

    test('rejects BuildContext parameters with a fix in the message', () async {
      final errors = <String>[];
      final result = await _build(
        '''
@StyledPreset()
abstract class _StyleCardSpec {
  static Style normal(BuildContext context) => const Style();
}
''',
        onError: errors.add,
      );
      expect(result.succeeded, isFalse);
      expect(errors.join('\n'), contains('reference tokens directly'));
    });

    test('rejects two default variants and clashing aliases', () async {
      final errors = <String>[];
      await _build(
        '''
@StyledPreset()
abstract class _StyleTagSpec {
  @Variant(isDefault: true)
  static Style a() => const Style();
  @Variant(isDefault: true)
  static Style b() => const Style();
}
''',
        onError: errors.add,
      );
      expect(errors.join('\n'), contains('Only one variant'));

      errors.clear();
      await _build(
        '''
@StyledPreset()
abstract class _StyleTagSpec {
  @Variant(aliases: ['b'])
  static Style a() => const Style();
  @Variant()
  static Style b() => const Style();
}
''',
        onError: errors.add,
      );
      expect(errors.join('\n'), contains('clashes'));
    });

    test('rejects @On for an unknown variant', () async {
      final errors = <String>[];
      await _build(
        '''
@StyledPreset()
abstract class _StyleTagSpec {
  @Variant()
  static Style a() => const Style();
  @On('selected', variants: ['missing'])
  static Style picked() => const Style();
}
''',
        onError: errors.add,
      );
      expect(errors.join('\n'), contains('unknown variant "missing"'));
    });

    test('accepts static const fields as base, variants and states', () async {
      await _build(
        '''
@StyledPreset()
abstract class _StyleChipSpec {
  static const base = Style();
  @Variant(isDefault: true)
  static const neutral = Style();
  static const neutralHovered = Style();
  static const disabled = Style();
  @On('selected')
  static const picked = Style();
}
''',
        output: decodedMatches(allOf([
          _has('enum ChipVariant { neutral }'),
          _has("final base = _StyleChipSpec.base.on(StyleState.disabled, style: _StyleChipSpec.disabled)"
              ".on(const StyleState('selected'), style: _StyleChipSpec.picked);"),
          _has('ChipVariant.neutral => base.merge(_StyleChipSpec.neutral)'
              '.on(StyleState.hovered, style: _StyleChipSpec.neutralHovered),'),
          isNot(_has('context.theme')),
        ])),
      );
    });

    test('rejects StyledTheme parameters', () async {
      final errors = <String>[];
      await _build(
        '''
@StyledPreset()
abstract class _StyleCardSpec {
  static Style normal(StyledTheme theme) => const Style();
}
''',
        onError: errors.add,
      );
      expect(errors.join('\n'), contains('takes a StyledTheme'));
    });
  });
}
