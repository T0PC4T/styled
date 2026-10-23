import 'package:flutter/widgets.dart';

import 'style_resolver.dart';

export 'models.dart';
export 'style_resolver.dart';
export 'tokens.dart';

@immutable
class Style extends StyleResolver {
  final BoxStyle box;
  final StyledTextStyle text;
  final IconStyle icon;
  final FlexStyle flex;
  final ImageStyle image;

  /// Typed String-token state overrides: token -> Style
  final Map<String, Style> states;

  /// Static tags/tokens attached directly to this style instance
  final Set<String> tags;

  const Style({
    this.box = const BoxStyle(),
    this.text = const StyledTextStyle(),
    this.icon = const IconStyle(),
    this.flex = const FlexStyle(),
    this.image = const ImageStyle(),
    this.states = const {},
    this.tags = const {},
  });

  @override
  Style resolve(BuildContext context) => this;

  @override
  StyleResolver merge(covariant StyleResolver other) {
    if (other is Style) {
      final mergedStates = <String, Style>{...states};
      for (final entry in other.states.entries) {
        mergedStates[entry.key] = mergedStates.containsKey(entry.key)
            ? mergedStates[entry.key]!.merge(entry.value) as Style
            : entry.value;
      }

      return Style(
        box: box.merge(other.box),
        text: text.merge(other.text),
        icon: icon.merge(other.icon),
        flex: flex.merge(other.flex),
        image: image.merge(other.image),
        states: mergedStates,
        tags: {...tags, ...other.tags},
      );
    }
    return super.merge(other);
  }

  @override
  Style add({
    BoxStyle? box,
    StyledTextStyle? text,
    IconStyle? icon,
    FlexStyle? flex,
    ImageStyle? image,
    Map<String, Style>? states,
    Set<String>? tags,
  }) {
    final mergedStates = states != null ? {...this.states, ...states} : this.states;
    final mergedTags = tags != null ? {...this.tags, ...tags} : this.tags;

    return Style(
      box: box != null ? this.box.merge(box) : this.box,
      text: text != null ? this.text.merge(text) : this.text,
      icon: icon != null ? this.icon.merge(icon) : this.icon,
      flex: flex != null ? this.flex.merge(flex) : this.flex,
      image: image != null ? this.image.merge(image) : this.image,
      states: mergedStates,
      tags: mergedTags,
    );
  }

  @override
  Style overwrite({
    BoxStyle? box,
    StyledTextStyle? text,
    IconStyle? icon,
    FlexStyle? flex,
    ImageStyle? image,
    Map<String, Style>? states,
    Set<String>? tags,
  }) {
    return Style(
      box: box ?? this.box,
      text: text ?? this.text,
      icon: icon ?? this.icon,
      flex: flex ?? this.flex,
      image: image ?? this.image,
      states: states ?? this.states,
      tags: tags ?? this.tags,
    );
  }

  /// Unified token registration: .on(token, ...)
  /// Attaches a state override that takes effect when [token] is active.
  @override
  Style on(
    String token, {
    BoxStyle? box,
    StyledTextStyle? text,
    IconStyle? icon,
    FlexStyle? flex,
    ImageStyle? image,
    Style? style,
  }) {
    final stateStyle = style ??
        Style(
          box: box ?? const BoxStyle(),
          text: text ?? const StyledTextStyle(),
          icon: icon ?? const IconStyle(),
          flex: flex ?? const FlexStyle(),
          image: image ?? const ImageStyle(),
        );

    final updatedState = states.containsKey(token)
        ? (states[token]!.merge(stateStyle) as Style)
        : stateStyle;

    return copyWith(
      states: {...states, token: updatedState},
    );
  }

  /// Checks if a tag is present on this style.
  bool isTag(String token) => tags.contains(token);

  /// Attaches a static tag to this style.
  Style withTag(String token) => copyWith(tags: {...tags, token});

  /// Applies active tokens and merges their matching state styles.
  @override
  Style resolveTokens(Iterable<String> activeTokens) {
    Style current = this;
    for (final token in activeTokens) {
      if (states[token] case Style stateStyle) {
        current = current.merge(stateStyle) as Style;
      }
    }
    return current;
  }

  Style copyWith({
    BoxStyle? box,
    StyledTextStyle? text,
    IconStyle? icon,
    FlexStyle? flex,
    ImageStyle? image,
    Map<String, Style>? states,
    Set<String>? tags,
  }) {
    return Style(
      box: box ?? this.box,
      text: text ?? this.text,
      icon: icon ?? this.icon,
      flex: flex ?? this.flex,
      image: image ?? this.image,
      states: states ?? this.states,
      tags: tags ?? this.tags,
    );
  }

  Decoration get decoratedBoxStyle {
    final currentShape = box.shape ?? BoxShape.rectangle;
    final decorationImage = box.image ??
        (box.networkImage != null
            ? DecorationImage(
                image: NetworkImage(box.networkImage!),
                fit: image.fit ?? BoxFit.cover,
                alignment: image.alignment ?? Alignment.center,
                repeat: image.repeat ?? ImageRepeat.noRepeat,
                centerSlice: image.centerSlice,
                matchTextDirection: image.matchTextDirection ?? false,
                scale: image.scale ?? 1.0,
                opacity: image.opacity ?? 1.0,
                filterQuality: image.filterQuality ?? FilterQuality.low,
                invertColors: image.invertColors ?? false,
                isAntiAlias: image.isAntiAlias ?? false,
              )
            : null);

    return BoxDecoration(
      color: box.color,
      border: box.effectiveBorderBox,
      borderRadius: currentShape == BoxShape.circle ? null : box.circularRadius,
      boxShadow: box.boxShadow,
      gradient: box.gradient,
      shape: currentShape,
      image: decorationImage,
      backgroundBlendMode: box.backgroundBlendMode,
    );
  }

  TextStyle get textStyle => text.textStyle;


  IconThemeData get iconStyle {
    return IconThemeData(
      color: icon.color,
      size: icon.size,
      fill: icon.fill,
      weight: icon.weight,
      grade: icon.grade,
      opticalSize: icon.opticalSize,
      shadows: icon.shadows,
      applyTextScaling: icon.applyTextScaling,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Style &&
          runtimeType == other.runtimeType &&
          box == other.box &&
          text == other.text &&
          icon == other.icon &&
          flex == other.flex &&
          image == other.image &&
          _mapEquals(states, other.states) &&
          _setEquals(tags, other.tags);

  @override
  int get hashCode => Object.hash(box, text, icon, flex, image, Object.hashAll(states.entries), Object.hashAll(tags));

  static bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  static bool _setEquals<T>(Set<T> a, Set<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}

/// InheritedWidget for propagating a parent [Style] down the widget tree.
class InheritedStyle extends InheritedWidget {
  final Style style;

  const InheritedStyle({super.key, required this.style, required super.child});

  static InheritedStyle? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<InheritedStyle>();
  }

  @override
  bool updateShouldNotify(InheritedStyle oldWidget) {
    return style != oldWidget.style;
  }
}
