import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:styled_design_core/io.dart';
import 'package:styled_design_core/styled_design_core.dart';

/// A command failed for a reason the user can fix; [message] says how.
class CliFailure implements Exception {
  final String message;
  final int exitCode;
  const CliFailure(this.message, {this.exitCode = 1});

  @override
  String toString() => message;
}

/// Where a command runs: the workspace folder, the output sinks and the clock.
final class CliContext {
  final String cwd;
  final StringSink out;
  final StringSink err;
  final DateTime Function() now;

  CliContext({required this.cwd, required this.out, required this.err, required this.now});

  /// [path] resolved against the current directory.
  String resolve(String path) => p.normalize(p.isAbsolute(path) ? path : p.join(cwd, path));
}

/// The base of every `design` command: the context, and the workspace the
/// global `--workspace` option names.
abstract class DesignCommand extends Command<int> {
  final CliContext ctx;
  DesignCommand(this.ctx);

  StringSink get out => ctx.out;

  /// The workspace folder: `--workspace`, or the current directory.
  String get workspaceDir => ctx.resolve(globalResults?['workspace'] as String? ?? '.');

  /// The rest arguments, after checking there are between [min] and [max].
  List<String> rest({int min = 0, int? max, required String usage}) {
    final args = argResults!.rest;
    if (args.length < min || (max != null && args.length > max)) usageException(usage);
    return args;
  }

  /// The workspace, or a failure saying how to get one.
  DesignWorkspace loadWorkspace() {
    final dir = Directory(workspaceDir);
    if (!File(p.join(dir.path, 'design.json')).existsSync()) {
      throw CliFailure(
        'No design.json in ${dir.path}. Run design init --catalog <path to catalog.json>, '
        'or pass --workspace <dir>.',
      );
    }
    return DesignWorkspace.load(dir);
  }

  /// The workspace's catalog.json, or a failure saying how to get one.
  Catalog loadCatalog(DesignWorkspace ws) {
    final problem = ws.loadProblems.where((d) => d.file == 'catalog.json').firstOrNull;
    if (problem != null) {
      throw CliFailure('catalog.json does not read: ${problem.message} Copy it again from the library.');
    }
    final json = ws.files['catalog.json'];
    if (json == null) {
      throw CliFailure(
        'No catalog.json in ${ws.root.path}. Copy the library\'s catalog.json there '
        '(design init --catalog <path> does it for a new workspace).',
      );
    }
    try {
      return Catalog.fromJson(json);
    } on Object catch (e) {
      throw CliFailure('catalog.json is not a catalog ($e). Copy it again from the library.');
    }
  }

  /// The workspace-relative path of screen [ref]: an id (`admin.automations`)
  /// or a path (`screens/admin/automations.json`).
  String screenPath(String ref) {
    if (ref.endsWith('.json')) {
      final abs = ctx.resolve(ref);
      final rel = p.isWithin(workspaceDir, abs) ? p.relative(abs, from: workspaceDir) : ref;
      return p.posix.joinAll(p.split(rel));
    }
    if (!isScreenId(ref)) {
      throw UsageException("'$ref' is not a screen id or path. Write admin.automations.", usage);
    }
    return WorkspaceInput.pathForScreenId(ref);
  }

  /// The JSON of screen [ref] in [ws], or a failure naming the screens there are.
  (String, Map<String, Object?>) screenJson(DesignWorkspace ws, String ref) {
    final path = screenPath(ref);
    final json = ws.files[path];
    if (json != null) return (path, json);
    final broken = ws.loadProblems.where((d) => d.file == path).firstOrNull;
    if (broken != null) throw CliFailure('$path does not read: ${broken.message} Fix the JSON first.');
    final ids = ws.screenFiles.keys.map(WorkspaceInput.screenIdForPath);
    final near = nearestName(WorkspaceInput.screenIdForPath(path), ids);
    throw CliFailure(
      'No screen at $path.${near == null ? '' : " Did you mean '$near'?"} '
      'Create one with design new screen <id> --from <template>.',
    );
  }

  /// The parsed screen [ref], or a failure listing why it does not parse.
  ScreenDoc parseScreen(DesignWorkspace ws, String ref) {
    final (path, json) = screenJson(ws, ref);
    final (doc, problems) = parseScreenSafely(json, file: path);
    if (doc == null) {
      throw CliFailure(
        '$path does not parse:\n${problems.where((d) => d.isError).map(diagnosticLine).join('\n')}\n'
        'Fix these, then run the command again.',
      );
    }
    return doc;
  }

  /// Writes [text] to the workspace-relative [path], creating folders.
  void writeFile(String path, String text) {
    final file = File(p.join(workspaceDir, path));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(text);
  }

  /// Writes a design document in canonical form.
  void writeDocument(String path, Map<String, Object?> json) => writeFile(path, formatDocument(json, path: path));

  bool exists(String path) => File(p.join(workspaceDir, path)).existsSync();

  /// Prints [diagnostics] one per line, then a summary line.
  void printDiagnostics(List<Diagnostic> diagnostics) {
    for (final d in diagnostics) {
      out.writeln(diagnosticLine(d));
    }
    out.writeln(summaryLine(diagnostics));
  }
}

/// One diagnostic on one line: severity, code, file and pointer, node,
/// message, then hint and allowed values.
String diagnosticLine(Diagnostic d) {
  final where = [?d.file, if (d.pointer != null) (d.pointer!.isEmpty ? '/' : d.pointer!)].join(' ');
  final extra = [?d.hint, if (d.allowed != null) 'allowed: ${d.allowed!.join(', ')}'].join(' ');
  return '${d.severity.name} ${d.code} ${where.isEmpty ? '' : '$where '}'
      '${d.node == null ? '' : '[${d.node}] '}${d.message}${extra.isEmpty ? '' : ' ($extra)'}';
}

String summaryLine(List<Diagnostic> diagnostics) {
  final errors = diagnostics.where((d) => d.isError).length;
  final warnings = diagnostics.length - errors;
  if (diagnostics.isEmpty) return 'No problems.';
  String n(int count, String word) => '$count $word${count == 1 ? '' : 's'}';
  return '${n(errors, 'error')}, ${n(warnings, 'warning')}.';
}

/// Pretty JSON with a trailing newline.
String prettyJson(Object? json) => '${const JsonEncoder.withIndent('  ').convert(json)}\n';
