import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:styled_design_core/styled_design_core.dart';

import 'agents_md.dart';
import 'context.dart';
import 'templates.dart';

/// `design init [dir] --catalog <path>`.
class InitCommand extends DesignCommand {
  @override
  final name = 'init';
  @override
  final description = 'Create a design workspace: design.json, tokens, presets, screens, templates, AGENTS.md.';
  @override
  String get invocation => 'design init [dir] --catalog <path to catalog.json>';

  InitCommand(super.ctx) {
    argParser.addOption('catalog', help: "The library's catalog.json, copied into the workspace.", valueHelp: 'path');
  }

  @override
  int run() {
    final args = rest(max: 1, usage: 'Give at most one folder: design init [dir] --catalog <path>.');
    final dir = args.isEmpty ? workspaceDir : ctx.resolve(args.single);
    final catalogPath = argResults!['catalog'] as String?;
    if (catalogPath == null) usageException("design init needs --catalog <path to the library's catalog.json>.");
    final catalogFile = File(ctx.resolve(catalogPath));
    if (!catalogFile.existsSync()) {
      throw CliFailure('No catalog at ${catalogFile.path}. Pass the library\'s catalog.json.');
    }
    final catalogText = catalogFile.readAsStringSync();
    final Catalog catalog;
    try {
      catalog = Catalog.fromJson(jsonDecode(catalogText) as Map<String, Object?>);
    } on Object catch (e) {
      throw CliFailure('${catalogFile.path} is not a catalog ($e). Pass the catalog.json the library build writes.');
    }
    if (File(p.join(dir, 'design.json')).existsSync()) {
      throw CliFailure('$dir already holds a workspace (design.json exists). Work in it, or pick another folder.');
    }
    final screens = Directory(p.join(dir, 'screens'));
    final pages = <String>[
      if (screens.existsSync())
        for (final f in screens.listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.json') && _kindOf(f) == 'page')
            WorkspaceInput.screenIdForPath(p.posix.joinAll(p.split(p.relative(f.path, from: dir)))),
    ]..sort();
    final name = p.basename(p.normalize(dir));
    final written = <String>[];
    void write(String path, String text) {
      final file = File(p.join(dir, path));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(text);
      written.add(path);
    }

    write(
      'design.json',
      formatDocument({
        'format': 1,
        'name': name,
        'start': pages.firstOrNull ?? '',
        'catalog': {'version': catalog.version, 'hash': ?catalog.hash},
        'export': {'bundle': 'bundle.json', 'fixtures': 'none'},
      }),
    );
    if (!File(p.join(dir, 'tokens', 'tokens.json')).existsSync()) {
      write('tokens/tokens.json', formatDocument({'format': 1, 'tokens': <String, Object?>{}}));
    }
    for (final folder in const ['presets', 'screens']) {
      Directory(p.join(dir, folder)).createSync(recursive: true);
    }
    for (final MapEntry(key: template, value: (_, text)) in screenTemplates.entries) {
      write('templates/$template.json', '${text.trim()}\n');
    }
    if (!File(p.join(dir, 'requests.md')).existsSync()) write('requests.md', _requestsHeader);
    write('catalog.json', catalogText);
    write('AGENTS.md', agentsMd(name: name, catalog: catalog));
    out
      ..writeln('Created the workspace $name in $dir:')
      ..writeln(written.map((f) => '  $f').join('\n'))
      ..writeln('Next: read AGENTS.md, then design new screen <id> --from list.');
    return 0;
  }

  static String? _kindOf(File f) {
    try {
      final json = jsonDecode(f.readAsStringSync());
      return json is Map ? json['kind'] as String? : null;
    } on Object {
      return null;
    }
  }
}

const _requestsHeader = '''
# Requests

Needs the catalog does not meet yet: a component, prop, token or icon. Add one with
`design request "<what and why>"`; the library team reads this file.

''';

/// `design request "<need>"`.
class RequestCommand extends DesignCommand {
  @override
  final name = 'request';
  @override
  final description = 'Note a need the catalog does not meet, in requests.md.';
  @override
  String get invocation => 'design request "<what you need and why>"';

  RequestCommand(super.ctx);

  @override
  int run() {
    final need = rest(min: 1, usage: 'Say what you need: design request "<what and why>".').join(' ').trim();
    if (need.isEmpty) usageException('Say what you need: design request "<what and why>".');
    loadWorkspace();
    final file = File(p.join(workspaceDir, 'requests.md'));
    final now = ctx.now();
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    var text = file.existsSync() ? file.readAsStringSync() : _requestsHeader;
    if (!text.endsWith('\n')) text += '\n';
    file.writeAsStringSync('$text- $date: ${need.replaceAll('\n', ' ')}\n');
    out.writeln('Added to requests.md. Build the closest thing with what the catalog has meanwhile.');
    return 0;
  }
}

/// `design new screen|preset|token`.
class NewCommand extends DesignCommand {
  @override
  final name = 'new';
  @override
  final description = 'Create a screen from a template, a preset variant, or a token.';

  NewCommand(super.ctx) {
    addSubcommand(NewScreenCommand(ctx));
    addSubcommand(NewPresetCommand(ctx));
    addSubcommand(NewTokenCommand(ctx));
  }
}

/// `design new screen <id> --from <template>`.
class NewScreenCommand extends DesignCommand {
  @override
  final name = 'screen';
  @override
  final description = 'Create a screen from a template: list, detail, formModal, dashboard or frame.';
  @override
  String get invocation => 'design new screen <id> --from <template>';

  NewScreenCommand(super.ctx) {
    argParser
      ..addOption('from', help: 'The template.', valueHelp: screenTemplates.keys.join('|'))
      ..addOption('title', help: 'The screen title (default: from the id).')
      ..addOption(
        'frame',
        help: 'For a page: the frame it is previewed in (default: the only frame, when there is one).',
        valueHelp: 'frames.admin',
      );
  }

  @override
  int run() {
    final id = rest(min: 1, max: 1, usage: 'Give one screen id: design new screen admin.users --from list.').single;
    if (!isScreenId(id)) usageException("'$id' is not a screen id. Write dotted lower camel: admin.users.");
    final from = argResults!['from'] as String?;
    if (from == null) usageException('Pick a template with --from ${screenTemplates.keys.join('|')}.');
    final ws = loadWorkspace();
    final custom = File(p.join(workspaceDir, 'templates', '$from.json'));
    final text = custom.existsSync() ? custom.readAsStringSync() : screenTemplates[from]?.$2;
    if (text == null) {
      final near = nearestName(from, screenTemplates.keys);
      usageException(
        "There is no template '$from'.${near == null ? '' : " Did you mean '$near'?"} "
        'Use one of ${screenTemplates.keys.join(', ')}, or add templates/$from.json.',
      );
    }
    final path = WorkspaceInput.pathForScreenId(id);
    if (exists(path)) throw CliFailure('$path already exists. Edit it, or pick another id.');
    final Map<String, Object?> json;
    try {
      json = fillTemplate(text, id: id, title: argResults!['title'] as String? ?? titleFromId(id));
    } on FormatException catch (e) {
      throw CliFailure('templates/$from.json is not valid JSON (${e.message}). Fix the template.');
    }
    if (json['kind'] == 'page' && !json.containsKey('frame')) {
      final frames = [
        for (final MapEntry(key: framePath, value: doc) in ws.toInput().screenFiles.entries)
          if (doc['kind'] == 'frame') (doc['id'] as String?) ?? WorkspaceInput.screenIdForPath(framePath),
      ];
      final asked = argResults!['frame'] as String?;
      if (asked != null) {
        if (!frames.contains(asked)) {
          throw CliFailure(
            "There is no frame '$asked'. Frames in this workspace: ${frames.isEmpty ? 'none' : frames.join(', ')}.",
          );
        }
        json['frame'] = asked;
      } else if (frames.length == 1) {
        json['frame'] = frames.single;
      }
      if (json.containsKey('frame')) {
        out.writeln('It is previewed in ${json['frame']}. Add a link to it there, such as a sidebar button.');
      } else if (frames.length > 1) {
        out.writeln(
          'Pick the frame it is previewed in with --frame (${frames.join(', ')}), or set "frame" in the file.',
        );
      }
    }
    writeDocument(path, json);
    out.writeln('Created $path from the $from template.');

    final manifest = ws.manifestJson;
    if (manifest != null && (manifest['start'] ?? '') == '' && json['kind'] == 'page') {
      writeDocument('design.json', {...manifest, 'start': id});
      out.writeln('Set start in design.json to $id.');
    }
    final catalog = ws.files['catalog.json'] == null ? null : loadCatalog(ws);
    if (catalog != null) {
      final input = ws.toInput().withFile(path, json);
      final found = validateWorkspace(input, catalog).where((d) => d.file == path && d.code != 'W-unreachable');
      if (found.isNotEmpty) printDiagnostics(found.toList());
    }
    out.writeln('Next: write its default fixture, edit the tree, then design validate.');
    return 0;
  }
}

final _presetId = RegExp(r'^Style[A-Z][A-Za-z0-9]*\.[a-z][A-Za-z0-9]*$');

/// `design new preset <Family.variant> --extends <Family.base>`.
class NewPresetCommand extends DesignCommand {
  @override
  final name = 'preset';
  @override
  final description = 'Create a designer preset: a new variant of a family, extending one of its variants.';
  @override
  String get invocation => 'design new preset <Family.variant> --extends <Family.base> [--style <json>]';

  NewPresetCommand(super.ctx) {
    argParser
      ..addOption('extends', help: 'The variant it builds on, such as StyleCard.surface.')
      ..addOption('style', help: 'The style delta as JSON (default: empty, to fill in).')
      ..addOption('description', help: 'What it is for.');
  }

  @override
  int run() {
    final id = rest(
      min: 1,
      max: 1,
      usage: 'Give one preset id: design new preset StyleCard.highlight --extends StyleCard.surface.',
    ).single;
    if (!_presetId.hasMatch(id)) usageException("'$id' is not a preset id. Write Family.variant: StyleCard.highlight.");
    final base = argResults!['extends'] as String?;
    if (base == null || !_presetId.hasMatch(base)) {
      usageException('Name the variant it builds on: --extends ${id.split('.').first}.<variant>.');
    }
    Object? style = <String, Object?>{};
    if (argResults!['style'] case final String text) {
      try {
        style = jsonDecode(text);
      } on FormatException catch (e) {
        usageException('--style is not valid JSON: ${e.message}.');
      }
    }
    final ws = loadWorkspace();
    final catalog = loadCatalog(ws);
    final (family, variant) = Catalog.splitPreset(id)!;
    final def = catalog.presets[family];
    if (def == null) {
      final near = nearestName(family, catalog.presets.keys);
      throw CliFailure(
        "There is no preset family '$family'.${near == null ? '' : " Did you mean '$near'?"} "
        'Search with design catalog <words> --kind preset.',
      );
    }
    if (def.variants.contains(variant)) {
      throw CliFailure("$id is a built-in variant. Pick a new variant name, such as '$family.${variant}Custom'.");
    }
    final path = WorkspaceInput.pathForPresetId(id);
    if (exists(path)) throw CliFailure('$path already exists. Edit it, or pick another id.');
    final json = <String, Object?>{
      'format': 1,
      'id': id,
      'extends': base,
      if (argResults!['description'] case final String d) 'description': d,
      'style': style,
    };
    writeDocument(path, json);
    out.writeln('Created $path.');
    final found = validateWorkspace(
      ws.toInput().withFile(path, json),
      catalog,
    ).where((d) => d.file == path && d.code != 'W-preset-unused').toList();
    if (found.isNotEmpty) printDiagnostics(found);
    out.writeln(
      'Next: fill in style with token keys (box, flex, text, icon, image, states), '
      'reference it as "style": "$id", then design validate.',
    );
    return 0;
  }
}

/// `design new token <key> --type <t> --light <v>`.
class NewTokenCommand extends DesignCommand {
  @override
  final name = 'token';
  @override
  final description = 'Add a new token to tokens/tokens.json.';
  @override
  String get invocation => 'design new token <key> --type <type> --light <value>';

  NewTokenCommand(super.ctx) {
    argParser
      ..addOption('type', allowed: tokenTypes, help: 'The token type.')
      ..addOption('light', help: 'The light value: #RRGGBB, a number, whole ms, w100..w900, text, or shadow JSON.')
      ..addOption('description', help: 'What it is for.');
  }

  @override
  int run() {
    final key = rest(
      min: 1,
      max: 1,
      usage: 'Give one token key: design new token accentSubtle --type color --light "#FFF7D6".',
    ).single;
    if (!tokenKeyPattern.hasMatch(key)) usageException("'$key' is not a token key. Write lower camel: accentSubtle.");
    final type = argResults!['type'] as String?;
    final light = argResults!['light'] as String?;
    if (type == null) usageException('Give the token type: --type ${tokenTypes.join('|')}.');
    if (light == null) usageException('Give the light value: --light <value>.');
    final value = parseTokenLiteral(type, light);
    final problem = tokenValueProblem(type, value);
    if (problem != null) throw CliFailure('$problem Pass --light ${tokenTypeExamples[type]}.');
    final ws = loadWorkspace();
    final catalog = loadCatalog(ws);
    if (catalog.tokens.containsKey(key)) {
      throw CliFailure(
        "'$key' is a library ${catalog.tokens[key]!.type} token. To override it, give tokens/tokens.json "
        '"$key": {"values": {"light": ...}} without type; or pick a new key.',
      );
    }
    const path = WorkspaceInput.tokensPath;
    if (ws.loadProblems.any((d) => d.file == path)) {
      throw const CliFailure('$path does not read as JSON. Fix it first.');
    }
    final doc = ws.tokensJson ?? <String, Object?>{'format': 1, 'tokens': <String, Object?>{}};
    final tokens = doc['tokens'];
    if (tokens is! Map<String, Object?>) throw const CliFailure('$path has no "tokens" object. Fix it first.');
    if (tokens.containsKey(key)) throw CliFailure("'$key' is already in $path. Edit it there.");
    writeDocument(path, {
      ...doc,
      'tokens': {
        ...tokens,
        key: {
          'type': type,
          if (argResults!['description'] case final String d) 'description': d,
          'values': {'light': value},
        },
      },
    });
    out.writeln("Added '$key' ($type) to $path. Use it in a preset or a token prop; add other modes under values.");
    return 0;
  }
}
