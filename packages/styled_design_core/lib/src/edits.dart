import 'package:meta/meta.dart';

import 'catalog.dart';
import 'diagnostics.dart';
import 'fmt.dart';
import 'json_util.dart';
import 'patch.dart';
import 'token_values.dart';
import 'validator.dart';
import 'workspace_input.dart';

/// What an edit of one workspace document gives: the document's new
/// canonical text to write (or null to delete the file), or why it was
/// refused. Both `design` commands and `design serve` apply these, so an edit
/// writes the same bytes whichever made it.
@immutable
final class DocumentEdit {
  /// The workspace-relative path of the document.
  final String path;

  /// Whether the edit may be written.
  final bool ok;

  /// The new document, or null when the edit deletes it (or was refused).
  final Map<String, Object?>? json;

  /// One or two sentences: what happened, and what to do next.
  final String message;

  /// When refused: the operations that could not apply, or the errors the
  /// edit would add. When written: the problems the document still has.
  final List<Diagnostic> diagnostics;

  const DocumentEdit._(this.path, {required this.ok, required this.message, this.json, this.diagnostics = const []});

  /// An edit refused before it reached a document, such as a malformed request.
  const DocumentEdit.refused(this.path, this.message, [this.diagnostics = const []]) : ok = false, json = null;

  /// Whether a written edit removes the file.
  bool get deletes => ok && json == null;

  /// The canonical text to write: the same bytes `design fmt` gives.
  String? get text => json == null ? null : formatDocument(json!, path: path);
}

String _key(Diagnostic d) => '${d.code}|${d.file}|${d.node}|${d.message}';

/// Validates [input] with [path] replaced by [json] (or removed when null)
/// and refuses the edit when that adds an error: the rule of `design patch`.
DocumentEdit _checked(
  WorkspaceInput input,
  Catalog catalog,
  String path,
  Map<String, Object?>? json, {
  required String written,
}) {
  final before = validateWorkspace(input, catalog).map(_key).toSet();
  final after = validateWorkspace(input.withFile(path, json), catalog);
  final added = [
    for (final d in after)
      if (d.isError && !before.contains(_key(d))) d,
  ];
  if (added.isNotEmpty) {
    return DocumentEdit._(
      path,
      ok: false,
      message:
          'Nothing written: the edit adds ${added.length} error${added.length == 1 ? '' : 's'}. '
          'Change it so it adds none, then send it again.',
      diagnostics: added,
    );
  }
  final left = [
    for (final d in after)
      if (d.file == path) d,
  ];
  final errors = left.where((d) => d.isError).length;
  final warnings = left.length - errors;
  String n(int count, String word) => '$count $word${count == 1 ? '' : 's'}';
  return DocumentEdit._(
    path,
    ok: true,
    json: json,
    message: left.isEmpty
        ? '$written.'
        : '$written. It still has ${n(errors, 'error')}, ${n(warnings, 'warning')}: run design validate $path.',
    diagnostics: left,
  );
}

DocumentEdit _refused(String path, String message, [List<Diagnostic> diagnostics = const []]) =>
    DocumentEdit.refused(path, message, diagnostics);

/// `design patch`: applies [ops] (see [applyPatch]) to the screen at [path]
/// and validates the workspace with the result. Refused when an operation
/// cannot apply or the edit adds an error.
DocumentEdit editScreen(WorkspaceInput input, Catalog catalog, String path, Object? ops) {
  final json = input.files[path];
  if (json == null) {
    return _refused(
      path,
      input.loadProblems.any((d) => d.file == path)
          ? '$path does not read as JSON. Fix it first.'
          : 'No screen at $path. Create one with design new screen <id> --from <template>.',
    );
  }
  final result = applyPatch(json, ops, screenId: WorkspaceInput.screenIdForPath(path));
  if (!result.ok) {
    return _refused(path, 'Nothing written. Fix the operations and send them again.', result.diagnostics);
  }
  return _checked(input, catalog, path, canonicalDocument(result.json!, path: path), written: 'Wrote $path');
}

/// The token document of [input], or a new empty one; null with a reason
/// when tokens.json does not read or has no `tokens` object.
(Map<String, Object?>?, String?) _tokenDoc(WorkspaceInput input) {
  const path = WorkspaceInput.tokensPath;
  if (input.loadProblems.any((d) => d.file == path)) return (null, '$path does not read as JSON. Fix it first.');
  final doc = deepCopyJson(input.tokensJson ?? {'format': 1, 'tokens': <String, Object?>{}})! as Map<String, Object?>;
  if (doc['tokens'] is! Map<String, Object?>) return (null, '$path has no "tokens" object. Fix it first.');
  return (doc, null);
}

/// `design token set`: sets token [key]'s value in [mode] in
/// tokens/tokens.json. A library token is overridden (it takes no [type]); a
/// key the library does not have becomes a new token, which needs [type] and
/// its light value first. Refused when the value does not fit the token's
/// type or the edit adds an error.
DocumentEdit setToken(
  WorkspaceInput input,
  Catalog catalog, {
  required String key,
  required Object? value,
  String mode = 'light',
  String? type,
  String? description,
}) {
  const path = WorkspaceInput.tokensPath;
  if (!tokenKeyPattern.hasMatch(key)) {
    return _refused(path, "'$key' is not a token key. Write lower camel: accentSubtle.");
  }
  final modes = catalog.modes.isEmpty ? const ['light'] : catalog.modes;
  if (!modes.contains(mode)) return _refused(path, "'$mode' is not a mode. The catalog has ${modes.join(', ')}.");
  final (doc, problem) = _tokenDoc(input);
  if (doc == null) return _refused(path, problem!);
  final tokens = doc['tokens']! as Map<String, Object?>;
  final existing = tokens[key];
  if (existing != null && existing is! Map<String, Object?>) {
    return _refused(path, "'$key' in $path is not an object. Fix it first.");
  }
  final entry = existing as Map<String, Object?>?;
  final library = catalog.tokens[key];
  final String effective;
  if (library != null) {
    if (type != null && type != library.type || entry?['type'] != null) {
      return _refused(
        path,
        "'$key' is a library ${library.type} token: an override takes no type. Leave the type out.",
      );
    }
    effective = library.type;
  } else if (entry?['type'] case final String own) {
    if (type != null && type != own) {
      return _refused(path, "'$key' is a $own token; its type cannot change. Pick another key for a $type token.");
    }
    effective = own;
  } else {
    if (type == null) {
      return _refused(
        path,
        "'$key' is not a library token. To add it, give its type (${tokenTypes.join(', ')}), "
        'or pick a key the catalog lists.',
      );
    }
    if (!tokenTypes.contains(type)) return _refused(path, "'$type' is not a token type: ${tokenTypes.join(', ')}.");
    if (mode != 'light') return _refused(path, "A new token needs its light value first. Set '$key' in light mode.");
    effective = type;
  }
  final valueProblem = tokenValueProblem(effective, value);
  if (valueProblem != null) {
    return _refused(path, '$valueProblem Give a value such as ${tokenTypeExamples[effective]}.');
  }

  final values = <String, Object?>{...?(entry?['values'] as Map<String, Object?>?), mode: value};
  final next = entry == null
      ? <String, Object?>{if (library == null) 'type': effective, 'description': ?description, 'values': values}
      : <String, Object?>{
          for (final MapEntry(key: field, value: v) in entry.entries)
            if (field != 'values' && field != 'description') field: v,
          if (description != null)
            'description': description
          else if (entry['description'] != null)
            'description': entry['description'],
          'values': values,
        };
  tokens[key] = next;
  final shown = value is String ? '"$value"' : '$value';
  return _checked(input, catalog, path, doc, written: 'Set $key to $shown in $mode mode in $path');
}

/// `design token unset`: removes token [key]'s value in [mode], or the whole
/// entry when [mode] is null (or no value is left). A new token keeps its
/// light value while it has others. Refused when the edit adds an error, such
/// as removing a new token a preset still uses.
DocumentEdit unsetToken(WorkspaceInput input, Catalog catalog, {required String key, String? mode}) {
  const path = WorkspaceInput.tokensPath;
  final (doc, problem) = _tokenDoc(input);
  if (doc == null) return _refused(path, problem!);
  final tokens = doc['tokens']! as Map<String, Object?>;
  final entry = tokens[key];
  if (entry is! Map<String, Object?>) return _refused(path, "'$key' is not in $path: there is nothing to unset.");
  final values = <String, Object?>{...?(entry['values'] as Map<String, Object?>?)};
  if (mode != null) {
    if (!values.containsKey(mode)) return _refused(path, "'$key' has no $mode value in $path.");
    if (mode == 'light' && entry['type'] != null && values.length > 1) {
      return _refused(
        path,
        "'$key' is a new token: it keeps its light value. Unset its other modes, or the whole token.",
      );
    }
    values.remove(mode);
  }
  if (mode == null || values.isEmpty) {
    tokens.remove(key);
  } else {
    tokens[key] = {for (final MapEntry(key: field, value: v) in entry.entries) field: field == 'values' ? values : v};
  }
  return _checked(
    input,
    catalog,
    path,
    doc,
    written: mode == null || values.isEmpty ? 'Removed $key from $path' : 'Removed the $mode value of $key from $path',
  );
}

/// `design preset write`: writes the designer preset [preset] (a preset
/// document with its `id`) to `presets/<id>.json`, creating or replacing it.
/// Refused when it adds an error.
DocumentEdit writePreset(WorkspaceInput input, Catalog catalog, Map<String, Object?> preset) {
  final id = preset['id'];
  if (id is! String || Catalog.splitPreset(id) == null) {
    return _refused('presets/', 'A preset document needs an "id" such as StyleCard.highlight.');
  }
  final path = WorkspaceInput.pathForPresetId(id);
  final doc = deepCopyJson(preset)! as Map<String, Object?>;
  final existed = input.files.containsKey(path);
  return _checked(input, catalog, path, doc, written: '${existed ? 'Rewrote' : 'Wrote'} $path');
}

/// `design preset remove`: deletes the designer preset [id]. Refused when a
/// screen or preset still uses it (the edit would add an error).
DocumentEdit removePreset(WorkspaceInput input, Catalog catalog, String id) {
  final path = WorkspaceInput.pathForPresetId(id);
  if (!input.files.containsKey(path)) return _refused(path, "No designer preset '$id' at $path.");
  return _checked(input, catalog, path, null, written: 'Removed $path');
}
