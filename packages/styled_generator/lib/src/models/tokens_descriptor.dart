/// Intermediate data models describing a `@StyledTokens` class to generate.
class TokensDescriptor {
  /// Name of the annotated spec class.
  final String specName;
  final String className;
  final String extensionName;
  final bool generateDefaultMap;
  final List<TokenDescriptor> tokens;

  const TokensDescriptor({
    required this.specName,
    required this.className,
    required this.extensionName,
    required this.generateDefaultMap,
    required this.tokens,
  });

  /// Theme modes declared on any token, in declaration order.
  List<String> get modeNames => <String>{for (final t in tokens) ...t.modes.keys}.toList();
}

/// A single design token.
class TokenDescriptor {
  /// Field name in the spec, and of the generated constant and getter.
  final String name;

  /// Key in the theme, including any prefix.
  final String key;
  final String typeName;

  /// Source of the default value.
  final String initializer;
  final String? docComment;

  /// Mode name to the source of the value in that mode.
  final Map<String, String> modes;

  const TokenDescriptor({
    required this.name,
    required this.key,
    required this.typeName,
    required this.initializer,
    required this.docComment,
    required this.modes,
  });

  /// [typeName] made nullable, for typed override parameters.
  String get nullableTypeName => typeName.endsWith('?') ? typeName : '$typeName?';
}
