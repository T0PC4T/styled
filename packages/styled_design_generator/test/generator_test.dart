import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:styled_design_generator/builder.dart';
import 'package:test/test.dart';

// Stand-ins for the Flutter and styled types the reader recognises by name.
const _fakes = r'''
class Key { const Key(); }
class Widget { final Key? key; const Widget({this.key}); }
class BuildContext {}
class IconData { final int code; const IconData(this.code); }
class Icons { static const inbox = IconData(1); static const alert = IconData(2); }
abstract class StyleResolver { const StyleResolver(); }
enum ButtonVariant { primary, ghost }
class StyleButton extends StyleResolver {
  final ButtonVariant variant;
  const StyleButton() : variant = ButtonVariant.primary;
  const StyleButton.primary() : variant = ButtonVariant.primary;
  const StyleButton.ghost() : variant = ButtonVariant.ghost;
  const StyleButton.fromVariant(this.variant);
}
class TextEditingController {}
enum Size { sm, md }
enum CardVariant { surface, flush }
class StyleCard extends StyleResolver {
  final CardVariant variant;
  const StyleCard() : variant = CardVariant.surface;
  const StyleCard.fromVariant(this.variant);
}
''';

const _widgets = r'''
import 'package:styled_design_core/styled_design_core.dart';

import 'fakes.dart';

@Designable(category: 'primitives', summary: 'A button.', primaryEvent: 'tap')
class MyButton extends Widget {
  final String? label;
  final IconData icon;
  final void Function()? onTap;
  final void Function(String value)? onChanged;
  final StyleResolver style;
  final Size size;
  final List<Widget> children;
  @DesignAnchor()
  final Widget? leading;
  final TextEditingController? controller;
  @DesignIgnore()
  final Object? secret;
  static const defaultLabels = ['a', 'b'];
  final List<String> labels;

  const MyButton(
    this.icon, {
    super.key,
    this.label,
    this.onTap,
    this.onChanged,
    this.style = const StyleButton(),
    this.size = Size.md,
    required this.children,
    this.leading,
    this.controller,
    this.secret,
    this.labels = defaultLabels,
  });

  const MyButton.ghost(this.icon, {super.key, this.label, this.onTap})
    : onChanged = null,
      style = const StyleButton.ghost(),
      size = Size.md,
      children = const [],
      leading = null,
      controller = null,
      secret = null,
      labels = const [];
}

@Designable(category: 'feedback', summary: 'A banner.')
class MyBanner extends Widget {
  final IconData icon;
  final bool dense;
  const MyBanner.info({super.key, this.icon = Icons.inbox, this.dense = false});
  const MyBanner.error({super.key, this.icon = Icons.alert, this.dense = false});
}

@Designable.value(category: 'menus', summary: 'An item.', primaryEvent: 'tap')
class MyItem {
  final String key;
  final void Function() onTap;
  const MyItem({required this.key, required this.onTap});
}

@Designable(category: 'menus', summary: 'A menu.')
class MyMenu extends Widget {
  final List<MyItem> items;
  final Widget Function(BuildContext) emptyBuilder;
  const MyMenu({super.key, required this.items, required this.emptyBuilder});
}
''';

/// A reader that also sees the real packages, so annotations resolve.
Future<TestReaderWriter> _reader() async {
  final rw = TestReaderWriter(rootPackage: 'pkg');
  await rw.testing.loadIsolateSources();
  return rw;
}

void main() {
  test('a definition per class: props, slots, events, constructors and the real calls', () async {
    await testBuilder(
      designDefinitionsBuilder(BuilderOptions.empty),
      {'pkg|lib/fakes.dart': _fakes, 'pkg|lib/widgets.dart': _widgets},
      rootPackage: 'pkg',
      readerWriter: await _reader(),
      outputs: {
        'pkg|lib/widgets.design.g.dart': decodedMatches(
          allOf([
            contains("import 'widgets.dart';"),
            contains("type: 'MyButton'"),
            contains("constructors: ['ghost']"),
            contains("DesignProp.icon('icon', required: true)"),
            contains("DesignProp.string('label')"),
            contains("DesignProp.style('style', families: ['StyleButton'])"),
            contains("DesignProp.choice('size', values: ['sm', 'md'], defaultValue: 'md')"),
            contains("DesignProp.style('style', families: ['StyleButton'])"),
            contains("DesignProp('labels', PropKind.stringList, defaultValue: ['a', 'b'])"),
            contains("DesignSlot('children', many: true, required: true)"),
            contains("DesignSlot('leading', anchor: true)"),
            contains("DesignEvent('tap', primary: true)"),
            contains("DesignEvent('changed', payload: {'value': 'string'})"),
            contains("ctx.icon('icon') ?? const IconData(0)"),
            contains('key: ctx.key'),
            contains("style: ctx.style('style') ?? const StyleButton()"),
            contains("labels: ctx.stringList('labels') ?? MyButton.defaultLabels"),
            contains("onChanged: ctx.valueCallback<String>('changed')"),
            contains("'ghost' => MyButton.ghost("),
            isNot(contains('controller:')),
            isNot(contains('secret:')),
            contains('kind: DesignKind.value'),
            contains("onTap: ctx.callback('tap') ?? () {}"),
            isNot(contains('MyItem(key: ctx.key')),
            contains("DesignSlot('items', accepts: ['MyItem'], many: true, required: true)"),
            contains("DesignSlot('empty', required: true)"),
            contains("emptyBuilder: (_) => ctx.child('empty') ?? const SizedBox.shrink()"),
            contains("DesignProp.icon('icon')"),
            isNot(contains("DesignProp.icon('icon', defaultValue: 'inbox')")),
            contains("DesignProp.boolean('dense', defaultValue: false)"),
            contains("icon: ctx.icon('icon') ?? Icons.alert"),
          ]),
        ),
      },
    );
  });

  test('a parameter with no rule fails the build and names it', () async {
    const bad = r'''
import 'package:styled_design_core/styled_design_core.dart';
import 'fakes.dart';

@Designable()
class Odd extends Widget {
  final Uri where;
  const Odd({required this.where});
}
''';
    final result = await testBuilder(
      designDefinitionsBuilder(BuilderOptions.empty),
      {'pkg|lib/fakes.dart': _fakes, 'pkg|lib/odd.dart': bad},
      rootPackage: 'pkg',
      readerWriter: await _reader(),
    );
    expect(result.succeeded, isFalse);
    expect(result.errors.join('\n'), allOf(contains('Odd'), contains('where'), contains('@DesignIgnore')));
  });

  test('the registry lists every definition and preset family', () async {
    await testBuilders(
      [designIndexBuilder(BuilderOptions.empty), designRegistryBuilder(BuilderOptions.empty)],
      {'pkg|lib/fakes.dart': _fakes, 'pkg|lib/widgets.dart': _widgets},
      rootPackage: 'pkg',
      readerWriter: await _reader(),
      outputs: {
        'pkg|lib/fakes.design_index.json': anything,
        'pkg|lib/widgets.design_index.json': anything,
        'pkg|lib/design.g.dart': decodedMatches(
          allOf([
            contains('MyButtonDefinition()'),
            contains('MyItemDefinition()'),
            contains('MyMenuDefinition()'),
            contains("'StyleButton': (v, a) =>"),
            contains('.StyleButton.fromVariant('),
            contains('.ButtonVariant.values.byName(v)'),
            contains("variants: ['primary', 'ghost']"),
            contains("defaultVariant: 'primary'"),
          ]),
        ),
      },
    );
  });

  group('the registry coverage check', () {
    const extra = r'''
import 'package:styled_design_core/styled_design_core.dart';

import 'fakes.dart';

class Loose extends Widget {
  const Loose({super.key});
}

@NotDesignable('Plumbing.')
class Quiet extends Widget {
  const Quiet({super.key});
}

class Helper {}
''';
    const hidden = r'''
import 'fakes.dart';

class Hidden extends Widget {
  const Hidden({super.key});
}
''';
    const barrel = "export 'widgets.dart';\nexport 'extra.dart';\n";
    final sources = {
      'pkg|lib/fakes.dart': _fakes,
      'pkg|lib/widgets.dart': _widgets,
      'pkg|lib/extra.dart': extra,
      'pkg|lib/hidden.dart': hidden,
      'pkg|lib/pkg.dart': barrel,
    };

    Future<TestBuilderResult> build(Map<String, Object?> options, Map<String, String> sources) async => testBuilders(
      [designIndexBuilder(BuilderOptions.empty), designRegistryBuilder(BuilderOptions(options))],
      sources,
      rootPackage: 'pkg',
      readerWriter: await _reader(),
    );

    test('is off by default', () async {
      final result = await build(const {}, sources);
      expect(result.succeeded, isTrue);
    });

    test('fails the build naming every exported widget with neither annotation', () async {
      final result = await build(const {'check_coverage': true}, sources);
      expect(result.succeeded, isFalse);
      final errors = result.errors.join('\n');
      expect(errors, contains('1 widget(s) exported from lib/pkg.dart'));
      expect(errors, contains('Loose (lib/extra.dart)'));
      expect(errors, allOf(isNot(contains('Quiet')), isNot(contains('MyButton')), isNot(contains('MyItem'))));
      expect(errors, allOf(isNot(contains('Hidden')), isNot(contains('Helper'))));
    });

    test('passes once every exported widget is annotated', () async {
      final annotated = {
        ...sources,
        'pkg|lib/extra.dart': extra.replaceFirst('class Loose', "@NotDesignable('Plumbing.')\nclass Loose"),
      };
      final result = await build(const {'check_coverage': true}, annotated);
      expect(result.succeeded, isTrue);
    });

    test('resolves coverage_barrel when the barrel is not lib/<package>.dart', () async {
      final moved = {...sources, 'pkg|lib/kit.dart': barrel}..remove('pkg|lib/pkg.dart');
      final result = await build(const {'check_coverage': true, 'coverage_barrel': 'lib/kit.dart'}, moved);
      expect(result.succeeded, isFalse);
      expect(result.errors.join('\n'), contains('Loose (lib/extra.dart)'));
    });
  });

  group('a style parameter\'s families', () {
    const framed = r'''
import 'package:styled_design_core/styled_design_core.dart';
import 'fakes.dart';

@Designable()
class Framed extends Widget {
  @DesignFamilies([StyleCard, StyleButton])
  final StyleResolver? style;
  @DesignFamilies.any()
  final StyleResolver? frame;
  const Framed({super.key, this.style, this.frame});
}
''';

    Future<TestBuilderResult> build(String widget, {Map<String, Object>? outputs}) async => testBuilder(
      designDefinitionsBuilder(BuilderOptions.empty),
      {'pkg|lib/fakes.dart': _fakes, 'pkg|lib/framed.dart': widget},
      rootPackage: 'pkg',
      readerWriter: await _reader(),
      outputs: outputs,
    );

    test('come from @DesignFamilies, a list or any', () async {
      await build(
        framed,
        outputs: {
          'pkg|lib/framed.design.g.dart': decodedMatches(
            allOf([
              contains("DesignProp.style('style', families: ['StyleCard', 'StyleButton'])"),
              contains("DesignProp.style('frame', families: [])"),
              contains("style: ctx.style('style')"),
            ]),
          ),
        },
      );
    });

    test('fail the build when a style parameter names none', () async {
      final result = await build(
        framed
            .replaceFirst('  const Framed(', '  final StyleResolver? loose;\n  const Framed(')
            .replaceFirst('this.frame});', 'this.frame, this.loose});'),
      );
      expect(result.succeeded, isFalse);
      expect(
        result.errors.join('\n'),
        allOf(
          contains('Framed'),
          contains('`loose`'),
          contains('@DesignFamilies([...])'),
          contains('@DesignFamilies.any()'),
        ),
      );
    });

    test('must be preset families', () async {
      final result = await build(
        framed.replaceFirst('@DesignFamilies([StyleCard, StyleButton])', '@DesignFamilies([Size])'),
      );
      expect(result.succeeded, isFalse);
      expect(result.errors.join('\n'), allOf(contains('Framed'), contains('`style`'), contains('not a preset family')));
    });
  });
}
