import 'dart:convert';

import 'package:styled_design_core/styled_design_core.dart';

import 'context.dart';

/// `design screens [--json]`: every screen, with its kind, title and route.
class ScreensCommand extends DesignCommand {
  @override
  final name = 'screens';
  @override
  final description = 'List the screens: id, kind, title and route.';
  @override
  String get invocation => 'design screens [--json]';

  ScreensCommand(super.ctx) {
    argParser.addFlag('json', negatable: false, help: 'Print [{"id", "kind", "title", "route", "frame", "path"}].');
  }

  @override
  int run() {
    rest(max: 0, usage: 'design screens takes no arguments.');
    final ws = loadWorkspace();
    final rows = <Map<String, Object?>>[];
    for (final MapEntry(key: path, value: json) in ws.screenFiles.entries) {
      rows.add({
        'id': json['id'] ?? WorkspaceInput.screenIdForPath(path),
        'kind': json['kind'],
        'title': json['title'],
        'route': ?json['route'],
        'frame': ?json['frame'],
        'path': path,
      });
    }
    rows.sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
    if (argResults!['json'] as bool) {
      out.write(prettyJson(rows));
    } else if (rows.isEmpty) {
      out.writeln('No screens yet. Start one with design new screen <id> --from list.');
    } else {
      for (final r in rows) {
        out.writeln(
          '${'${r['id']}'.padRight(32)} ${'${r['kind']}'.padRight(6)} ${r['title']}${r['route'] == null ? '' : '  ${r['route']}'}',
        );
      }
    }
    return 0;
  }
}

/// `design show <screen>`: the screen's document, as canonical JSON.
class ShowCommand extends DesignCommand {
  @override
  final name = 'show';
  @override
  final description = "Print a screen's document as canonical JSON.";
  @override
  String get invocation => 'design show <screen>';

  ShowCommand(super.ctx);

  @override
  int run() {
    final ref = rest(min: 1, max: 1, usage: 'Name one screen: design show admin.automations.').single;
    final ws = loadWorkspace();
    final (path, json) = screenJson(ws, ref);
    out.write(formatDocument(json, path: path));
    return 0;
  }
}

/// `design write <screen> --json '<document>'`: replaces or creates a screen
/// document, refused when it adds an error (the rule `design patch` follows).
class WriteCommand extends DesignCommand {
  @override
  final name = 'write';
  @override
  final description = 'Write a whole screen document; refused when it adds an error.';
  @override
  String get invocation => "design write <screen> --json '<screen document>'";

  WriteCommand(super.ctx) {
    argParser.addOption('json', help: 'The whole screen document.', valueHelp: 'json');
  }

  @override
  int run() {
    final ref = rest(min: 1, max: 1, usage: "Name one screen: design write admin.users --json '{...}'.").single;
    final text = argResults!['json'] as String?;
    if (text == null) usageException("Give the document as --json '{...}'.");
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      usageException('--json is not valid JSON: ${e.message}.');
    }
    if (decoded is! Map<String, Object?>) usageException('--json must be one JSON object: the screen document.');
    final ws = loadWorkspace();
    final catalog = loadCatalog(ws);
    final path = screenPath(ref);
    final id = WorkspaceInput.screenIdForPath(path);
    if (decoded['id'] != null && decoded['id'] != id) {
      throw CliFailure("The document's id is '${decoded['id']}' but it is written to $path, which spells '$id'.");
    }
    final document = canonicalDocument({...decoded, 'id': id}, path: path);
    final input = ws.toInput();
    String key(Diagnostic d) => '${d.code}|${d.file}|${d.node}|${d.message}';
    final before = validateWorkspace(input, catalog).map(key).toSet();
    final after = validateWorkspace(input.withFile(path, document), catalog);
    final added = [
      for (final d in after)
        if (d.isError && !before.contains(key(d))) d,
    ];
    if (added.isNotEmpty) {
      out.writeln('Nothing written: the document adds ${added.length} error${added.length == 1 ? '' : 's'}:');
      for (final d in added) {
        out.writeln(diagnosticLine(d));
      }
      out.writeln('Fix them and write it again.');
      return 1;
    }
    final existed = exists(path);
    writeDocument(path, document);
    final left = after.where((d) => d.file == path).toList();
    out.writeln(
      '${existed ? 'Wrote' : 'Created'} $path.'
      '${left.isEmpty ? '' : ' It now has ${summaryLine(left).toLowerCase()} Run design validate $path.'}',
    );
    return 0;
  }
}
