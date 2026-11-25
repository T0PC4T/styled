// The JSON Schemas in schemas/ and the validator's Dart checks must not drift
// apart. A small validator for the subset of JSON Schema 2020-12 the schemas
// use runs here (test only), and:
// - every document of the kit workspace passes its schema;
// - every document the schema rejects (in the broken cases, and in systematic
//   mutations of the kit) also gets an error from validateWorkspace.
// The Dart checks may be stricter than the schemas; never looser.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:styled_design_core/io.dart';
import 'package:styled_design_core/styled_design_core.dart';
import 'package:test/test.dart';

Map<String, Object?> _load(String name) =>
    jsonDecode(File('schemas/$name.schema.json').readAsStringSync()) as Map<String, Object?>;

final _schemas = {
  for (final n in ['workspace', 'tokens', 'preset', 'screen']) n: _load(n),
};

/// The schema a workspace document follows, or null for files no schema covers.
Map<String, Object?>? _schemaFor(String path) {
  if (path == 'design.json') return _schemas['workspace'];
  if (path == 'tokens/tokens.json') return _schemas['tokens'];
  if (path.startsWith('presets/')) return _schemas['preset'];
  if (path.startsWith('screens/')) return _schemas['screen'];
  return null;
}

/// Problems of [value] against [schema] (within [root]); empty when it conforms.
List<String> _check(Object? value, Object? schema, Map<String, Object?> root, [String at = '']) {
  if (schema == true || schema == null) return const [];
  if (schema == false) return ['$at: nothing is allowed here'];
  final s = schema as Map<String, Object?>;
  final out = <String>[];
  if (s[r'$ref'] case final String ref) {
    final name = ref.substring(r'#/$defs/'.length);
    out.addAll(_check(value, (root[r'$defs']! as Map<String, Object?>)[name], root, at));
  }
  if (s['type'] case final Object type) {
    final types = type is List ? type.cast<String>() : [type as String];
    if (!types.any((t) => _isType(value, t))) out.add('$at: not ${types.join('|')}');
  }
  if (s.containsKey('const') && !jsonEquals(s['const'], value)) out.add('$at: not ${s['const']}');
  if (s['enum'] case final List<Object?> options when !options.any((o) => jsonEquals(o, value))) {
    out.add('$at: not one of $options');
  }
  if (value is String) {
    if (s['pattern'] case final String pattern when !RegExp(pattern).hasMatch(value)) out.add('$at: !~ $pattern');
    if (s['minLength'] case final int n when value.length < n) out.add('$at: shorter than $n');
  }
  if (value is num) {
    if (s['minimum'] case final num n when value < n) out.add('$at: below $n');
    if (s['maximum'] case final num n when value > n) out.add('$at: above $n');
  }
  if (value is List<Object?>) {
    final prefix = (s['prefixItems'] as List<Object?>?) ?? const [];
    for (var i = 0; i < value.length; i++) {
      final itemSchema = i < prefix.length ? prefix[i] : s['items'];
      if (itemSchema != null) out.addAll(_check(value[i], itemSchema, root, '$at/$i'));
    }
    if (s['minItems'] case final int n when value.length < n) out.add('$at: fewer than $n items');
    if (s['maxItems'] case final int n when value.length > n) out.add('$at: more than $n items');
  }
  if (value is Map<String, Object?>) {
    for (final key in (s['required'] as List<Object?>?) ?? const []) {
      if (!value.containsKey(key)) out.add("$at: needs '$key'");
    }
    final props = (s['properties'] as Map<String, Object?>?) ?? const {};
    for (final MapEntry(:key, value: v) in value.entries) {
      if (props.containsKey(key)) {
        out.addAll(_check(v, props[key], root, '$at/$key'));
      } else if (s.containsKey('additionalProperties')) {
        out.addAll(_check(v, s['additionalProperties'], root, '$at/$key'));
      }
      if (s['propertyNames'] case final Object names) out.addAll(_check(key, names, root, '$at/<$key>'));
    }
    if (s['minProperties'] case final int n when value.length < n) out.add('$at: fewer than $n keys');
    if (s['maxProperties'] case final int n when value.length > n) out.add('$at: more than $n keys');
  }
  for (final sub in (s['allOf'] as List<Object?>?) ?? const []) {
    out.addAll(_check(value, sub, root, at));
  }
  if (s['anyOf'] case final List<Object?> subs when !subs.any((sub) => _check(value, sub, root, at).isEmpty)) {
    out.add('$at: matches none of anyOf');
  }
  if (s['oneOf'] case final List<Object?> subs
      when subs.where((sub) => _check(value, sub, root, at).isEmpty).length != 1) {
    out.add('$at: does not match exactly one of oneOf');
  }
  if (s['not'] case final Object sub when _check(value, sub, root, at).isEmpty) out.add('$at: matches not');
  if (s['if'] case final Object condition when _check(value, condition, root, at).isEmpty) {
    if (s['then'] case final Object then) out.addAll(_check(value, then, root, at));
  }
  return out;
}

bool _isType(Object? v, String t) => switch (t) {
  'object' => v is Map,
  'array' => v is List,
  'string' => v is String,
  'number' => v is num,
  'integer' => v is int || (v is double && v == v.roundToDouble()),
  'boolean' => v is bool,
  'null' => v == null,
  _ => false,
};

List<String> _schemaProblems(String path, Map<String, Object?> json) {
  final schema = _schemaFor(path);
  return schema == null ? const [] : _check(json, schema, schema);
}

/// Whether validateWorkspace reports an error in [path].
bool _dartRejects(WorkspaceInput input, Catalog catalog, String path) =>
    validateWorkspace(input, catalog).any((d) => d.isError && d.file == path);

Object? _deepCopy(Object? v) => jsonDecode(jsonEncode(v));

void main() {
  final kit = DesignWorkspace.load(Directory('test/fixtures/kit_workspace'));
  final catalog = kit.catalog!;

  test('every document of the kit workspace passes its schema', () {
    for (final MapEntry(key: path, value: json) in kit.files.entries) {
      expect(_schemaProblems(path, json), isEmpty, reason: path);
    }
  });

  test('every broken-case document the schema rejects, validateWorkspace rejects too', () {
    const root = 'test/fixtures/broken';
    final base = DesignWorkspace.load(Directory('$root/base'));
    final brokenCatalog = Catalog.fromJson(
      jsonDecode(File('$root/catalog.json').readAsStringSync()) as Map<String, Object?>,
    );
    var schemaRejected = 0;
    for (final dir in Directory(root).listSync().whereType<Directory>().where((d) => p.basename(d.path) != 'base')) {
      final overlay = DesignWorkspace.load(dir);
      final input = WorkspaceInput({...base.files, ...overlay.files}, loadProblems: overlay.loadProblems);
      for (final MapEntry(key: path, value: json) in overlay.files.entries) {
        if (_schemaProblems(path, json).isEmpty) continue;
        schemaRejected++;
        expect(_dartRejects(input, brokenCatalog, path), isTrue, reason: '${p.basename(dir.path)}: $path');
      }
    }
    expect(schemaRejected, greaterThanOrEqualTo(3), reason: 'the broken cases include schema errors');
  });

  test('systematic mutations of the kit: whatever the schema rejects, validateWorkspace rejects', () {
    var tried = 0;
    var schemaRejected = 0;
    void tryMutation(String path, Map<String, Object?> mutated, String what) {
      tried++;
      if (_schemaProblems(path, mutated).isEmpty) return;
      schemaRejected++;
      final input = WorkspaceInput({...kit.files, path: mutated});
      expect(
        _dartRejects(input, catalog, path),
        isTrue,
        reason: '$path: $what\n${_schemaProblems(path, mutated).join('\n')}',
      );
    }

    for (final MapEntry(key: path, value: json) in kit.files.entries) {
      if (_schemaFor(path) == null) continue;
      // Each top-level key removed, given a wrong type, and an unknown key added.
      for (final key in json.keys) {
        tryMutation(path, (_deepCopy(json)! as Map<String, Object?>)..remove(key), 'without $key');
        for (final wrong in <Object?>[42, 'text', true, <Object?>[], <String, Object?>{}]) {
          tryMutation(path, (_deepCopy(json)! as Map<String, Object?>)..[key] = wrong, '$key = $wrong');
        }
      }
      tryMutation(path, (_deepCopy(json)! as Map<String, Object?>)..['surprise'] = 1, 'an unknown key');
      // In screens: every node and action mutated the same way.
      if (path.startsWith('screens/')) {
        final copy = _deepCopy(json)! as Map<String, Object?>;
        final targets = <Map<String, Object?>>[];
        void collect(Object? v) {
          if (v is Map<String, Object?>) {
            if (v.containsKey('id') && v.containsKey('type') || v.containsKey('do')) targets.add(v);
            v.values.forEach(collect);
          } else if (v is List<Object?>) {
            v.forEach(collect);
          }
        }

        collect(copy);
        for (var i = 0; i < targets.length; i++) {
          for (final key in [...targets[i].keys, 'surprise']) {
            final mutated = _deepCopy(copy)! as Map<String, Object?>;
            final again = <Map<String, Object?>>[];
            void find(Object? v) {
              if (v is Map<String, Object?>) {
                if (v.containsKey('id') && v.containsKey('type') || v.containsKey('do')) again.add(v);
                v.values.forEach(find);
              } else if (v is List<Object?>) {
                v.forEach(find);
              }
            }

            find(mutated);
            final target = again[i];
            if (key == 'surprise') {
              target['surprise'] = 1;
            } else {
              target[key] = 42;
            }
            tryMutation(path, mutated, 'node/action $i: $key');
          }
        }
      }
    }
    expect(tried, greaterThan(500));
    expect(schemaRejected, greaterThan(200));
  });
}
