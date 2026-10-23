import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:build/build.dart';

/// Source-level facts about a field that the element model does not keep.
class AstFieldInfo {
  final String name;
  final String? typeName;
  final String? initializerSource;

  /// Text of a `//` comment on the same line after the declaration.
  final String? trailingComment;

  /// Source of named arguments on a `@Token(...)` annotation, by name.
  final Map<String, String> tokenArguments;

  /// Entries of a `@Token(modes: {...})` map literal: mode name to value source.
  final Map<String, String> tokenModes;

  const AstFieldInfo({
    required this.name,
    this.typeName,
    this.initializerSource,
    this.trailingComment,
    this.tokenArguments = const {},
    this.tokenModes = const {},
  });
}

/// Reads field initializers, declared types, trailing comments and `@Token`
/// arguments for [className] directly from the source.
Future<Map<String, AstFieldInfo>> extractClassFieldsFromAst(BuildStep buildStep, String className) async {
  final unit = await buildStep.resolver.compilationUnitFor(buildStep.inputId);
  for (final declaration in unit.declarations) {
    if (declaration is! ClassDeclaration || declaration.namePart.typeName.lexeme != className) continue;
    final result = <String, AstFieldInfo>{};
    for (final member in declaration.body.members) {
      if (member is! FieldDeclaration) continue;
      final typeStr = member.fields.type?.toSource();
      final trailing = _trailingComment(unit, member.endToken);
      final (args, modes) = _tokenAnnotation(member.metadata);
      for (final variable in member.fields.variables) {
        result[variable.name.lexeme] = AstFieldInfo(
          name: variable.name.lexeme,
          typeName: typeStr,
          initializerSource: variable.initializer?.toSource(),
          trailingComment: trailing,
          tokenArguments: args,
          tokenModes: modes,
        );
      }
    }
    return result;
  }
  return {};
}

String? _trailingComment(CompilationUnit unit, Token endToken) {
  final line = unit.lineInfo.getLocation(endToken.end).lineNumber;
  Token? comment = endToken.next?.precedingComments;
  while (comment != null) {
    if (unit.lineInfo.getLocation(comment.offset).lineNumber != line) return null;
    final text = comment.lexeme;
    if (text.startsWith('//') && !text.startsWith('///')) {
      final body = text.substring(2).trim();
      return body.isEmpty ? null : body;
    }
    comment = comment.next;
  }
  return null;
}

(Map<String, String>, Map<String, String>) _tokenAnnotation(NodeList<Annotation> metadata) {
  for (final annotation in metadata) {
    if (annotation.name.name != 'Token') continue;
    final args = <String, String>{};
    final modes = <String, String>{};
    for (final argument in annotation.arguments?.arguments ?? const []) {
      if (argument is! NamedArgument) continue;
      final name = argument.name.lexeme;
      final expression = argument.argumentExpression;
      args[name] = expression.toSource();
      if (name == 'modes' && expression is SetOrMapLiteral) {
        for (final element in expression.elements) {
          if (element is MapLiteralEntry && element.key is SimpleStringLiteral) {
            modes[(element.key as SimpleStringLiteral).value] = element.value.toSource();
          }
        }
      }
    }
    return (args, modes);
  }
  return (const {}, const {});
}
