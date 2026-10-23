import 'dart:ui' show Color, FontWeight;

import 'package:flutter/foundation.dart';

/// A strongly-typed design token key paired with its default fallback value.
///
/// Designed to be defined by downstream design systems and applications
/// (e.g. `package:analytics_ui`) rather than hardcoded in the core styling engine.
@immutable
final class ThemeToken<T> {
  final String key;
  final T defaultValue;

  const ThemeToken(this.key, this.defaultValue);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ThemeToken<dynamic> &&
          runtimeType == other.runtimeType &&
          key == other.key);

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'ThemeToken<$T>($key, default: $defaultValue)';
}

/// An immutable, open-ended token dictionary representing an active application theme.
///
/// [StyledTheme] is completely un-opinionated and stores tokens dynamically as key-value pairs.
/// Consuming design systems and applications define typed design tokens ([ThemeToken]) and
/// provide ergonomic property getters via Dart extensions.
@immutable
final class StyledTheme {
  final Map<String, Object?> _values;
  final Map<String, dynamic> metadata;

  const StyledTheme([this._values = const {}, this.metadata = const {}]);

  /// Creates a [StyledTheme] from a map of token keys to values.
  factory StyledTheme.fromMap(
    Map<String, Object?> values, [
    Map<String, dynamic> metadata = const {},
  ]) => StyledTheme(Map.unmodifiable(values), Map.unmodifiable(metadata));

  /// Deserializes a [StyledTheme] from a JSON map.
  /// Automatically parses hex color strings (`#RRGGBB` / `#AARRGGBB`) and font weight keys (`w100`..`w900`).
  factory StyledTheme.fromJson(Map<String, dynamic> json) {
    final values = <String, Object?>{};
    final metadata = <String, dynamic>{};

    for (final MapEntry(:key, :value) in json.entries) {
      if (key == 'metadata' && value is Map<String, dynamic>) {
        metadata.addAll(value);
      } else {
        values[key] = _parseValue(value);
      }
    }

    return StyledTheme(values, metadata);
  }

  static Object? _parseValue(Object? value) => switch (value) {
    final String s when s.startsWith('#') => _parseHexColor(s) ?? s,
    'w100' => FontWeight.w100,
    'w200' => FontWeight.w200,
    'w300' => FontWeight.w300,
    'w400' => FontWeight.w400,
    'w500' => FontWeight.w500,
    'w600' => FontWeight.w600,
    'w700' => FontWeight.w700,
    'w800' => FontWeight.w800,
    'w900' => FontWeight.w900,
    _ => value,
  };

  static Color? _parseHexColor(String hexString) {
    final raw = hexString.substring(1);
    final hex = switch (raw.length) {
      6 => 'FF$raw',
      _ => raw,
    };
    final parsed = int.tryParse(hex, radix: 16);
    return parsed != null ? Color(parsed) : null;
  }

  static String _formatColor(Color color) {
    final argb = color
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase();
    return ((color.toARGB32() >> 24) & 0xFF == 255)
        ? '#${argb.substring(2)}'
        : '#$argb';
  }

  /// Serializes this [StyledTheme] into a JSON map.
  Map<String, dynamic> toJson() => {
    for (final MapEntry(:key, :value) in _values.entries)
      key: switch (value) {
        final Color c => _formatColor(c),
        final FontWeight w => 'w${w.value}',
        _ => value,
      },
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  /// Type-safe retrieval with guaranteed fallback to [token.defaultValue].
  T get<T>(ThemeToken<T> token) {
    final val = _values[token.key];
    if (val is T) return val;
    return switch (val) {
      final num n when T == double => n.toDouble() as T,
      final num n when T == int => n.toInt() as T,
      _ => token.defaultValue,
    };
  }

  /// Ergonomic shorthand for [get].
  T call<T>(ThemeToken<T> token) => get(token);

  /// Checks if an explicit value for [token] is present in the theme map.
  bool has(ThemeToken<dynamic> token) => _values.containsKey(token.key);

  /// Creates a copy of this theme with a single token updated.
  StyledTheme set<T>(ThemeToken<T> token, T value) =>
      copyWith(overrides: {token.key: value});

  /// Creates a copy of this theme with multiple token overrides and metadata.
  StyledTheme copyWith({
    Map<String, Object?>? overrides,
    Map<String, dynamic>? metadata,
  }) => StyledTheme({
    ..._values,
    if (overrides != null) ...overrides,
  }, metadata ?? this.metadata);

  /// Merges another theme's values over this theme.
  StyledTheme merge(StyledTheme other) => StyledTheme(
    {..._values, ...other._values},
    {...metadata, ...other.metadata},
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StyledTheme &&
          runtimeType == other.runtimeType &&
          mapEquals(_values, other._values) &&
          mapEquals(metadata, other.metadata));

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(_values.entries),
    Object.hashAllUnordered(metadata.entries),
  );
}
