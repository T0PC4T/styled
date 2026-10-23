import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../theme/styled_theme.dart';
import 'models.dart';
import 'style_resolver.dart';
import 'tokens.dart';

export 'models.dart';
export 'style_resolver.dart';
export 'tokens.dart';

/// A complete, immutable description of how a styled widget looks and lays out.
///
/// Combine styles with [merge] or `+`, and attach state-dependent overrides
/// with [on]:
///
/// ```dart
/// final card = Style(
///   box: BoxStyle(color: surface, border: StyledBorder.all(color: line, width: 1, radius: 12)),
/// ).on(StyleState.hovered, box: BoxStyle(border: StyledBorder(color: accent)));
/// ```
@immutable
class Style extends StyleResolver {
  final BoxStyle box;
  final StyledTextStyle text;
  final IconStyle icon;
  final FlexStyle flex;
  final ImageStyle image;

  /// Overrides merged on top of this style while the keyed state is active.
  final Map<StyleState, Style> states;

  const Style({
    this.box = const BoxStyle(),
    this.text = const StyledTextStyle(),
    this.icon = const IconStyle(),
    this.flex = const FlexStyle(),
    this.image = const ImageStyle(),
    this.states = const {},
  });

  @override
  Style resolve(BuildContext context) => this;

  /// Merges [other] over this style. Sub-styles merge field by field and
  /// state overrides merge per state.
  @override
  Style merge(Style? other) {
    if (other == null || identical(other, this)) return this;
    return Style(
      box: box.merge(other.box),
      text: text.merge(other.text),
      icon: icon.merge(other.icon),
      flex: flex.merge(other.flex),
      image: image.merge(other.image),
      states: _mergeStates(states, other.states),
    );
  }

  @override
  Style operator +(Style other) => merge(other);

  /// Merges individual sub-styles over this style.
  Style add({
    BoxStyle? box,
    StyledTextStyle? text,
    IconStyle? icon,
    FlexStyle? flex,
    ImageStyle? image,
    Map<StyleState, Style>? states,
  }) =>
      Style(
        box: this.box.merge(box),
        text: this.text.merge(text),
        icon: this.icon.merge(icon),
        flex: this.flex.merge(flex),
        image: this.image.merge(image),
        states: states == null ? this.states : _mergeStates(this.states, states),
      );

  /// Attaches an override that applies while [state] is active. Pass either
  /// sub-styles or a complete [style]. Calling [on] again for the same state
  /// merges into the existing override.
  Style on(
    StyleState state, {
    BoxStyle? box,
    StyledTextStyle? text,
    IconStyle? icon,
    FlexStyle? flex,
    ImageStyle? image,
    Style? style,
  }) {
    final override = (style ?? const Style()).add(box: box, text: text, icon: icon, flex: flex, image: image);
    return copyWith(states: _mergeStates(states, {state: override}));
  }

  /// Whether an override is registered for [state].
  bool hasState(StyleState state) => states.containsKey(state);

  /// Whether any override is keyed by a [StyledScreen] tier.
  bool get hasScreenStates => states.keys.any(StyledScreen.isScreenState);

  /// Applies the overrides for [active] in order; later states win.
  ///
  /// When [context] is given and this style has screen-tier overrides, the
  /// current [StyledScreen] state is applied first, below everything else.
  /// The result carries no state overrides of its own.
  Style resolveStates(Iterable<StyleState> active, {BuildContext? context}) {
    var current = copyWith(states: const {});
    if (states.isEmpty) return current;
    final ordered = [
      if (context != null && hasScreenStates) StyledScreen.of(context).state,
      ...active,
    ];
    for (final state in ordered) {
      final override = states[state];
      if (override != null) current = current.merge(override.copyWith(states: const {}));
    }
    return current;
  }

  /// Takes [parent]'s text and icon properties as defaults for this style.
  Style inheritFrom(Style? parent) {
    if (parent == null) return this;
    return copyWith(text: parent.text.merge(text), icon: parent.icon.merge(icon));
  }

  Style copyWith({
    BoxStyle? box,
    StyledTextStyle? text,
    IconStyle? icon,
    FlexStyle? flex,
    ImageStyle? image,
    Map<StyleState, Style>? states,
  }) =>
      Style(
        box: box ?? this.box,
        text: text ?? this.text,
        icon: icon ?? this.icon,
        flex: flex ?? this.flex,
        image: image ?? this.image,
        states: states ?? this.states,
      );

  /// This style bound to [theme], which can produce Flutter types such as
  /// [ThemedStyle.textStyle] for widgets that are not styled widgets.
  ThemedStyle bind(StyledTheme theme) => ThemedStyle(this, theme);

  static Map<StyleState, Style> _mergeStates(Map<StyleState, Style> a, Map<StyleState, Style> b) {
    if (b.isEmpty) return a;
    if (a.isEmpty) return b;
    return {
      ...a,
      for (final MapEntry(:key, :value) in b.entries) key: a[key]?.merge(value) ?? value,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Style &&
          box == other.box &&
          text == other.text &&
          icon == other.icon &&
          flex == other.flex &&
          image == other.image &&
          mapEquals(states, other.states);

  @override
  int get hashCode => Object.hash(
        box,
        text,
        icon,
        flex,
        image,
        Object.hashAllUnordered(states.entries.map((e) => Object.hash(e.key, e.value))),
      );
}

/// A [Style] bound to a theme, so its token references can be read as
/// concrete Flutter values.
///
/// ```dart
/// final title = AppTypography.h2.bind(context.theme);
/// CustomPaint(painter: ChartPainter(labelStyle: title.textStyle));
/// ```
///
/// Merging a [ThemedStyle] returns a plain [Style].
class ThemedStyle extends Style {
  final StyledTheme theme;

  ThemedStyle(Style style, this.theme)
      : super(
          box: style.box,
          text: style.text,
          icon: style.icon,
          flex: style.flex,
          image: style.image,
          states: style.states,
        );

  /// The Flutter [TextStyle] for [text].
  TextStyle get textStyle => text.toTextStyle(theme);

  /// The Flutter [IconThemeData] for [icon].
  IconThemeData get iconTheme => icon.toIconTheme(theme);

  /// The [BoxDecoration] for [box].
  BoxDecoration get decoration => box.decoration(theme);
}

/// Passes the resolved [Style] of a box down to descendant text and icons.
class InheritedStyle extends InheritedWidget {
  final Style style;

  const InheritedStyle({super.key, required this.style, required super.child});

  static InheritedStyle? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<InheritedStyle>();

  /// The nearest inherited style, if any.
  static Style? maybeStyleOf(BuildContext context) => of(context)?.style;

  @override
  bool updateShouldNotify(InheritedStyle oldWidget) => style != oldWidget.style;
}
