import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:styled_design_cli/src/serve.dart';
import 'package:styled_design_cli/styled_design_cli.dart';
import 'package:test/test.dart';

final _kit = p.normalize(p.absolute('../styled_design_core/test/fixtures/kit_workspace'));

/// A 1x1 PNG.
const _png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

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

/// A WebSocket client that buffers what the server sends: a fake studio tab.
final class FakeStudio {
  final WebSocket socket;
  final _buffer = <Map<String, Object?>>[];
  final _waiters = <(bool Function(Map<String, Object?>), Completer<Map<String, Object?>>)>[];

  FakeStudio._(this.socket) {
    socket.listen((data) {
      final message = jsonDecode(data as String) as Map<String, Object?>;
      for (final waiter in [..._waiters]) {
        if (waiter.$1(message)) {
          _waiters.remove(waiter);
          waiter.$2.complete(message);
          return;
        }
      }
      _buffer.add(message);
    });
  }

  static Future<FakeStudio> connect(int port, {Map<String, String>? headers}) async =>
      FakeStudio._(await WebSocket.connect('ws://127.0.0.1:$port/ws', headers: headers));

  /// The next message of [type], waiting up to [timeout] for it.
  Future<Map<String, Object?>> next(String type, {Duration timeout = const Duration(seconds: 5)}) {
    bool test(Map<String, Object?> m) => m['type'] == type;
    final buffered = _buffer.where(test).firstOrNull;
    if (buffered != null) {
      _buffer.remove(buffered);
      return Future.value(buffered);
    }
    final completer = Completer<Map<String, Object?>>();
    _waiters.add((test, completer));
    return completer.future.timeout(timeout, onTimeout: () => throw TimeoutException('No $type within $timeout'));
  }

  /// Every message buffered so far, then clears the buffer.
  List<Map<String, Object?>> drain() {
    final all = [..._buffer];
    _buffer.clear();
    return all;
  }

  void send(Map<String, Object?> message) => socket.add(jsonEncode(message));

  Future<void> close() => socket.close();
}

Future<({int code, String out, String err})> design(List<String> args, {required String cwd}) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runDesign(args, out: out, err: err, cwd: cwd);
  return (code: code, out: out.toString(), err: err.toString());
}

Future<(int, String, String?)> get(int port, String path, {Map<String, String> headers = const {}}) async {
  final client = HttpClient();
  try {
    final request = await client.get('127.0.0.1', port, path);
    headers.forEach(request.headers.set);
    final response = await request.close();
    return (response.statusCode, await utf8.decodeStream(response), response.headers.contentType?.mimeType);
  } finally {
    client.close(force: true);
  }
}

void main() {
  late Directory temp;
  late String ws;
  late DesignServer server;
  final log = <String>[];

  setUp(() async {
    temp = Directory(Directory.systemTemp.createTempSync('design_serve_test').resolveSymbolicLinksSync());
    ws = p.join(temp.path, 'kit');
    copyDir(_kit, ws);
    File(p.join(ws, 'requests.md')).writeAsStringSync('# Requests\n');
    log.clear();
    server = await DesignServer.start(workspaceDir: ws, port: 0, log: log.add);
  });

  tearDown(() async {
    await server.close();
    temp.deleteSync(recursive: true);
  });

  String screenFile(String id) => '${p.joinAll([ws, 'screens', ...id.split('.')])}.json';

  group('the WebSocket', () {
    test('sends a snapshot of every document, requests.md, the catalog and the diagnostics on connect', () async {
      final studio = await FakeStudio.connect(server.port);
      final snapshot = await studio.next('snapshot');
      final files = snapshot['files']! as Map<String, Object?>;
      expect(files.keys, containsAll(['design.json', 'tokens/tokens.json', 'screens/admin/automations.json']));
      expect(files.keys.where((k) => k.startsWith('screens/')), hasLength(5));
      expect(files.keys, isNot(contains('catalog.json')), reason: 'the catalog comes once, as catalog');
      expect((snapshot['catalog']! as Map)['components'], isA<Map<String, Object?>>());
      expect(snapshot['name'], 'Onboarding360');
      expect(snapshot['requests'], '# Requests\n');
      expect(snapshot['loadProblems'], isEmpty);
      expect(snapshot['diagnostics'], isA<List<Object?>>());
      expect(server.studioCount, 1);
      await studio.close();
    });

    test('pushes a saved file as changed within half a second', () async {
      final studio = await FakeStudio.connect(server.port);
      await studio.next('snapshot');
      final file = File(screenFile('admin.automations'));
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      json['title'] = 'Automations, edited';

      final latencies = <int>[];
      for (var i = 0; i < 3; i++) {
        json['description'] = 'Save $i';
        final watch = Stopwatch()..start();
        file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
        final changed = await studio.next('changed');
        latencies.add(watch.elapsedMilliseconds);
        final doc = (changed['files']! as Map)['screens/admin/automations.json']! as Map;
        expect(doc['description'], 'Save $i');
        expect(changed['loadProblems'], isEmpty);
        expect(changed['diagnostics'], isA<List<Object?>>());
        expect(changed.containsKey('catalog'), isFalse);
      }
      printOnFailure('save to changed: $latencies ms');
      expect(latencies.reduce((a, b) => a > b ? a : b), lessThan(500), reason: 'latencies: $latencies ms');
      await studio.close();
    });

    test('a file that stops reading sends its load problem and drops out; a fixed one comes back', () async {
      final studio = await FakeStudio.connect(server.port);
      await studio.next('snapshot');
      final file = File(screenFile('admin.dashboard'));
      final good = file.readAsStringSync();
      file.writeAsStringSync(good.replaceFirst('"kind"', '"kind" "'));
      final broken = await studio.next('changed');
      expect((broken['files']! as Map).containsKey('screens/admin/dashboard.json'), isTrue);
      expect((broken['files']! as Map)['screens/admin/dashboard.json'], isNull);
      final problems = (broken['loadProblems']! as List).cast<Map<String, Object?>>();
      expect(problems.single['code'], 'E-json');
      expect(problems.single['file'], 'screens/admin/dashboard.json');
      final diagnostics = (broken['diagnostics']! as List).cast<Map<String, Object?>>();
      expect(diagnostics.any((d) => d['code'] == 'E-json' && d['file'] == 'screens/admin/dashboard.json'), isTrue);

      file.writeAsStringSync(good);
      final fixed = await studio.next('changed');
      expect((fixed['files']! as Map)['screens/admin/dashboard.json'], isA<Map<String, Object?>>());
      expect(fixed['loadProblems'], isEmpty);
      await studio.close();
    });

    test('adds, deletes, requests.md and bursts of saves', () async {
      final studio = await FakeStudio.connect(server.port);
      await studio.next('snapshot');
      final added = File(p.join(ws, 'screens', 'admin', 'reports', 'list.json'));
      final json = jsonDecode(File(screenFile('admin.dashboard')).readAsStringSync()) as Map<String, Object?>;
      added.parent.createSync(recursive: true);
      added.writeAsStringSync(jsonEncode({...json, 'id': 'admin.reports.list', 'route': '/admin/reports'}));
      final add = await studio.next('changed');
      expect((add['files']! as Map)['screens/admin/reports/list.json'], isA<Map<String, Object?>>());

      added.deleteSync();
      final delete = await studio.next('changed');
      expect((delete['files']! as Map).containsKey('screens/admin/reports/list.json'), isTrue);
      expect((delete['files']! as Map)['screens/admin/reports/list.json'], isNull);
      expect(delete['loadProblems'], isEmpty, reason: 'deleted, not broken');

      File(p.join(ws, 'requests.md')).writeAsStringSync('# Requests\n\n- A timeline component.\n');
      final requests = await studio.next('changed');
      expect(requests['requests'], contains('timeline'));
      expect(requests['files'], isEmpty);

      // Several saves in one burst arrive as one message.
      final tokens = File(p.join(ws, 'tokens', 'tokens.json'));
      final text = tokens.readAsStringSync();
      for (var i = 0; i < 5; i++) {
        tokens.writeAsStringSync(text.replaceFirst('"light": 16', '"light": ${16 + i}'));
      }
      final burst = await studio.next('changed');
      expect(((burst['files']! as Map)['tokens/tokens.json']! as Map)['tokens'], isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(studio.drain().where((m) => m['type'] == 'changed'), isEmpty, reason: 'debounced into one');

      // Files outside the documents do not count.
      File(p.join(ws, 'AGENTS.md')).writeAsStringSync('changed');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(studio.drain(), isEmpty);
      await studio.close();
    });

    test('write: an edit that adds no error is written in canonical form; one that does is refused', () async {
      final studio = await FakeStudio.connect(server.port);
      await studio.next('snapshot');
      const path = 'screens/admin/dashboard.json';
      final json = jsonDecode(File(screenFile('admin.dashboard')).readAsStringSync()) as Map<String, Object?>;

      studio.send({
        'type': 'write',
        'id': 'w1',
        'path': path,
        'json': {...json, 'title': 'Admin home'},
      });
      final ok = await studio.next('writeResult');
      expect(ok['ok'], isTrue, reason: '$ok');
      expect(ok['id'], 'w1');
      final written = File(screenFile('admin.dashboard')).readAsStringSync();
      expect(jsonDecode(written)['title'], 'Admin home');
      expect(written, endsWith('}\n'));
      final changed = await studio.next('changed');
      expect(((changed['files']! as Map)[path]! as Map)['title'], 'Admin home');

      final root = {...(json['root']! as Map<String, Object?>), 'type': 'NoSuchWidget'};
      studio.send({
        'type': 'write',
        'path': path,
        'json': {...json, 'root': root},
      });
      final refused = await studio.next('writeResult');
      expect(refused['ok'], isFalse);
      expect(refused['message'], contains('Nothing written'));
      expect((refused['diagnostics']! as List).cast<Map>().map((d) => d['code']), contains('E-component-unknown'));
      expect(jsonDecode(File(screenFile('admin.dashboard')).readAsStringSync())['title'], 'Admin home');

      studio.send({'type': 'write', 'path': '../outside.json', 'json': json});
      final outside = await studio.next('writeResult');
      expect(outside['ok'], isFalse);
      expect(outside['message'], contains('not a design document'));
      expect(File(p.join(temp.path, 'outside.json')).existsSync(), isFalse);
      await studio.close();
    });

    test('refuses a page from another site', () async {
      await expectLater(
        FakeStudio.connect(server.port, headers: {'Origin': 'https://example.com'}),
        throwsA(isA<WebSocketException>()),
      );
      final local = await FakeStudio.connect(server.port, headers: {'Origin': 'http://localhost:8080'});
      await local.next('snapshot');
      await local.close();
      final (status, _, _) = await get(server.port, '/', headers: {'Host': 'evil.example:${server.port}'});
      expect(status, HttpStatus.forbidden);
    });
  });

  group('screenshot and focus', () {
    test('a capture is relayed to the studio tab and its PNG written', () async {
      final studio = await FakeStudio.connect(server.port);
      await studio.next('snapshot');
      final run = design([
        'screenshot',
        'admin.automations',
        '--fixture',
        'empty',
        '--mode',
        'dark',
        '--size',
        '390x844',
        '--port',
        '${server.port}',
      ], cwd: temp.path);
      final capture = await studio.next('capture');
      expect(capture, {
        'type': 'capture',
        'id': capture['id'],
        'screen': 'admin.automations',
        'fixture': 'empty',
        'mode': 'dark',
        'width': 390,
        'height': 844,
      });
      studio.send({'type': 'captured', 'id': capture['id'], 'png': _png});
      final result = await run;
      expect(result.code, 0, reason: result.err);
      expect(result.out, contains('Wrote admin.automations-empty-dark.png (1x1, dark, fixture empty)'));
      expect(File(p.join(temp.path, 'admin.automations-empty-dark.png')).readAsBytesSync(), base64Decode(_png));

      final failing = design([
        'screenshot',
        'admin.dashboard',
        '--out',
        'shots/d.png',
        '--port',
        '${server.port}',
      ], cwd: temp.path);
      final second = await studio.next('capture');
      expect(second['width'], 1440);
      expect(second['height'], 900);
      expect(second['mode'], 'light');
      studio.send({'type': 'captureFailed', 'id': second['id'], 'message': 'The screen threw while drawing.'});
      final failed = await failing;
      expect(failed.code, 1);
      expect(failed.err, contains('The screen threw while drawing.'));
      await studio.close();
    });

    test('says what to do with no server, no studio tab, or an unknown screen or fixture', () async {
      final noServer = await design(['screenshot', 'admin.automations', '--port', '1'], cwd: temp.path);
      expect(noServer.code, 1);
      expect(noServer.err, contains('No design serve answers on port 1'));

      final noStudio = await design(['screenshot', 'admin.automations', '--port', '${server.port}'], cwd: temp.path);
      expect(noStudio.code, 1);
      expect(noStudio.err, contains('no studio tab is connected'));
      expect(noStudio.err, contains(server.url));

      final studio = await FakeStudio.connect(server.port);
      await studio.next('snapshot');
      final unknown = await design(['screenshot', 'admin.automation', '--port', '${server.port}'], cwd: temp.path);
      expect(unknown.code, 1);
      expect(unknown.err, contains("Did you mean 'admin.automations'?"));
      final fixture = await design([
        'screenshot',
        'admin.automations',
        '--fixture',
        'nope',
        '--port',
        '${server.port}',
      ], cwd: temp.path);
      final fixtures = (jsonDecode(File(screenFile('admin.automations')).readAsStringSync())['fixtures'] as Map).keys;
      expect(fixture.err, contains("admin.automations has no fixture 'nope'. It has: ${fixtures.join(', ')}."));

      final usage = await design(['screenshot', 'admin.automations', '--size', 'big'], cwd: temp.path);
      expect(usage.code, 64);
      expect(usage.err, contains('--size'));
      await studio.close();
    });

    test('focus is relayed to every studio tab', () async {
      final a = await FakeStudio.connect(server.port);
      final b = await FakeStudio.connect(server.port);
      await a.next('snapshot');
      await b.next('snapshot');
      final run = await design([
        'focus',
        'admin.automations#newAutomation',
        '--port',
        '${server.port}',
      ], cwd: temp.path);
      expect(run.code, 0, reason: run.err);
      expect(run.out, contains('The studio shows admin.automations#newAutomation in 2 tabs.'));
      for (final studio in [a, b]) {
        expect(await studio.next('focus'), {'type': 'focus', 'screen': 'admin.automations', 'node': 'newAutomation'});
      }
      final bad = await design(['focus', 'admin.automations#Bad'], cwd: temp.path);
      expect(bad.code, 64);
      await a.close();
      await b.close();
    });
  });

  group('HTTP', () {
    test('without a studio, / says how to build one', () async {
      final (status, body, type) = await get(server.port, '/');
      expect(status, 200);
      expect(type, 'text/html');
      expect(body, contains('flutter build web'));
      expect(body, contains('DESIGN_STUDIO_DIR'));
    });

    test('serves the studio files, index.html for app routes, and nothing outside the folder', () async {
      final studioDir = Directory(p.join(temp.path, 'web'))..createSync();
      File(p.join(studioDir.path, 'index.html')).writeAsStringSync('<html>studio</html>');
      File(p.join(studioDir.path, 'main.dart.js')).writeAsStringSync('main();');
      File(p.join(temp.path, 'secret.txt')).writeAsStringSync('secret');
      final withStudio = await DesignServer.start(workspaceDir: ws, port: 0, studioDir: studioDir.path);
      addTearDown(withStudio.close);
      expect(await get(withStudio.port, '/'), (200, '<html>studio</html>', 'text/html'));
      expect(await get(withStudio.port, '/main.dart.js'), (200, 'main();', 'text/javascript'));
      expect((await get(withStudio.port, '/screens/admin.automations')).$2, '<html>studio</html>');
      expect((await get(withStudio.port, '/missing.js')).$1, 404);
      expect((await get(withStudio.port, '/..%2Fsecret.txt')).$2, isNot(contains('secret')));
      expect((await get(withStudio.port, '/api/status')).$2, contains('"studios":0'));
    });

    test('a built studio is served (set DESIGN_STUDIO_DIR to its build/web)', () async {
      final dir = Platform.environment['DESIGN_STUDIO_DIR']!;
      final withStudio = await DesignServer.start(workspaceDir: ws, port: 0, studioDir: dir);
      addTearDown(withStudio.close);
      final (status, body, _) = await get(withStudio.port, '/');
      expect(status, 200);
      expect(body, contains('flutter_bootstrap.js'));
      final (jsStatus, _, jsType) = await get(withStudio.port, '/flutter_bootstrap.js');
      expect((jsStatus, jsType), (200, 'text/javascript'));
      final (mainStatus, _, _) = await get(withStudio.port, '/main.dart.js');
      expect(mainStatus, 200);
    }, skip: Platform.environment['DESIGN_STUDIO_DIR'] == null ? 'DESIGN_STUDIO_DIR is not set' : false);
  });

  group('design serve', () {
    test('says what to do when it cannot start', () async {
      final noWorkspace = await design(['serve', '--port', '0'], cwd: temp.path);
      expect(noWorkspace.code, 1);
      expect(noWorkspace.err, contains('design init'));
      final noStudio = await design(['-w', ws, 'serve', '--port', '0', '--studio', temp.path], cwd: temp.path);
      expect(noStudio.code, 1);
      expect(noStudio.err, contains('flutter build web'));
      final badPort = await design(['-w', ws, 'serve', '--port', 'x'], cwd: temp.path);
      expect(badPort.code, 64);
      final taken = await design(['-w', ws, 'serve', '--port', '${server.port}'], cwd: temp.path);
      expect(taken.code, 1);
      expect(taken.err, contains('--port'));
    });
  });
}
