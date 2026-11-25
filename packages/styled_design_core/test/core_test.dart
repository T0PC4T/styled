import 'dart:io';

import 'package:styled_design_core/io.dart';
import 'package:styled_design_core/styled_design_core.dart';
import 'package:test/test.dart';

DesignWorkspace _kit() => DesignWorkspace.load(Directory('test/fixtures/kit_workspace'));

void main() {
  group('kit workspace', () {
    test('every screen and preset parses with no problems', () {
      final ws = _kit();
      expect(ws.loadProblems, isEmpty);
      for (final MapEntry(key: path, value: json) in ws.screenFiles.entries) {
        final (doc, problems) = ScreenDoc.parse(json, file: path);
        expect(problems, isEmpty, reason: '$path: ${problems.join('\n')}');
        expect(doc!.id, DesignWorkspace.screenIdForPath(path), reason: 'the path spells the id');
      }
      final bundle = ws.toBundle();
      expect(bundle.screens.keys, containsAll(['admin.automations', 'admin.automationCreate', 'frames.admin']));
      expect(bundle.presets.keys, unorderedEquals(['StyleButton.quiet', 'StyleCard.highlight']));
      expect(bundle.tokens.tokens['accentSubtle']!.isNew, isTrue);
      expect(bundle.start, 'admin.automations');
    });

    test('the automations page has its nodes, slots, repeat and actions', () {
      final screen = _kit().toBundle().screen('admin.automations');
      expect(screen.kind, ScreenKind.page);
      expect(screen.route, '/admin/automations');
      final table = screen.node('table')!;
      expect(table.componentType, 'OnboardingDataTable');
      expect(table.slots['columns']!.map((c) => c.id), ['colName', 'colStatus', 'colActions']);
      final rowTap = table.on['rowTap']!.single as NavigateAction;
      expect(rowTap.to, 'admin.automationEditor');
      expect(rowTap.mode, NavigateMode.push);
      expect(screen.node('metric')!.repeat!.as, 'm');
      final newButton = screen.node('newAutomation')!;
      expect(newButton.constructor, 'primary');
      final open = newButton.on['tap']!.single as OpenModalAction;
      expect(open.then.single, isA<NavigateAction>());
    });

    test('fixtures merge over the default', () {
      final screen = _kit().toBundle().screen('admin.automations');
      final failed = screen.fixture('failed');
      expect(failed['error'], 'Automations could not be loaded. Try again.');
      expect((failed['automations']! as List).length, 3, reason: 'the rest comes from default');
      final empty = screen.fixture('empty');
      expect(empty['automations'], isEmpty);
      expect((empty['paging']! as Map)['pageSize'], 25, reason: 'nested objects merge key by key');
    });

    test('locationFor fills route params and the query', () {
      final editor = _kit().toBundle().screen('admin.automationEditor');
      expect(editor.locationFor(params: {'id': 'auto_welcome'}).toString(), '/admin/automations/auto_welcome');
      expect(
        editor.locationFor(params: {'id': 'a b'}, query: {'tab': 'rules', 'x': null}).toString(),
        '/admin/automations/a%20b?tab=rules',
      );
      expect(() => editor.locationFor(), throwsA(isA<DesignError>()));
    });
  });

  group('expressions', () {
    const scope = MapScope({
      'data': {
        'paging': {'total': 30, 'page': 1},
        'automations': [
          {'id': 'a', 'enabled': true},
          {'id': 'b', 'enabled': false},
        ],
        'error': null,
        'when': '2026-11-24T09:05:00Z',
      },
      'state': {'name': 'Welcome'},
      'page': {'id': 'admin.automations'},
    });
    Object? eval(Object? json) => Expr.compile(json).eval(scope);

    test('binds read paths, list indexes and missing steps as null', () {
      expect(eval({r'$bind': 'data.paging.total'}), 30);
      expect(eval({r'$bind': 'data.automations.1.id'}), 'b');
      expect(eval({r'$bind': 'data.nothing.here'}), isNull);
      expect(eval({r'$bind': 'nope.x'}), isNull);
    });

    test('text fills holes and formats them', () {
      expect(eval({r'$text': '{{state.name}} was saved'}), 'Welcome was saved');
      expect(eval({r'$text': 'Last run {{data.when|dateTime}}'}), 'Last run 24 Nov 2026, 09:05');
      expect(eval({r'$text': 'x{{data.error}}y'}), 'xy');
      expect(eval({r'$text': '{{data.paging.total|number}} of {{data.automations|count}}'}), '30 of 2');
    });

    test('logic, comparison, membership, choice and match', () {
      expect(
        eval({
          r'$gt': [
            {r'$bind': 'data.paging.total'},
            25,
          ],
        }),
        isTrue,
      );
      expect(
        eval({
          r'$not': {
            r'$empty': {r'$bind': 'data.error'},
          },
        }),
        isFalse,
      );
      expect(
        eval({
          r'$in': [
            {r'$bind': 'page.id'},
            ['admin.automations', 'admin.x'],
          ],
        }),
        isTrue,
      );
      expect(
        eval({
          r'$eq': [
            {r'$bind': 'page.id'},
            'admin.dashboard',
          ],
        }),
        isFalse,
      );
      expect(
        eval({
          r'$and': [
            true,
            {r'$bind': 'data.automations.0.enabled'},
          ],
        }),
        isTrue,
      );
      expect(
        eval({
          r'$or': [
            false,
            {r'$bind': 'data.automations.1.enabled'},
          ],
        }),
        isFalse,
      );
      expect(
        eval({
          r'$if': [
            {r'$bind': 'data.error'},
            'bad',
            'good',
          ],
        }),
        'good',
      );
      expect(
        eval({
          r'$match': [
            {r'$bind': 'data.automations.0.enabled'},
            {'true': 'success'},
            'neutral',
          ],
        }),
        'success',
      );
      expect(
        eval({
          r'$match': [
            'other',
            {'true': 'success'},
            'neutral',
          ],
        }),
        'neutral',
      );
    });

    test('plain lists and objects evaluate their members', () {
      expect(
        eval({
          'id': {r'$bind': 'data.automations.0.id'},
          'fixed': 1,
        }),
        {'id': 'a', 'fixed': 1},
      );
      expect(
        Expr.compile({
          'a': 1,
          'b': [true],
        }).isLiteral,
        isTrue,
      );
    });

    test('paths lists everything an expression reads', () {
      final e = Expr.compile({
        r'$if': [
          {r'$bind': 'data.error'},
          {r'$text': '{{state.name|upper}}'},
          {r'$bind': 'row.id'},
        ],
      });
      expect(e.paths.map((p) => '$p'), ['data.error', 'state.name', 'row.id']);
      expect(e.formatterNames, ['upper']);
    });

    test('bad expressions report a pointer and a reason', () {
      expect(
        () => Expr.compile({
          'x': {r'$bind': 'Data.y'},
        }),
        throwsA(isA<ExpressionError>().having((e) => e.pointer, 'pointer', r'/x/$bind')),
      );
      expect(() => Expr.compile({r'$bind': 'a', 'b': 1}), throwsA(isA<ExpressionError>()));
      expect(() => Expr.compile({r'$nope': 1}), throwsA(isA<ExpressionError>()));
      expect(
        () => Expr.compile({
          r'$eq': [1],
        }),
        throwsA(isA<ExpressionError>()),
      );
    });

    test('truthiness', () {
      for (final falsy in [null, false, 0, '', <Object?>[], <String, Object?>{}]) {
        expect(isTruthy(falsy), isFalse, reason: '$falsy');
      }
      for (final truthy in [
        true,
        1,
        'a',
        [0],
        {'a': null},
      ]) {
        expect(isTruthy(truthy), isTrue, reason: '$truthy');
      }
    });
  });

  group('screen parsing problems', () {
    Map<String, Object?> page(Map<String, Object?> root) => {
      'format': 1,
      'id': 'a.b',
      'kind': 'page',
      'title': 'T',
      'route': '/a/b',
      'root': root,
    };

    test('unknown node fields and actions report pointers and hints', () {
      final (doc, problems) = ScreenDoc.parse(
        page({
          'id': 'page',
          'type': 'StyledListView',
          'prop': {},
          'children': [
            {
              'id': 'b',
              'type': 'OnboardingButton',
              'on': {
                'tap': [
                  {'do': 'navigat', 'to': 'x.y'},
                ],
              },
            },
          ],
        }),
        file: 'screens/a/b.json',
      );
      expect(doc, isNull);
      expect(problems.map((d) => d.pointer), containsAll(['/root/prop', '/root/children/0/on/tap/0/do']));
      expect(problems.firstWhere((d) => d.pointer == '/root/prop').hint, "Did you mean 'props'?");
      expect(problems.firstWhere((d) => d.pointer!.endsWith('/do')).hint, "Did you mean 'navigate'?");
      expect(problems.every((d) => d.file == 'screens/a/b.json'), isTrue);
    });

    test('a page without a route and a modal with one are errors', () {
      final (_, noRoute) = ScreenDoc.parse(
        {
          ...page({'id': 'p', 'type': 'X'}),
        }..remove('route'),
      );
      expect(noRoute.map((d) => d.message), contains("A page needs a 'route'."));
      final (_, modalRoute) = ScreenDoc.parse({
        ...page({'id': 'p', 'type': 'X'}),
        'kind': 'modal',
      });
      expect(modalRoute.map((d) => d.message), contains('Only a page has a route or a frame.'));
    });
  });

  group('helpers', () {
    test('nearestName finds likely typos only', () {
      expect(nearestName('heading', ['title', 'subtitle', 'header']), 'header');
      expect(nearestName('titel', ['title', 'subtitle']), 'title');
      expect(nearestName('zzzz', ['title', 'subtitle']), isNull);
    });

    test('mergePatch follows RFC 7386', () {
      expect(
        mergePatch(
          {
            'a': 1,
            'b': {'c': 2, 'd': 3},
          },
          {
            'b': {'c': null, 'e': 4},
            'f': [1],
          },
        ),
        {
          'a': 1,
          'b': {'d': 3, 'e': 4},
          'f': [1],
        },
      );
    });

    test('catalog round-trips through JSON', () {
      const c = Catalog(
        tokens: {'paddingSm': CatalogToken(key: 'paddingSm', type: 'double', light: 8)},
        presets: {
          'StyleButton': CatalogPresetFamily(name: 'StyleButton', variants: ['primary'], defaultVariant: 'primary'),
        },
        components: {
          'OnboardingButton': DesignComponent(
            type: 'OnboardingButton',
            constructors: ['primary'],
            props: [
              DesignProp.string('label'),
              DesignProp.style('style', families: ['StyleButton']),
            ],
            slots: [DesignSlot('leading'), DesignSlot('anchor', anchor: true)],
            events: [DesignEvent('tap', primary: true)],
            rules: [
              DesignRule.notInside(['OnboardingCard'], code: 'W-x'),
            ],
          ),
        },
      );
      final back = Catalog.fromJson(c.toJson());
      expect(back.toJson(), c.toJson());
      expect(back.components['OnboardingButton']!.primaryEvent!.name, 'tap');
    });

    test('the kit catalog excerpt reads', () {
      final json = DesignWorkspace.load(Directory('schemas')).files; // schemas folder holds no workspace
      expect(json, isEmpty);
    });
  });

  test('toBundle reports a wrongly typed optional field instead of throwing', () {
    final dir = Directory.systemTemp.createTempSync('ws');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/screens/a').createSync(recursive: true);
    File('${dir.path}/screens/a/b.json').writeAsStringSync(
      '{"format":1,"id":"a.b","kind":"page","title":"B","route":"/a/b","root":{"id":"r","type":"X","note":42}}',
    );
    expect(
      () => DesignWorkspace.load(dir).toBundle(),
      throwsA(
        isA<DesignError>().having((e) => e.diagnostics.map((d) => d.pointer), 'pointers', contains('/root/note')),
      ),
    );
  });

  test('a button in an anchor slot need not bind its primary event; elsewhere it must', () {
    const catalog = Catalog(
      components: {
        'Page': DesignComponent(type: 'Page', slots: [DesignSlot('children', many: true)]),
        'Menu': DesignComponent(
          type: 'Menu',
          slots: [DesignSlot('child', anchor: true)],
          events: [DesignEvent('open')],
        ),
        'Button': DesignComponent(type: 'Button', events: [DesignEvent('tap', primary: true)]),
      },
    );
    const input = WorkspaceInput({
      'design.json': {'format': 1, 'name': 'W', 'start': 'a.b'},
      'screens/a/b.json': {
        'format': 1,
        'id': 'a.b',
        'kind': 'page',
        'title': 'B',
        'route': '/a/b',
        'root': {
          'id': 'page',
          'type': 'Page',
          'children': [
            {
              'id': 'menu',
              'type': 'Menu',
              'slots': {
                'child': [
                  {'id': 'anchored', 'type': 'Button'},
                ],
              },
            },
            {'id': 'loose', 'type': 'Button'},
          ],
        },
      },
    });
    final unbound = validateWorkspace(input, catalog).where((d) => d.code == 'W-unbound-primary').map((d) => d.node);
    expect(unbound, ['a.b#loose']);
  });
}
