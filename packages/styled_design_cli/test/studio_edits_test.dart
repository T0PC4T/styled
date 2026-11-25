// Phase 4's acceptance test: an edit made in the studio's inspector writes
// the same bytes as the matching `design` command. Each edit goes through the
// two real paths, on two copies of one workspace: the studio's message,
// handled by the running `design serve`, and the command, run in-process.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:styled_design_cli/src/serve.dart';
import 'package:test/test.dart';

import 'studio_support.dart';

final _kit = p.normalize(p.absolute('../styled_design_core/test/fixtures/kit_workspace'));

/// Every file of [dir] by relative path, as bytes.
Map<String, List<int>> _files(String dir) => {
  for (final f in Directory(dir).listSync(recursive: true).whereType<File>())
    p.relative(f.path, from: dir): f.readAsBytesSync(),
};

void main() {
  late Directory temp;
  late String studioCopy;
  late String cliCopy;
  late DesignServer server;
  late FakeStudio studio;
  var nextId = 0;

  setUp(() async {
    temp = Directory(Directory.systemTemp.createTempSync('design_edits_test').resolveSymbolicLinksSync());
    studioCopy = p.join(temp.path, 'studio');
    cliCopy = p.join(temp.path, 'cli');
    copyDir(_kit, studioCopy);
    copyDir(_kit, cliCopy);
    server = await DesignServer.start(workspaceDir: studioCopy, port: 0);
    studio = await FakeStudio.connect(server.port);
    await studio.next('snapshot');
  });

  tearDown(() async {
    await studio.close();
    await server.close();
    temp.deleteSync(recursive: true);
  });

  /// Sends [message] as the studio does and returns the server's answer.
  Future<Map<String, Object?>> send(Map<String, Object?> message) async {
    final id = 'e${++nextId}';
    studio.send({...message, 'id': id});
    final result = await studio.next('editResult');
    expect(result['id'], id);
    return result;
  }

  Future<void> cli(List<String> args) async {
    final run = await design(['-w', cliCopy, ...args], cwd: temp.path);
    expect(run.code, 0, reason: '${run.out}${run.err}');
  }

  void expectSameBytes(String changed) {
    final studioFiles = _files(studioCopy);
    final cliFiles = _files(cliCopy);
    expect(studioFiles.keys.toSet(), cliFiles.keys.toSet());
    for (final path in studioFiles.keys) {
      expect(studioFiles[path], cliFiles[path], reason: '$path differs');
    }
    final original = File(p.join(_kit, changed));
    if (original.existsSync()) {
      expect(studioFiles[changed], isNot(original.readAsBytesSync()), reason: '$changed changed');
    }
    expect(studioFiles, contains(changed));
  }

  test('a label: the inspector\'s setProp and design patch', () async {
    final ops = [
      {'op': 'setProp', 'node': 'newAutomation', 'prop': 'label', 'value': 'Add automation'},
    ];
    final result = await send({'type': 'patch', 'screen': 'admin.automations', 'ops': ops});
    expect(result['ok'], isTrue, reason: '$result');
    expect(result['path'], 'screens/admin/automations.json');
    final changed = await studio.next('changed');
    expect((changed['files']! as Map).keys, ['screens/admin/automations.json']);
    await cli(['patch', 'admin.automations', '--ops', jsonEncode(ops)]);
    expectSameBytes('screens/admin/automations.json');
  });

  test('a preset: the inspector\'s style prop and design patch', () async {
    final ops = [
      {'op': 'setProp', 'node': 'pausedNotice', 'prop': 'style', 'value': 'StyleCard.subtle'},
    ];
    expect((await send({'type': 'patch', 'screen': 'admin.dashboard', 'ops': ops}))['ok'], isTrue);
    await cli(['patch', 'admin.dashboard', '--ops', jsonEncode(ops)]);
    expectSameBytes('screens/admin/dashboard.json');
  });

  test('a token: the token editor and design token set, unset', () async {
    final set = await send({'type': 'tokenSet', 'key': 'primary', 'mode': 'dark', 'value': '#123456'});
    expect(set['ok'], isTrue, reason: '$set');
    await cli(['token', 'set', 'primary', '--value', '#123456', '--mode', 'dark']);
    expectSameBytes('tokens/tokens.json');

    final radius = await send({'type': 'tokenSet', 'key': 'cardRadius', 'value': 20});
    expect(radius['ok'], isTrue);
    await cli(['token', 'set', 'cardRadius', '--value', '20']);
    final unset = await send({'type': 'tokenUnset', 'key': 'accentSubtle', 'mode': 'dark'});
    expect(unset['ok'], isTrue);
    await cli(['token', 'unset', 'accentSubtle', '--mode', 'dark']);
    expectSameBytes('tokens/tokens.json');
  });

  test('a link target: the inspector\'s link and design link, and a changed target and design patch', () async {
    final added = await send({
      'type': 'patch',
      'screen': 'admin.dashboard',
      'ops': [
        {
          'op': 'setEvent',
          'node': 'pausedNotice',
          'event': 'tap',
          'actions': [
            {'do': 'navigate', 'to': 'admin.automations', 'mode': 'replaceAll'},
          ],
        },
      ],
    });
    expect(added['ok'], isTrue, reason: '$added');
    await cli(['link', 'admin.dashboard#pausedNotice.tap', '--to', 'admin.automations', '--mode', 'replaceAll']);
    expectSameBytes('screens/admin/dashboard.json');

    final retarget = [
      {
        'op': 'setEvent',
        'node': 'pausedNotice',
        'event': 'tap',
        'actions': [
          {
            'do': 'navigate',
            'to': 'admin.automationEditor',
            'params': {'id': 'auto_welcome'},
          },
        ],
      },
    ];
    expect((await send({'type': 'patch', 'screen': 'admin.dashboard', 'ops': retarget}))['ok'], isTrue);
    await cli(['patch', 'admin.dashboard', '--ops', jsonEncode(retarget)]);
    expectSameBytes('screens/admin/dashboard.json');
  });

  test('a designer preset: the preset editor and design preset write, remove', () async {
    final preset = {
      'format': 1,
      'id': 'StyleCard.calm',
      'extends': 'StyleCard.surface',
      'description': 'A quiet card.',
      'style': {
        'box': {'color': 'surfaceSubtle', 'boxShadow': <Object?>[]},
      },
    };
    expect((await send({'type': 'presetWrite', 'preset': preset}))['ok'], isTrue);
    await cli(['preset', 'write', 'StyleCard.calm', '--json', jsonEncode(preset)]);
    expectSameBytes('presets/StyleCard.calm.json');

    expect((await send({'type': 'presetRemove', 'presetId': 'StyleCard.calm'}))['ok'], isTrue);
    await cli(['preset', 'remove', 'StyleCard.calm']);
    expect(File(p.join(studioCopy, 'presets', 'StyleCard.calm.json')).existsSync(), isFalse);
    expect(_files(studioCopy).keys.toSet(), _files(cliCopy).keys.toSet());
  });

  test('an edit that adds an error is refused the same way on both paths, and nothing is written', () async {
    final ops = [
      {'op': 'setProp', 'node': 'automationsTile', 'prop': 'icon', 'value': 'no_such_icon'},
    ];
    final result = await send({'type': 'patch', 'screen': 'admin.dashboard', 'ops': ops});
    expect(result['ok'], isFalse);
    expect((result['diagnostics']! as List).cast<Map<String, Object?>>().single['code'], 'E-icon-unknown');
    final run = await design(['-w', cliCopy, 'patch', 'admin.dashboard', '--ops', jsonEncode(ops)], cwd: temp.path);
    expect(run.code, 1);
    expect(run.out, contains('E-icon-unknown'));
    expect(_files(studioCopy), _files(cliCopy));

    final token = await send({'type': 'tokenSet', 'key': 'primary', 'value': 'blue'});
    expect(token['ok'], isFalse);
    expect(token['message'], contains('#RRGGBB'));
    final cliToken = await design(['-w', cliCopy, 'token', 'set', 'primary', '--value', 'blue'], cwd: temp.path);
    expect(cliToken.code, 1);
    expect(cliToken.out, contains(token['message']));
  });

  test('design token and design preset say how to call them', () async {
    Future<int> code(List<String> args) async => (await design(['-w', cliCopy, ...args], cwd: temp.path)).code;
    expect(await code(['token', 'set', 'primary']), 64, reason: 'no --value');
    expect(await code(['token', 'set']), 64);
    expect(await code(['token', 'unset', 'nope']), 1);
    expect(await code(['preset', 'write', 'StyleCard.calm']), 64, reason: 'no --json');
    expect(await code(['preset', 'write', 'nope', '--json', '{}']), 64);
    expect(await code(['preset', 'write', 'StyleCard.calm', '--json', '{"id": "StyleCard.other"}']), 64);
    expect(await code(['preset', 'remove', 'StyleCard.highlight']), 1, reason: 'the dashboard uses it');
    final added = await design([
      '-w',
      cliCopy,
      'token',
      'set',
      'brandNew',
      '--type',
      'color',
      '--value',
      '#FFFFFF',
      '--description',
      'Brand.',
    ], cwd: temp.path);
    expect(added.code, 0, reason: added.out);
    expect(added.out, contains('Set brandNew to "#FFFFFF" in light mode'));
    expect(added.out, contains('1 warning: run design validate tokens/tokens.json'));
  });
}
