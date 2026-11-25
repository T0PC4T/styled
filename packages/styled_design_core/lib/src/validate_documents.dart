part of 'validator.dart';

final _presetIdPattern = RegExp(r'^Style[A-Z][A-Za-z0-9]*\.[a-z][A-Za-z0-9]*$');

String _kindName<T>() => switch (T) {
  const (String) => 'text',
  const (bool) => 'true or false',
  const (int) => 'a whole number',
  const (num) => 'a number',
  const (List<Object?>) => 'a list',
  _ => 'an object',
};

String _jsonKindOf(Object? value) => switch (value) {
  null => 'null',
  String() => 'text',
  bool() => 'true or false',
  num() => 'a number',
  List<Object?>() => 'a list',
  _ => 'an object',
};

extension on _Validator {
  /// Reports E-schema for keys of [json] outside [allowed].
  void onlyKeys(Map<String, Object?> json, Set<String> allowed, String file, String pointer, String what) {
    for (final key in json.keys) {
      if (allowed.contains(key)) continue;
      report(
        'E-schema',
        "$what has no field '$key'.",
        file: file,
        pointer: '$pointer/${pointerSegment(key)}',
        hint: didYouMean(key, allowed) ?? 'Remove it.',
        allowed: shortList(allowed.where((k) => k != r'$schema')),
      );
    }
  }

  void requireKeys(Map<String, Object?> json, List<String> required, String file, String pointer, String what) {
    for (final key in required) {
      if (!json.containsKey(key)) {
        report('E-schema', "$what needs '$key'.", file: file, pointer: pointer, hint: "Add '$key'.");
      }
    }
  }

  /// Checks [json][key] is a [T]; reports E-schema and returns null when not.
  T? field<T>(Map<String, Object?> json, String key, String file, String pointer, {bool required = false}) {
    if (!json.containsKey(key)) return null;
    final value = json[key];
    if (value is T) return value;
    report(
      'E-schema',
      "'$key' must be ${_kindName<T>()}, not ${_jsonKindOf(value)}.",
      file: file,
      pointer: '$pointer/${pointerSegment(key)}',
    );
    return null;
  }

  void checkFormat(Map<String, Object?> json, String file) {
    if (json.containsKey('format') && json['format'] != 1) {
      report('E-schema', 'format must be 1.', file: file, pointer: '/format', hint: 'Write "format": 1.');
    }
  }

  // ---------------------------------------------------------- design.json

  void checkManifest() {
    const file = 'design.json';
    final json = input.manifestJson;
    if (json == null) {
      if (!input.loadProblems.any((d) => d.file == file)) {
        report(
          'E-schema',
          'The workspace has no design.json.',
          file: file,
          pointer: '',
          hint: 'Run design init, or write design.json with format, name and start.',
        );
      }
      return;
    }
    manifest = WorkspaceManifest(
      name: json['name'] is String ? json['name']! as String : '',
      start: json['start'] is String ? json['start']! as String : '',
    );
    onlyKeys(json, const {r'$schema', 'format', 'name', 'start', 'catalog', 'export'}, file, '', 'design.json');
    requireKeys(json, const ['format', 'name', 'start'], file, '', 'design.json');
    checkFormat(json, file);
    final name = field<String>(json, 'name', file, '');
    if (name != null && name.isEmpty) report('E-schema', 'name must not be empty.', file: file, pointer: '/name');
    final start = field<String>(json, 'start', file, '');
    if (start != null) {
      if (start.isEmpty) {
        final pages = [
          for (final MapEntry(key: path, value: s) in input.screenFiles.entries)
            if (s['kind'] == 'page') WorkspaceInput.screenIdForPath(path),
        ];
        if (pages.isNotEmpty) {
          report(
            'E-schema',
            'start is empty; it names the page the prototype opens on.',
            file: file,
            pointer: '/start',
            hint: "Set start to a page, such as '${pages.first}'.",
            allowed: shortList(pages),
          );
        }
      } else if (!isScreenId(start)) {
        report(
          'E-schema',
          "start '$start' is not a screen id. Write dotted lower camel: admin.automations.",
          file: file,
          pointer: '/start',
        );
      }
    }
    final catalogJson = field<Map<String, Object?>>(json, 'catalog', file, '');
    if (catalogJson != null) {
      onlyKeys(catalogJson, const {'version', 'hash'}, file, '/catalog', 'catalog');
      requireKeys(catalogJson, const ['version'], file, '/catalog', 'catalog');
      final version = field<int>(catalogJson, 'version', file, '/catalog');
      if (version != null && version < 1) {
        report('E-schema', 'catalog.version is 1 or more.', file: file, pointer: '/catalog/version');
      }
      field<String>(catalogJson, 'hash', file, '/catalog');
    }
    final export = field<Map<String, Object?>>(json, 'export', file, '');
    if (export != null) {
      onlyKeys(export, const {'bundle', 'fixtures'}, file, '/export', 'export');
      field<String>(export, 'bundle', file, '/export');
      final fixtures = field<String>(export, 'fixtures', file, '/export');
      if (fixtures != null && !const {'none', 'default', 'all'}.contains(fixtures)) {
        report(
          'E-schema',
          "export.fixtures is none, default or all, not '$fixtures'.",
          file: file,
          pointer: '/export/fixtures',
          hint: didYouMean(fixtures, const ['none', 'default', 'all']),
          allowed: const ['none', 'default', 'all'],
        );
      }
    }
  }

  // ----------------------------------------------------------- tokens.json

  void checkTokens() {
    for (final t in catalog.tokens.values) {
      tokens[t.key] = t.type;
      lightValues[t.key] = t.light;
    }
    const file = WorkspaceInput.tokensPath;
    final json = input.tokensJson;
    if (json == null) return;
    onlyKeys(json, const {r'$schema', 'format', 'tokens'}, file, '', 'tokens.json');
    requireKeys(json, const ['format', 'tokens'], file, '', 'tokens.json');
    checkFormat(json, file);
    final entries = field<Map<String, Object?>>(json, 'tokens', file, '');
    if (entries == null) return;
    final modes = catalog.modes.isEmpty ? const ['light'] : catalog.modes;
    for (final MapEntry(:key, :value) in entries.entries) {
      final at = '/tokens/${pointerSegment(key)}';
      if (!tokenKeyPattern.hasMatch(key)) {
        report('E-schema', "'$key' is not a token key. Write lower camel: accentSubtle.", file: file, pointer: at);
        continue;
      }
      if (value is! Map<String, Object?>) {
        report(
          'E-schema',
          'A token entry is an object with values (and type for a new token), not ${_jsonKindOf(value)}.',
          file: file,
          pointer: at,
          hint: 'Write {"values": {"light": ...}}.',
        );
        continue;
      }
      onlyKeys(value, const {'type', 'description', 'values'}, file, at, 'A token entry');
      requireKeys(value, const ['values'], file, at, "Token '$key'");
      field<String>(value, 'description', file, at);
      final type = field<String>(value, 'type', file, at);
      final library = catalog.tokens[key];
      String? effective;
      if (type != null && !tokenTypes.contains(type)) {
        report(
          'E-schema',
          "'$type' is not a token type.",
          file: file,
          pointer: '$at/type',
          hint: didYouMean(type, tokenTypes),
          allowed: tokenTypes,
        );
      } else if (library != null) {
        effective = library.type;
        if (type != null) {
          report(
            'E-token-type',
            "'$key' is a library ${library.type} token; an override gives only values, without type.",
            file: file,
            pointer: '$at/type',
            hint: 'Remove "type", or pick a new key to add a new token.',
          );
        }
      } else if (type == null) {
        report(
          'E-token-unknown',
          "'$key' is not a library token, so it cannot be overridden.",
          file: file,
          pointer: at,
          hint:
              didYouMean(key, catalog.tokens.keys) ??
              'To add a new token, give "type" and a "light" value: design new token $key --type <type> --light <value>.',
        );
      } else {
        effective = type;
        newTokens.add(key);
      }
      if (effective != null) tokens[key] = effective;

      final values = field<Map<String, Object?>>(value, 'values', file, at);
      if (values == null) continue;
      if (values.containsKey('light')) lightValues[key] = values['light'];
      if (values.isEmpty) {
        report('E-schema', "Token '$key' has no values.", file: file, pointer: '$at/values', hint: 'Add "light".');
      }
      if (library == null && type != null && !values.containsKey('light')) {
        report(
          'E-token-light',
          "New token '$key' has no light value; every other mode falls back to it.",
          file: file,
          pointer: '$at/values',
          hint: 'Add "light": ${tokenTypeExamples[type] ?? '...'}.',
        );
      }
      for (final MapEntry(key: mode, value: v) in values.entries) {
        final vp = '$at/values/${pointerSegment(mode)}';
        if (!modes.contains(mode)) {
          report(
            'E-schema',
            "'$mode' is not a mode of the catalog.",
            file: file,
            pointer: vp,
            hint: didYouMean(mode, modes),
            allowed: shortList(modes),
          );
          continue;
        }
        if (effective == null) continue;
        final problem = tokenValueProblem(effective, v);
        if (problem != null) {
          report(
            'E-token-type',
            "Token '$key' ($effective): $problem",
            file: file,
            pointer: vp,
            hint: 'Write a $effective value, such as ${tokenTypeExamples[effective]}.',
          );
        }
      }
    }
  }

  // --------------------------------------------------------------- presets

  void collectPresets() {
    for (final MapEntry(key: path, value: json) in input.presetFiles.entries) {
      onlyKeys(json, const {r'$schema', 'format', 'id', 'extends', 'description', 'style'}, path, '', 'A preset');
      requireKeys(json, const ['format', 'id', 'extends', 'style'], path, '', 'A preset');
      checkFormat(json, path);
      field<String>(json, 'description', path, '');
      final id = field<String>(json, 'id', path, '');
      final extendsId = field<String>(json, 'extends', path, '');
      if (extendsId != null && !_presetIdPattern.hasMatch(extendsId)) {
        report(
          'E-schema',
          "extends '$extendsId' is not a preset id. Write Family.variant: StyleCard.surface.",
          file: path,
          pointer: '/extends',
        );
      }
      if (id == null) continue;
      if (!_presetIdPattern.hasMatch(id)) {
        report(
          'E-schema',
          "'$id' is not a preset id. Write Family.variant: StyleCard.highlight.",
          file: path,
          pointer: '/id',
        );
        continue;
      }
      final expected = WorkspaceInput.pathForPresetId(id);
      if (path != expected) {
        report(
          'E-id-path',
          "Preset '$id' is in $path; a preset's file is named after its id.",
          file: path,
          pointer: '/id',
          hint: 'Rename the file to $expected.',
        );
      }
      final (family, variant) = Catalog.splitPreset(id)!;
      final def = catalog.presets[family];
      if (def == null) {
        report(
          'E-preset-family',
          "There is no preset family '$family'; a designer preset adds a variant to an existing family.",
          file: path,
          pointer: '/id',
          hint: didYouMean(family, catalog.presets.keys, show: (f) => '$f.$variant'),
          allowed: shortList(catalog.presets.keys),
        );
      } else if (def.variants.contains(variant)) {
        report(
          'E-preset-variant',
          "'$id' is a built-in variant; a designer preset needs a new name.",
          file: path,
          pointer: '/id',
          hint: "Pick a name that is not one of ${def.variants.join(', ')}, such as '$family.${variant}Custom'.",
        );
      }
      if (presets.containsKey(id)) continue;
      presets[id] = _Preset(
        path,
        id,
        family,
        extendsId != null && _presetIdPattern.hasMatch(extendsId) ? extendsId : null,
      );
    }
  }

  void checkPreset(_Preset preset) {
    final json = input.files[preset.path]!;
    final ext = preset.extendsId;
    if (ext != null) {
      final (extFamily, extVariant) = Catalog.splitPreset(ext)!;
      final def = catalog.presets[preset.family];
      final familyIds = [
        if (def != null)
          for (final v in def.variants) '${preset.family}.$v',
        for (final p in presets.values)
          if (p.family == preset.family && p.id != preset.id) p.id,
      ];
      if (extFamily != preset.family) {
        report(
          'E-preset-extends',
          "'${preset.id}' extends '$ext', a variant of another family; a preset extends a variant of its own family.",
          file: preset.path,
          pointer: '/extends',
          hint:
              didYouMean('${preset.family}.$extVariant', familyIds) ??
              (familyIds.isEmpty ? null : "Extend a ${preset.family} variant, such as '${familyIds.first}'."),
          allowed: shortList(familyIds),
        );
      } else if (!(def?.variants.contains(extVariant) ?? false) && !presets.containsKey(ext)) {
        if (def != null) {
          report(
            'E-preset-extends',
            "'${preset.id}' extends '$ext', which is neither a built-in variant nor a designer preset.",
            file: preset.path,
            pointer: '/extends',
            hint: didYouMean(ext, familyIds),
            allowed: shortList(familyIds),
          );
        }
      } else {
        // Follow designer presets back to a built-in variant; a loop is a cycle.
        final chain = [preset.id];
        String? current = ext;
        while (current != null && presets.containsKey(current)) {
          if (chain.contains(current)) {
            if (current == preset.id) {
              report(
                'E-preset-extends',
                "'${preset.id}' extends itself through ${[...chain, current].join(' → ')}.",
                file: preset.path,
                pointer: '/extends',
                hint: 'Make one of these extend a built-in ${preset.family} variant.',
                allowed: shortList(def?.variants.map((v) => '${preset.family}.$v') ?? const []),
              );
            }
            break;
          }
          chain.add(current);
          current = presets[current]!.extendsId;
        }
      }
      if (presets.containsKey(ext)) usedPresets.add(ext);
    }
    final style = json['style'];
    if (json.containsKey('style')) _StyleCheck(this, preset.path).style(style, '/style', withStates: true);
  }
}
