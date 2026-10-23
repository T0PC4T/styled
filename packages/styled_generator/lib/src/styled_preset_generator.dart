import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:styled_annotation/styled_annotation.dart';

import 'inspectors/preset_inspector.dart';
import 'writers/preset_writer.dart';

/// Generator for [@StyledPreset] annotations.
///
/// Annotate a spec class of static `Style` fields and methods to generate a
/// variant enum and a `StyleResolver` with a const constructor per variant,
/// state overrides applied in precedence order, and value equality.
class StyledPresetGenerator extends GeneratorForAnnotation<StyledPreset> {
  const StyledPresetGenerator();

  @override
  FutureOr<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@StyledPreset can only be applied to classes.',
        todo: 'Remove @StyledPreset from ${element.name} or convert it into a class.',
        element: element,
      );
    }

    final descriptor = PresetInspector.inspect(element, annotation);
    return PresetWriter.write(descriptor);
  }
}
