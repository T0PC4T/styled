import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:styled_design_core/io.dart';
import 'package:styled_design_core/styled_design_core.dart';

import 'context.dart';

/// The port `design serve`, `design screenshot` and `design focus` use by default.
const defaultStudioPort = 4400;

/// How long the server waits for a studio tab to answer a capture.
const captureTimeout = Duration(seconds: 30);

/// `design serve`: serves the studio's web files, pushes the workspace to every
/// studio tab over a WebSocket, and relays `design screenshot` and
/// `design focus` to a tab.
///
/// Every message is a JSON object with a `type`.
///
/// Server to studio:
/// - `snapshot` on connect: `{name, files: {path: json}, loadProblems: [diagnostic],
///   requests: text|null, catalog: json|null, diagnostics: [diagnostic]}`. `files` holds
///   every document `DesignWorkspace.load` reads except catalog.json, which comes as
///   `catalog`; `loadProblems` lists the files that do not read (`E-json`).
/// - `changed` after a save, add or delete: `{files: {path: json|null}, loadProblems,
///   diagnostics}`, plus `requests` and `catalog` when those changed. A path maps to its
///   new JSON, or to null when it was deleted or no longer reads; in the second case
///   `loadProblems` names it, and the studio keeps drawing the last version that read.
/// - `capture` `{id, screen, fixture?, mode?, width?, height?}`: draw the screen and
///   answer `captured` `{id, png}` (base64) or `captureFailed` `{id, message}`.
/// - `focus` `{screen, node?}`: show the screen and point at the node.
/// - `writeResult` `{id?, path, ok, message, diagnostics}`: the answer to a `write`.
///
/// Studio to server:
/// - `write` `{id?, path, json}`: replace a document. Refused when it adds an error,
///   the same rule as `design patch`; otherwise written in canonical form.
/// - `captured`, `captureFailed`: the answers to `capture`.
///
/// HTTP, loopback only: `GET /` and the studio's files, `GET /api/status`,
/// `POST /api/capture` (answers image/png) and `POST /api/focus`.
final class DesignServer {
  /// The workspace folder, with symbolic links resolved.
  final Directory root;

  /// The folder of the studio's built web files, or null.
  final String? studioDir;

  final Duration debounce;
  final void Function(String line) _log;

  final HttpServer _http;
  final _studios = <_StudioClient>[];
  final _captures = <String, ({_StudioClient client, Completer<List<int>> done})>{};
  StreamSubscription<FileSystemEvent>? _watch;
  Timer? _debounceTimer;
  var _nextId = 0;
  var _nextClient = 0;

  late _Snapshot _state;
  String? _catalogText;
  Catalog? _catalog;

  DesignServer._(this.root, this.studioDir, this._http, this.debounce, this._log);

  /// Starts serving [workspaceDir] on the loopback interface at [port] (0 picks
  /// a free one). Throws a [SocketException] when the port is taken.
  static Future<DesignServer> start({
    required String workspaceDir,
    int port = defaultStudioPort,
    String? studioDir,
    Duration debounce = const Duration(milliseconds: 60),
    void Function(String line)? log,
  }) async {
    final root = Directory(Directory(workspaceDir).resolveSymbolicLinksSync());
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    final server = DesignServer._(root, studioDir, http, debounce, log ?? (_) {});
    server._state = server._load();
    server._watch = root.watch(recursive: true).listen(server._onEvent, onError: (Object e) => server._log('$e'));
    http.listen(server._handle, onError: (Object e) => server._log('$e'));
    return server;
  }

  int get port => _http.port;

  /// The address to open in a browser.
  String get url => 'http://127.0.0.1:$port';

  /// How many studio tabs are connected.
  int get studioCount => _studios.length;

  /// The diagnostics of the workspace as it is now.
  List<Diagnostic> get diagnostics => _state.diagnostics;

  Future<void> close() async {
    _debounceTimer?.cancel();
    await _watch?.cancel();
    for (final capture in _captures.values) {
      if (!capture.done.isCompleted) capture.done.completeError(const _RelayFailure(503, 'design serve stopped.'));
    }
    for (final studio in [..._studios]) {
      await studio.socket.close();
    }
    await _http.close(force: true);
  }

  // ------------------------------------------------------------- workspace

  _Snapshot _load() {
    final ws = DesignWorkspace.load(root);
    final requestsFile = File(p.join(root.path, 'requests.md'));
    final requests = requestsFile.existsSync() ? requestsFile.readAsStringSync() : null;
    final input = WorkspaceInput(ws.files, loadProblems: ws.loadProblems);
    return _Snapshot(ws.files, ws.loadProblems, requests, _validate(input));
  }

  /// The catalog the workspace validates against, parsed once per change of catalog.json.
  Catalog? _catalogOf(Map<String, Map<String, Object?>> files) {
    final json = files['catalog.json'];
    final text = json == null ? null : jsonEncode(json);
    if (text != _catalogText) {
      _catalogText = text;
      try {
        _catalog = json == null ? null : Catalog.fromJson(json);
      } on Object catch (e) {
        _log('catalog.json is not a catalog ($e).');
        _catalog = null;
      }
    }
    return _catalog;
  }

  List<Diagnostic> _validate(WorkspaceInput input) {
    final catalog = _catalogOf(input.files);
    return catalog == null ? sortDiagnostics([...input.loadProblems]) : validateWorkspace(input, catalog);
  }

  void _onEvent(FileSystemEvent event) {
    final rel = p.relative(event.path, from: root.path);
    if (rel.startsWith('..') || !_watched(p.posix.joinAll(p.split(rel)))) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, _reload);
  }

  static bool _watched(String rel) =>
      rel == 'design.json' ||
      rel == 'catalog.json' ||
      rel == 'requests.md' ||
      rel == 'tokens' ||
      rel == 'presets' ||
      rel == 'screens' ||
      rel.startsWith('tokens/') ||
      rel.startsWith('presets/') ||
      rel.startsWith('screens/');

  /// Reads the workspace again and pushes what changed to every studio tab.
  void _reload() {
    final before = _state;
    final after = _load();
    _state = after;
    final files = <String, Object?>{};
    for (final path in {...before.files.keys, ...after.files.keys}) {
      final a = before.files[path];
      final b = after.files[path];
      if (a == null && b == null) continue;
      if (a == null || b == null || jsonEncode(a) != jsonEncode(b)) files[path] = b;
    }
    final catalogChanged = files.containsKey('catalog.json');
    files.remove('catalog.json');
    final problemsChanged = jsonEncode(before.loadProblems) != jsonEncode(after.loadProblems);
    final requestsChanged = before.requests != after.requests;
    if (files.isEmpty && !catalogChanged && !problemsChanged && !requestsChanged) return;
    _broadcast({
      'type': 'changed',
      'files': files,
      'loadProblems': [for (final d in after.loadProblems) d.toJson()],
      'diagnostics': [for (final d in after.diagnostics) d.toJson()],
      if (requestsChanged) 'requests': after.requests,
      if (catalogChanged) 'catalog': after.files['catalog.json'],
    });
    final errors = after.diagnostics.where((d) => d.isError).length;
    final changedNames = [...files.keys, if (catalogChanged) 'catalog.json', if (requestsChanged) 'requests.md'];
    _log(
      '${changedNames.isEmpty ? 'A file' : changedNames.join(', ')} changed: '
      '${summaryLine(after.diagnostics)}${errors > 0 ? ' Run design validate for details.' : ''}',
    );
  }

  Map<String, Object?> _snapshotMessage() => {
    'type': 'snapshot',
    'name': _state.files['design.json']?['name'] ?? p.basename(root.path),
    'files': {
      for (final MapEntry(:key, :value) in _state.files.entries)
        if (key != 'catalog.json') key: value,
    },
    'loadProblems': [for (final d in _state.loadProblems) d.toJson()],
    'requests': _state.requests,
    'catalog': _state.files['catalog.json'],
    'diagnostics': [for (final d in _state.diagnostics) d.toJson()],
  };

  // ------------------------------------------------------------- HTTP

  Future<void> _handle(HttpRequest request) async {
    try {
      if (!_hostOk(request)) {
        return _text(request, HttpStatus.forbidden, 'design serve answers only on 127.0.0.1 and localhost.');
      }
      final path = request.uri.path;
      if (path == '/ws') return await _upgrade(request);
      if (path.startsWith('/api/')) {
        if (!_originOk(request)) {
          return _text(request, HttpStatus.forbidden, 'Only pages served from this machine may call design serve.');
        }
        return await _api(request, path.substring('/api/'.length));
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        return _text(request, HttpStatus.methodNotAllowed, 'Only GET is served here.');
      }
      await _static(request, path);
    } on Object catch (e) {
      _log('A request to ${request.uri} failed: $e');
      try {
        _text(request, HttpStatus.internalServerError, 'design serve failed: $e');
      } on Object {
        // The response was already sent.
      }
    }
  }

  static const _loopbackHosts = {'127.0.0.1', 'localhost', '::1', '[::1]'};

  /// Refuses requests for another host name, so a page cannot reach the server
  /// through DNS rebinding.
  bool _hostOk(HttpRequest request) {
    final host = request.headers.host;
    return host == null || _loopbackHosts.contains(host.toLowerCase());
  }

  /// Browsers send Origin on WebSocket and cross-site requests: only pages from
  /// this machine may connect, so another web site cannot drive the studio.
  bool _originOk(HttpRequest request) {
    final origin = request.headers.value('origin');
    if (origin == null) return true;
    final uri = Uri.tryParse(origin);
    return uri != null && _loopbackHosts.contains(uri.host.toLowerCase());
  }

  Future<void> _upgrade(HttpRequest request) async {
    if (!_originOk(request)) {
      return _text(request, HttpStatus.forbidden, 'Only pages served from this machine may connect.');
    }
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      return _text(request, HttpStatus.badRequest, '/ws is the studio WebSocket. Open $url in a browser.');
    }
    final socket = await WebSocketTransformer.upgrade(request);
    final client = _StudioClient(socket, ++_nextClient);
    _studios.add(client);
    _log('Studio tab ${client.number} connected (${_studios.length} open).');
    client.send(_snapshotMessage());
    socket.listen(
      (data) => _onStudioMessage(client, data),
      onDone: () => _disconnected(client),
      onError: (Object e) => _disconnected(client),
      cancelOnError: true,
    );
  }

  void _disconnected(_StudioClient client) {
    if (!_studios.remove(client)) return;
    _log('Studio tab ${client.number} disconnected (${_studios.length} open).');
    for (final MapEntry(key: id, value: capture) in [..._captures.entries]) {
      if (capture.client == client && !capture.done.isCompleted) {
        _captures.remove(id);
        capture.done.completeError(
          const _RelayFailure(HttpStatus.serviceUnavailable, 'The studio tab closed before it answered. Run it again.'),
        );
      }
    }
  }

  void _broadcast(Map<String, Object?> message) {
    for (final studio in _studios) {
      studio.send(message);
    }
  }

  void _onStudioMessage(_StudioClient client, Object? data) {
    final Object? message;
    try {
      message = data is String ? jsonDecode(data) : null;
    } on FormatException {
      return client.send({'type': 'error', 'message': 'Send JSON objects with a "type".'});
    }
    if (message is! Map<String, Object?>) {
      return client.send({'type': 'error', 'message': 'Send JSON objects with a "type".'});
    }
    switch (message['type']) {
      case 'captured':
        final capture = _captures.remove('${message['id']}');
        final png = message['png'];
        if (capture == null || capture.done.isCompleted) return;
        try {
          capture.done.complete(base64Decode(png is String ? png : ''));
        } on FormatException {
          capture.done.completeError(const _RelayFailure(HttpStatus.badGateway, 'The studio sent a broken image.'));
        }
      case 'captureFailed':
        final capture = _captures.remove('${message['id']}');
        if (capture == null || capture.done.isCompleted) return;
        capture.done.completeError(
          _RelayFailure(HttpStatus.unprocessableEntity, '${message['message'] ?? 'The studio could not draw it.'}'),
        );
      case 'write':
        client.send(_write(message['id'], message['path'], message['json']));
      case 'hello':
        break;
      default:
        client.send({
          'type': 'error',
          'message': "Unknown message type '${message['type']}'. The studio sends write, captured or captureFailed.",
        });
    }
  }

  static final _documentPath = RegExp(
    r'^(design\.json|tokens/tokens\.json|presets/[A-Z][A-Za-z0-9]*\.[a-z][A-Za-z0-9]*\.json|'
    r'screens/([a-z][A-Za-z0-9]*/)*[a-z][A-Za-z0-9]*\.json)$',
  );

  /// Writes [json] to [path] when it adds no error: the rule of `design patch`.
  Map<String, Object?> _write(Object? id, Object? path, Object? json) {
    Map<String, Object?> result(bool ok, String message, [List<Diagnostic> diagnostics = const []]) => {
      'type': 'writeResult',
      'id': ?id,
      'path': path,
      'ok': ok,
      'message': message,
      'diagnostics': [for (final d in diagnostics) d.toJson()],
    };
    if (path is! String || !_documentPath.hasMatch(path)) {
      return result(
        false,
        'Nothing written: $path is not a design document. Write design.json, tokens/tokens.json, '
        'presets/<Family.variant>.json or screens/<a>/<b>.json.',
      );
    }
    if (json is! Map<String, Object?>) return result(false, 'Nothing written: "json" must be a JSON object.');
    final catalog = _catalogOf(_state.files);
    if (catalog == null) {
      return result(false, 'Nothing written: the workspace has no readable catalog.json to check the edit against.');
    }
    final edited = canonicalDocument(json, path: path);
    final input = WorkspaceInput(_state.files, loadProblems: _state.loadProblems);
    String key(Diagnostic d) => '${d.code}|${d.file}|${d.node}|${d.message}';
    final before = _state.diagnostics.map(key).toSet();
    final after = validateWorkspace(input.withFile(path, edited), catalog);
    final added = [
      for (final d in after)
        if (d.isError && !before.contains(key(d))) d,
    ];
    if (added.isNotEmpty) {
      return result(
        false,
        'Nothing written: the edit adds ${added.length} error${added.length == 1 ? '' : 's'}. '
        'Change it so it adds none, then send it again.',
        added,
      );
    }
    final file = File(p.joinAll([root.path, ...p.posix.split(path)]));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(formatDocument(edited, path: path));
    _debounceTimer?.cancel();
    _reload();
    final left = after.where((d) => d.file == path).toList();
    return result(true, 'Wrote $path.${left.isEmpty ? '' : ' It still has ${summaryLine(left).toLowerCase()}'}', left);
  }

  Future<void> _api(HttpRequest request, String endpoint) async {
    if (endpoint == 'status' && request.method == 'GET') {
      return _json(request, HttpStatus.ok, {
        'workspace': root.path,
        'name': _state.files['design.json']?['name'],
        'studios': _studios.length,
        'studio': studioDir,
        'errors': _state.diagnostics.where((d) => d.isError).length,
        'warnings': _state.diagnostics.where((d) => !d.isError).length,
      });
    }
    if (request.method != 'POST' || (endpoint != 'capture' && endpoint != 'focus')) {
      return _text(
        request,
        HttpStatus.notFound,
        'design serve has GET /api/status, POST /api/capture and POST /api/focus.',
      );
    }
    final Object? body;
    try {
      body = jsonDecode(await utf8.decodeStream(request));
    } on FormatException {
      return _text(request, HttpStatus.badRequest, 'Send a JSON object.');
    }
    if (body is! Map<String, Object?>) return _text(request, HttpStatus.badRequest, 'Send a JSON object.');
    try {
      if (endpoint == 'focus') {
        final message = _focusMessage(body);
        if (_studios.isEmpty) throw _noStudio();
        _broadcast(message);
        final target = '${message['screen']}${message['node'] == null ? '' : '#${message['node']}'}';
        return _text(
          request,
          HttpStatus.ok,
          'The studio shows $target${_studios.length == 1 ? '' : ' in ${_studios.length} tabs'}.',
        );
      }
      final message = _captureMessage(body);
      if (_studios.isEmpty) throw _noStudio();
      final client = _studios.last;
      final id = 'c${++_nextId}';
      final done = Completer<List<int>>();
      _captures[id] = (client: client, done: done);
      client.send({...message, 'id': id});
      final png = await done.future.timeout(
        captureTimeout,
        onTimeout: () {
          _captures.remove(id);
          throw _RelayFailure(
            HttpStatus.gatewayTimeout,
            'The studio did not answer within ${captureTimeout.inSeconds} seconds. '
            'Check the studio tab is open and not in the background, then run it again.',
          );
        },
      );
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('image', 'png')
        ..add(png);
      await request.response.close();
    } on _RelayFailure catch (e) {
      _text(request, e.status, e.message);
    }
  }

  _RelayFailure _noStudio() => _RelayFailure(
    HttpStatus.serviceUnavailable,
    'design serve is running, but no studio tab is connected. Open $url in a browser, then run this again.',
  );

  /// The screen id in [body], after checking the workspace has it.
  String _screenOf(Map<String, Object?> body) {
    final screen = body['screen'];
    if (screen is! String || !isScreenId(screen)) {
      throw const _RelayFailure(HttpStatus.badRequest, 'Name a screen id, such as admin.automations.');
    }
    final path = WorkspaceInput.pathForScreenId(screen);
    if (_state.files.containsKey(path)) return screen;
    if (_state.loadProblems.any((d) => d.file == path)) {
      throw _RelayFailure(HttpStatus.unprocessableEntity, '$path does not read as JSON. Fix it first.');
    }
    final ids = _state.files.keys.where((k) => k.startsWith('screens/')).map(WorkspaceInput.screenIdForPath);
    final near = nearestName(screen, ids);
    throw _RelayFailure(
      HttpStatus.notFound,
      "No screen '$screen' in the workspace.${near == null ? '' : " Did you mean '$near'?"}",
    );
  }

  Map<String, Object?> _focusMessage(Map<String, Object?> body) {
    final screen = _screenOf(body);
    final node = body['node'];
    if (node != null && (node is! String || !isIdent(node))) {
      throw const _RelayFailure(HttpStatus.badRequest, 'A node id is lower camel, such as saveButton.');
    }
    return {'type': 'focus', 'screen': screen, 'node': ?node};
  }

  Map<String, Object?> _captureMessage(Map<String, Object?> body) {
    final screen = _screenOf(body);
    final fixture = body['fixture'];
    if (fixture != null) {
      final fixtures = _state.files[WorkspaceInput.pathForScreenId(screen)]?['fixtures'];
      final names = fixtures is Map<String, Object?> ? fixtures.keys.toList() : const <String>[];
      if (fixture is! String || !names.contains(fixture)) {
        throw _RelayFailure(
          HttpStatus.notFound,
          "$screen has no fixture '$fixture'. "
          '${names.isEmpty ? 'It has no fixtures.' : 'It has: ${names.join(', ')}.'}',
        );
      }
    }
    final mode = body['mode'];
    if (mode != null && mode != 'light' && mode != 'dark') {
      throw const _RelayFailure(HttpStatus.badRequest, 'mode is light or dark.');
    }
    int? size(String key) {
      final v = body[key];
      if (v == null) return null;
      if (v is! int || v < 1 || v > 8000) {
        throw _RelayFailure(HttpStatus.badRequest, '$key is a whole number of pixels from 1 to 8000.');
      }
      return v;
    }

    return {
      'type': 'capture',
      'screen': screen,
      'fixture': ?fixture,
      'mode': ?mode,
      'width': ?size('width'),
      'height': ?size('height'),
    };
  }

  // ------------------------------------------------------------- files

  static const _types = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.mjs': 'text/javascript; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.json': 'application/json',
    '.wasm': 'application/wasm',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.ttf': 'font/ttf',
    '.otf': 'font/otf',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
    '.txt': 'text/plain; charset=utf-8',
    '.map': 'application/json',
  };

  Future<void> _static(HttpRequest request, String path) async {
    final dir = studioDir;
    if (dir == null) {
      if (path == '/' || path == '/index.html') {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write(_noStudioPage());
        return request.response.close();
      }
      return _text(request, HttpStatus.notFound, 'No studio is served. Open $url for how to build one.');
    }
    final segments = Uri.decodeFull(path).split('/').where((s) => s.isNotEmpty).toList();
    var file = File(p.joinAll([dir, ...segments]));
    if (segments.any((s) => s == '..' || s.contains(r'\')) || !p.isWithin(dir, file.path) && segments.isNotEmpty) {
      return _text(request, HttpStatus.notFound, 'Not found.');
    }
    if (segments.isEmpty || !file.existsSync() && !_types.containsKey(p.extension(file.path).toLowerCase())) {
      file = File(p.join(dir, 'index.html'));
    }
    if (!file.existsSync()) return _text(request, HttpStatus.notFound, 'Not found: $path');
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.set(
        HttpHeaders.contentTypeHeader,
        _types[p.extension(file.path).toLowerCase()] ?? 'application/octet-stream',
      )
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    if (request.method == 'HEAD') return request.response.close();
    await request.response.addStream(file.openRead());
    await request.response.close();
  }

  String _noStudioPage() {
    String e(String s) => const HtmlEscape().convert(s);
    return '''
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>design serve</title>
<style>body{font:15px/1.5 system-ui,sans-serif;max-width:46em;margin:3em auto;padding:0 1em}code,pre{background:#f2f4f7;padding:.1em .3em;border-radius:4px}pre{padding:.8em}</style>
</head><body>
<h1>design serve</h1>
<p>Serving the workspace <code>${e(root.path)}</code>: ${e(summaryLine(_state.diagnostics))}
${_studios.length} studio tab${_studios.length == 1 ? '' : 's'} connected.</p>
<p>No studio is being served. Build the design studio once, then serve it with the workspace:</p>
<pre>cd &lt;app repo&gt;/packages/design_studio
flutter build web
design serve --studio &lt;app repo&gt;/packages/design_studio/build/web</pre>
<p>Or set <code>DESIGN_STUDIO_DIR</code> to that folder and run <code>design serve</code>.</p>
<p>The studio connects to <code>ws://127.0.0.1:$port/ws</code>.</p>
</body></html>
''';
  }

  void _text(HttpRequest request, int status, String message) {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.text
      ..write(message.endsWith('\n') ? message : '$message\n');
    unawaited(request.response.close());
  }

  void _json(HttpRequest request, int status, Object? json) {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(json));
    unawaited(request.response.close());
  }
}

final class _Snapshot {
  final Map<String, Map<String, Object?>> files;
  final List<Diagnostic> loadProblems;
  final String? requests;
  final List<Diagnostic> diagnostics;
  const _Snapshot(this.files, this.loadProblems, this.requests, this.diagnostics);
}

final class _StudioClient {
  final WebSocket socket;
  final int number;
  _StudioClient(this.socket, this.number);

  void send(Map<String, Object?> message) {
    if (socket.readyState == WebSocket.open) socket.add(jsonEncode(message));
  }
}

/// A relay request that cannot be answered: the HTTP status and what to do.
final class _RelayFailure implements Exception {
  final int status;
  final String message;
  const _RelayFailure(this.status, this.message);
}
