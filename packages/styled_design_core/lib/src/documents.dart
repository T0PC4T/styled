import 'package:meta/meta.dart';

import 'catalog.dart';
import 'diagnostics.dart';

/// One entry of tokens/tokens.json: an override of a library token (no
/// [type]) or a new token ([type] and a `light` value).
@immutable
final class TokenEntry {
  final String key;
  final String? type;
  final String? description;

  /// Value per mode, in token JSON form.
  final Map<String, Object?> values;

  const TokenEntry({required this.key, required this.values, this.type, this.description});

  bool get isNew => type != null;

  factory TokenEntry.fromJson(String key, Map<String, Object?> json) => TokenEntry(
    key: key,
    type: json['type'] as String?,
    description: json['description'] as String?,
    values: {...(json['values'] as Map<String, Object?>? ?? const {})},
  );

  Map<String, Object?> toJson() => {'type': ?type, 'description': ?description, 'values': values};
}

/// tokens/tokens.json: token overrides and new tokens.
@immutable
final class TokenDoc {
  final Map<String, TokenEntry> tokens;

  const TokenDoc([this.tokens = const {}]);

  static const empty = TokenDoc();

  factory TokenDoc.fromJson(Map<String, Object?> json) => TokenDoc({
    for (final MapEntry(:key, :value) in ((json['tokens'] as Map<String, Object?>?) ?? const {}).entries)
      key: TokenEntry.fromJson(key, value! as Map<String, Object?>),
  });

  Map<String, Object?> toJson() => {
    'format': 1,
    'tokens': {for (final t in tokens.values) t.key: t.toJson()},
  };
}

/// A designer preset: a new variant of an existing family, a base variant plus
/// a style delta in tokens.
@immutable
final class PresetDoc {
  /// `StyleCard.highlight`.
  final String id;

  /// The variant it builds on: `StyleCard.surface`.
  final String extendsId;

  final String? description;

  /// The style delta, in the Style JSON form.
  final Map<String, Object?> style;

  const PresetDoc({required this.id, required this.extendsId, required this.style, this.description});

  String get family => Catalog.splitPreset(id)!.$1;
  String get variant => Catalog.splitPreset(id)!.$2;

  factory PresetDoc.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final extendsId = json['extends'];
    final style = json['style'];
    if (id is! String || Catalog.splitPreset(id) == null) {
      throw const DesignError("A preset needs an 'id' such as StyleCard.highlight.");
    }
    if (extendsId is! String) throw DesignError("Preset '$id' needs 'extends'.");
    if (style is! Map<String, Object?>) throw DesignError("Preset '$id' needs a 'style' object.");
    return PresetDoc(id: id, extendsId: extendsId, style: style, description: json['description'] as String?);
  }

  Map<String, Object?> toJson() => {
    'format': 1,
    'id': id,
    'extends': extendsId,
    'description': ?description,
    'style': style,
  };
}

/// design.json, the workspace manifest.
@immutable
final class WorkspaceManifest {
  final String name;

  /// The screen the prototype opens on.
  final String start;
  final int? catalogVersion;
  final String? catalogHash;

  /// Where `design export` writes the bundle, relative to design.json.
  final String? exportBundle;

  /// none, default or all.
  final String exportFixtures;

  const WorkspaceManifest({
    required this.name,
    required this.start,
    this.catalogVersion,
    this.catalogHash,
    this.exportBundle,
    this.exportFixtures = 'none',
  });

  factory WorkspaceManifest.fromJson(Map<String, Object?> json) {
    final catalog = json['catalog'] as Map<String, Object?>?;
    final export = json['export'] as Map<String, Object?>?;
    return WorkspaceManifest(
      name: json['name'] as String? ?? '',
      start: json['start'] as String? ?? '',
      catalogVersion: catalog?['version'] as int?,
      catalogHash: catalog?['hash'] as String?,
      exportBundle: export?['bundle'] as String?,
      exportFixtures: export?['fixtures'] as String? ?? 'none',
    );
  }
}
