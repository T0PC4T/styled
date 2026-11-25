import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:styled_design_core/styled_design_core.dart';

import 'context.dart';

/// Writes (or deletes) the document of a [DocumentEdit] under [root], the
/// one place `design token`, `design preset` and `design serve` write edits.
void writeDocumentEdit(String root, DocumentEdit edit) {
  final file = File(p.joinAll([root, ...p.posix.split(edit.path)]));
  if (edit.deletes) {
    if (file.existsSync()) file.deleteSync();
    return;
  }
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(edit.text!);
}

/// Prints [edit]'s outcome and writes it when it is allowed: exit 0, or 1
/// when refused.
int _apply(DesignCommand cmd, DocumentEdit edit) {
  if (!edit.ok) {
    for (final d in edit.diagnostics) {
      cmd.out.writeln(diagnosticLine(d));
    }
    cmd.out.writeln(edit.message);
    return 1;
  }
  writeDocumentEdit(cmd.workspaceDir, edit);
  cmd.out.writeln(edit.message);
  return 0;
}

/// `design token set|unset`.
class TokenCommand extends Command<int> {
  @override
  final name = 'token';
  @override
  final description = 'Set or unset a token value in tokens/tokens.json.';

  TokenCommand(CliContext ctx) {
    addSubcommand(TokenSetCommand(ctx));
    addSubcommand(TokenUnsetCommand(ctx));
  }
}

/// `design token set <key> --value <v> [--mode light] [--type t] [--description d]`.
class TokenSetCommand extends DesignCommand {
  @override
  final name = 'set';
  @override
  final description = "Set a token's value in one mode: override a library token, or add a new one with --type.";
  @override
  String get invocation => 'design token set <key> --value <value> [--mode light|dark] [--type <type>]';

  TokenSetCommand(super.ctx) {
    argParser
      ..addOption('value', help: 'The value: #RRGGBB, a number, whole ms, w100..w900, text, or shadow JSON.')
      ..addOption('mode', defaultsTo: 'light', help: 'The mode the value is for.')
      ..addOption('type', allowed: tokenTypes, help: 'For a new token only: its type.')
      ..addOption('description', help: 'For a new token: what it is for.');
  }

  @override
  int run() {
    final key = rest(min: 1, max: 1, usage: 'Name one token: design token set primary --value "#3B82F6".').single;
    final text = argResults!['value'] as String?;
    if (text == null) usageException('Give the value: --value <value>, such as --value "#3B82F6" or --value 12.');
    final ws = loadWorkspace();
    final catalog = loadCatalog(ws);
    final declared = argResults!['type'] as String?;
    final own = switch (ws.tokensJson?['tokens']) {
      final Map<String, Object?> tokens => switch (tokens[key]) {
        final Map<String, Object?> entry => entry['type'] as String?,
        _ => null,
      },
      _ => null,
    };
    final type = catalog.tokens[key]?.type ?? own ?? declared;
    return _apply(
      this,
      setToken(
        ws.toInput(),
        catalog,
        key: key,
        value: type == null ? text : parseTokenLiteral(type, text),
        mode: argResults!['mode'] as String,
        type: declared,
        description: argResults!['description'] as String?,
      ),
    );
  }
}

/// `design token unset <key> [--mode m]`.
class TokenUnsetCommand extends DesignCommand {
  @override
  final name = 'unset';
  @override
  final description = "Remove a token's value in one mode, or the whole token, from tokens/tokens.json.";
  @override
  String get invocation => 'design token unset <key> [--mode light|dark]';

  TokenUnsetCommand(super.ctx) {
    argParser.addOption('mode', help: 'Remove only this mode (default: the whole token).');
  }

  @override
  int run() {
    final key = rest(min: 1, max: 1, usage: 'Name one token: design token unset cardRadius --mode dark.').single;
    final ws = loadWorkspace();
    return _apply(this, unsetToken(ws.toInput(), loadCatalog(ws), key: key, mode: argResults!['mode'] as String?));
  }
}

/// `design preset write|remove`.
class PresetCommand extends Command<int> {
  @override
  final name = 'preset';
  @override
  final description = 'Write or remove a designer preset in presets/.';

  PresetCommand(CliContext ctx) {
    addSubcommand(PresetWriteCommand(ctx));
    addSubcommand(PresetRemoveCommand(ctx));
  }
}

/// `design preset write <Family.variant> --json '<preset document>'`.
class PresetWriteCommand extends DesignCommand {
  @override
  final name = 'write';
  @override
  final description = 'Write a designer preset; refused if it adds an error.';
  @override
  String get invocation => "design preset write <Family.variant> --json '<preset document>'";

  PresetWriteCommand(super.ctx) {
    argParser.addOption(
      'json',
      help:
          'The preset document: {"format": 1, "extends": "Family.base", "style": {...}}; id defaults to the argument.',
      valueHelp: 'json',
    );
  }

  @override
  int run() {
    final id = rest(
      min: 1,
      max: 1,
      usage: "Name one preset: design preset write StyleCard.calm --json '{...}'.",
    ).single;
    if (Catalog.splitPreset(id) == null) {
      usageException("'$id' is not a preset id. Write Family.variant: StyleCard.calm.");
    }
    final text = argResults!['json'] as String?;
    if (text == null) {
      usageException('Give the preset document: --json \'{"format": 1, "extends": ..., "style": ...}\'.');
    }
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException catch (e) {
      usageException('--json is not valid JSON: ${e.message}. Quote it with single quotes in the shell.');
    }
    if (json is! Map<String, Object?>) usageException('--json is a preset document: a JSON object.');
    if (json['id'] case final Object other when other != id) {
      usageException("--json names the preset '$other', but the argument is '$id'. Make them the same.");
    }
    final ws = loadWorkspace();
    final preset = json.containsKey('id')
        ? json
        : {
            if (json.containsKey('format')) 'format': json['format'],
            'id': id,
            for (final MapEntry(:key, :value) in json.entries)
              if (key != 'format') key: value,
          };
    return _apply(this, writePreset(ws.toInput(), loadCatalog(ws), preset));
  }
}

/// `design preset remove <Family.variant>`.
class PresetRemoveCommand extends DesignCommand {
  @override
  final name = 'remove';
  @override
  final description = 'Delete a designer preset nothing uses.';
  @override
  String get invocation => 'design preset remove <Family.variant>';

  PresetRemoveCommand(super.ctx);

  @override
  int run() {
    final id = rest(min: 1, max: 1, usage: 'Name one preset: design preset remove StyleCard.calm.').single;
    final ws = loadWorkspace();
    return _apply(this, removePreset(ws.toInput(), loadCatalog(ws), id));
  }
}
