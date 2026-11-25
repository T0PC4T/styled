import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:styled_design_core/io.dart';

import 'agents_md.dart';
import 'context.dart';

/// Runs one `design` command in-process: the same entry point as the executable.
typedef DesignRun = Future<int> Function(List<String> args, {StringSink? out, StringSink? err, String? cwd});

/// One MCP tool: a `design` command with its arguments mapped. There is one
/// code path: every tool runs the command's own code, so a tool and the
/// command it names behave, validate and write identically.
final class McpTool {
  final String name;
  final String description;
  final Map<String, Object?> inputSchema;

  /// The command line for the given arguments, without `--workspace`.
  final List<String> Function(Map<String, Object?> args) command;

  /// Whether the tool writes files (for clients that care).
  final bool writes;

  const McpTool(this.name, this.description, this.inputSchema, this.command, {this.writes = false});
}

Map<String, Object?> _object(Map<String, Object?> properties, {List<String> required = const []}) => {
  'type': 'object',
  'properties': properties,
  if (required.isNotEmpty) 'required': required,
  'additionalProperties': false,
};

const _string = {'type': 'string'};
String _s(Map<String, Object?> a, String k) => '${a[k] ?? ''}';

/// The design tools: blueprint section 10's list, plus `guide`, `screen_new` and `contract`.
final List<McpTool> designTools = [
  McpTool(
    'catalog_search',
    'Search the catalog (components, presets, tokens, icons, formatters) by words. Returns JSON.',
    _object({
      'query': {'type': 'string', 'description': 'Words that must all match, such as "table row".'},
      'kind': {
        'type': 'string',
        'enum': ['component', 'token', 'preset', 'icon', 'formatter'],
      },
    }),
    (a) => [
      'catalog',
      if (_s(a, 'query').trim().isNotEmpty) ..._s(a, 'query').trim().split(RegExp(r'\s+')),
      if (a['kind'] != null) ...['--kind', _s(a, 'kind')],
      '--json',
    ],
  ),
  McpTool(
    'catalog_get',
    'One component in full: its constructors, props (kinds, defaults, allowed values), slots, events, rules and an example node. Returns JSON.',
    _object(
      {
        'name': {'type': 'string', 'description': 'The exact component name, such as OnboardingDataTable.'},
      },
      required: ['name'],
    ),
    (a) => ['catalog', _s(a, 'name'), '--json'],
  ),
  McpTool(
    'screen_list',
    'Every screen: id, kind, title, route and frame. Returns JSON.',
    _object({}),
    (a) => ['screens', '--json'],
  ),
  McpTool(
    'screen_read',
    "A screen's whole document, as canonical JSON.",
    _object({'screen': _string}, required: ['screen']),
    (a) => ['show', _s(a, 'screen')],
  ),
  McpTool(
    'screen_new',
    'Create a screen from a template (list, detail, formModal, dashboard, frame). A page joins the only frame, or the one named.',
    _object(
      {
        'screen': {'type': 'string', 'description': 'The new id, dotted lower camel: admin.users.'},
        'template': {
          'type': 'string',
          'enum': ['list', 'detail', 'formModal', 'dashboard', 'frame'],
        },
        'title': _string,
        'frame': _string,
      },
      required: ['screen', 'template'],
    ),
    (a) => [
      'new',
      'screen',
      _s(a, 'screen'),
      '--from',
      _s(a, 'template'),
      if (a['title'] != null) ...['--title', _s(a, 'title')],
      if (a['frame'] != null) ...['--frame', _s(a, 'frame')],
    ],
    writes: true,
  ),
  McpTool(
    'screen_write',
    'Write a whole screen document (create or replace). Refused, writing nothing, when it adds an error.',
    _object(
      {
        'screen': _string,
        'document': {'type': 'object', 'description': 'The whole screen document.'},
      },
      required: ['screen', 'document'],
    ),
    (a) => ['write', _s(a, 'screen'), '--json', jsonEncode(a['document'])],
    writes: true,
  ),
  McpTool(
    'screen_patch',
    'Structural edits by node id: insert, remove, move, setProp, setEvent, setWhen, wrap. Refused, writing nothing, when they add an error.',
    _object(
      {
        'screen': _string,
        'ops': {
          'type': 'array',
          'items': {'type': 'object'},
          'description': 'Operations, such as {"op": "setProp", "node": "title", "prop": "title", "value": "Users"}.',
        },
      },
      required: ['screen', 'ops'],
    ),
    (a) => ['patch', _s(a, 'screen'), '--ops', jsonEncode(a['ops'])],
    writes: true,
  ),
  McpTool(
    'link',
    "Add a navigate action to a node's event: from is screen#node.event.",
    _object(
      {
        'from': {'type': 'string', 'description': 'screen#node.event, such as admin.users#table.rowTap.'},
        'to': _string,
        'mode': {
          'type': 'string',
          'enum': ['push', 'replaceAll', 'replace'],
        },
        'params': {
          'type': 'object',
          'description': 'Route params: a value starting with a root (row., data., event.) binds.',
          'additionalProperties': {'type': 'string'},
        },
      },
      required: ['from', 'to'],
    ),
    (a) => [
      'link',
      _s(a, 'from'),
      '--to',
      _s(a, 'to'),
      if (a['mode'] != null) ...['--mode', _s(a, 'mode')],
      for (final MapEntry(:key, :value) in ((a['params'] as Map<String, Object?>?) ?? const {}).entries) ...[
        '--param',
        '$key=$value',
      ],
    ],
    writes: true,
  ),
  McpTool(
    'validate',
    'Check every document; every problem with its file, pointer, node and a hint. Returns JSON.',
    _object({
      'strict': {'type': 'boolean', 'description': 'Warnings fail too. Finished means strict is clean.'},
    }),
    (a) => ['validate', '--json', if (a['strict'] == true) '--strict'],
  ),
  McpTool(
    'describe',
    'The screen as it resolves against a fixture: each node, its props after bindings, what is hidden, where events lead.',
    _object({'screen': _string, 'fixture': _string}, required: ['screen']),
    (a) => [
      'describe',
      _s(a, 'screen'),
      if (a['fixture'] != null) ...['--fixture', _s(a, 'fixture')],
    ],
  ),
  McpTool(
    'screenshot',
    'A PNG of the screen drawn by a connected studio tab (needs design serve and an open studio).',
    _object(
      {
        'screen': _string,
        'fixture': _string,
        'mode': {
          'type': 'string',
          'enum': ['light', 'dark'],
        },
        'size': {'type': 'string', 'description': 'WIDTHxHEIGHT, such as 1440x900 or 390x844.'},
      },
      required: ['screen'],
    ),
    (a) => [
      'screenshot',
      _s(a, 'screen'),
      if (a['fixture'] != null) ...['--fixture', _s(a, 'fixture')],
      if (a['mode'] != null) ...['--mode', _s(a, 'mode')],
      if (a['size'] != null) ...['--size', _s(a, 'size')],
    ],
  ),
  McpTool(
    'flow',
    'Which event on which node leads to which screen. Returns JSON.',
    _object({}),
    (a) => ['flow', '--json'],
  ),
  McpTool(
    'contract',
    "What the app must supply for a screen: data keys and kinds, modal data, emits and the route. Returns JSON.",
    _object({'screen': _string}, required: ['screen']),
    (a) => ['contract', _s(a, 'screen'), '--json'],
  ),
  McpTool(
    'token_set',
    'Set a token value for a mode (light by default); a new token needs its type.',
    _object(
      {
        'key': _string,
        'value': {'description': 'The value in token JSON form: #RRGGBB, a number, whole milliseconds, w600, text.'},
        'mode': _string,
        'type': {
          'type': 'string',
          'enum': ['color', 'double', 'duration', 'fontWeight', 'string', 'shadow'],
        },
      },
      required: ['key', 'value'],
    ),
    (a) => [
      'token',
      'set',
      _s(a, 'key'),
      '--value',
      a['value'] is String ? a['value']! as String : jsonEncode(a['value']),
      if (a['mode'] != null) ...['--mode', _s(a, 'mode')],
      if (a['type'] != null) ...['--type', _s(a, 'type')],
    ],
    writes: true,
  ),
  McpTool(
    'preset_write',
    'Write a designer preset (a new variant of an existing family). Refused when it adds an error.',
    _object(
      {
        'id': {'type': 'string', 'description': 'Family.variant, such as StyleCard.highlight.'},
        'document': {'type': 'object', 'description': 'The preset document: {"extends": ..., "style": {...}}.'},
      },
      required: ['id', 'document'],
    ),
    (a) => ['preset', 'write', _s(a, 'id'), '--json', jsonEncode(a['document'])],
    writes: true,
  ),
  McpTool(
    'request',
    'Record something the catalog lacks (a component, prop, token or icon) for the developer. Build with what exists meanwhile.',
    _object(
      {
        'need': {'type': 'string', 'description': 'What is missing and why.'},
      },
      required: ['need'],
    ),
    (a) => ['request', _s(a, 'need')],
    writes: true,
  ),
];

/// The design tools over the Model Context Protocol: JSON-RPC 2.0, one
/// message per line, on stdin and stdout.
final class DesignMcpServer {
  /// The workspace folder every tool works in.
  final String workspace;
  final DesignRun run;
  final List<McpTool> tools;

  static const supportedVersions = ['2025-06-18', '2025-03-26', '2024-11-05'];

  DesignMcpServer({required this.workspace, required this.run, List<McpTool>? tools}) : tools = tools ?? designTools;

  /// Serves [lines] until they end, sending each response through [send].
  Future<void> serve(Stream<String> lines, void Function(String line) send) async {
    await for (final line in lines) {
      if (line.trim().isEmpty) continue;
      Object? message;
      try {
        message = jsonDecode(line);
      } on FormatException catch (e) {
        send(jsonEncode(_error(null, -32700, 'Parse error: ${e.message}')));
        continue;
      }
      if (message is List<Object?>) {
        final replies = [for (final m in message) ?await handle(m)];
        if (replies.isNotEmpty) send(jsonEncode(replies));
      } else if (await handle(message) case final reply?) {
        send(jsonEncode(reply));
      }
    }
  }

  /// The response to one message, or null for a notification.
  Future<Map<String, Object?>?> handle(Object? message) async {
    if (message is! Map<String, Object?>) return _error(null, -32600, 'Invalid request: not an object.');
    final id = message['id'];
    final method = message['method'];
    final params = (message['params'] as Map<String, Object?>?) ?? const {};
    if (method is! String) return id == null ? null : _error(id, -32600, 'Invalid request: no method.');
    if (id == null) return null; // notifications/initialized and friends
    switch (method) {
      case 'initialize':
        final asked = params['protocolVersion'];
        return _result(id, {
          'protocolVersion': supportedVersions.contains(asked) ? asked : supportedVersions.first,
          'capabilities': {
            'tools': {'listChanged': false},
          },
          'serverInfo': {'name': 'design', 'version': '0.1.0'},
          'instructions':
              'Design tools for the workspace at $workspace. Call guide first: it explains the loop, the naming '
              'rules and every diagnostic code. You are finished when validate with strict: true reports no problems.',
        });
      case 'ping':
        return _result(id, const {});
      case 'tools/list':
        return _result(id, {
          'tools': [
            {
              'name': 'guide',
              'description':
                  'How to work in this design workspace: the loop, the rules, the naming, every code. Read it first.',
              'inputSchema': _object({}),
            },
            for (final t in tools)
              {
                'name': t.name,
                'description': t.description,
                'inputSchema': t.inputSchema,
                'annotations': {'readOnlyHint': !t.writes},
              },
          ],
        });
      case 'tools/call':
        final name = params['name'];
        final args = (params['arguments'] as Map<String, Object?>?) ?? const {};
        if (name == 'guide') return _result(id, _text(_guide()));
        final tool = tools.where((t) => t.name == name).firstOrNull;
        if (tool == null) {
          return _error(id, -32602, "Unknown tool '$name'. Call tools/list for the names.");
        }
        return _result(id, await _call(tool, args));
      default:
        return _error(id, -32601, "Method '$method' not found.");
    }
  }

  Future<Map<String, Object?>> _call(McpTool tool, Map<String, Object?> args) async {
    final List<String> command;
    try {
      command = tool.command(args);
    } on Object catch (e) {
      return {..._text('The arguments do not fit ${tool.name}: $e'), 'isError': true};
    }
    Directory? temp;
    final extra = <String>[];
    if (tool.name == 'screenshot') {
      temp = Directory.systemTemp.createTempSync('design_mcp_');
      extra.addAll(['--out', p.join(temp.path, 'screenshot.png')]);
    }
    final out = StringBuffer();
    final err = StringBuffer();
    try {
      final code = await run(['--workspace', workspace, ...command, ...extra], out: out, err: err, cwd: workspace);
      final text = [out.toString().trimRight(), err.toString().trimRight()].where((s) => s.isNotEmpty).join('\n');
      final content = <Map<String, Object?>>[
        {'type': 'text', 'text': text.isEmpty ? (code == 0 ? 'Done.' : 'Failed.') : text},
      ];
      if (temp != null && code == 0) {
        final png = File(p.join(temp.path, 'screenshot.png'));
        if (png.existsSync()) {
          content.add({'type': 'image', 'data': base64Encode(png.readAsBytesSync()), 'mimeType': 'image/png'});
        }
      }
      return {'content': content, 'isError': code != 0};
    } finally {
      temp?.deleteSync(recursive: true);
    }
  }

  String _guide() {
    final file = File(p.join(workspace, 'AGENTS.md'));
    if (file.existsSync()) return file.readAsStringSync();
    final ws = DesignWorkspace.load(Directory(workspace));
    return agentsMd(name: ws.manifest?.name ?? p.basename(workspace), catalog: ws.catalog);
  }

  static Map<String, Object?> _text(String text) => {
    'content': [
      {'type': 'text', 'text': text},
    ],
  };

  static Map<String, Object?> _result(Object? id, Object? result) => {'jsonrpc': '2.0', 'id': id, 'result': result};

  static Map<String, Object?> _error(Object? id, int code, String message) => {
    'jsonrpc': '2.0',
    'id': id,
    'error': {'code': code, 'message': message},
  };
}

/// `design mcp`: the design tools as an MCP server on stdio.
class McpCommand extends DesignCommand {
  @override
  final name = 'mcp';
  @override
  final description = 'Serve the design tools over the Model Context Protocol on stdin/stdout.';
  @override
  String get invocation => 'design mcp [--workspace <dir>]';

  final DesignRun designRun;

  McpCommand(super.ctx, this.designRun);

  @override
  Future<int> run() async {
    rest(max: 0, usage: 'design mcp takes no arguments; pass --workspace before it.');
    loadWorkspace(); // fail now, with a clear message, when there is no workspace
    final server = DesignMcpServer(workspace: workspaceDir, run: designRun);
    await server.serve(stdin.transform(utf8.decoder).transform(const LineSplitter()), (line) => stdout.writeln(line));
    return 0;
  }
}
