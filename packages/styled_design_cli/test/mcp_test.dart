import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:styled_design_cli/styled_design_cli.dart';
import 'package:styled_design_core/io.dart';
import 'package:styled_design_core/styled_design_core.dart';
import 'package:test/test.dart';

const _kit = '../styled_design_core/test/fixtures/kit_workspace';

/// A copy of the kit workspace in a temp folder.
String _copyKit() {
  final temp = Directory.systemTemp.createTempSync('design_mcp_test_');
  addTearDown(() => temp.deleteSync(recursive: true));
  for (final entity in Directory(_kit).listSync(recursive: true)) {
    final rel = p.relative(entity.path, from: _kit);
    if (entity is Directory) {
      Directory(p.join(temp.path, rel)).createSync(recursive: true);
    } else if (entity is File) {
      File(p.join(temp.path, rel))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(entity.readAsBytesSync());
    }
  }
  return temp.path;
}

/// Talks JSON-RPC lines to a server, as an MCP client would.
final class _Client {
  final DesignMcpServer server;
  final _requests = StreamController<String>();
  final _responses = <int, Completer<Map<String, Object?>>>{};
  var _next = 1;

  _Client(this.server) {
    unawaited(
      server.serve(_requests.stream, (line) {
        final message = jsonDecode(line) as Map<String, Object?>;
        _responses.remove(message['id'])?.complete(message);
      }),
    );
  }

  Future<Map<String, Object?>> request(String method, [Map<String, Object?> params = const {}]) {
    final id = _next++;
    final done = _responses[id] = Completer();
    _requests.add(jsonEncode({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params}));
    return done.future;
  }

  void notify(String method) => _requests.add(jsonEncode({'jsonrpc': '2.0', 'method': method}));

  /// Calls [tool] and returns (isError, text).
  Future<(bool, String)> call(String tool, [Map<String, Object?> args = const {}]) async {
    final reply = await request('tools/call', {'name': tool, 'arguments': args});
    final result = reply['result']! as Map<String, Object?>;
    final text = [
      for (final c in result['content']! as List)
        if ((c as Map)['type'] == 'text') c['text'],
    ].join('\n');
    return (result['isError'] == true, text);
  }

  Future<void> close() => _requests.close();
}

void main() {
  late String workspace;
  late _Client client;

  setUp(() {
    workspace = _copyKit();
    client = _Client(DesignMcpServer(workspace: workspace, run: runDesign));
    addTearDown(client.close);
  });

  test('initialize, then tools/list names every design tool', () async {
    final init = await client.request('initialize', {
      'protocolVersion': '2025-06-18',
      'capabilities': <String, Object?>{},
      'clientInfo': {'name': 'test', 'version': '1'},
    });
    final result = init['result']! as Map<String, Object?>;
    expect(result['protocolVersion'], '2025-06-18');
    expect((result['serverInfo']! as Map)['name'], 'design');
    client.notify('notifications/initialized');
    final list = await client.request('tools/list');
    final names = [for (final t in (list['result']! as Map)['tools'] as List) (t as Map)['name']];
    expect(
      names,
      containsAll([
        'guide',
        'catalog_search',
        'catalog_get',
        'screen_list',
        'screen_read',
        'screen_write',
        'screen_patch',
        'validate',
        'describe',
        'screenshot',
        'link',
        'flow',
        'token_set',
        'preset_write',
        'request',
      ]),
    );
    final unknown = await client.request('tools/call', {'name': 'nope'});
    expect((unknown['error']! as Map)['code'], -32602);
  });

  test('the phase 2 task through MCP alone: a new list page, linked from the sidebar, strict-clean', () async {
    final (_, guide) = await client.call('guide');
    expect(guide, contains('design validate'));
    expect(guide, contains('`screen_patch {screen, ops}`'), reason: 'the guide maps each command to its tool');

    final (searchFailed, search) = await client.call('catalog_search', {'query': 'sidebar button'});
    expect(searchFailed, isFalse, reason: search);
    expect(search, contains('OnboardingSidebarButton'));

    final (newFailed, created) = await client.call('screen_new', {'screen': 'admin.users', 'template': 'list'});
    expect(newFailed, isFalse, reason: created);
    expect(created, contains('frames.admin'), reason: 'the page joined the only frame');

    final (patchFailed, patched) = await client.call('screen_patch', {
      'screen': 'frames.admin',
      'ops': [
        {
          'op': 'insert',
          'parent': 'manage',
          'slot': 'children',
          'node': {
            'id': 'navUsers',
            'type': 'OnboardingSidebarButton',
            'props': {
              'label': 'Users',
              'icon': 'users',
              'selected': {
                r'$eq': [
                  {r'$bind': 'page.id'},
                  'admin.users',
                ],
              },
            },
          },
        },
      ],
    });
    expect(patchFailed, isFalse, reason: patched);

    final (linkFailed, linked) = await client.call('link', {
      'from': 'frames.admin#navUsers.tap',
      'to': 'admin.users',
      'mode': 'replaceAll',
    });
    expect(linkFailed, isFalse, reason: linked);

    final (validateFailed, report) = await client.call('validate', {'strict': true});
    expect(validateFailed, isFalse, reason: report);
    final json = jsonDecode(report) as Map<String, Object?>;
    expect(json['errors'], 0);
    expect(json['warnings'], 0, reason: report);

    final (_, flow) = await client.call('flow');
    expect(flow, contains('navUsers'));

    final ws = DesignWorkspace.load(Directory(workspace));
    expect(validateWorkspace(ws.toInput(), ws.catalog!, strict: true), isEmpty);
  });

  test('a tool that would add an error writes nothing and says why', () async {
    final before = File(p.join(workspace, 'screens/admin/automations.json')).readAsStringSync();
    final (failed, text) = await client.call('screen_patch', {
      'screen': 'admin.automations',
      'ops': [
        {'op': 'setProp', 'node': 'title', 'prop': 'heading', 'value': 'x'},
      ],
    });
    expect(failed, isTrue);
    expect(text, contains('E-prop-unknown'));
    expect(File(p.join(workspace, 'screens/admin/automations.json')).readAsStringSync(), before);
  });

  test('screen_list, screen_read and screen_write', () async {
    final (_, list) = await client.call('screen_list');
    expect((jsonDecode(list) as List).map((s) => (s as Map)['id']), contains('admin.automations'));
    final (_, read) = await client.call('screen_read', {'screen': 'admin.dashboard'});
    final doc = jsonDecode(read) as Map<String, Object?>;
    expect(doc['id'], 'admin.dashboard');
    final (failed, written) = await client.call('screen_write', {
      'screen': 'admin.dashboard',
      'document': {...doc, 'title': 'Admin home'},
    });
    expect(failed, isFalse, reason: written);
    expect(File(p.join(workspace, 'screens/admin/dashboard.json')).readAsStringSync(), contains('Admin home'));
  });

  test('request records a need for the developer', () async {
    final (failed, text) = await client.call('request', {'need': 'A rich text editor for template bodies.'});
    expect(failed, isFalse, reason: text);
    expect(
      File(p.join(workspace, 'requests.md')).readAsStringSync(),
      contains('A rich text editor for template bodies.'),
    );
  });

  test('token_set takes a colour as text and a number as a number', () async {
    final (colourFailed, colour) = await client.call('token_set', {'key': 'primary', 'value': '#7A3FD1'});
    expect(colourFailed, isFalse, reason: colour);
    final (numberFailed, number) = await client.call('token_set', {'key': 'paddingSm', 'value': 10, 'mode': 'dark'});
    expect(numberFailed, isFalse, reason: number);
    final tokens = jsonDecode(File(p.join(workspace, 'tokens/tokens.json')).readAsStringSync()) as Map<String, Object?>;
    final entries = tokens['tokens']! as Map<String, Object?>;
    expect((entries['primary']! as Map)['values'], {'light': '#7A3FD1'});
    expect((entries['paddingSm']! as Map)['values'], {'dark': 10});
    final (wrongFailed, wrong) = await client.call('token_set', {'key': 'paddingSm', 'value': 'wide'});
    expect(wrongFailed, isTrue, reason: 'a word is not a number');
    expect(wrong, isNotEmpty);
  });

  test('preset_write writes a designer preset whose id is the argument', () async {
    final (failed, text) = await client.call('preset_write', {
      'id': 'StyleCard.calm',
      'document': {
        'format': 1,
        'extends': 'StyleCard.surface',
        'style': {
          'box': {'color': 'surfaceSubtle'},
        },
      },
    });
    expect(failed, isFalse, reason: text);
    final written = jsonDecode(File(p.join(workspace, 'presets/StyleCard.calm.json')).readAsStringSync()) as Map;
    expect(written['id'], 'StyleCard.calm');
    expect(written['extends'], 'StyleCard.surface');
    final (_, report) = await client.call('validate', {'strict': true});
    expect(report, contains('W-preset-unused'), reason: 'written, and nothing uses it yet');
    expect((jsonDecode(report) as Map)['errors'], 0);
  });
}
