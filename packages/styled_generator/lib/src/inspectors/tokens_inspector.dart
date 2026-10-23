import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:styled_annotation/styled_annotation.dart';

import '../models/tokens_descriptor.dart';
import '../utils/ast_utils.dart';
import '../utils/naming.dart';

/// Layer 1 Inspector: Extracts token specifications from a `@StyledTokens`
/// spec class.
///
/// Every static field becomes a token. Types, initializers, trailing `//`
/// comments and `@Token` mode values are read from the source, so they are
/// emitted exactly as written; the element model is the fallback.
class TokensInspector {
  static const _tokenChecker = TypeChecker.any([
    TypeChecker.typeNamedLiterally('Token', inPackage: 'styled_annotation'),
    TypeChecker.typeNamed(Token),
  ]);

  static Future<TokensDescriptor> inspect(
    ClassElement element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    final specName = element.name!;
    final className = Naming.nonEmpty(annotation.peek('className')?.stringValue) ?? Naming.tokensClassName(specName);
    final prefix = Naming.nonEmpty(annotation.peek('prefix')?.stringValue);
    final astFields = await extractClassFieldsFromAst(buildStep, specName);

    final tokens = [
      for (final field in element.fields)
        if (field.isStatic) _token(field, astFields[field.name!], specName, prefix),
    ];

    if (tokens.isEmpty) {
      throw InvalidGenerationSourceError(
        'Class $specName must declare at least one static const token field.',
        todo: 'Add a field such as `static const primary = Color(0xFF2563EB);` to $specName.',
        element: element,
      );
    }

    return TokensDescriptor(
      specName: specName,
      className: className,
      extensionName: Naming.nonEmpty(annotation.peek('extensionName')?.stringValue) ?? '${className}Extension',
      generateDefaultMap: annotation.peek('generateDefaultMap')?.boolValue ?? true,
      tokens: tokens,
    );
  }

  static TokenDescriptor _token(FieldElement field, AstFieldInfo? ast, String specName, String? prefix) {
    final name = field.name!;
    final tokenAnnotation = _tokenChecker.firstAnnotationOf(field);
    final explicitKey = tokenAnnotation == null ? null : ConstantReader(tokenAnnotation).peek('key')?.stringValue;
    final key = explicitKey ?? name;

    return TokenDescriptor(
      name: name,
      key: prefix == null ? key : '$prefix.$key',
      typeName: Naming.nonEmpty(ast?.typeName) ?? _typeOf(field),
      initializer: Naming.nonEmpty(ast?.initializerSource) ?? _initializerOf(field, specName),
      docComment: field.documentationComment ?? (ast?.trailingComment == null ? null : '/// ${ast!.trailingComment}'),
      modes: {
        if (ast?.tokenArguments['dark'] case final dark? when dark != 'null') 'dark': dark,
        ...?ast?.tokenModes,
      },
    );
  }

  static String _typeOf(FieldElement field) {
    final display = field.type.getDisplayString();
    if (display != 'dynamic') return display;
    return field.computeConstantValue()?.type?.getDisplayString() ?? 'dynamic';
  }

  static String _initializerOf(FieldElement field, String specName) {
    final value = field.computeConstantValue();
    if (value == null) {
      throw InvalidGenerationSourceError(
        'Field ${field.name} on $specName must be a const value with an initializer.',
        todo: 'Declare ${field.name} as `static const ${field.name} = ...;`.',
        element: field,
      );
    }
    return _formatDartObject(value);
  }

  static String _formatDartObject(DartObject object) {
    if (object.isNull) return 'null';
    if (object.toBoolValue() case final b?) return '$b';
    if (object.toIntValue() case final i?) return '$i';
    if (object.toDoubleValue() case final d?) return '$d';
    if (object.toStringValue() case final s?) return "'$s'";
    final typeName = object.type?.getDisplayString() ?? '';
    if (typeName.contains('Color')) {
      final value = object.getField('value')?.toIntValue();
      if (value != null) return 'Color(0x${value.toRadixString(16).toUpperCase().padLeft(8, '0')})';
    }
    return object.toString();
  }
}
