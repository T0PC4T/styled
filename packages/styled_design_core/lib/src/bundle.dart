import 'package:meta/meta.dart';

import 'diagnostics.dart';
import 'documents.dart';
import 'screen.dart';

/// What the app ships and the runtime draws: tokens, designer presets and
/// screens, from one workspace. `design export` writes it as bundle.json; the
/// studio and tests build one in memory from a workspace.
@immutable
final class DesignBundle {
  static const currentFormat = 1;

  final String name;

  /// The screen a prototype starts on.
  final String start;

  /// The catalog version the bundle was validated against. The app refuses a
  /// bundle that needs a newer catalog than its registry.
  final int requiresCatalog;
  final String? hash;
  final TokenDoc tokens;
  final Map<String, PresetDoc> presets;
  final Map<String, ScreenDoc> screens;

  /// Per screen: the shape of its default fixture (keys and kinds, no
  /// values), its emits and the modals it can open.
  final Map<String, Object?> contracts;

  const DesignBundle({
    required this.screens,
    this.name = '',
    this.start = '',
    this.requiresCatalog = 1,
    this.hash,
    this.tokens = TokenDoc.empty,
    this.presets = const {},
    this.contracts = const {},
  });

  /// The screen with [id]; throws a [DesignError] when there is none.
  ScreenDoc screen(String id) =>
      screens[id] ??
      (throw DesignError("The bundle has no screen '$id'.", [
        Diagnostic.of(
          'E-screen-unknown',
          "No screen '$id'.",
          hint: switch (nearestName(id, screens.keys)) {
            final n? => "Did you mean '$n'?",
            null => null,
          },
        ),
      ]));

  factory DesignBundle.fromJson(Map<String, Object?> json) {
    if (json['format'] != currentFormat) throw DesignError('Unsupported bundle format ${json['format']}.');
    final screens = <String, ScreenDoc>{};
    for (final MapEntry(:key, :value) in ((json['screens'] as Map<String, Object?>?) ?? const {}).entries) {
      final screenJson = {'format': 1, 'id': key, ...value! as Map<String, Object?>};
      screens[key] = ScreenDoc.fromJson(screenJson, file: 'bundle.json#$key');
    }
    return DesignBundle(
      name: json['name'] as String? ?? '',
      start: json['start'] as String? ?? '',
      requiresCatalog: ((json['requires'] as Map<String, Object?>?)?['catalog'] as int?) ?? 1,
      hash: json['hash'] as String?,
      tokens: TokenDoc.fromJson({'tokens': json['tokens'] ?? const <String, Object?>{}}),
      presets: {
        for (final MapEntry(:key, :value) in ((json['presets'] as Map<String, Object?>?) ?? const {}).entries)
          key: PresetDoc.fromJson({'id': key, ...value! as Map<String, Object?>}),
      },
      screens: screens,
      contracts: (json['contracts'] as Map<String, Object?>?) ?? const {},
    );
  }
}
