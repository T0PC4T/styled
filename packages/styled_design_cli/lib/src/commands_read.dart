import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:styled_design_core/styled_design_core.dart';

import 'context.dart';

const _kinds = ['component', 'token', 'preset', 'icon', 'formatter'];

/// `design catalog [query] [--kind ...] [--json]`.
class CatalogCommand extends DesignCommand {
  @override
  final name = 'catalog';
  @override
  final description =
      'Search components, tokens, presets, icons and formatters; an exact component name prints it in full.';
  @override
  String get invocation => 'design catalog [words] [--kind component|token|preset|icon|formatter] [--json]';

  CatalogCommand(super.ctx) {
    argParser
      ..addOption('kind', allowed: _kinds, help: 'Search only this kind.')
      ..addFlag('json', negatable: false, help: 'Print JSON.');
  }

  @override
  int run() {
    final query = rest(usage: 'design catalog [words]').join(' ').trim();
    final kind = argResults!['kind'] as String?;
    final json = argResults!['json'] as bool;
    final catalog = loadCatalog(loadWorkspace());

    final exact = catalog.components[query];
    if (exact != null && (kind == null || kind == 'component')) {
      if (json) {
        out.write(prettyJson({...exact.toJson(), 'example': exampleNode(exact, catalog)}));
      } else {
        out.write(describeComponent(exact, catalog));
      }
      return 0;
    }

    // Every word must appear in one of an entry's texts.
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    bool hit(Iterable<String?> texts) {
      final lower = [for (final t in texts) ?t?.toLowerCase()];
      return words.every((w) => lower.any((t) => t.contains(w)));
    }

    bool wants(String k) => kind == null || kind == k;

    final components = [
      if (wants('component'))
        for (final c in catalog.components.values)
          if (hit([c.type, c.summary, c.category, ...c.props.map((p) => p.doc)])) c,
    ];
    final tokens = [
      if (wants('token'))
        for (final t in catalog.tokens.values)
          if (hit([t.key, t.type, t.doc, t.group])) t,
    ];
    final presets = [
      if (wants('preset'))
        for (final f in catalog.presets.values)
          if (hit([f.name, f.doc, ...f.variants, ...f.variants.map((v) => '${f.name}.$v')])) f,
    ];
    final icons = [
      if (wants('icon'))
        for (final i in catalog.icons)
          if (hit([i])) i,
    ];
    final formatters = [
      if (wants('formatter'))
        for (final f in catalog.formatters)
          if (hit([f])) f,
    ];

    if (json) {
      out.write(
        prettyJson({
          if (wants('component')) 'components': {for (final c in components) c.type: c.summary},
          if (wants('token')) 'tokens': {for (final t in tokens) t.key: t.toJson()},
          if (wants('preset')) 'presets': {for (final f in presets) f.name: f.toJson()},
          if (wants('icon')) 'icons': icons,
          if (wants('formatter')) 'formatters': formatters,
        }),
      );
      return 0;
    }
    final total = components.length + tokens.length + presets.length + icons.length + formatters.length;
    if (total == 0) {
      out.writeln(
        "Nothing in the catalog matches '$query'. Try other words, or design request \"<what you need>\" "
        'and build the closest thing with what exists.',
      );
      return 0;
    }
    if (components.isNotEmpty) {
      out.writeln('components:');
      for (final c in components) {
        out.writeln('  ${c.type.padRight(28)} ${c.kind == DesignKind.value ? '(value) ' : ''}${c.summary}');
      }
    }
    if (presets.isNotEmpty) {
      out.writeln('presets:');
      for (final f in presets) {
        out.writeln('  ${f.name.padRight(28)} ${f.variants.join(', ')}');
      }
    }
    if (tokens.isNotEmpty) {
      out.writeln('tokens:');
      for (final t in tokens) {
        out.writeln(
          '  ${t.key.padRight(28)} ${t.type.padRight(10)} ${jsonEncode(t.light)}${t.doc == null ? '' : '  ${t.doc}'}',
        );
      }
    }
    if (icons.isNotEmpty) out.writeln('icons: ${icons.join(', ')}');
    if (formatters.isNotEmpty) out.writeln('formatters: ${formatters.join(', ')}');
    if (components.length == 1 && query.isNotEmpty) {
      out.writeln('Run design catalog ${components.single.type} for its props.');
    }
    return 0;
  }
}

/// One component in full, for `design catalog <Component>`.
String describeComponent(DesignComponent c, Catalog catalog) {
  final b = StringBuffer()
    ..writeln('${c.type} (${c.kind.name}, ${c.category})')
    ..writeln('  ${c.summary}');
  final types = [if (c.hasDefaultConstructor) c.type, for (final k in c.constructors) '${c.type}.$k'];
  b.writeln('  type: ${types.join(', ')}');
  if (c.props.isNotEmpty) {
    b.writeln('props:');
    for (final prop in c.props) {
      final parts = [
        prop.kind.name,
        if (prop.required) 'required',
        if (prop.defaultValue != null) 'default ${jsonEncode(prop.defaultValue)}',
        if (prop.values.isNotEmpty) 'values: ${prop.values.join(', ')}',
        if (prop.kind == PropKind.style) 'families: ${prop.families.isEmpty ? 'any' : prop.families.join(', ')}',
        if (prop.tokenType != null) 'token type: ${prop.tokenType}',
        if (!prop.bindable) 'literal only',
      ];
      b.writeln('  ${prop.name.padRight(22)} ${parts.join('  ')}${prop.doc == null ? '' : '  — ${prop.doc}'}');
    }
  }
  if (c.slots.isNotEmpty) {
    b.writeln('slots:');
    for (final slot in c.slots) {
      final parts = [
        slotAcceptsText(slot),
        if (slot.many) 'many' else 'single',
        if (slot.required) 'required',
        if (slot.template != null) 'template: adds ${slot.template}',
      ];
      b.writeln('  ${slot.name.padRight(22)} ${parts.join('  ')}${slot.doc == null ? '' : '  — ${slot.doc}'}');
    }
  }
  if (c.events.isNotEmpty) {
    b.writeln('events:');
    for (final e in c.events) {
      final payload = e.payload.isEmpty
          ? ''
          : 'event: ${e.payload.entries.map((x) => '${x.key} ${x.value}').join(', ')}';
      b.writeln(
        '  ${e.name.padRight(22)} ${[if (e.primary) 'primary', if (payload.isNotEmpty) payload].join('  ')}'
        '${e.doc == null ? '' : '  — ${e.doc}'}',
      );
    }
  }
  if (c.rules.isNotEmpty) {
    b.writeln('rules:');
    for (final r in c.rules) {
      b.writeln(
        '  ${r.code}: ${r.message ?? '${r.rule} ${r.types.join(', ')}${r.props.isEmpty ? '' : ' ${jsonEncode(r.props)}'}'}',
      );
    }
  }
  b
    ..writeln('example:')
    ..writeln(
      const JsonEncoder.withIndent('  ').convert(exampleNode(c, catalog)).split('\n').map((l) => '  $l').join('\n'),
    );
  return b.toString();
}

/// `design validate [paths...] [--json] [--strict]`.
class ValidateCommand extends DesignCommand {
  @override
  final name = 'validate';
  @override
  final description = 'Check every document against the catalog and report every problem.';
  @override
  String get invocation => 'design validate [paths...] [--json] [--strict]';

  ValidateCommand(super.ctx) {
    argParser
      ..addFlag('json', negatable: false, help: 'Print {"diagnostics": [...], "errors": n, "warnings": n}.')
      ..addFlag('strict', negatable: false, help: 'Warnings fail too (exit 1).');
  }

  @override
  int run() {
    final ws = loadWorkspace();
    final catalog = loadCatalog(ws);
    final strict = argResults!['strict'] as bool;
    var diagnostics = validateWorkspace(ws.toInput(), catalog, strict: strict);
    final filters = [for (final arg in argResults!.rest) _filterPath(arg)];
    final known = {...ws.files.keys, for (final d in ws.loadProblems) ?d.file};
    for (final f in filters) {
      if (!known.any((k) => k == f || k.startsWith('$f/'))) {
        throw CliFailure(
          'No design document at $f. Name a file or folder of the workspace (screens/admin/users.json, screens/admin) '
          'or a screen id, or run design validate with no paths.',
        );
      }
    }
    if (filters.isNotEmpty) {
      diagnostics = [
        for (final d in diagnostics)
          if (d.file != null && filters.any((f) => d.file == f || d.file!.startsWith('$f/'))) d,
      ];
    }
    final errors = diagnostics.where((d) => d.isError).length;
    final warnings = diagnostics.length - errors;
    if (argResults!['json'] as bool) {
      out.write(
        prettyJson({
          'diagnostics': [for (final d in diagnostics) d.toJson()],
          'errors': errors,
          'warnings': warnings,
        }),
      );
    } else {
      printDiagnostics(diagnostics);
    }
    return diagnosticsFail(diagnostics, strict: strict) ? 1 : 0;
  }

  /// A filter argument as a workspace-relative path: a file, a folder, or a screen id.
  String _filterPath(String arg) {
    if (!arg.contains('/') && !arg.endsWith('.json') && isScreenId(arg) && arg.contains('.')) {
      return WorkspaceInput.pathForScreenId(arg);
    }
    final abs = ctx.resolve(arg);
    final rel = p.isWithin(workspaceDir, abs) ? p.relative(abs, from: workspaceDir) : arg;
    final posix = p.posix.joinAll(p.split(rel));
    return posix.endsWith('/') ? posix.substring(0, posix.length - 1) : posix;
  }
}

/// `design describe <screen> [--fixture name]`.
class DescribeCommand extends DesignCommand {
  @override
  final name = 'describe';
  @override
  final description = 'Print the resolved tree of a screen against a fixture, as text.';
  @override
  String get invocation => 'design describe <screen> [--fixture <name>]';

  DescribeCommand(super.ctx) {
    argParser.addOption('fixture', defaultsTo: 'default', help: 'The fixture to resolve against.');
  }

  @override
  int run() {
    final ref = rest(min: 1, max: 1, usage: 'Name one screen: design describe admin.automations.').single;
    final ws = loadWorkspace();
    final catalog = loadCatalog(ws);
    final screen = parseScreen(ws, ref);
    final fixture = argResults!['fixture'] as String;
    if (fixture != 'default' && !screen.fixtures.containsKey(fixture)) {
      throw CliFailure(
        "${screen.id} has no fixture '$fixture'. Its fixtures: ${['default', ...screen.fixtures.keys.where((k) => k != 'default')].join(', ')}.",
      );
    }
    out.write(describeScreen(screen, catalog, fixture: fixture));
    return 0;
  }
}

/// `design flow [--json|--mermaid]`.
class FlowCommand extends DesignCommand {
  @override
  final name = 'flow';
  @override
  final description = 'Print which event on which node leads to which screen.';
  @override
  String get invocation => 'design flow [--json|--mermaid]';

  FlowCommand(super.ctx) {
    argParser
      ..addFlag('json', negatable: false, help: 'Print JSON.')
      ..addFlag('mermaid', negatable: false, help: 'Print a Mermaid flowchart.');
  }

  @override
  int run() {
    final ws = loadWorkspace();
    final flow = buildFlow(parseScreens(ws.toInput()).values);
    if (argResults!['json'] as bool) {
      out.write(prettyJson(flow.toJson()));
    } else if (argResults!['mermaid'] as bool) {
      out.write(flow.toMermaid());
    } else {
      out.write(flow.toText());
    }
    return 0;
  }
}

/// `design contract <screen> [--json]`.
class ContractCommand extends DesignCommand {
  @override
  final name = 'contract';
  @override
  final description = 'Print what the app must supply for a screen: route, params, data, events, modals.';
  @override
  String get invocation => 'design contract <screen> [--json]';

  ContractCommand(super.ctx) {
    argParser.addFlag('json', negatable: false, help: 'Print JSON.');
  }

  @override
  int run() {
    final ref = rest(min: 1, max: 1, usage: 'Name one screen: design contract admin.automations.').single;
    final ws = loadWorkspace();
    final screen = parseScreen(ws, ref);
    final contract = screenContract(screen, screens: parseScreens(ws.toInput()));
    out.write(argResults!['json'] as bool ? prettyJson(contract.toJson()) : contract.toText());
    return 0;
  }
}

/// `design fmt [--check]`.
class FmtCommand extends DesignCommand {
  @override
  final name = 'fmt';
  @override
  final description = 'Rewrite every document in canonical form (key order, indent, node ids).';
  @override
  String get invocation => 'design fmt [--check]';

  FmtCommand(super.ctx) {
    argParser.addFlag('check', negatable: false, help: 'Write nothing; list the files that would change (exit 1).');
  }

  @override
  int run() {
    final ws = loadWorkspace();
    final check = argResults!['check'] as bool;
    final unreadable = ws.loadProblems.where((d) => d.file != 'catalog.json').toList();
    for (final d in unreadable) {
      out.writeln(diagnosticLine(d));
    }
    final changed = <String>[];
    for (final path in ws.files.keys.where((k) => k != 'catalog.json').toList()..sort()) {
      final file = File(p.join(workspaceDir, path));
      final text = formatDocument(ws.files[path]!, path: path);
      if (file.readAsStringSync() == text) continue;
      changed.add(path);
      if (!check) file.writeAsStringSync(text);
    }
    if (check) {
      for (final path in changed) {
        out.writeln('would change: $path');
      }
      out.writeln(
        changed.isEmpty ? 'Every document is canonical.' : 'Run design fmt to rewrite ${changed.length} file(s).',
      );
      return changed.isEmpty && unreadable.isEmpty ? 0 : 1;
    }
    for (final path in changed) {
      out.writeln('formatted: $path');
    }
    out.writeln(changed.isEmpty ? 'Every document was already canonical.' : 'Formatted ${changed.length} file(s).');
    if (unreadable.isNotEmpty) out.writeln('Fix the JSON of the files above, then run design fmt again.');
    return unreadable.isEmpty ? 0 : 1;
  }
}

/// `design export [--out path]`.
class ExportCommand extends DesignCommand {
  @override
  final name = 'export';
  @override
  final description = 'Validate strictly, then write the bundle the app ships.';
  @override
  String get invocation => 'design export [--out <path>]';

  ExportCommand(super.ctx) {
    argParser.addOption('out', help: 'Where to write the bundle (default: design.json export.bundle).');
  }

  @override
  int run() {
    final ws = loadWorkspace();
    final catalog = loadCatalog(ws);
    final result = buildBundle(ws.toInput(), catalog);
    if (!result.ok) {
      printDiagnostics(result.diagnostics);
      out.writeln('Export refused: it is strict, so every error and warning must be fixed first.');
      return 1;
    }
    final outArg = argResults!['out'] as String?;
    final target = outArg != null
        ? ctx.resolve(outArg)
        : p.normalize(p.join(workspaceDir, ws.manifest?.exportBundle ?? 'bundle.json'));
    final file = File(target);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(result.text!);
    out.writeln('Wrote ${p.relative(target, from: ctx.cwd)} (${result.bundle!['hash']}).');
    return 0;
  }
}
