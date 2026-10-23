import 'dart:async';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:styled_annotation/styled_annotation.dart';

import 'ast_utils.dart';

class StyledTokensGenerator extends GeneratorForAnnotation<StyledTokens> {
  const StyledTokensGenerator();

  @override
  FutureOr<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@StyledTokens can only be applied to classes.',
        element: element,
      );
    }

    final rawClassName = annotation.peek('className')?.stringValue;
    final className = (rawClassName != null && rawClassName.isNotEmpty)
        ? rawClassName
        : _deriveClassName(element.name!);

    final rawExtensionName = annotation.peek('extensionName')?.stringValue;
    final extensionName =
        (rawExtensionName != null && rawExtensionName.isNotEmpty)
            ? rawExtensionName
            : '${className}Extension';

    final generateDefaultMap =
        annotation.peek('generateDefaultMap')?.boolValue ?? true;

    // Read AST initializers
    final astFields =
        await extractClassFieldsFromAst(buildStep, element.name!);

    const tokenChecker = TypeChecker.any([
      TypeChecker.typeNamedLiterally('Token', inPackage: 'styled_annotation'),
      TypeChecker.typeNamedLiterally('Token', inPackage: 'styled'),
      TypeChecker.typeNamed(Token),
    ]);

    final tokens = <_TokenFieldInfo>[];

    for (final field in element.fields) {
      if (!field.isStatic) continue;

      final fieldName = field.name!;
      final tokenAnnotation = tokenChecker.firstAnnotationOf(field);
      final tokenReader =
          tokenAnnotation != null ? ConstantReader(tokenAnnotation) : null;
      final explicitKey = tokenReader?.peek('key')?.stringValue;
      final key = explicitKey ?? fieldName;

      final astInfo = astFields[fieldName];

      // Determine type
      String typeName;
      if (astInfo?.typeName != null && astInfo!.typeName!.isNotEmpty) {
        typeName = astInfo.typeName!;
      } else {
        final displayType = field.type.getDisplayString();
        if (displayType != 'dynamic') {
          typeName = displayType;
        } else {
          final constVal = field.computeConstantValue();
          typeName = constVal?.type?.getDisplayString() ?? 'dynamic';
        }
      }

      // Determine initializer expression
      String initializerSource;
      if (astInfo?.initializerSource != null &&
          astInfo!.initializerSource!.isNotEmpty) {
        initializerSource = astInfo.initializerSource!;
      } else {
        final constVal = field.computeConstantValue();
        if (constVal != null) {
          initializerSource = _formatDartObject(constVal);
        } else {
          throw InvalidGenerationSourceError(
            'Field $fieldName on ${element.name} must be a const value with an initializer.',
            element: field,
          );
        }
      }

      tokens.add(_TokenFieldInfo(
        fieldName: fieldName,
        key: key,
        typeName: typeName,
        initializerSource: initializerSource,
      ));
    }

    if (tokens.isEmpty) {
      throw InvalidGenerationSourceError(
        'Class ${element.name} must declare at least one static const token field.',
        element: element,
      );
    }

    final buffer = StringBuffer();

    // 1. Tokens Container Class
    buffer.writeln('/// Strongly-typed token identifiers generated from [${element.name}].');
    buffer.writeln('abstract final class $className {');
    for (final t in tokens) {
      buffer.writeln(
          '  static const ${t.fieldName} = ThemeToken<${t.typeName}>(\'${t.key}\', ${t.initializerSource});');
    }
    buffer.writeln();

    // List of all tokens
    buffer.writeln('  /// All tokens defined in [${element.name}].');
    buffer.writeln('  static const all = <ThemeToken<dynamic>>[');
    for (final t in tokens) {
      buffer.writeln('    ${t.fieldName},');
    }
    buffer.writeln('  ];');

    // toDefaultMap
    if (generateDefaultMap) {
      buffer.writeln();
      buffer.writeln('  /// Map of all token keys to their default fallback values.');
      buffer.writeln('  static Map<String, dynamic> toDefaultMap() => {');
      for (final t in tokens) {
        buffer.writeln('    ${t.fieldName}.key: ${t.fieldName}.defaultValue,');
      }
      buffer.writeln('  };');
    }

    buffer.writeln('}');
    buffer.writeln();

    // 2. StyledTheme Extension
    buffer.writeln('/// Convenient typed token accessors on [StyledTheme].');
    buffer.writeln('extension $extensionName on StyledTheme {');
    for (final t in tokens) {
      buffer.writeln(
          '  ${t.typeName} get ${t.fieldName} => get($className.${t.fieldName});');
    }
    buffer.writeln('}');

    return buffer.toString();
  }

  static String _deriveClassName(String elementName) {
    var name = elementName;
    if (name.startsWith('_')) name = name.substring(1);
    if (name.endsWith('Spec')) name = name.substring(0, name.length - 4);
    if (!name.endsWith('Tokens')) name = '${name}Tokens';
    return name;
  }

  static String _formatDartObject(DartObject object) {
    if (object.isNull) return 'null';
    if (object.toBoolValue() != null) return object.toBoolValue().toString();
    if (object.toIntValue() != null) return object.toIntValue().toString();
    if (object.toDoubleValue() != null) return object.toDoubleValue().toString();
    if (object.toStringValue() != null) return '\'${object.toStringValue()}\'';

    final typeName = object.type?.getDisplayString() ?? '';
    if (typeName.contains('Color')) {
      final value = object.getField('value')?.toIntValue();
      if (value != null) {
        final hex = value.toRadixString(16).toUpperCase().padLeft(8, '0');
        return 'Color(0x$hex)';
      }
    }
    return object.toString();
  }
}

class _TokenFieldInfo {
  final String fieldName;
  final String key;
  final String typeName;
  final String initializerSource;

  _TokenFieldInfo({
    required this.fieldName,
    required this.key,
    required this.typeName,
    required this.initializerSource,
  });
}
