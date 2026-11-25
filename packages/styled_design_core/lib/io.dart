/// File access for design workspaces: loads a workspace folder from disk.
/// Not for the Flutter runtime; the CLI and tests use it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'styled_design_core.dart';

/// A design workspace folder: design.json, tokens, presets and screens, read
/// as raw JSON with the path of each file relative to the folder.
final class DesignWorkspace {
  final Directory root;

  /// Workspace-relative path (forward slashes) → decoded JSON object.
  final Map<String, Map<String, Object?>> files;

  /// Files that are not valid JSON objects (`E-json`).
  final List<Diagnostic> loadProblems;

  DesignWorkspace._(this.root, this.files, this.loadProblems);

  /// Reads every `.json` document under [dir]: design.json, catalog.json,
  /// tokens/, presets/ and screens/.
  static DesignWorkspace load(Directory dir) {
    final files = <String, Map<String, Object?>>{};
    final problems = <Diagnostic>[];
    void read(File file) {
      final rel = p.posix.joinAll(p.split(p.relative(file.path, from: dir.path)));
      try {
        final json = jsonDecode(file.readAsStringSync());
        if (json is Map<String, Object?>) {
          files[rel] = json;
        } else {
          problems.add(
            Diagnostic.of(
              'E-json',
              'A design document is a JSON object.',
              file: rel,
              pointer: '',
              hint: 'Wrap the document in { ... }.',
            ),
          );
        }
      } on FormatException catch (e) {
        problems.add(
          Diagnostic.of(
            'E-json',
            'Not valid JSON: ${e.message}${e.offset == null ? '' : ' (at character ${e.offset})'}.',
            file: rel,
            pointer: '',
            hint: 'Fix the commas, quotes or brackets there; design fmt only rewrites files that parse.',
          ),
        );
      }
    }

    for (final name in const ['design.json', 'catalog.json']) {
      final f = File(p.join(dir.path, name));
      if (f.existsSync()) read(f);
    }
    for (final sub in const ['tokens', 'presets', 'screens']) {
      final d = Directory(p.join(dir.path, sub));
      if (!d.existsSync()) continue;
      final found = d.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.json')).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      found.forEach(read);
    }
    return DesignWorkspace._(dir, files, problems);
  }

  /// The workspace as the validator and the other pure operations read it.
  WorkspaceInput toInput() => WorkspaceInput(files, loadProblems: loadProblems);

  Map<String, Object?>? get manifestJson => files['design.json'];
  WorkspaceManifest? get manifest => switch (manifestJson) {
    final m? => WorkspaceManifest.fromJson(m),
    null => null,
  };

  Catalog? get catalog => switch (files['catalog.json']) {
    final c? => Catalog.fromJson(c),
    null => null,
  };

  Map<String, Object?>? get tokensJson => files['tokens/tokens.json'];

  /// presets/*.json, by path.
  Map<String, Map<String, Object?>> get presetFiles => {
    for (final MapEntry(:key, :value) in files.entries)
      if (key.startsWith('presets/')) key: value,
  };

  /// screens/**/*.json, by path.
  Map<String, Map<String, Object?>> get screenFiles => {
    for (final MapEntry(:key, :value) in files.entries)
      if (key.startsWith('screens/')) key: value,
  };

  /// The screen id a path spells: screens/admin/automations.json → admin.automations.
  static String screenIdForPath(String path) =>
      p.posix.withoutExtension(path.substring('screens/'.length)).split('/').join('.');

  /// The path a screen id spells.
  static String pathForScreenId(String id) => 'screens/${id.split('.').join('/')}.json';

  /// An in-memory bundle of everything that parses, fixtures included. Throws a
  /// [DesignError] listing the problems when a screen or preset does not parse.
  DesignBundle toBundle() {
    final problems = <Diagnostic>[...loadProblems];
    final screens = <String, ScreenDoc>{};
    for (final MapEntry(key: path, value: json) in screenFiles.entries) {
      final (doc, found) = parseScreenSafely(json, file: path);
      problems.addAll(found.where((d) => d.isError));
      if (doc != null) screens[doc.id] = doc;
    }
    final presets = <String, PresetDoc>{};
    for (final MapEntry(key: path, value: json) in presetFiles.entries) {
      try {
        final doc = PresetDoc.fromJson(json);
        presets[doc.id] = doc;
      } on DesignError catch (e) {
        problems.add(Diagnostic.of('E-schema', e.message, file: path, pointer: ''));
      }
    }
    if (problems.isNotEmpty) throw DesignError('The workspace at ${root.path} has errors.', problems);
    final manifest = this.manifest;
    return DesignBundle(
      name: manifest?.name ?? '',
      start: manifest?.start ?? '',
      tokens: tokensJson == null ? TokenDoc.empty : TokenDoc.fromJson(tokensJson!),
      presets: presets,
      screens: screens,
    );
  }
}
