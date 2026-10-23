import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';
import 'package:styled_annotation/styled_annotation.dart';

import '../models/preset_descriptor.dart';
import '../utils/naming.dart';

/// Layer 1 Inspector: Extracts a preset specification from a `@StyledPreset`
/// spec class.
///
/// Classifies each static member of the spec:
/// 1. `@Variant()` members are variants, and `@On('state')` members are states.
/// 2. `base` is merged under every variant.
/// 3. Members named after a built-in state (`hovered`, `mobile`, ...) are
///    states for every variant, and `${variant}${State}` members are states
///    for that variant only.
/// 4. Any other public `Style` member is a variant.
///
/// Then validates the result, so the writer can assume a well-formed
/// [PresetDescriptor].
class PresetInspector {
  /// Built-in states recognised by member name, mapped to the generated expression.
  static const builtinStates = <String, String>{
    'hovered': 'StyleState.hovered',
    'pressed': 'StyleState.pressed',
    'focused': 'StyleState.focused',
    'disabled': 'StyleState.disabled',
    'error': 'StyleState.error',
    'mobile': 'StyledScreen.mobile.state',
    'tablet': 'StyledScreen.tablet.state',
    'desktop': 'StyledScreen.desktop.state',
  };

  static const _variantChecker = TypeChecker.any([
    TypeChecker.typeNamedLiterally('Variant', inPackage: 'styled_annotation'),
    TypeChecker.typeNamed(Variant),
  ]);

  static const _onChecker = TypeChecker.any([
    TypeChecker.typeNamedLiterally('On', inPackage: 'styled_annotation'),
    TypeChecker.typeNamed(On),
  ]);

  /// Parameter types that would let a spec read concrete theme values.
  static const _forbiddenParameterTypes = {'BuildContext', 'StyledTheme', 'Size'};

  static PresetDescriptor inspect(ClassElement element, ConstantReader annotation) {
    final specName = element.name!;
    final className = Naming.nonEmpty(annotation.peek('name')?.stringValue) ?? Naming.presetClassName(specName);
    final enumName =
        Naming.nonEmpty(annotation.peek('variantEnumName')?.stringValue) ?? Naming.variantEnumName(className);

    final members = _members(element);
    final (base, variants, states) = _classify(members);
    _validate(element, members, base, variants, states);

    return PresetDescriptor(
      specName: specName,
      className: className,
      enumName: enumName,
      docComment: element.documentationComment,
      base: base,
      variants: variants,
      states: states,
      fields: _fields([?base, ...variants.map((v) => v.member), ...states.map((s) => s.member)], members),
    );
  }

  /// Static methods and static `Style` fields of the spec, by name.
  static Map<String, _Member> _members(ClassElement element) => {
        for (final m in element.methods)
          if (m.isStatic) m.name!: _Member.method(m),
        for (final f in element.fields)
          if (f.isStatic && f.type.getDisplayString() == 'Style') f.name!: _Member.field(f),
      };

  static (PresetMemberDescriptor?, List<VariantDescriptor>, List<StateDescriptor>) _classify(
    Map<String, _Member> members,
  ) {
    PresetMemberDescriptor? base;
    final annotatedVariants = <VariantDescriptor>[];
    final states = <StateDescriptor>[];
    final candidates = <PresetMemberDescriptor>[];

    for (final member in members.values) {
      final name = member.name;
      final variantAnnotation = _variantChecker.firstAnnotationOf(member.element);
      final onAnnotation = _onChecker.firstAnnotationOf(member.element);

      if (variantAnnotation != null) {
        final reader = ConstantReader(variantAnnotation);
        annotatedVariants.add(VariantDescriptor(
          member: member.describe(),
          isDefault: reader.peek('isDefault')?.boolValue ?? false,
          aliases: [for (final a in reader.peek('aliases')?.listValue ?? const []) a.toStringValue()!],
        ));
      } else if (onAnnotation != null) {
        final reader = ConstantReader(onAnnotation);
        states.add(StateDescriptor(
          member: member.describe(),
          stateExpression: "const StyleState('${reader.read('state').stringValue}')",
          variants: [for (final v in reader.peek('variants')?.listValue ?? const []) v.toStringValue()!],
        ));
      } else if (name.startsWith('_')) {
        continue;
      } else if (name == 'base') {
        base = member.describe();
      } else if (builtinStates[name] case final state?) {
        states.add(StateDescriptor(member: member.describe(), stateExpression: state, variants: const []));
      } else if (member.typeName == 'Style') {
        candidates.add(member.describe());
      }
    }

    // Unannotated `${variant}${State}` members are states of that variant.
    final variantNames = {...annotatedVariants.map((v) => v.name), ...candidates.map((m) => m.name)};
    final fallbackVariants = <VariantDescriptor>[];
    for (final member in candidates) {
      if (_scopedState(member.name, variantNames) case (final variant, final state)) {
        states.add(StateDescriptor(member: member, stateExpression: builtinStates[state]!, variants: [variant]));
      } else {
        fallbackVariants.add(VariantDescriptor(member: member, isDefault: false, aliases: const []));
      }
    }

    return (base, [...annotatedVariants, ...fallbackVariants], states);
  }

  /// Splits `primaryHovered` into `(primary, hovered)` when `primary` is a variant.
  static (String, String)? _scopedState(String name, Set<String> variantNames) {
    for (final state in builtinStates.keys) {
      final suffix = '${state[0].toUpperCase()}${state.substring(1)}';
      if (name.length > suffix.length && name.endsWith(suffix)) {
        final variant = name.substring(0, name.length - suffix.length);
        if (variantNames.contains(variant)) return (variant, state);
      }
    }
    return null;
  }

  static void _validate(
    ClassElement element,
    Map<String, _Member> members,
    PresetMemberDescriptor? base,
    List<VariantDescriptor> variants,
    List<StateDescriptor> states,
  ) {
    final spec = element.name;
    if (variants.isEmpty) {
      throw InvalidGenerationSourceError(
        'Class $spec must declare at least one variant: a @Variant() member, or a public static method or field of type Style.',
        todo: 'Add a `static const Style primary = Style(...)` field or a `@Variant()` method to $spec.',
        element: element,
      );
    }

    for (final descriptor in [?base, ...variants.map((v) => v.member), ...states.map((s) => s.member)]) {
      final member = members[descriptor.name]!;
      if (member.typeName != 'Style') {
        throw InvalidGenerationSourceError(
          '${member.name} on $spec must be a Style, not ${member.typeName}.',
          todo: 'Change ${member.name} to return a Style, or make it private.',
          element: member.element,
        );
      }
      for (final param in member.params) {
        final type = param.type.getDisplayString();
        if (_forbiddenParameterTypes.contains(type)) {
          throw InvalidGenerationSourceError(
            '${member.name} on $spec takes a $type. Spec members must not read concrete theme values: '
            'reference tokens directly (AppTokens.primary, AlphaOf(AppTokens.primary, AppTokens.opacitySubtle)) '
            'and the engine resolves them against the active theme. Only `StyledScreen screen` is injected.',
            todo: 'Remove the $type parameter from ${member.name}.',
            element: member.element,
          );
        }
        if (param.isPositional && !_isScreen(param)) {
          throw InvalidGenerationSourceError(
            'Parameter ${param.name} of ${member.name} on $spec must be named, or be `StyledScreen screen`.',
            todo: 'Wrap ${param.name} in `{}` to make it a named parameter.',
            element: member.element,
          );
        }
      }
    }

    final defaults = variants.where((v) => v.isDefault).toList();
    if (defaults.length > 1) {
      throw InvalidGenerationSourceError(
        'Only one variant on $spec can be the default; found ${defaults.map((v) => v.name).join(', ')}.',
        todo: 'Keep `isDefault: true` on one variant only.',
        element: members[defaults[1].name]!.element,
      );
    }

    final names = <String>{for (final v in variants) v.name};
    for (final v in variants) {
      for (final alias in v.aliases) {
        if (!names.add(alias)) {
          throw InvalidGenerationSourceError(
            'Alias "$alias" on ${v.name} in $spec clashes with another variant or alias.',
            todo: 'Rename or remove the alias "$alias".',
            element: members[v.name]!.element,
          );
        }
      }
    }

    final variantNames = {for (final v in variants) v.name};
    for (final s in states) {
      for (final v in s.variants) {
        if (!variantNames.contains(v)) {
          throw InvalidGenerationSourceError(
            '${s.member.name} on $spec targets unknown variant "$v".',
            todo: 'Use one of: ${variantNames.join(', ')}.',
            element: members[s.member.name]!.element,
          );
        }
      }
    }
  }

  /// Parameters of [styleMembers], other than the injected screen, in first-seen order.
  static List<PresetFieldDescriptor> _fields(
    List<PresetMemberDescriptor> styleMembers,
    Map<String, _Member> members,
  ) {
    final fields = <String, PresetFieldDescriptor>{};
    for (final descriptor in styleMembers) {
      for (final param in members[descriptor.name]!.params) {
        if (_isScreen(param)) continue;
        fields.putIfAbsent(
          param.name!,
          () => PresetFieldDescriptor(
            name: param.name!,
            typeName: param.type.getDisplayString(),
            defaultValueCode: param.defaultValueCode,
            isRequired: param.isRequiredNamed,
          ),
        );
      }
    }
    return fields.values.toList();
  }

  static bool _isScreen(FormalParameterElement p) => p.type.getDisplayString() == 'StyledScreen';
}

/// A spec member as the analyzer sees it, kept for validation and error reporting.
class _Member {
  final Element element;
  final String name;
  final String typeName;
  final List<FormalParameterElement> params;
  final bool isField;
  final String? docComment;

  _Member.method(MethodElement method)
      : element = method,
        name = method.name!,
        typeName = method.returnType.getDisplayString(),
        params = method.formalParameters,
        isField = false,
        docComment = method.documentationComment;

  _Member.field(FieldElement field)
      : element = field,
        name = field.name!,
        typeName = field.type.getDisplayString(),
        params = const [],
        isField = true,
        docComment = field.documentationComment;

  PresetMemberDescriptor describe() => PresetMemberDescriptor(
        name: name,
        docComment: docComment,
        isField: isField,
        arguments: [
          for (final p in params)
            PresetArgumentDescriptor(name: p.name!, isNamed: p.isNamed, isScreen: PresetInspector._isScreen(p)),
        ],
      );
}
