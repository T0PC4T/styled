/// build_runner builders for the styled design engine.
///
/// - `design_definitions`: beside each library with `@Designable` classes, a
///   `.design.g.dart` library of their generated `DesignDefinition`s.
/// - `design_index`: per library, an index of its definitions and preset
///   families, kept in the build cache.
/// - `design_registry`: the package's `lib/design.g.dart`, listing every
///   definition, preset factory and preset family from the indexes. With the
///   option `check_coverage: true` (off by default) it also fails the build
///   listing every `Widget` the package barrel (`lib/<package>.dart`, or
///   `coverage_barrel`) exports that carries neither `@Designable` nor
///   `@NotDesignable`.
library;

import 'package:build/build.dart';

import 'src/builders.dart';

Builder designDefinitionsBuilder(BuilderOptions options) => DesignDefinitionsBuilder();
Builder designIndexBuilder(BuilderOptions options) => DesignIndexBuilder();
Builder designRegistryBuilder(BuilderOptions options) => DesignRegistryBuilder(
  checkCoverage: options.config['check_coverage'] as bool? ?? false,
  coverageBarrel: options.config['coverage_barrel'] as String?,
);
