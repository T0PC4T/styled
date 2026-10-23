import 'package:analyzer/dart/ast/ast.dart';
import 'package:build/build.dart';

class AstFieldInfo {
  final String name;
  final String? typeName;
  final String? initializerSource;

  const AstFieldInfo({
    required this.name,
    this.typeName,
    this.initializerSource,
  });
}

/// Extracts field initializers and explicit type annotations directly from the AST.
Future<Map<String, AstFieldInfo>> extractClassFieldsFromAst(
  BuildStep buildStep,
  String className,
) async {
  try {
    final unit = await buildStep.resolver.compilationUnitFor(buildStep.inputId);
    for (final declaration in unit.declarations) {
      if (declaration is ClassDeclaration &&
          declaration.namePart.typeName.lexeme == className) {
        final result = <String, AstFieldInfo>{};
        for (final member in declaration.body.members) {
          if (member is FieldDeclaration) {
            final typeStr = member.fields.type?.toSource();
            for (final variable in member.fields.variables) {
              final varName = variable.name.lexeme;
              final initSource = variable.initializer?.toSource();
              result[varName] = AstFieldInfo(
                name: varName,
                typeName: typeStr,
                initializerSource: initSource,
              );
            }
          }
        }
        return result;
      }
    }
  } catch (_) {
    // Graceful fallback to analyzer element introspection
  }
  return {};
}
