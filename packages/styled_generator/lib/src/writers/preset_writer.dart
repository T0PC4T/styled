import '../models/preset_descriptor.dart';
import '../utils/doc_utils.dart';

/// Layer 3 Emitter: Writes the variant enum and `StyleResolver` class for a
/// [PresetDescriptor].
///
/// Emits:
/// 1. `enum <Name>Variant`: one value per variant.
/// 2. `class Style<Name> extends StyleResolver`: a const constructor per
///    variant and alias, `fromVariant`, the fields taken from spec member
///    parameters, `resolve`, `copyWith`, `==`, `hashCode` and `toString`.
///
/// `resolve` applies, lowest precedence first: `base`, states for every
/// variant, the variant itself (including states it attaches), then states
/// for that variant only.
class PresetWriter {
  /// Emits the Dart source for [descriptor].
  static String write(PresetDescriptor descriptor) {
    final out = StringBuffer();
    _writeEnum(out, descriptor);
    _writeClass(out, descriptor);
    return out.toString();
  }

  static void _writeEnum(StringBuffer out, PresetDescriptor d) {
    out.writeln('/// Variant options for [${d.className}].');
    out.writeln('enum ${d.enumName} {');
    for (final v in d.variants) {
      writeDocComment(out, v.member.docComment, indent: '  ');
      out.writeln('  ${v.name},');
    }
    out.writeln('}');
    out.writeln();
  }

  static void _writeClass(StringBuffer out, PresetDescriptor d) {
    if (d.docComment != null) {
      writeDocComment(out, d.docComment, indent: '');
      out.writeln('///');
    }
    out.writeln('/// Style preset generated from [${d.specName}].');
    out.writeln('class ${d.className} extends StyleResolver {');
    out.writeln('  final ${d.enumName} variant;');
    for (final f in d.fields) {
      out.writeln('  final ${f.typeName} ${f.name};');
    }
    out.writeln();
    _writeConstructors(out, d);
    _writeResolve(out, d);
    _writeCopyWith(out, d);
    _writeEquality(out, d);
    out.writeln('}');
  }

  static void _writeConstructors(StringBuffer out, PresetDescriptor d) {
    final params = d.fields.map((f) {
      if (f.isRequired) return '    required this.${f.name},';
      if (f.defaultValueCode != null) return '    this.${f.name} = ${f.defaultValueCode},';
      return '    this.${f.name},';
    }).join('\n');

    void ctor(String name, String variant, String? doc) {
      writeDocComment(out, doc, indent: '  ');
      final target = name.isEmpty ? d.className : '${d.className}.$name';
      out.writeln(params.isEmpty
          ? '  const $target() : variant = ${d.enumName}.$variant;'
          : '  const $target({\n$params\n  }) : variant = ${d.enumName}.$variant;');
    }

    final defaultVariant = d.defaultVariant;
    ctor('', defaultVariant.name, defaultVariant.member.docComment);
    for (final v in d.variants) {
      ctor(v.name, v.name, v.member.docComment);
      for (final alias in v.aliases) {
        ctor(alias, v.name, v.member.docComment ?? '/// Alias for [${d.className}.${v.name}].');
      }
    }
    out.writeln(params.isEmpty
        ? '  const ${d.className}.fromVariant(this.variant);'
        : '  const ${d.className}.fromVariant(\n    this.variant, {\n$params\n  });');
    out.writeln();
  }

  static void _writeResolve(StringBuffer out, PresetDescriptor d) {
    String withStates(String expression, Iterable<StateDescriptor> states) {
      final buffer = StringBuffer(expression);
      for (final s in states) {
        buffer.write('\n          .on(${s.stateExpression}, style: ${_call(d.specName, s.member)})');
      }
      return buffer.toString();
    }

    out.writeln('  @override');
    out.writeln('  Style resolve(BuildContext context) {');
    if (d.usesScreen) out.writeln('    final screen = StyledScreen.of(context);');

    final globalStates = d.globalStates;
    final hasShared = d.base != null || globalStates.isNotEmpty;
    if (hasShared) {
      final baseCall = d.base != null ? _call(d.specName, d.base!) : 'const Style()';
      out.writeln('    final base = ${withStates(baseCall, globalStates)};');
    }
    out.writeln('    return switch (variant) {');
    for (final v in d.variants) {
      final call = _call(d.specName, v.member);
      final merged = hasShared ? 'base.merge($call)' : call;
      out.writeln('      ${d.enumName}.${v.name} => ${withStates(merged, d.statesFor(v))},');
    }
    out.writeln('    };');
    out.writeln('  }');
    out.writeln();
  }

  static void _writeCopyWith(StringBuffer out, PresetDescriptor d) {
    out.writeln('  /// A copy with the given fields replaced.');
    out.writeln('  ${d.className} copyWith({');
    out.writeln('    ${d.enumName}? variant,');
    for (final f in d.fields) {
      out.writeln('    ${f.nullableTypeName} ${f.name},');
    }
    out.writeln('  }) => ${d.className}.fromVariant(');
    out.writeln('        variant ?? this.variant,');
    for (final f in d.fields) {
      out.writeln('        ${f.name}: ${f.name} ?? this.${f.name},');
    }
    out.writeln('      );');
    out.writeln();
  }

  static void _writeEquality(StringBuffer out, PresetDescriptor d) {
    final fields = d.fields;
    final checks = ['variant == other.variant', ...fields.map((f) => '${f.name} == other.${f.name}')];
    out.writeln('  @override');
    out.writeln('  bool operator ==(Object other) =>');
    out.writeln('      identical(this, other) ||');
    out.writeln('      other is ${d.className} &&');
    out.writeln('          runtimeType == other.runtimeType &&');
    out.writeln('          ${checks.join(' &&\n          ')};');
    out.writeln();
    out.writeln('  @override');
    out.writeln(fields.isEmpty
        ? '  int get hashCode => variant.hashCode;'
        : '  int get hashCode => Object.hash(variant, ${fields.map((f) => f.name).join(', ')});');
    out.writeln();
    out.writeln('  @override');
    out.writeln(fields.isEmpty
        ? "  String toString() => '${d.className}.\${variant.name}';"
        : "  String toString() => '${d.className}.\${variant.name}(${fields.map((f) => '${f.name}: \$${f.name}').join(', ')})';");
  }

  /// `Spec.primary` for a field, `Spec.primary(size: size, screen)` for a method.
  static String _call(String spec, PresetMemberDescriptor member) {
    if (member.isField) return '$spec.${member.name}';
    final args = member.arguments.map((a) {
      final value = a.isScreen ? 'screen' : a.name;
      return a.isNamed ? '${a.name}: $value' : value;
    });
    return '$spec.${member.name}(${args.join(', ')})';
  }
}
