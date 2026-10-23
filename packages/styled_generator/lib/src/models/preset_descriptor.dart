/// Intermediate data models describing a `@StyledPreset` resolver to generate.
class PresetDescriptor {
  /// Name of the annotated spec class, which the generated code calls into.
  final String specName;
  final String className;
  final String enumName;
  final String? docComment;

  /// The `base` member, merged under every variant.
  final PresetMemberDescriptor? base;
  final List<VariantDescriptor> variants;
  final List<StateDescriptor> states;

  /// Parameters of the spec members, which become fields of the resolver.
  final List<PresetFieldDescriptor> fields;

  const PresetDescriptor({
    required this.specName,
    required this.className,
    required this.enumName,
    required this.docComment,
    required this.base,
    required this.variants,
    required this.states,
    required this.fields,
  });

  /// The variant used by the unnamed constructor.
  VariantDescriptor get defaultVariant => variants.firstWhere((v) => v.isDefault, orElse: () => variants.first);

  /// States that apply to every variant.
  List<StateDescriptor> get globalStates => [for (final s in states) if (s.variants.isEmpty) s];

  /// States limited to [variant].
  List<StateDescriptor> statesFor(VariantDescriptor variant) => [
        for (final s in states)
          if (s.variants.contains(variant.name)) s,
      ];

  /// Every member that produces a style.
  List<PresetMemberDescriptor> get members => [
        ?base,
        ...variants.map((v) => v.member),
        ...states.map((s) => s.member),
      ];

  /// Whether any member takes the injected `StyledScreen`.
  bool get usesScreen => members.any((m) => m.usesScreen);
}

/// A spec member that produces a `Style`: a static method or a static field.
class PresetMemberDescriptor {
  final String name;
  final String? docComment;
  final bool isField;
  final List<PresetArgumentDescriptor> arguments;

  const PresetMemberDescriptor({
    required this.name,
    required this.docComment,
    required this.isField,
    required this.arguments,
  });

  bool get usesScreen => arguments.any((a) => a.isScreen);
}

/// A parameter of a spec method, as passed from the generated `resolve`.
class PresetArgumentDescriptor {
  final String name;
  final bool isNamed;

  /// Whether this is the injected `StyledScreen`, rather than a resolver field.
  final bool isScreen;

  const PresetArgumentDescriptor({required this.name, required this.isNamed, required this.isScreen});
}

/// A variant: a value of the generated enum, with its own constructor.
class VariantDescriptor {
  final PresetMemberDescriptor member;
  final bool isDefault;
  final List<String> aliases;

  const VariantDescriptor({required this.member, required this.isDefault, required this.aliases});

  String get name => member.name;
}

/// A style applied while a `StyleState` is active.
class StateDescriptor {
  final PresetMemberDescriptor member;

  /// Dart expression for the `StyleState` this member overrides.
  final String stateExpression;

  /// Variant names this override is limited to; empty means every variant.
  final List<String> variants;

  const StateDescriptor({required this.member, required this.stateExpression, required this.variants});
}

/// A field of the generated resolver, taken from a spec member parameter.
class PresetFieldDescriptor {
  final String name;
  final String typeName;
  final String? defaultValueCode;
  final bool isRequired;

  const PresetFieldDescriptor({
    required this.name,
    required this.typeName,
    required this.defaultValueCode,
    required this.isRequired,
  });

  /// [typeName] made nullable, for `copyWith` parameters.
  String get nullableTypeName => typeName.endsWith('?') ? typeName : '$typeName?';
}
