import 'dart:convert';
import 'dart:io';

import 'package:styled_design_core/io.dart';
import 'package:styled_design_core/styled_design_core.dart';
import 'package:test/test.dart';

/// The small test catalog and base workspace of the broken-document folder.
Catalog _catalog() =>
    Catalog.fromJson(jsonDecode(File('test/fixtures/broken/catalog.json').readAsStringSync()) as Map<String, Object?>);
WorkspaceInput _base() => DesignWorkspace.load(Directory('test/fixtures/broken/base')).toInput();
Map<String, Object?> _home() => _base().files['screens/app/home.json']!;

void main() {
  final catalog = _catalog();

  group('fmt', () {
    test('orders screen and node keys and keeps other objects as written', () {
      final text = formatDocument({
        'root': {
          'on': <String, Object?>{},
          'props': {'z': 1, 'a': 2},
          'type': 'StyledText',
          'id': 't',
        },
        'title': 'T',
        'kind': 'page',
        'id': 'a.b',
        'format': 1,
        'extra': true,
      }, path: 'screens/a/b.json');
      final json = jsonDecode(text) as Map<String, Object?>;
      expect(json.keys, ['format', 'id', 'kind', 'title', 'root', 'extra']);
      expect((json['root']! as Map).keys, ['id', 'type', 'props', 'on']);
      expect(((json['root']! as Map)['props']! as Map).keys, ['z', 'a']);
      expect(text, endsWith('}\n'));
      expect(text, contains('\n  "id": "a.b"'));
    });

    test('assigns lower-camel ids unique in the screen', () {
      final json = canonicalDocument({
        'kind': 'page',
        'root': {
          'id': 'onboardingButton',
          'type': 'StyledListView',
          'children': [
            {'type': 'OnboardingButton.primary'},
            {
              'type': 'OnboardingCard',
              'slots': {
                'child': [
                  {'type': 'OnboardingButton'},
                ],
              },
            },
          ],
        },
      });
      final ids = <String>[];
      forEachNodeJson(json['root'], (n) => ids.add(n['id']! as String));
      expect(ids, ['onboardingButton', 'onboardingButton2', 'onboardingCard', 'onboardingButton3']);
    });

    test('is stable and never changes its input', () {
      final home = _home();
      final before = jsonEncode(home);
      final once = formatDocument(home, path: 'screens/app/home.json');
      expect(formatDocument(jsonDecode(once) as Map<String, Object?>, path: 'screens/app/home.json'), once);
      expect(jsonEncode(home), before);
    });

    test('leaves non-screen documents in their order', () {
      expect(formatDocument({'b': 1, 'a': 2}), '{\n  "b": 1,\n  "a": 2\n}\n');
    });
  });

  group('patch', () {
    PatchResult patch(List<Object?> ops) => applyPatch(_home(), ops);
    Map<String, Object?>? nodeIn(Map<String, Object?> screen, String id) {
      Map<String, Object?>? found;
      forEachNodeJson(screen['root'], (n) {
        if (n['id'] == id) found = n;
      });
      return found;
    }

    test('insert, setProp, setWhen, setEvent, move, wrap and remove', () {
      final input = _home();
      final before = jsonEncode(input);
      final result = applyPatch(input, [
        {
          'op': 'insert',
          'parent': 'page',
          'slot': 'children',
          'index': 0,
          'node': {
            'type': 'StyledText',
            'props': {'text': 'Hi'},
          },
        },
        {'op': 'setProp', 'node': 'styledText', 'prop': 'style', 'value': 'StyleText.body'},
        {
          'op': 'setWhen',
          'node': 'styledText',
          'when': {r'$bind': 'data.total'},
        },
        {
          'op': 'setEvent',
          'node': 'card',
          'event': 'tap',
          'actions': [
            {'do': 'toast', 'message': 'x'},
          ],
        },
        {'op': 'move', 'node': 'tabB', 'parent': 'header', 'slot': 'actions'},
        {
          'op': 'wrap',
          'node': 'total',
          'with': {'id': 'col', 'type': 'OnboardingColumn'},
          'slot': 'children',
        },
        {'op': 'remove', 'node': 'metrics'},
        {'op': 'setProp', 'node': 'card', 'prop': 'style', 'value': null},
      ]);
      expect(result.ok, isTrue, reason: result.diagnostics.join('\n'));
      final json = result.json!;
      expect(jsonEncode(input), before, reason: 'the input is not changed');
      final page = json['root']! as Map<String, Object?>;
      final children = page['children']! as List;
      expect((children.first as Map)['id'], 'styledText');
      expect(nodeIn(json, 'styledText')!['when'], {r'$bind': 'data.total'});
      expect(nodeIn(json, 'metrics'), isNull);
      expect(((nodeIn(json, 'header')!['slots']! as Map)['actions']! as List).map((n) => (n as Map)['id']), [
        'newItem',
        'tabB',
      ]);
      expect((nodeIn(json, 'col')!['children']! as List).single, containsPair('id', 'total'));
      expect(nodeIn(json, 'card')!.containsKey('props'), isFalse);
      expect((nodeIn(json, 'card')!['on']! as Map)['tap'], isNotEmpty);
      expect(validateWorkspace(_base().withFile('screens/app/home.json', json), catalog).map((d) => d.code), [
        'W-preset-unused',
      ], reason: 'the card no longer uses StyleCard.highlight');
    });

    test('a children insert goes where the node keeps its children', () {
      final screen = {
        'id': 'a.b',
        'root': {
          'id': 'p',
          'type': 'StyledListView',
          'slots': {'children': <Object?>[]},
        },
      };
      final json = applyPatch(screen, [
        {
          'op': 'insert',
          'parent': 'p',
          'slot': 'children',
          'node': {'id': 't', 'type': 'StyledText'},
        },
      ]).json!;
      final root = json['root']! as Map<String, Object?>;
      expect(root.containsKey('children'), isFalse);
      expect(((root['slots']! as Map)['children']! as List).single, {'id': 't', 'type': 'StyledText'});
    });

    test('reports unknown nodes, duplicate ids and bad ops, and returns nothing', () {
      final result = patch([
        {'op': 'setProp', 'node': 'tabC', 'prop': 'label', 'value': 'x'},
        {
          'op': 'insert',
          'parent': 'page',
          'slot': 'children',
          'node': {'id': 'card', 'type': 'StyledText'},
        },
        {'op': 'remov', 'node': 'card'},
        {'op': 'remove', 'node': 'page'},
        {'op': 'move', 'node': 'header', 'parent': 'newItem', 'slot': 'actions'},
        {'op': 'setProp', 'node': 'card'},
      ]);
      expect(result.ok, isFalse);
      expect(result.json, isNull);
      final byPointer = {for (final d in result.diagnostics) d.pointer: d};
      expect(byPointer['/0/node']!.code, 'E-node-unknown');
      expect(byPointer['/0/node']!.hint, "Did you mean 'tabB'?");
      expect(byPointer['/0/node']!.node, 'app.home#tabC');
      expect(byPointer['/1/node']!.code, 'E-duplicate-id');
      expect(byPointer['/1/node']!.hint, contains("'card2'"));
      expect(byPointer['/2/op']!.code, 'E-patch-op');
      expect(byPointer['/2/op']!.hint, "Did you mean 'remove'?");
      expect(byPointer['/2/op']!.allowed, patchOps.keys.toList());
      expect(byPointer['/3/node']!.code, 'E-patch-op');
      expect(byPointer['/4/parent']!.code, 'E-patch-op');
      expect(byPointer['/5']!.code, 'E-patch-op');
      expect(applyPatch(_home(), 'nope').diagnostics.single.code, 'E-patch-op');
    });
  });

  group('flow', () {
    test('edges for every link kind, nested then lists included', () {
      final flow = buildFlow(parseScreens(_base()).values);
      expect(flow.edges.map((e) => '$e'), [
        'app.detail → frames.main (frame)',
        'app.detail#header.back → app.home (back)',
        'app.detail#save.tap → app.home (backTo)',
        'app.home → frames.main (frame)',
        'app.home#newItem.tap → app.create (openModal)',
        'app.home#newItem.tap → app.detail (push)',
        'app.home#table.rowTap → app.detail (push)',
        'app.home#rowEdit.tap → app.detail (push)',
        'frames.main#navHome.tap → app.home (replaceAll)',
      ]);
      expect(flow.toJson()['screens'], {
        'app.create': 'modal',
        'app.detail': 'page',
        'app.home': 'page',
        'frames.main': 'frame',
      });
      final mermaid = flow.toMermaid();
      expect(mermaid, startsWith('flowchart LR\n'));
      expect(mermaid, contains('app_create("app.create")'));
      expect(mermaid, contains('frames_main[["frames.main"]]'));
      expect(mermaid, contains('app_home -.->|frame| frames_main'));
    });
  });

  group('contract', () {
    test('data shapes, emits, params and openable modals', () {
      final screens = parseScreens(_base());
      final home = screenContract(screens['app.home']!, screens: screens).toJson();
      expect(home['data'], {
        'items': [
          {'id': 'string', 'name': 'string'},
        ],
        'metrics': [
          {'key': 'string', 'count': 'number'},
        ],
        'total': 'number',
      });
      expect(home['emits'], [
        {
          'name': 'select',
          'description': 'A metric was chosen.',
          'payload': {'key': 'string'},
          'returns': 'none',
        },
      ]);
      expect((home['modals']! as Map).keys, ['app.create']);
      expect(home['query'], {
        'tab': {
          'values': ['a', 'b'],
        },
      });
      final detail = screenContract(screens['app.detail']!).toJson();
      expect(detail['params'], {
        'id': {'sample': 'a'},
      });
      expect(screenContract(screens['app.home']!, screens: screens).toText(), contains('opens modal:'));
    });

    test('shapes fill empty lists and nulls from the other fixtures', () {
      expect(
        shapeOf(
          {'a': null, 'b': <Object?>[]},
          [
            {
              'a': 'x',
              'b': [1],
            },
          ],
        ),
        {
          'a': 'string?',
          'b': ['number'],
        },
      );
      expect(shapeOf(null), 'any');
      expect(shapeOf(<Object?>[]), <Object?>[]);
    });
  });

  group('describe', () {
    test('evaluates props, expands repeats and templates, and shows where events lead', () {
      final screens = parseScreens(_base());
      final text = describeScreen(screens['app.home']!, catalog);
      expect(text, startsWith('app.home "Home" (page /app), fixture default\n'));
      expect(text, contains('state: filter="all"'));
      expect(text, contains('#metric[all] OnboardingMetric key="all" count=2'));
      expect(text, contains('cell (row 1 of 2):'));
      expect(text, contains('#nameCell StyledText text="B" style="StyleText.cellTitle"'));
      expect(text, contains('#total StyledText text="2 items"'));
      expect(text, contains('tap → openModal app.create, then navigate app.detail (push) id=event.result'));
      expect(text, contains('tap → setQuery tab="b"'));
      final empty = describeScreen(screens['app.home']!, catalog, fixture: 'empty');
      expect(empty, contains('#metric OnboardingMetric [repeat: no items]'));
      expect(empty, contains('cell: [no rows]'));
    });

    test('marks nodes a when hides', () {
      final screen = ScreenDoc.fromJson({
        'format': 1,
        'id': 'a.b',
        'kind': 'page',
        'title': 'T',
        'route': '/a',
        'fixtures': {
          'default': {'show': false},
        },
        'root': {
          'id': 'page',
          'type': 'StyledListView',
          'children': [
            {
              'id': 'hidden',
              'type': 'StyledText',
              'when': {r'$bind': 'data.show'},
              'props': {'text': 'x'},
            },
          ],
        },
      });
      expect(describeScreen(screen, catalog), contains('#hidden StyledText [hidden: when]'));
    });
  });

  group('export', () {
    test('writes a deterministic bundle that DesignBundle reads', () {
      final result = buildBundle(_base(), catalog);
      expect(result.ok, isTrue, reason: result.diagnostics.join('\n'));
      final json = jsonDecode(result.text!) as Map<String, Object?>;
      expect(json['hash'], bundleHash(json));
      expect(json['hash'], startsWith('sha256:'));
      expect(json['requires'], {'catalog': 3});
      final screens = json['screens']! as Map<String, Object?>;
      expect(screens.keys, ['app.create', 'app.detail', 'app.home', 'frames.main']);
      final home = screens['app.home']! as Map<String, Object?>;
      expect(home.keys, ['kind', 'title', 'route', 'query', 'state', 'emits', 'root', 'fixtures']);
      expect((home['fixtures']! as Map).keys, ['default'], reason: 'export.fixtures is default');
      final bundle = DesignBundle.fromJson(json);
      expect(bundle.screen('app.home').fixtures.keys, ['default']);
      expect(bundle.presets['StyleCard.highlight']!.extendsId, 'StyleCard.surface');
      expect(bundle.tokens.tokens.keys, ['accentSubtle', 'cardRadius']);
      expect((bundle.contracts['app.home']! as Map)['modals'], ['app.create']);
      expect(buildBundle(_base(), catalog).text, result.text);
    });

    test('refuses on any error or warning and returns the diagnostics', () {
      final input = _base().withFile('screens/app/extra.json', {
        'format': 1,
        'id': 'app.extra',
        'kind': 'page',
        'title': 'Extra',
        'route': '/extra',
        'root': {
          'id': 'page',
          'type': 'StyledListView',
          'props': {'style': 'StyleContentList.normal'},
          'children': [
            {
              'id': 't',
              'type': 'StyledText',
              'props': {'text': 'x'},
            },
          ],
        },
      });
      final result = buildBundle(input, catalog);
      expect(result.ok, isFalse);
      expect(result.text, isNull);
      expect(result.diagnostics.single.code, 'W-unreachable');
    });
  });

  group('validator', () {
    test('a structurally broken screen still gets its other checks', () {
      final home = jsonDecode(jsonEncode(_home())) as Map<String, Object?>;
      final page = home['root']! as Map<String, Object?>;
      (page['children']! as List).add({
        'id': 'broken',
        'type': 'StyledText',
        'props': {'text': 'x'},
        'colour': 1,
      });
      (page['children']! as List).add({'id': 'other', 'type': 'StyledTxt'});
      final found = validateWorkspace(_base().withFile('screens/app/home.json', home), catalog);
      expect(found.map((d) => d.code), containsAll(['E-schema', 'E-component-unknown']));
      expect(found.firstWhere((d) => d.code == 'E-schema').node, 'app.home#broken');
    });

    test('isRoutePrefix compares segment by segment', () {
      expect(isRoutePrefix('/app', '/app/items/:id'), isTrue);
      expect(isRoutePrefix('/app/items/:x', '/app/items/:id/edit'), isTrue);
      expect(isRoutePrefix('/ap', '/app'), isFalse);
      expect(isRoutePrefix('/', '/anything'), isTrue);
    });

    test('token values follow tokens.schema.json', () {
      expect(tokenValueProblem('color', '#AABBCC'), isNull);
      expect(tokenValueProblem('color', '#AABBCCDD'), isNull);
      expect(tokenValueProblem('color', '#ABC'), isNotNull);
      expect(tokenValueProblem('double', 1.5), isNull);
      expect(tokenValueProblem('duration', 200), isNull);
      expect(tokenValueProblem('duration', 12.5), isNotNull);
      expect(tokenValueProblem('fontWeight', 'w600'), isNull);
      expect(tokenValueProblem('fontWeight', 'w650'), isNotNull);
      expect(tokenValueProblem('string', 'Inter'), isNull);
      expect(tokenValueProblem('shadow', {'opacity': 0.1, 'blurRadius': 4}), isNull);
      expect(tokenValueProblem('shadow', {'opacity': 2, 'blurRadius': 4}), isNotNull);
      expect(tokenValueProblem('shadow', {'opacity': 0.1}), isNotNull);
      expect(parseTokenLiteral('double', '8'), 8);
      expect(parseTokenLiteral('shadow', '{"opacity": 0.1, "blurRadius": 2}'), {'opacity': 0.1, 'blurRadius': 2});
    });

    test('every code in diagnosticCodes is an error or a warning by its prefix', () {
      for (final code in diagnosticCodes.keys) {
        expect(code, matches(RegExp(r'^[EW]-[a-z]+(-[a-z]+)*$')));
      }
    });
  });
}
