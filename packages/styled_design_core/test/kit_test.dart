import 'dart:convert';
import 'dart:io';

import 'package:styled_design_core/io.dart';
import 'package:styled_design_core/styled_design_core.dart';
import 'package:test/test.dart';

/// The kit workspace against the real catalog the library dumps.
const _kit = 'test/fixtures/kit_workspace';

void main() {
  final hasCatalog = File('$_kit/catalog.json').existsSync();
  final skip = hasCatalog ? false : 'the kit catalog.json is not there yet';

  group('kit workspace with its catalog', () {
    late DesignWorkspace ws;
    late Catalog catalog;
    setUpAll(() {
      if (!hasCatalog) return;
      ws = DesignWorkspace.load(Directory(_kit));
      catalog = ws.catalog!;
    });

    test('validates with no errors and no warnings', () {
      final found = validateWorkspace(ws.toInput(), catalog);
      expect(found.where((d) => d.isError), isEmpty, reason: found.join('\n'));
      expect(found, isEmpty, reason: found.join('\n'));
    }, skip: skip);

    test('exports a bundle that DesignBundle reads back', () {
      final result = buildBundle(ws.toInput(), catalog);
      expect(result.ok, isTrue, reason: result.diagnostics.join('\n'));
      final json = jsonDecode(result.text!) as Map<String, Object?>;
      expect(json.keys.toList(), [
        'format', 'name', 'hash', 'requires', 'start', 'tokens', 'presets', 'screens', 'contracts', //
      ]);
      expect(json['hash'], bundleHash(json));
      expect(json['requires'], {'catalog': catalog.version});
      final bundle = DesignBundle.fromJson(json);
      expect(bundle.name, 'Onboarding360');
      expect(bundle.start, 'admin.automations');
      expect(bundle.requiresCatalog, catalog.version);
      expect(
        bundle.screens.keys,
        containsAll(['admin.automations', 'admin.automationEditor', 'admin.automationCreate']),
      );
      expect(bundle.presets.keys, unorderedEquals(['StyleButton.quiet', 'StyleCard.highlight']));
      expect(bundle.tokens.tokens['accentSubtle']!.isNew, isTrue);
      expect(bundle.screen('admin.automations').fixtures, isEmpty, reason: 'export.fixtures is none');
      final contract = bundle.contracts['admin.automations']! as Map<String, Object?>;
      expect(contract['modals'], ['admin.automationCreate']);
      expect((contract['data']! as Map)['error'], 'string?', reason: 'null in default, text in failed');
      expect(((contract['data']! as Map)['automations']! as List).single, {
        'id': 'string',
        'name': 'string',
        'enabled': 'bool',
      });
      // Deterministic: the same workspace gives the same bytes.
      expect(buildBundle(ws.toInput(), catalog).text, result.text);
    }, skip: skip);

    test('flow lists the kit links', () {
      final flow = buildFlow(parseScreens(ws.toInput()).values);
      final lines = flow.edges.map((e) => '$e').toList();
      expect(
        lines,
        containsAll([
          'admin.automations → frames.admin (frame)',
          'admin.automations#crumbAdmin.tap → admin.dashboard (backTo)',
          'admin.automations#newAutomation.tap → admin.automationCreate (openModal)',
          'admin.automations#newAutomation.tap → admin.automationEditor (push)',
          'admin.automations#table.rowTap → admin.automationEditor (push)',
          'admin.automations#rowEdit.tap → admin.automationEditor (push)',
          'admin.automationEditor#header.back → admin.automations (back)',
          'admin.dashboard#automationsTile.tap → admin.automations (replaceAll)',
          'frames.admin#navDashboard.tap → admin.dashboard (replaceAll)',
          'frames.admin#navAutomations.tap → admin.automations (replaceAll)',
        ]),
      );
      expect(flow.toMermaid(), contains('frames_admin -->|"navDashboard.tap: replaceAll"| admin_dashboard'));
      expect((flow.toJson()['edges']! as List).first, containsPair('kind', isA<String>()));
    }, skip: skip);

    test('describe draws the list page against its fixtures', () {
      final screens = parseScreens(ws.toInput());
      final text = describeScreen(screens['admin.automations']!, catalog);
      expect(text, contains('#metric[enabled] OnboardingMetric key="enabled" label="Enabled" count=2'));
      expect(text, contains('#errorBanner OnboardingCalloutBanner.error [hidden: when]'));
      expect(text, contains('#nameCellTitle StyledText text="Welcome email"'));
      expect(text, contains('rowTap → navigate admin.automationEditor (push) id=event.row.id'));
      expect(text, contains('#rowPaused OnboardingStatusBadge.neutral [not drawn: the slot shows one node]'));
      final failed = describeScreen(screens['admin.automations']!, catalog, fixture: 'failed');
      expect(failed, contains('#errorBanner OnboardingCalloutBanner.error message="Automations could not be loaded.'));
    }, skip: skip);

    test("every widget's example node validates inside a page", () {
      // Codes an example cannot avoid out of context: it reads data the page
      // has no fixture for, emits events the page does not declare, or
      // belongs in another kind of screen.
      const outOfContext = {'E-bind-path', 'E-bind-root', 'E-emit-undeclared', 'E-outlet-outside-frame'};
      for (final comp in catalog.components.values.where((c) => c.kind == DesignKind.widget)) {
        final node = exampleNode(comp, catalog);
        final page = {
          'format': 1,
          'id': 'example.page',
          'kind': 'page',
          'title': 'Example',
          'route': '/example',
          'root': {
            'id': 'examplePage',
            'type': 'StyledListView',
            'props': {'style': 'StyleContentList.normal'},
            'children': [node],
          },
        };
        final input = WorkspaceInput({
          'design.json': {'format': 1, 'name': 'example', 'start': 'example.page'},
          'screens/example/page.json': page,
        });
        final problems = validateWorkspace(
          input,
          catalog,
        ).where((d) => !outOfContext.contains(d.code) && !d.code.startsWith('W-'));
        expect(problems, isEmpty, reason: '${comp.type}: ${problems.join('\n')}');
      }
    }, skip: skip);
  });
}
