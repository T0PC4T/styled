import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';

import 'component_reader.dart';
import 'writers.dart';

bool _skip(AssetId id) => id.path.endsWith('.g.dart') || !id.path.startsWith('lib/');

Future<LibraryElement?> _library(BuildStep step) async {
  if (_skip(step.inputId) || !await step.resolver.isLibrary(step.inputId)) return null;
  return step.resolver.libraryFor(step.inputId);
}

Iterable<(ClassElement, Object)> _designables(LibraryElement library) sync* {
  for (final cls in library.classes) {
    final annotation = designableChecker.firstAnnotationOf(cls, throwOnUnresolved: false);
    if (annotation != null) yield (cls, annotation);
  }
}

String _format(String source, AssetId id) {
  try {
    return DartFormatter(languageVersion: DartFormatter.latestLanguageVersion, pageWidth: 120).format(source);
  } on FormatterException catch (e) {
    log.severe('Generated code for ${id.path} does not parse:\n${e.message()}\n$source');
    rethrow;
  }
}

/// `x.dart` → `x.design.g.dart`, a standalone library beside it.
class DesignDefinitionsBuilder implements Builder {
  @override
  final buildExtensions = const {
    '.dart': ['.design.g.dart'],
  };

  @override
  Future<void> build(BuildStep step) async {
    final library = await _library(step);
    if (library == null) return;
    final plans = [
      for (final (cls, annotation) in _designables(library)) readComponent(cls, annotation as dynamic),
    ].where((c) => c.handWritten == null).toList();
    if (plans.isEmpty) return;

    final unit = await step.resolver.compilationUnitFor(step.inputId);
    final imports = [for (final d in unit.directives.whereType<ImportDirective>()) d.toSource()];
    final source = StringBuffer(generatedHeader)
      ..writeln()
      ..writeAll(imports.map((i) => '$i\n'))
      ..writeln("import 'package:flutter/widgets.dart';")
      ..writeln("import 'package:styled/styled.dart';")
      ..writeln(
        "import 'package:styled_design/styled_design.dart' show DesignDefinition, DesignBuildContext, "
        'DesignComponent, DesignProp, DesignSlot, DesignEvent, DesignRule, DesignKind, PropKind;',
      )
      ..writeln("import '${p.basename(step.inputId.path)}';")
      ..write(writeDefinitions(plans));
    final out = step.inputId.changeExtension('.design.g.dart');
    await step.writeAsString(out, _format(source.toString(), out));
  }
}

/// `x.dart` → `x.design_index.json` in the build cache.
class DesignIndexBuilder implements Builder {
  @override
  final buildExtensions = const {
    '.dart': ['.design_index.json'],
  };

  @override
  Future<void> build(BuildStep step) async {
    final library = await _library(step);
    if (library == null) return;
    final generatedUri =
        'package:${step.inputId.package}/${step.inputId.changeExtension('.design.g.dart').path.substring('lib/'.length)}';
    final definitions = <DefinitionRef>[];
    for (final (cls, annotation) in _designables(library)) {
      final plan = readComponent(cls, annotation as dynamic);
      definitions.add(
        plan.handWritten == null
            ? DefinitionRef(plan.definitionName, generatedUri)
            : DefinitionRef(plan.handWritten!, plan.handWrittenUri!),
      );
    }
    final presets = [for (final cls in library.classes) ?readPresetFamily(cls)];
    if (definitions.isEmpty && presets.isEmpty) return;
    await step.writeAsString(step.inputId.changeExtension('.design_index.json'), encodeIndex(definitions, presets));
  }
}

/// `$lib$` → `lib/design.g.dart`.
///
/// With [checkCoverage] (the `check_coverage` builder option, off by default) it also resolves the
/// package's barrel ([coverageBarrel], `lib/<package>.dart` unless `coverage_barrel` names another) and
/// fails the build listing every `Widget` subclass the barrel exports from this package that carries
/// neither `@Designable` nor `@NotDesignable`.
class DesignRegistryBuilder implements Builder {
  final bool checkCoverage;
  final String? coverageBarrel;

  DesignRegistryBuilder({this.checkCoverage = false, this.coverageBarrel});

  @override
  final buildExtensions = const {
    r'$lib$': ['design.g.dart'],
  };

  @override
  Future<void> build(BuildStep step) async {
    if (checkCoverage) await _checkCoverage(step);
    final definitions = <DefinitionRef>[];
    final presets = <PresetFamilyPlan>[];
    final ids = await step.findAssets(Glob('lib/**.design_index.json')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final id in ids) {
      final json = jsonDecode(await step.readAsString(id)) as Map<String, Object?>;
      definitions.addAll([
        for (final d in json['definitions']! as List) DefinitionRef.fromJson(d as Map<String, Object?>),
      ]);
      presets.addAll([for (final p in json['presets']! as List) PresetFamilyPlan.fromJson(p as Map<String, Object?>)]);
    }
    final seen = <String>{};
    final unique = [
      for (final d in definitions)
        if (seen.add('${d.uri}#${d.className}')) d,
    ];
    final out = AssetId(step.inputId.package, 'lib/design.g.dart');
    await step.writeAsString(out, _format(writeRegistry(unique, presets), out));
  }

  /// Fails the build when the barrel exports a widget of this package with neither annotation.
  Future<void> _checkCoverage(BuildStep step) async {
    final package = step.inputId.package;
    final barrel = AssetId(package, coverageBarrel ?? 'lib/$package.dart');
    if (!await step.canRead(barrel) || !await step.resolver.isLibrary(barrel)) {
      throw StateError('check_coverage: ${barrel.path} is not a library of $package; set coverage_barrel.');
    }
    final missing = unannotatedWidgets(await step.resolver.libraryFor(barrel), package);
    if (missing.isEmpty) return;
    throw InvalidGenerationSourceError(
      '${missing.length} widget(s) exported from ${barrel.path} carry neither @Designable nor @NotDesignable:\n'
      '${missing.map((m) => '  - $m').join('\n')}\n'
      'Annotate each with @Designable(...) if a design document may place it, else @NotDesignable(\'reason\').',
    );
  }
}

/// `Widget` subclasses declared in [package] and exported by [library] without `@Designable` or
/// `@NotDesignable`, as `Name (lib/src/path.dart)`, sorted.
List<String> unannotatedWidgets(LibraryElement library, String package) {
  final missing = <String>[];
  for (final element in library.exportNamespace.definedNames2.values) {
    if (element is! ClassElement) continue;
    final uri = element.library.uri;
    if (uri.scheme != 'package' || uri.pathSegments.first != package) continue;
    if (!element.allSupertypes.any((t) => t.element.name == 'Widget')) continue;
    if (designableChecker.hasAnnotationOf(element, throwOnUnresolved: false) ||
        notDesignableChecker.hasAnnotationOf(element, throwOnUnresolved: false)) {
      continue;
    }
    missing.add('${element.name} (lib/${uri.pathSegments.skip(1).join('/')})');
  }
  return missing..sort();
}

// Keep source_gen's error type in the public surface of this library.
typedef DesignGenerationError = InvalidGenerationSourceError;
