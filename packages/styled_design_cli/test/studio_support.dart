import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:styled_design_cli/styled_design_cli.dart';

/// A 1x1 PNG.
const onePixelPng = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

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
