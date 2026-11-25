import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:styled_design_cli/styled_design_cli.dart';
import 'package:styled_design_core/io.dart';
import 'package:styled_design_core/styled_design_core.dart';
import 'package:test/test.dart';

final _kit = p.normalize(p.absolute('../styled_design_core/test/fixtures/kit_workspace'));
final _kitCatalog = p.join(_kit, 'catalog.json');

/// One in-process run of `design`, with its output.
final class Run {
  final int code;
  final String out;
  final String err;
  Run(this.code, this.out, this.err);

  @override
  String toString() => 'exit $code\n--- out\n$out--- err\n$err';
}

Future<Run> design(List<String> args, {String? cwd}) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runDesign(args, out: out, err: err, cwd: cwd, now: () => DateTime(2026, 11, 25));
  return Run(code, out.toString(), err.toString());
}

void copyDir(String from, String to) {
  for (final entity in Directory(from).listSync(recursive: true)) {
    final target = p.join(to, p.relative(entity.path, from: from));
    if (entity is Directory) {
      Directory(target).createSync(recursive: true);
    } else if (entity is File) {
      File(target).parent.createSync(recursive: true);
      entity.copySync(target);
    }
  }
}

void main() {
  final skip = File(_kitCatalog).existsSync() ? false : 'the kit catalog.json is not there yet';
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('design_cli_test'));
  tearDown(() => temp.deleteSync(recursive: true));

  String kitCopy() {
    final dir = p.join(temp.path, 'kit');
    copyDir(_kit, dir);
    return dir;
  }

  Future<String> initWorkspace() async {
    final dir = p.join(temp.path, 'app');
    final run = await design(['init', dir, '--catalog', _kitCatalog]);
    expect(run.code, 0, reason: '$run');
    return dir;
  }

  group('usage', () {
    test('no command prints usage; an unknown one is a usage error', () async {
      final none = await design([]);
      expect(none.code, 0);
      expect(none.out, contains('Available commands:'));
      final unknown = await design(['frobnicate']);
      expect(unknown.code, 64);
      expect(unknown.err, contains('frobnicate'));
    });

    test('a command outside a workspace says how to get one', () async {
      final run = await design(['-w', temp.path, 'validate']);
      expect(run.code, 1);
      expect(run.err, contains('design init'));
    });
  });

  group('init', () {
    test('creates the workspace, copies the catalog and writes AGENTS.md', () async {
      final dir = await initWorkspace();
      for (final f in [
        'design.json',
        'tokens/tokens.json',
        'catalog.json',
        'requests.md',
        'AGENTS.md',
        'templates/list.json',
        'templates/frame.json',
      ]) {
        expect(File(p.join(dir, f)).existsSync(), isTrue, reason: f);
      }
      for (final d in ['presets', 'screens']) {
        expect(Directory(p.join(dir, d)).existsSync(), isTrue, reason: d);
      }
      final manifest = jsonDecode(File(p.join(dir, 'design.json')).readAsStringSync()) as Map;
      expect(manifest['name'], 'app');
      expect(manifest['start'], '');
      final agents = File(p.join(dir, 'AGENTS.md')).readAsStringSync();
      for (final code in diagnosticCodes.keys) {
        expect(agents, contains('`$code`'), reason: code);
      }
      expect(agents, contains('`W-table-in-card`'), reason: 'library rule codes from the catalog');
      expect(agents, contains('design link <screen>#<node>.<event>'));
      expect(File(p.join(dir, 'catalog.json')).readAsStringSync(), File(_kitCatalog).readAsStringSync());
      final fresh = await design(['-w', dir, 'validate']);
      expect(fresh.code, 0, reason: '$fresh');

      final again = await design(['init', dir, '--catalog', _kitCatalog]);
      expect(again.code, 1);
      expect(again.err, contains('already holds a workspace'));
      final noCatalog = await design(['init', p.join(temp.path, 'other')]);
      expect(noCatalog.code, 64);
      expect(noCatalog.err, contains('--catalog'));
    }, skip: skip);
  });

  group('new', () {
    test('a screen from each template validates with no errors', () async {
      final dir = await initWorkspace();
      const ids = {
        'list': 'admin.users',
        'detail': 'admin.userEditor',
        'formModal': 'admin.userCreate',
        'dashboard': 'admin.home',
        'frame': 'frames.main',
      };
      for (final MapEntry(key: template, value: id) in ids.entries) {
        final run = await design(['-w', dir, 'new', 'screen', id, '--from', template]);
        expect(run.code, 0, reason: '$run');
        expect(File(p.join(dir, WorkspaceInput.pathForScreenId(id))).existsSync(), isTrue);
      }
      final manifest = jsonDecode(File(p.join(dir, 'design.json')).readAsStringSync()) as Map;
      expect(manifest['start'], 'admin.users', reason: 'the first page becomes the start');
      final ws = DesignWorkspace.load(Directory(dir));
      final found = validateWorkspace(ws.toInput(), ws.catalog!);
      expect(found.where((d) => d.isError), isEmpty, reason: found.join('\n'));
      expect(found.map((d) => d.code).toSet(), {'W-unreachable'}, reason: found.join('\n'));
      final editor = ws.screenFiles['screens/admin/userEditor.json']!;
      expect(editor['route'], '/admin/userEditor/:id');

      final again = await design(['-w', dir, 'new', 'screen', 'admin.users', '--from', 'list']);
      expect(again.code, 1);
      expect(again.err, contains('already exists'));
      final unknown = await design(['-w', dir, 'new', 'screen', 'admin.x', '--from', 'lists']);
      expect(unknown.code, 64);
      expect(unknown.err, contains("Did you mean 'list'?"));
    }, skip: skip);

    test('a new page joins the only frame, or the one --frame names', () async {
      final dir = await initWorkspace();
      expect((await design(['-w', dir, 'new', 'screen', 'frames.main', '--from', 'frame'])).code, 0);
      final run = await design(['-w', dir, 'new', 'screen', 'admin.users', '--from', 'list']);
      expect(run.code, 0, reason: '$run');
      expect(run.out, contains('previewed in frames.main'));
      Map<String, Object?> read(String id) =>
          jsonDecode(File(p.join(dir, WorkspaceInput.pathForScreenId(id))).readAsStringSync()) as Map<String, Object?>;
      expect(read('admin.users')['frame'], 'frames.main');

      expect((await design(['-w', dir, 'new', 'screen', 'frames.other', '--from', 'frame'])).code, 0);
      final two = await design(['-w', dir, 'new', 'screen', 'admin.teams', '--from', 'list']);
      expect(two.out, contains('--frame'));
      expect(read('admin.teams').containsKey('frame'), isFalse, reason: 'two frames: the agent picks');
      final picked = await design([
        '-w',
        dir,
        'new',
        'screen',
        'admin.roles',
        '--from',
        'list',
        '--frame',
        'frames.other',
      ]);
      expect(picked.code, 0, reason: '$picked');
      expect(read('admin.roles')['frame'], 'frames.other');
      final wrong = await design(['-w', dir, 'new', 'screen', 'admin.x', '--from', 'list', '--frame', 'frames.nope']);
      expect(wrong.code, 1);
      expect(wrong.err, contains("no frame 'frames.nope'"));
    }, skip: skip);

    test('a preset and a token', () async {
      final dir = await initWorkspace();
      final token = await design(['-w', dir, 'new', 'token', 'accentSoft', '--type', 'color', '--light', '#FFF7D6']);
      expect(token.code, 0, reason: '$token');
      final tokens = jsonDecode(File(p.join(dir, 'tokens/tokens.json')).readAsStringSync()) as Map;
      expect((tokens['tokens'] as Map)['accentSoft'], {
        'type': 'color',
        'values': {'light': '#FFF7D6'},
      });
      expect((await design(['-w', dir, 'new', 'token', 'padding', '--type', 'double', '--light', '4'])).code, 1);
      expect((await design(['-w', dir, 'new', 'token', 'bad', '--type', 'color', '--light', 'red'])).code, 1);
      expect((await design(['-w', dir, 'new', 'token', 'bad', '--type', 'colour', '--light', 'red'])).code, 64);

      final preset = await design([
        '-w',
        dir,
        'new',
        'preset',
        'StyleCard.soft',
        '--extends',
        'StyleCard.surface',
        '--style',
        '{"box": {"color": "accentSoft"}}',
      ]);
      expect(preset.code, 0, reason: '$preset');
      expect(File(p.join(dir, 'presets/StyleCard.soft.json')).existsSync(), isTrue);
      final ws = DesignWorkspace.load(Directory(dir));
      expect(validateWorkspace(ws.toInput(), ws.catalog!).map((d) => d.code), ['W-preset-unused']);
      final clash = await design(['-w', dir, 'new', 'preset', 'StyleCard.surface', '--extends', 'StyleCard.subtle']);
      expect(clash.code, 1);
      expect(clash.err, contains('built-in'));
    }, skip: skip);
  });

  group('validate', () {
    test('the kit is clean; --json gives counts; a broken file fails', () async {
      final dir = kitCopy();
      final run = await design(['-w', dir, 'validate']);
      expect(run.code, 0, reason: '$run');
      expect(run.out, contains('No problems.'));

      final file = File(p.join(dir, 'screens/admin/dashboard.json'));
      file.writeAsStringSync(file.readAsStringSync().replaceFirst('"OnboardingKpiCard"', '"OnboardingKpiCrad"'));
      final broken = await design(['-w', dir, 'validate', '--json']);
      expect(broken.code, 1);
      final json = jsonDecode(broken.out) as Map<String, Object?>;
      expect(json['errors'], 1);
      expect(json['warnings'], 0);
      final d = (json['diagnostics']! as List).single as Map;
      expect(d['code'], 'E-component-unknown');
      expect(d['node'], 'admin.dashboard#automationsTile');
      expect(d['hint'], "Did you mean 'OnboardingKpiCard'?");

      final filtered = await design(['-w', dir, 'validate', 'screens/admin/automations.json']);
      expect(filtered.code, 0, reason: 'only the named file is shown');
      final byId = await design(['-w', dir, 'validate', 'admin.dashboard']);
      expect(byId.code, 1);
    }, skip: skip);

    test('--strict fails on warnings', () async {
      final dir = await initWorkspace();
      await design(['-w', dir, 'new', 'screen', 'admin.users', '--from', 'list']);
      await design(['-w', dir, 'new', 'screen', 'admin.userCreate', '--from', 'formModal']);
      expect((await design(['-w', dir, 'validate'])).code, 0);
      final strict = await design(['-w', dir, 'validate', '--strict']);
      expect(strict.code, 1);
      expect(strict.out, contains('W-unreachable'));
    }, skip: skip);
  });

  group('patch and link', () {
    test('patch writes an edit that adds no error, and refuses one that does', () async {
      final dir = kitCopy();
      final path = p.join(dir, 'screens/admin/dashboard.json');
      final good = await design([
        '-w',
        dir,
        'patch',
        'admin.dashboard',
        '--ops',
        '[{"op": "setProp", "node": "title", "prop": "subtitle", "value": "Everything at a glance"}]',
      ]);
      expect(good.code, 0, reason: '$good');
      final written = File(path).readAsStringSync();
      expect(written, contains('Everything at a glance'));
      expect(
        written,
        formatDocument(jsonDecode(written) as Map<String, Object?>, path: 'screens/admin/dashboard.json'),
      );

      final bad = await design([
        '-w',
        dir,
        'patch',
        'admin.dashboard',
        '--ops',
        '[{"op": "setProp", "node": "title", "prop": "subtitel", "value": "x"}]',
      ]);
      expect(bad.code, 1);
      expect(bad.out, contains('Nothing written'));
      expect(bad.out, contains('E-prop-unknown'));
      expect(bad.out, contains("Did you mean 'subtitle'?"));
      expect(File(path).readAsStringSync(), written, reason: 'nothing written');

      final unknown = await design([
        '-w',
        dir,
        'patch',
        'admin.dashboard',
        '--ops',
        '[{"op": "remove", "node": "tile"}]',
      ]);
      expect(unknown.code, 1);
      expect(unknown.out, contains('E-node-unknown'));
      final notJson = await design(['-w', dir, 'patch', 'admin.dashboard', '--ops', '[{']);
      expect(notJson.code, 64);
    }, skip: skip);

    test('link appends a navigate action, binding values that start with a root', () async {
      final dir = kitCopy();
      final run = await design([
        '-w',
        dir,
        'link',
        'admin.automations#cardMenu.tap',
        '--to',
        'admin.automationEditor',
        '--param',
        'id=item.id',
      ]);
      // OnboardingCardMenu has no tap event: the edit adds an error and is refused.
      expect(run.code, 1, reason: '$run');
      expect(run.out, contains('E-event-unknown'));

      final ok = await design([
        '-w',
        dir,
        'link',
        'admin.dashboard#pausedNotice.tap',
        '--to',
        'admin.automationEditor',
        '--param',
        'id=data.counts.paused',
      ]);
      expect(ok.code, 0, reason: '$ok');
      final screen = jsonDecode(File(p.join(dir, 'screens/admin/dashboard.json')).readAsStringSync()) as Map;
      Map? card;
      forEachNodeJson(screen['root'], (n) {
        if (n['id'] == 'pausedNotice') card = n;
      });
      expect((card!['on'] as Map)['tap'], [
        {
          'do': 'navigate',
          'to': 'admin.automationEditor',
          'params': {
            'id': {r'$bind': 'data.counts.paused'},
          },
        },
      ]);

      final missing = await design([
        '-w',
        dir,
        'link',
        'admin.dashboard#title.tabSelected',
        '--to',
        'admin.automationEditor',
      ]);
      expect(missing.code, 1);
      expect(missing.out, contains('E-param-missing'));
      final usage = await design(['-w', dir, 'link', 'admin.dashboard.title', '--to', 'admin.automations']);
      expect(usage.code, 64);
    }, skip: skip);
  });

  group('fmt', () {
    test('--check lists files that would change and writes nothing; fmt makes them canonical', () async {
      final dir = kitCopy();
      // The kit is canonical; write one document compactly, keys out of order, so fmt has work to do.
      final file = File(p.join(dir, 'screens/admin/automations.json'));
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      file.writeAsStringSync(jsonEncode({'root': json['root'], ...json}));
      final before = file.readAsStringSync();
      final check = await design(['-w', dir, 'fmt', '--check']);
      expect(check.code, 1);
      expect(check.out, contains('would change: screens/admin/automations.json'));
      expect(check.out, isNot(contains('catalog.json')));
      expect(File(p.join(dir, 'screens/admin/automations.json')).readAsStringSync(), before);

      expect((await design(['-w', dir, 'fmt'])).code, 0);
      final after = await design(['-w', dir, 'fmt', '--check']);
      expect(after.code, 0, reason: '$after');
      final ws = DesignWorkspace.load(Directory(dir));
      expect(validateWorkspace(ws.toInput(), ws.catalog!), isEmpty, reason: 'formatting changes no meaning');
    }, skip: skip);
  });

  group('export', () {
    test('writes the bundle to --out, readable by DesignBundle', () async {
      final dir = kitCopy();
      final out = p.join(temp.path, 'out', 'bundle.json');
      final run = await design(['-w', dir, 'export', '--out', out]);
      expect(run.code, 0, reason: '$run');
      final json = jsonDecode(File(out).readAsStringSync()) as Map<String, Object?>;
      final bundle = DesignBundle.fromJson(json);
      expect(bundle.screens, hasLength(5));
      expect(json['hash'], bundleHash(json));
    }, skip: skip);

    test('refuses a workspace with warnings', () async {
      final dir = await initWorkspace();
      await design(['-w', dir, 'new', 'screen', 'admin.users', '--from', 'list']);
      await design(['-w', dir, 'new', 'screen', 'admin.userCreate', '--from', 'formModal']);
      final out = p.join(temp.path, 'bundle.json');
      final run = await design(['-w', dir, 'export', '--out', out]);
      expect(run.code, 1);
      expect(run.out, contains('Export refused'));
      expect(File(out).existsSync(), isFalse);
    }, skip: skip);
  });

  group('read commands', () {
    test('catalog, describe, flow, contract and request', () async {
      final dir = kitCopy();
      final exact = await design(['-w', dir, 'catalog', 'OnboardingDataTable']);
      expect(exact.code, 0);
      expect(exact.out, contains('rows                   rows  required'));
      expect(exact.out, contains('W-table-in-card'));
      expect(exact.out, contains('example:'));
      final search = await design(['-w', dir, 'catalog', 'sidebar', '--kind', 'component', '--json']);
      expect((jsonDecode(search.out) as Map)['components'], contains('OnboardingSidebarButton'));
      final icons = await design(['-w', dir, 'catalog', 'pencil', '--kind', 'icon']);
      expect(icons.out, contains('pencil'));

      final describe = await design(['-w', dir, 'describe', 'admin.automationEditor', '--fixture', 'invalid']);
      expect(describe.code, 0);
      expect(describe.out, contains('error="Give the automation a name."'));
      final badFixture = await design(['-w', dir, 'describe', 'admin.automationEditor', '--fixture', 'nope']);
      expect(badFixture.code, 1);
      expect(badFixture.err, contains('default, saving, invalid'));

      final flow = await design(['-w', dir, 'flow', '--mermaid']);
      expect(flow.out, startsWith('flowchart LR'));
      final flowJson = await design(['-w', dir, 'flow', '--json']);
      expect((jsonDecode(flowJson.out) as Map)['edges'], isNotEmpty);

      final contract = await design(['-w', dir, 'contract', 'admin.automations', '--json']);
      expect(contract.code, 0);
      final c = jsonDecode(contract.out) as Map<String, Object?>;
      expect((c['modals']! as Map).keys, ['admin.automationCreate']);
      final unknown = await design(['-w', dir, 'contract', 'admin.automation']);
      expect(unknown.code, 1);
      expect(unknown.err, contains("Did you mean 'admin.automations'?"));

      final request = await design(['-w', dir, 'request', 'A date picker for the editor']);
      expect(request.code, 0);
      expect(
        File(p.join(dir, 'requests.md')).readAsStringSync(),
        endsWith('- 2026-11-25: A date picker for the editor\n'),
      );
    }, skip: skip);
  });

  test('templates are listed and fill in their placeholders', () {
    final json = fillTemplate(screenTemplates['detail']!.$2, id: 'shop.order', title: 'Order "A"');
    expect(json['id'], 'shop.order');
    expect(json['route'], '/shop/order/:id');
    expect(json['title'], 'Order "A"');
    expect(screenTemplates.keys, ['list', 'detail', 'formModal', 'dashboard', 'frame']);
  });
}
