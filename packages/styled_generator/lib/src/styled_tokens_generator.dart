import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:styled_annotation/styled_annotation.dart';

import 'inspectors/tokens_inspector.dart';
import 'writers/tokens_writer.dart';

/// Generator for [@StyledTokens] annotations.
///
/// Annotate a spec class of static const values to generate typed
/// `ThemeToken` constants, typed getters and overrides on `StyledTheme`, and
/// the theme modes declared with `@Token(dark:)` or `@Token(modes:)`.
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
        todo: 'Remove @StyledTokens from ${element.name} or convert it into a class.',
        element: element,
      );
    }

    final descriptor = await TokensInspector.inspect(element, annotation, buildStep);
    return TokensWriter.write(descriptor);
  }
}
