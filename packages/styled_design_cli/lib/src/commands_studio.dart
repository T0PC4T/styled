import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:styled_design_core/styled_design_core.dart';

import 'context.dart';
import 'serve.dart';

/// Adds `--port` to a command's options.
void _addPort(DesignCommand command) => command.argParser.addOption(
  'port',
  defaultsTo: '$defaultStudioPort',
  help: 'The port design serve listens on.',
  valueHelp: 'n',
);

int _port(DesignCommand command) {
  final text = command.argResults!['port'] as String;
  final port = int.tryParse(text);
  if (port == null || port < 0 || port > 65535) command.usageException('--port must be a number from 0 to 65535.');
  return port;
}

/// `design serve [--port 4400] [--studio <dir>]`.
class ServeCommand extends DesignCommand {
  @override
  final name = 'serve';
  @override
  final description = 'Serve the studio and push every saved change to it, live.';
  @override
  String get invocation => 'design serve [--port $defaultStudioPort] [--studio <dir>]';

  /// Completes to stop the server; Ctrl-C when null.
  final Future<void>? stop;

  ServeCommand(super.ctx, {this.stop}) {
    _addPort(this);
    argParser.addOption(
      'studio',
      help: "The studio's built web files (flutter build web in design_studio). Default: \$DESIGN_STUDIO_DIR.",
      valueHelp: 'dir',
    );
  }

  @override
  Future<int> run() async {
    rest(max: 0, usage: 'design serve takes no arguments: design serve --port 4400 --studio <dir>.');
    final port = _port(this);
    loadWorkspace();
    final studioArg = argResults!['studio'] as String? ?? Platform.environment['DESIGN_STUDIO_DIR'];
    final studio = studioArg == null || studioArg.isEmpty ? null : ctx.resolve(studioArg);
    if (studio != null && !File(p.join(studio, 'index.html')).existsSync()) {
      throw CliFailure(
        'No index.html in $studio. Build the studio with flutter build web in packages/design_studio, '
        'then pass --studio <that package>/build/web.',
      );
    }
    final DesignServer server;
    try {
      server = await DesignServer.start(
        workspaceDir: workspaceDir,
        port: port,
        studioDir: studio,
        log: (line) => out.writeln(line),
      );
    } on SocketException catch (e) {
      throw CliFailure(
        'Cannot listen on port $port (${e.osError?.message ?? e.message}). '
        'Stop the other design serve, or pass --port <another port>.',
      );
    }
    out
      ..writeln('Serving ${server.root.path} at ${server.url}: ${summaryLine(server.diagnostics)}')
      ..writeln(
        studio == null
            ? 'No studio given: ${server.url} says how to build one. Pass --studio <dir> or set DESIGN_STUDIO_DIR.'
            : 'Open ${server.url} in a browser. Every save shows there.',
      )
      ..writeln('Then design screenshot <screen> or design focus <screen> talk to that tab. Ctrl-C stops.');
    await (stop ?? _interrupted());
    await server.close();
    out.writeln('Stopped.');
    return 0;
  }

  static Future<void> _interrupted() {
    final done = Completer<void>();
    final subscriptions = <StreamSubscription<ProcessSignal>>[];
    void finish(ProcessSignal _) {
      for (final s in subscriptions) {
        unawaited(s.cancel());
      }
      if (!done.isCompleted) done.complete();
    }

    subscriptions.add(ProcessSignal.sigint.watch().listen(finish));
    if (!Platform.isWindows) subscriptions.add(ProcessSignal.sigterm.watch().listen(finish));
    return done.future;
  }
}

/// Sends a relay request to a running `design serve` and returns the response.
Future<(int, List<int>)> _relay(int port, String endpoint, Map<String, Object?> body) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.post(InternetAddress.loopbackIPv4.address, port, '/api/$endpoint');
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close().timeout(captureTimeout + const Duration(seconds: 10));
    final bytes = await response.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
    return (response.statusCode, bytes);
  } on SocketException {
    throw CliFailure(
      'No design serve answers on port $port. Start one in the workspace with design serve, '
      'open it in a browser, then run this again${port == defaultStudioPort ? '' : ' with --port $port'}.',
    );
  } on TimeoutException {
    throw const CliFailure('design serve did not answer in time. Check the studio tab is open, then run it again.');
  } finally {
    client.close(force: true);
  }
}

final _sizePattern = RegExp(r'^(\d{1,4})x(\d{1,4})$');

/// `design screenshot <screen> [--fixture f] [--mode light|dark] [--size WxH] [--out file.png]`.
class ScreenshotCommand extends DesignCommand {
  @override
  final name = 'screenshot';
  @override
  final description = 'Save a PNG of a screen, drawn by the studio tab of a running design serve.';
  @override
  String get invocation =>
      'design screenshot <screen> [--fixture <name>] [--mode light|dark] [--size 1440x900] [--out <file.png>]';

  ScreenshotCommand(super.ctx) {
    argParser
      ..addOption('fixture', help: 'The fixture to draw it with (default: default).', valueHelp: 'name')
      ..addOption('mode', allowed: ['light', 'dark'], defaultsTo: 'light', help: 'The theme mode.')
      ..addOption('size', defaultsTo: '1440x900', help: 'Width x height in pixels.', valueHelp: 'WxH')
      ..addOption('out', help: 'The PNG to write (default: <screen>[-<fixture>][-dark].png).', valueHelp: 'file');
    _addPort(this);
  }

  @override
  Future<int> run() async {
    final screen = rest(min: 1, max: 1, usage: 'Name one screen: design screenshot admin.automations.').single;
    if (!isScreenId(screen)) usageException("'$screen' is not a screen id. Write admin.automations.");
    final fixture = argResults!['fixture'] as String?;
    final mode = argResults!['mode'] as String;
    final size = _sizePattern.firstMatch(argResults!['size'] as String);
    final width = size == null ? 0 : int.parse(size[1]!);
    final height = size == null ? 0 : int.parse(size[2]!);
    if (width < 1 || height < 1) usageException('--size is width x height in pixels, such as 1440x900 or 390x844.');
    final port = _port(this);
    final outArg = argResults!['out'] as String? ?? '${[screen, ?fixture, if (mode == 'dark') 'dark'].join('-')}.png';
    final target = ctx.resolve(outArg);

    final (status, bytes) = await _relay(port, 'capture', {
      'screen': screen,
      'fixture': ?fixture,
      'mode': mode,
      'width': width,
      'height': height,
    });
    if (status != HttpStatus.ok) throw CliFailure(utf8.decode(bytes, allowMalformed: true).trim());
    final dims = pngSize(bytes);
    if (dims == null) throw const CliFailure('The studio sent something that is not a PNG. Reload the studio tab.');
    File(target)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    out.writeln(
      'Wrote ${p.isWithin(ctx.cwd, target) ? p.relative(target, from: ctx.cwd) : target} '
      '(${dims.$1}x${dims.$2}, $mode, fixture ${fixture ?? 'default'}).',
    );
    return 0;
  }
}

/// The width and height of a PNG, or null when [bytes] is not one.
(int, int)? pngSize(List<int> bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < 24) return null;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return null;
  }
  int word(int at) => bytes[at] << 24 | bytes[at + 1] << 16 | bytes[at + 2] << 8 | bytes[at + 3];
  return (word(16), word(20));
}

final _focusPattern = RegExp(r'^([a-z][A-Za-z0-9]*(?:\.[a-z][A-Za-z0-9]*)*)(?:#([a-z][A-Za-z0-9]*))?$');

/// `design focus <screen>[#node]`.
class FocusCommand extends DesignCommand {
  @override
  final name = 'focus';
  @override
  final description = 'Show a screen, and point at one of its nodes, in the studio tab of design serve.';
  @override
  String get invocation => 'design focus <screen>[#<node>]';

  FocusCommand(super.ctx) {
    _addPort(this);
  }

  @override
  Future<int> run() async {
    final spec = rest(min: 1, max: 1, usage: 'Name one screen: design focus admin.automations#saveButton.').single;
    final m = _focusPattern.firstMatch(spec);
    if (m == null) usageException("'$spec' is not <screen>[#<node>], such as admin.automations#saveButton.");
    final (status, bytes) = await _relay(_port(this), 'focus', {'screen': m[1], 'node': ?m[2]});
    final text = utf8.decode(bytes, allowMalformed: true).trim();
    if (status != HttpStatus.ok) throw CliFailure(text);
    out.writeln(text);
    return 0;
  }
}
