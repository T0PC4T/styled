import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:styled/styled.dart';
import 'package:styled_design_core/styled_design_core.dart';

import 'engine_definitions.dart';
import 'registry.dart';
import 'token_registry.dart';

/// The catalog a registry offers: every component (the engine's included),
/// token, preset family, state, icon and formatter, with a content hash.
///
/// A library writes this as its catalog.json from a test, which also fails
/// when the checked-in file is stale. Built from the live registry, it cannot
/// disagree with what the runtime draws.
Catalog catalogOf(
  DesignRegistry registry, {
  int version = 1,
  List<String> modes = const ['light', 'dark'],
  List<String> states = const [
    'hovered', 'focused', 'pressed', 'error', 'disabled', //
    'selected', 'active', 'loading', 'approved', 'mobile', 'tablet', 'desktop',
  ],
}) {
  final components = {
    for (final d in [...registry.definitions.values, ...engineDefinitions]) d.spec.type: d.spec,
  };
  final tokens = <String, CatalogToken>{};
  final themes = {for (final mode in modes.where((m) => m != 'light')) mode: registry.themeFor(mode)};
  for (final token in registry.tokens) {
    final type = TokenRegistry.tokenTypeOf(token);
    tokens[token.key] = CatalogToken(
      key: token.key,
      type: type,
      light: tokenValueToJson(token.defaultValue),
      modes: {
        for (final MapEntry(key: mode, value: theme) in themes.entries)
          if (theme.has(token)) mode: tokenValueToJson(theme.get(token)),
      },
      group: registry.tokenGroups[token.key],
    );
  }
  final unhashed = Catalog(
    version: version,
    modes: modes,
    tokens: tokens,
    presets: registry.presetFamilies,
    states: states,
    icons: registry.icons.keys.toList()..sort(),
    formatters: registry.formatters.names.toList(),
    components: Map.fromEntries(components.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
    rules: registry.rules,
  );
  final hash = sha256.convert(utf8.encode(jsonEncode(unhashed.toJson())));
  return Catalog.fromJson({...unhashed.toJson(), 'hash': 'sha256:$hash'});
}

/// [catalog] as the canonical catalog.json text: two-space indent, trailing newline.
String catalogJson(Catalog catalog) => '${const JsonEncoder.withIndent('  ').convert(catalog.toJson())}\n';

/// A token value in its JSON form (see tokens.schema.json).
Object? tokenValueToJson(Object? value) => switch (value) {
  final Color c => _hex(c),
  final double d => d == d.roundToDouble() && d.isFinite ? d.toInt() : d,
  final Duration d => d.inMilliseconds,
  final FontWeight w => 'w${w.value}',
  final ShadowLevel s => {
    'opacity': s.opacity,
    'blurRadius': s.blurRadius,
    if (s.spreadRadius != 0) 'spreadRadius': s.spreadRadius,
    if (s.dx != 0) 'dx': s.dx,
    if (s.dy != 0) 'dy': s.dy,
  },
  _ => value,
};

String _hex(Color c) {
  final argb = c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
  return argb.startsWith('FF') ? '#${argb.substring(2)}' : '#$argb';
}
