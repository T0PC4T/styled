import 'package:flutter/widgets.dart';

import 'style.dart';

/// Produces a [Style] from the build context, usually from theme tokens.
///
/// [Style] itself is a resolver that returns itself. Presets such as
/// `StyleButton.primary()` resolve against `context.theme` at build time.
abstract class StyleResolver {
  const StyleResolver();

  /// Resolves the style for [context].
  Style resolve(BuildContext context);

  /// Transforms the resolved style when this resolver is resolved.
  StyleResolver map(Style Function(Style style) transform) => _MappedStyleResolver(this, transform);

  /// Merges [other] over the resolved style.
  StyleResolver merge(Style? other) => other == null ? this : map((style) => style.merge(other));

  /// Shorthand for [merge].
  StyleResolver operator +(Style other) => merge(other);
}

class _MappedStyleResolver extends StyleResolver {
  final StyleResolver _base;
  final Style Function(Style style) _transform;

  const _MappedStyleResolver(this._base, this._transform);

  @override
  Style resolve(BuildContext context) => _transform(_base.resolve(context));
}
