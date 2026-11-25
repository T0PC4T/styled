import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:styled/styled.dart';
import 'package:styled_design_core/styled_design_core.dart';

import 'engine_definitions.dart';
import 'navigation.dart';
import 'registry.dart';
import 'token_registry.dart';

/// Turns a reference to an image (an id, a path) into a provider. The engine
/// never builds a network image itself.
typedef DesignImageResolver = ImageProvider? Function(String reference);

/// Receives every problem the runtime meets: a wrong prop kind, an unknown
/// component, an action that throws.
typedef DesignErrorReporter = void Function(DesignRuntimeError error);

/// A problem met while drawing or running a screen.
@immutable
class DesignRuntimeError {
  final String screenId;
  final String? nodeId;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const DesignRuntimeError(this.screenId, this.nodeId, this.message, {this.cause, this.stackTrace});

  @override
  String toString() => 'DesignRuntimeError($screenId#${nodeId ?? '-'}): $message${cause == null ? '' : ' ($cause)'}';
}

/// Resolves preset ids: a built-in variant from the registry, or a designer
/// preset from the bundle, which is its base merged with its style delta.
final class PresetResolver {
  final DesignRegistry registry;
  final Map<String, PresetDoc> designerPresets;
  final TokenRegistry tokens;
  final Map<String, StyleResolver> _cache = {};

  PresetResolver(this.registry, this.designerPresets, this.tokens);

  /// The resolver for [id] (`StyleCard.highlight`). Throws a [DesignError]
  /// for an unknown family or variant, or an `extends` cycle.
  StyleResolver resolve(String id, {Map<String, Object?> args = const {}}) {
    if (args.isEmpty) {
      final cached = _cache[id];
      if (cached != null) return cached;
    }
    final result = _resolve(id, args, const {});
    if (args.isEmpty) _cache[id] = result;
    return result;
  }

  StyleResolver _resolve(String id, Map<String, Object?> args, Set<String> seen) {
    if (seen.contains(id)) throw DesignError("Preset '$id' extends itself through ${seen.join(' → ')}.");
    final designer = designerPresets[id];
    if (designer != null) {
      final base = _resolve(designer.extendsId, args, {...seen, id});
      return base + Style.fromJson(designer.style, tokens);
    }
    final split = Catalog.splitPreset(id);
    final factory = split == null ? null : registry.presets[split.$1];
    if (split == null || factory == null) {
      throw DesignError("Unknown preset '$id'.", [
        Diagnostic.of('E-preset-unknown', "No preset family for '$id'.", allowed: registry.presets.keys.toList()),
      ]);
    }
    try {
      return factory(split.$2, PresetArgs(args, <T>(key) => tokens.typed<T>(key)));
    } on ArgumentError {
      throw DesignError("Preset family ${split.$1} has no variant '${split.$2}'.");
    }
  }
}

/// Inherited access to the bundle, registry, navigator, overlays, image
/// resolver and error reporter. Put one above the app; every DesignScreen
/// below it draws from it.
class DesignScope extends InheritedWidget {
  final DesignBundle bundle;
  final DesignRegistry registry;
  final DesignNavigator navigator;
  final DesignOverlays? overlays;
  final DesignImageResolver? images;
  final DesignErrorReporter? onError;

  /// The studio: unbound primary events draw enabled and log, widget errors
  /// show a labelled box, unknown types draw a placeholder.
  final bool studio;

  final TokenRegistry tokens;
  final PresetResolver presets;

  factory DesignScope({
    Key? key,
    required DesignBundle bundle,
    required DesignRegistry registry,
    required DesignNavigator navigator,
    required Widget child,
    DesignOverlays? overlays,
    DesignImageResolver? images,
    DesignErrorReporter? onError,
    bool studio = false,
    TokenRegistry? tokens,
  }) {
    if (bundle.requiresCatalog > registry.catalogVersion) {
      throw DesignError(
        'This bundle needs catalog version ${bundle.requiresCatalog}, but this build of the app implements '
        'version ${registry.catalogVersion}. Ship the app update before the design, or export against the older catalog.',
      );
    }
    final full = registry.withDefinitions(engineDefinitions);
    final tokenRegistry = tokens ?? TokenRegistry(registry.tokens, bundle.tokens, baseTheme: registry.themeFor);
    return DesignScope._(
      key: key,
      bundle: bundle,
      registry: full,
      navigator: navigator,
      overlays: overlays,
      images: images,
      onError: onError,
      studio: studio,
      tokens: tokenRegistry,
      presets: PresetResolver(full, bundle.presets, tokenRegistry),
      child: child,
    );
  }

  const DesignScope._({
    super.key,
    required this.bundle,
    required this.registry,
    required this.navigator,
    required this.tokens,
    required this.presets,
    required super.child,
    this.overlays,
    this.images,
    this.onError,
    this.studio = false,
  });

  static DesignScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesignScope>() ??
      (throw FlutterError('No DesignScope above this DesignScreen. Put one above the app.'));

  /// Reports [error] to [onError], and in debug builds to the console.
  void report(DesignRuntimeError error) {
    onError?.call(error);
    if (kDebugMode && onError == null) debugPrint('$error');
  }

  @override
  bool updateShouldNotify(DesignScope oldWidget) =>
      bundle != oldWidget.bundle ||
      registry != oldWidget.registry ||
      navigator != oldWidget.navigator ||
      overlays != oldWidget.overlays ||
      studio != oldWidget.studio;
}
