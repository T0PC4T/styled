import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import 'catalog.dart';
import 'contract.dart';
import 'diagnostics.dart';
import 'fmt.dart';
import 'json_util.dart';
import 'screen.dart';
import 'validator.dart';
import 'workspace_input.dart';

/// What [buildBundle] returns: the bundle JSON, or null and the diagnostics
/// that stopped it.
@immutable
final class ExportResult {
  final Map<String, Object?>? bundle;

  /// Every diagnostic of the strict validation that ran first.
  final List<Diagnostic> diagnostics;

  const ExportResult(this.bundle, this.diagnostics);

  bool get ok => bundle != null;

  /// The bundle as canonical JSON text.
  String? get text => bundle == null ? null : canonicalJsonText(bundle);
}

/// The fields of a screen the bundle keeps, in order.
const _bundleScreenKeys = ['kind', 'title', 'route', 'params', 'query', 'state', 'emits', 'root'];

/// `design export`: validates [input] strictly (any error or warning stops
/// it), then writes one deterministic bundle:
///
/// `{format, name, hash, requires: {catalog}, start, tokens, presets,
/// screens, contracts}`. Ids are sorted; fixtures are kept only when
/// design.json says `export.fixtures` default or all. The hash is
/// `sha256:` over the bundle's compact JSON without the hash.
ExportResult buildBundle(WorkspaceInput input, Catalog catalog) {
  final diagnostics = validateWorkspace(input, catalog, strict: true);
  if (diagnosticsFail(diagnostics, strict: true)) return ExportResult(null, diagnostics);

  final manifest = input.manifest!;
  final fixtures = manifest.exportFixtures;

  final tokensJson = input.tokensJson?['tokens'];
  final tokens = <String, Object?>{};
  if (tokensJson is Map<String, Object?>) {
    for (final key in tokensJson.keys.toList()..sort()) {
      final entry = tokensJson[key]! as Map<String, Object?>;
      tokens[key] = {'type': ?entry['type'], 'description': ?entry['description'], 'values': entry['values']};
    }
  }

  final presetsById = <String, Map<String, Object?>>{
    for (final json in input.presetFiles.values) json['id']! as String: json,
  };
  final presets = <String, Object?>{
    for (final id in presetsById.keys.toList()..sort())
      id: {
        'extends': presetsById[id]!['extends'],
        'description': ?presetsById[id]!['description'],
        'style': deepCopyJson(presetsById[id]!['style']),
      },
  };

  final docs = parseScreens(input);
  final rawById = <String, Map<String, Object?>>{
    for (final MapEntry(key: path, value: json) in input.screenFiles.entries)
      WorkspaceInput.screenIdForPath(path): canonicalDocument(json, path: path),
  };
  final ids = docs.keys.toList()..sort();
  final screens = <String, Object?>{};
  final contracts = <String, Object?>{};
  for (final id in ids) {
    final raw = rawById[id]!;
    final doc = docs[id]!;
    screens[id] = {
      for (final key in _bundleScreenKeys)
        if (raw.containsKey(key)) key: raw[key],
      if (fixtures == 'all' && raw['fixtures'] != null) 'fixtures': raw['fixtures'],
      if (fixtures == 'default' && doc.fixtures.containsKey('default'))
        'fixtures': {'default': (raw['fixtures']! as Map<String, Object?>)['default']},
    };
    contracts[id] = {
      'data': dataShape(doc),
      'emits': [for (final MapEntry(:key, :value) in doc.emits.entries) emitContract(key, value)],
      'modals': [
        for (final m in openableModals(doc))
          if (docs[m]?.kind == ScreenKind.modal) m,
      ],
    };
  }

  final body = <String, Object?>{
    'format': 1,
    'name': manifest.name,
    'requires': {'catalog': catalog.version},
    'start': manifest.start,
    'tokens': tokens,
    'presets': presets,
    'screens': screens,
    'contracts': contracts,
  };
  final hash = 'sha256:${sha256.convert(utf8.encode(jsonEncode(body)))}';
  final bundle = {
    'format': 1,
    'name': manifest.name,
    'hash': hash,
    for (final MapEntry(:key, :value) in body.entries)
      if (key != 'format' && key != 'name') key: value,
  };
  return ExportResult(bundle, diagnostics);
}

/// The hash a bundle should carry: `sha256:` over its compact JSON without
/// `hash`. Equal to the bundle's own `hash` when nothing was changed.
String bundleHash(Map<String, Object?> bundle) {
  final body = {...bundle}..remove('hash');
  return 'sha256:${sha256.convert(utf8.encode(jsonEncode(body)))}';
}
