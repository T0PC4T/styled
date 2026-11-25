import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:styled_design/styled_design.dart';

final class _TextDef extends DesignDefinition {
  const _TextDef();
  @override
  DesignComponent get spec => const DesignComponent(type: 'T', props: [DesignProp.string('text')]);
  @override
  Object build(DesignBuildContext ctx) => Text(ctx.string('text') ?? '', key: ctx.key);
}

/// A list whose cells come from a template slot, side by side.
final class _ListDef extends DesignDefinition {
  const _ListDef();
  @override
  DesignComponent get spec => const DesignComponent(
    type: 'L',
    props: [DesignProp('rows', PropKind.rows)],
    slots: [
      DesignSlot('cell', template: 'row'),
      DesignSlot('cells', many: true, template: 'row'),
    ],
  );
  @override
  Object build(DesignBuildContext ctx) {
    final cell = ctx.template('cell');
    final cells = ctx.templateList('cells');
    final rows = ctx.rows('rows') ?? const [];
    return Column(key: ctx.key, children: [for (final row in rows) cell(row), for (final row in rows) ...cells(row)]);
  }
}

final _screen = ScreenDoc.fromJson({
  'format': 1,
  'id': 'a.list',
  'kind': 'page',
  'title': 'List',
  'route': '/a/list',
  'root': {
    'id': 'list',
    'type': 'L',
    'props': {
      'rows': {r'$bind': 'data.rows'},
    },
    'slots': {
      'cell': [
        {
          'id': 'cellText',
          'type': 'T',
          'props': {
            'text': {r'$bind': 'row.name'},
          },
        },
      ],
      'cells': [
        {
          'id': 'cellA',
          'type': 'T',
          'props': {'text': 'a'},
        },
        {'id': 'cellB', 'type': 'Missing'},
      ],
    },
  },
});

Future<void> _pump(WidgetTester tester, {required bool studio}) => tester.pumpWidget(
  DesignScope(
    bundle: DesignBundle(screens: {_screen.id: _screen}),
    registry: DesignRegistry(definitions: const [_TextDef(), _ListDef()]),
    navigator: RecordingDesignNavigator(),
    studio: studio,
    onError: (_) {},
    child: const Directionality(
      textDirection: TextDirection.ltr,
      child: DesignScreen(
        'a.list',
        data: {
          'rows': [
            {'name': 'Ada'},
            {'name': 'Grace'},
          ],
        },
      ),
    ),
  ),
);

List<Key?> _keys(WidgetTester tester) => [
  for (final w in tester.widgetList(find.byWidgetPredicate((w) => w is Text || w is DesignPlaceholder)))
    // The placeholder's own label is not a node.
    if (w is! Text || w.data != 'Missing') w.key,
];

void main() {
  testWidgets('outside the studio a template node has no key of its own, as before', (tester) async {
    await _pump(tester, studio: false);
    expect(find.text('Ada'), findsOneWidget);
    expect(_keys(tester), everyElement(isNull));
    expect(find.byKey(const ValueKey<String>('list')), findsOneWidget);
  });

  testWidgets('in the studio each template instance gets a DesignNodeKey naming its node', (tester) async {
    await _pump(tester, studio: true);
    expect(_keys(tester), [
      const DesignNodeKey('cellText', 0),
      const DesignNodeKey('cellText', 1),
      const DesignNodeKey('cellA', 0),
      const DesignNodeKey('cellB', 0),
      const DesignNodeKey('cellA', 1),
      const DesignNodeKey('cellB', 1),
    ]);
    expect(tester.takeException(), isNull, reason: 'no duplicate keys among siblings');

    // A rebuild with the same rows keeps the keys.
    await _pump(tester, studio: true);
    expect(_keys(tester).first, const DesignNodeKey('cellText', 0));
  });

  test('designNodeIdOf reads node keys, and nothing else', () {
    expect(designNodeIdOf(const ValueKey<String>('saveButton')), 'saveButton');
    expect(designNodeIdOf(const ValueKey<String>('row#auto_welcome')), 'row');
    expect(designNodeIdOf(const DesignNodeKey('cellText', 3)), 'cellText');
    expect(designNodeIdOf(const ValueKey<int>(3)), isNull);
    expect(designNodeIdOf(null), isNull);
  });

  test('TemplateInstances keeps an item\'s number and numbers equal texts apart', () {
    final instances = TemplateInstances();
    final a = {'id': 1};
    final b = {'id': 1};
    expect([instances.of(a), instances.of(b), instances.of(a), instances.of('x'), instances.of('x')], [0, 1, 0, 2, 3]);
  });
}
