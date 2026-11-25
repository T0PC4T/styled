/// build_runner builders for the styled design engine.
///
/// - `design_definitions`: beside each library with `@Designable` classes, a
///   `.design.g.dart` library of their generated `DesignDefinition`s.
/// - `design_index`: per library, an index of its definitions and preset
///   families, kept in the build cache.
/// - `design_registry`: the package's `lib/design.g.dart`, listing every
///   definition, preset factory and preset family from the indexes.
library;

import 'package:build/build.dart';

import 'src/builders.dart';

Builder designDefinitionsBuilder(BuilderOptions options) => DesignDefinitionsBuilder();
Builder designIndexBuilder(BuilderOptions options) => DesignIndexBuilder();
Builder designRegistryBuilder(BuilderOptions options) => DesignRegistryBuilder();
