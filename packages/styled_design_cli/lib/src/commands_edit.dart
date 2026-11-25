import 'dart:convert';

import 'package:styled_design_core/io.dart';
import 'package:styled_design_core/styled_design_core.dart';

import 'context.dart';

/// Shared by `patch` and `link`: applies [ops] to the screen at [path],
/// validates the workspace with the result, and writes the canonical file
/// only when the edit adds no error.
int applyScreenEdit(DesignCommand cmd, DesignWorkspace ws, Catalog catalog, String path, Object? ops) {
  final out = cmd.out;
  final json = ws.files[path]!;
  final result = applyPatch(json, ops, screenId: WorkspaceInput.screenIdForPath(path));
  if (!result.ok) {
    for (final d in result.diagnostics) {
      out.writeln(diagnosticLine(d));
    }
    out.writeln('Nothing written. Fix the operations above and send them again.');
    return 1;
  }
  final edited = canonicalDocument(result.json!, path: path);
  final input = ws.toInput();
  String key(Diagnostic d) => '${d.code}|${d.file}|${d.node}|${d.message}';
  final before = validateWorkspace(input, catalog).map(key).toSet();
  final after = validateWorkspace(input.withFile(path, edited), catalog);
  final added = [
    for (final d in after)
      if (d.isError && !before.contains(key(d))) d,
  ];
  if (added.isNotEmpty) {
    out.writeln('Nothing written: the edit adds ${added.length} error${added.length == 1 ? '' : 's'}:');
    for (final d in added) {
      out.writeln(diagnosticLine(d));
    }
    out.writeln('Change the edit so it adds none, then send it again.');
    return 1;
  }
  cmd.writeDocument(path, edited);
  final left = after.where((d) => d.file == path).toList();
  out.writeln(
    'Wrote $path.${left.isEmpty ? '' : ' It now has ${summaryLine(left).toLowerCase()} Run design validate $path.'}',
  );
  return 0;
}

/// `design patch <screen> --ops '<json list>'`.
class PatchCommand extends DesignCommand {
  @override
  final name = 'patch';
  @override
  final description = 'Apply structural edits by node id; refused when they add an error.';
  @override
  String get invocation => "design patch <screen> --ops '<json list>'";

  PatchCommand(super.ctx) {
    argParser.addOption(
      'ops',
      help: 'A JSON list of operations: insert, remove, move, setProp, setEvent, setWhen, wrap.',
      valueHelp: 'json',
    );
  }

  @override
  int run() {
    final ref = rest(min: 1, max: 1, usage: "Name one screen: design patch admin.automations --ops '[...]'.").single;
    final text = argResults!['ops'] as String?;
    if (text == null) {
      usageException(
        'Give the edits as --ops \'[{"op": "setProp", "node": "<id>", "prop": "<name>", "value": ...}]\'.',
      );
    }
    final Object? ops;
    try {
      ops = jsonDecode(text);
    } on FormatException catch (e) {
      usageException('--ops is not valid JSON: ${e.message}. Quote it with single quotes in the shell.');
    }
    final ws = loadWorkspace();
    final catalog = loadCatalog(ws);
    final (path, _) = screenJson(ws, ref);
    return applyScreenEdit(this, ws, catalog, path, ops);
  }
}

final _linkSpec = RegExp(r'^([a-z][A-Za-z0-9]*(?:\.[a-z][A-Za-z0-9]*)*)#([a-z][A-Za-z0-9]*)\.([a-z][A-Za-z0-9]*)$');

/// `design link <screen>#<node>.<event> --to <screen> [--mode] [--param k=v]`.
class LinkCommand extends DesignCommand {
  @override
  final name = 'link';
  @override
  final description = 'Append a navigate action to a node\'s event.';
  @override
  String get invocation =>
      'design link <screen>#<node>.<event> --to <screen> [--mode push|replaceAll|replace] [--param k=v ...]';

  LinkCommand(super.ctx) {
    argParser
      ..addOption('to', help: 'The page to go to.')
      ..addOption('mode', allowed: ['push', 'replaceAll', 'replace'], help: 'Default push; replaceAll in a frame.')
      ..addMultiOption('param', help: 'A route param: k=v. A value starting with a root (row., data., event.) binds.');
  }

  @override
  int run() {
    final spec = rest(
      min: 1,
      max: 1,
      usage: 'Name one event: design link admin.users#table.rowTap --to admin.user.',
    ).single;
    final m = _linkSpec.firstMatch(spec);
    if (m == null) usageException("'$spec' is not <screen>#<node>.<event>, such as admin.users#table.rowTap.");
    final to = argResults!['to'] as String?;
    if (to == null || !isScreenId(to)) usageException('Name the page to go to: --to <screen id>.');
    final ws = loadWorkspace();
    final catalog = loadCatalog(ws);
    final (path, json) = screenJson(ws, m[1]!);
    final nodeId = m[2]!;
    final event = m[3]!;

    // Roots a param value may start with: the standard ones, and every
    // repeat or template variable this screen can introduce.
    final roots = {'data', 'state', 'params', 'query', 'event', 'page'};
    forEachNodeJson(json['root'], (n) {
      if (n['repeat'] case {'as': final String variable}) roots.add(variable);
      if (n['repeat'] case {'index': final String index}) roots.add(index);
      final comp = n['type'] is String ? catalog.components[Catalog.splitType(n['type']! as String).$1] : null;
      for (final slot in comp?.slots ?? const <DesignSlot>[]) {
        if (slot.template case final t?) roots.add(t);
      }
    });
    final params = <String, Object?>{};
    for (final pair in argResults!['param'] as List<String>) {
      final eq = pair.indexOf('=');
      if (eq <= 0) usageException("--param '$pair' is not k=v.");
      final k = pair.substring(0, eq);
      final v = pair.substring(eq + 1);
      final root = v.split('.').first;
      final isPath = RegExp(r'^[a-z][A-Za-z0-9]*(\.([A-Za-z_][A-Za-z0-9_]*|[0-9]+))*$').hasMatch(v);
      params[k] = isPath && roots.contains(root) && (v.contains('.') || v == root) ? {r'$bind': v} : v;
    }

    Map<String, Object?>? node;
    forEachNodeJson(json['root'], (n) {
      if (n['id'] == nodeId) node ??= n;
    });
    final existing = switch (node?['on']) {
      final Map<String, Object?> on => on[event],
      _ => null,
    };
    final mode = argResults!['mode'] as String? ?? (json['kind'] == 'frame' ? 'replaceAll' : 'push');
    final action = {
      'do': 'navigate',
      'to': to,
      if (mode != 'push') 'mode': mode,
      if (params.isNotEmpty) 'params': params,
    };
    final ops = [
      {
        'op': 'setEvent',
        'node': nodeId,
        'event': event,
        'actions': [if (existing is List<Object?>) ...existing, action],
      },
    ];
    return applyScreenEdit(this, ws, catalog, path, ops);
  }
}
