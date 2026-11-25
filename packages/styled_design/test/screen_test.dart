import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:styled/styled.dart';
import 'package:styled_design/styled_design.dart';

// Minimal stand-ins for a library's widgets.

final class _TextDef extends DesignDefinition {
  const _TextDef();
  @override
  DesignComponent get spec => const DesignComponent(type: 'T', props: [DesignProp.string('text')]);
  @override
  Object build(DesignBuildContext ctx) => Text(ctx.string('text') ?? '', key: ctx.key);
}

final class _ButtonDef extends DesignDefinition {
  const _ButtonDef();
  @override
  DesignComponent get spec => const DesignComponent(
    type: 'B',
    props: [DesignProp.string('label')],
    events: [DesignEvent('tap', primary: true)],
  );
  @override
  Object build(DesignBuildContext ctx) {
    final onTap = ctx.callback('tap');
    return GestureDetector(
      key: ctx.key,
      onTap: onTap,
      child: Text('${ctx.string('label')}${onTap == null ? ' (disabled)' : ''}'),
    );
  }
}

final class _ColumnDef extends DesignDefinition {
  const _ColumnDef();
  @override
  DesignComponent get spec => const DesignComponent(type: 'Col', slots: [DesignSlot('children', many: true)]);
  @override
  Object build(DesignBuildContext ctx) => Column(key: ctx.key, children: ctx.children('children'));
}

final class _InputDef extends DesignDefinition {
  const _InputDef();
  @override
  DesignComponent get spec => const DesignComponent(
    type: 'In',
    events: [DesignEvent('changed', payload: {'value': 'string'})],
  );
  @override
  Object build(DesignBuildContext ctx) {
    final changed = ctx.valueCallback<String>('changed');
    return GestureDetector(key: ctx.key, onTap: () => changed?.call('typed'), child: const Text('input'));
  }
}

/// A list whose item template adds `row`.
final class _ListDef extends DesignDefinition {
  const _ListDef();
  @override
  DesignComponent get spec => const DesignComponent(
    type: 'L',
    props: [DesignProp('rows', PropKind.rows)],
    slots: [DesignSlot('cell', template: 'row')],
  );
  @override
  Object build(DesignBuildContext ctx) {
    final cell = ctx.template('cell');
    return Column(key: ctx.key, children: [for (final row in ctx.rows('rows') ?? const []) cell(row)]);
  }
}

class _Overlays implements DesignOverlays {
  bool confirmAnswer = true;
  final toasts = <String>[];

  @override
  Future<bool> confirm(BuildContext context, {required String title, String? message, String? confirmLabel, bool destructive = false}) async =>
      confirmAnswer;

  @override
  Future<Object?> openModal(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context).push<Object?>(PageRouteBuilder(pageBuilder: (context, _, _) => builder(context)));

  @override
  void toast(BuildContext context, String message, {ToastTone tone = ToastTone.success}) => toasts.add('$tone $message');
}

ScreenDoc _page(String id, Map<String, Object?> root, {Map<String, Object?> extra = const {}}) => ScreenDoc.fromJson({
  'format': 1,
  'id': id,
  'kind': 'page',
  'title': id,
  'route': '/${id.replaceAll('.', '/')}',
  ...extra,
  'root': root,
});

Future<(RecordingDesignNavigator, List<DesignRuntimeError>, _Overlays)> _pump(
  WidgetTester tester,
  Map<String, ScreenDoc> screens,
  Widget screen,
) async {
  final navigator = RecordingDesignNavigator();
  final errors = <DesignRuntimeError>[];
  final overlays = _Overlays();
  await tester.pumpWidget(
    DesignScope(
      bundle: DesignBundle(screens: screens),
      registry: DesignRegistry(definitions: const [_TextDef(), _ButtonDef(), _ColumnDef(), _InputDef(), _ListDef()]),
      navigator: navigator,
      overlays: overlays,
      onError: errors.add,
      child: WidgetsApp(
        color: const Color(0xFF000000),
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(settings: settings, pageBuilder: (c, _, _) => builder(c)),
        home: screen,
      ),
    ),
  );
  await tester.pump();
  return (navigator, errors, overlays);
}

void main() {
  testWidgets('when, repeat and template slots draw from data', (tester) async {
    final screen = _page('a.list', {
      'id': 'col',
      'type': 'Col',
      'children': [
        {'id': 'title', 'type': 'T', 'props': {'text': {r'$text': '{{data.count}} items'}}},
        {'id': 'hidden', 'type': 'T', 'when': {r'$bind': 'data.nothing'}, 'props': {'text': 'hidden'}},
        {
          'id': 'item',
          'type': 'T',
          'repeat': {'over': {r'$bind': 'data.items'}, 'as': 'it', 'index': 'i', 'key': {r'$bind': 'it.id'}},
          'when': {r'$ne': [{r'$bind': 'it.id'}, 'skip']},
          'props': {'text': {r'$text': '{{i}}:{{it.name}}'}},
        },
        {
          'id': 'list',
          'type': 'L',
          'props': {'rows': {r'$bind': 'data.items'}},
          'slots': {
            'cell': [
              {'id': 'cellText', 'type': 'T', 'props': {'text': {r'$bind': 'row.name'}}},
            ],
          },
        },
      ],
    });
    final data = {
      'count': 3,
      'items': [
        {'id': 'a', 'name': 'Ada'},
        {'id': 'skip', 'name': 'Skipped'},
        {'id': 'c', 'name': 'Cy'},
      ],
    };
    final (_, errors, _) = await _pump(tester, {screen.id: screen}, DesignScreen('a.list', data: data));
    expect(errors, isEmpty);
    expect(find.text('3 items'), findsOneWidget);
    expect(find.text('hidden'), findsNothing);
    expect(find.text('0:Ada'), findsOneWidget);
    expect(find.text('2:Cy'), findsOneWidget);
    expect(find.text('1:Skipped'), findsNothing);
    expect(find.text('Skipped'), findsOneWidget, reason: 'the template draws every row');
    expect(find.byKey(const ValueKey('item#c')), findsOneWidget, reason: 'repeat keys come from repeat.key');
  });

  testWidgets('navigate fills the route from params; unbound events pass null', (tester) async {
    final list = _page('a.list', {
      'id': 'col',
      'type': 'Col',
      'children': [
        {
          'id': 'open',
          'type': 'B',
          'props': {'label': 'Open'},
          'on': {
            'tap': [
              {'do': 'navigate', 'to': 'a.detail', 'params': {'id': {r'$bind': 'data.id'}}, 'query': {'tab': 'x'}},
            ],
          },
        },
        {'id': 'dead', 'type': 'B', 'props': {'label': 'Dead'}},
      ],
    });
    final detail = ScreenDoc.fromJson({
      'format': 1,
      'id': 'a.detail',
      'kind': 'page',
      'title': 'D',
      'route': '/a/:id',
      'params': {'id': {'sample': 'x'}},
      'root': {'id': 't', 'type': 'T'},
    });
    final (navigator, errors, _) = await _pump(tester, {list.id: list, detail.id: detail}, const DesignScreen('a.list', data: {'id': 'q 1'}));
    expect(find.text('Dead (disabled)'), findsOneWidget);
    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(navigator.calls, ['push /a/q%201?tab=x']);
    expect(errors, isEmpty);
  });

  testWidgets('emit returning false stops the list; other results become event.result', (tester) async {
    final screen = _page('a.form', {
      'id': 'col',
      'type': 'Col',
      'children': [
        {
          'id': 'save',
          'type': 'B',
          'props': {'label': 'Save'},
          'on': {
            'tap': [
              {'do': 'emit', 'name': 'save', 'payload': {'name': {r'$bind': 'state.name'}}},
              {'do': 'toast', 'message': {r'$text': 'saved {{event.result}}'}},
              {'do': 'back', 'fallback': 'a.form'},
            ],
          },
        },
        {
          'id': 'name',
          'type': 'In',
          'on': {
            'changed': [
              {'do': 'setState', 'set': {'name': {r'$bind': 'event.value'}}},
            ],
          },
        },
        {'id': 'echo', 'type': 'T', 'props': {'text': {r'$bind': 'state.name'}}},
      ],
    }, extra: {
      'state': {'name': {r'$bind': 'data.initial'}},
    });
    Object? answer = false;
    final emits = <DesignEmit>[];
    final (navigator, errors, overlays) = await _pump(
      tester,
      {screen.id: screen},
      DesignScreen('a.form', data: const {'initial': 'Ada'}, onEmit: (e) {
        emits.add(e);
        return answer;
      }),
    );
    expect(find.text('Ada'), findsOneWidget, reason: 'state starts from data');

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(emits.single.payload, {'name': 'Ada'});
    expect(overlays.toasts, isEmpty, reason: 'false stops the list');
    expect(navigator.calls, isEmpty);

    await tester.tap(find.text('input'));
    await tester.pump();
    expect(find.text('typed'), findsOneWidget, reason: 'setState redraws');

    answer = 'id7';
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(emits.last.payload, {'name': 'typed'});
    expect(overlays.toasts, ['ToastTone.success saved id7']);
    expect(navigator.calls, ['back /a/form']);
    expect(errors, isEmpty);
  });

  testWidgets('openModal shows the modal screen; its emits reach the opener; then runs on a truthy result', (tester) async {
    final page = _page('a.list', {
      'id': 'open',
      'type': 'B',
      'props': {'label': 'New'},
      'on': {
        'tap': [
          {
            'do': 'openModal',
            'screen': 'a.create',
            'then': [
              {'do': 'navigate', 'to': 'a.list', 'mode': 'replace', 'query': {'id': {r'$bind': 'event.result'}}},
            ],
          },
        ],
      },
    });
    final modal = ScreenDoc.fromJson({
      'format': 1,
      'id': 'a.create',
      'kind': 'modal',
      'title': 'Create',
      'root': {
        'id': 'ok',
        'type': 'B',
        'props': {'label': {r'$text': 'Create {{data.label}}'}},
        'on': {
          'tap': [
            {'do': 'emit', 'name': 'create'},
            {'do': 'closeModal', 'result': {r'$bind': 'event.result'}},
          ],
        },
      },
    });
    final (navigator, errors, _) = await _pump(
      tester,
      {page.id: page, modal.id: modal},
      DesignScreen(
        'a.list',
        modalData: const {
          'a.create': {'label': 'thing'},
        },
        onEmit: (e) => e.name == 'create' ? 'new1' : null,
      ),
    );
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(find.text('Create thing'), findsOneWidget, reason: 'modal data comes from the opener');
    await tester.tap(find.text('Create thing'));
    await tester.pumpAndSettle();
    expect(find.text('Create thing'), findsNothing);
    expect(navigator.calls, ['replace /a/list?id=new1']);
    expect(errors, isEmpty);
  });

  testWidgets('confirm runs then only when confirmed', (tester) async {
    final screen = _page('a.x', {
      'id': 'del',
      'type': 'B',
      'props': {'label': 'Delete'},
      'on': {
        'tap': [
          {
            'do': 'confirm',
            'title': 'Sure?',
            'then': [
              {'do': 'toast', 'message': 'gone', 'tone': 'error'},
            ],
          },
        ],
      },
    });
    final (_, _, overlays) = await _pump(tester, {screen.id: screen}, const DesignScreen('a.x'));
    overlays.confirmAnswer = false;
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(overlays.toasts, isEmpty);
    overlays.confirmAnswer = true;
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(overlays.toasts, ['ToastTone.error gone']);
  });

  testWidgets('problems stay local and are reported, not thrown', (tester) async {
    final screen = _page('a.bad', {
      'id': 'col',
      'type': 'Col',
      'children': [
        {'id': 'unknown', 'type': 'Nope'},
        {'id': 'wrongKind', 'type': 'T', 'props': {'text': 42}},
        {'id': 'fine', 'type': 'T', 'props': {'text': 'still here'}},
      ],
    }, extra: {
      'fixtures': {
        'default': {'needed': 1},
      },
    });
    final (_, errors, _) = await _pump(tester, {screen.id: screen}, const DesignScreen('a.bad'));
    expect(find.text('still here'), findsOneWidget);
    expect(errors.map((e) => e.message), containsAll([
      "Unknown component 'Nope'.",
      'Prop \'text\' must be text, not int (42).',
      "The app supplies no 'needed', which the default fixture has.",
    ]));
  });

  test('TokenRegistry: overrides, new tokens and the mode fallback', () {
    const primary = ThemeToken<Color>('primary', Color(0xFF000001));
    const onPrimary = ThemeToken<Color>('onPrimary', Color(0xFFFFFFFF));
    const gap = ThemeToken<double>('gap', 8);
    StyledTheme base(String mode) => StyledTheme(mode == 'dark' ? {'primary': const Color(0xFF0000AA)} : const {}, {'mode': mode});
    final registry = TokenRegistry(
      [primary, onPrimary, gap],
      TokenDoc.fromJson({
        'tokens': {
          'primary': {'values': {'light': '#112233'}},
          'onPrimary': {'values': {'light': '#445566'}},
          'gap': {'values': {'light': 12, 'dark': 16}},
          'accentSubtle': {'type': 'color', 'values': {'light': '#FFF7D6', 'dark': '#4D6B5200'}},
        },
      }),
      baseTheme: base,
    );
    final light = registry.themeFor('light');
    final dark = registry.themeFor('dark');
    expect(light.get(primary), const Color(0xFF112233));
    expect(dark.get(primary), const Color(0xFF0000AA), reason: 'the library dark value beats the document light value');
    expect(dark.get(onPrimary), const Color(0xFF445566), reason: 'no dark value anywhere: the document light value');
    expect(dark.get(gap), 16, reason: 'the document dark value wins');
    final accent = registry.typed<Color>('accentSubtle');
    expect(light.get(accent), const Color(0xFFFFF7D6));
    expect(dark.get(accent), const Color(0x4D6B5200));
    expect(() => registry.typed<double>('primary'), throwsA(isA<DesignError>()));
    expect(() => registry.typed<Color>('nope'), throwsA(isA<DesignError>()));
    expect(
      () => TokenRegistry([gap], TokenDoc.fromJson({'tokens': {'gap': {'values': {'light': '8px'}}}})).themeFor('light'),
      throwsA(isA<DesignError>()),
    );
  });

  test('a completer keeps dart:async used', () => expect(Completer<void>().isCompleted, isFalse));

  test('a bundle that needs a newer catalog than the registry is refused', () {
    expect(
      () => DesignScope(
        bundle: const DesignBundle(screens: {}, requiresCatalog: 2),
        registry: DesignRegistry(definitions: const []),
        navigator: RecordingDesignNavigator(),
        child: const SizedBox(),
      ),
      throwsA(isA<DesignError>().having((e) => e.message, 'message', contains('catalog version 2'))),
    );
  });

  testWidgets('a frame reads the page in its outlet as page.id and page.title, and draws it', (tester) async {
    final frame = ScreenDoc.fromJson({
      'format': 1,
      'id': 'frames.main',
      'kind': 'frame',
      'title': 'Frame',
      'root': {
        'id': 'col',
        'type': 'Col',
        'children': [
          {'id': 'which', 'type': 'T', 'props': {'text': {r'$text': '{{page.id}}: {{page.title}}'}}},
          {'id': 'outlet', 'type': 'DesignOutlet'},
        ],
      },
    });
    await _pump(
      tester,
      {frame.id: frame},
      const DesignOutletScope(
        page: Text('the page'),
        pageId: 'a.list',
        pageTitle: 'List',
        child: DesignScreen('frames.main'),
      ),
    );
    expect(find.text('a.list: List'), findsOneWidget);
    expect(find.text('the page'), findsOneWidget);
  });
}
