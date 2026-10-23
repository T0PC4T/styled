# Styled

A headless, token-driven styling engine for Flutter, with code generation for design tokens and component presets.

Styled moves every visual decision into data, and every design value into the theme. A `Style` describes decoration, size, spacing, layout, typography, icons and motion, plus how they change when a widget is hovered, pressed, selected or shown on a phone. Every colour, size, radius, spacing, font size and duration in a style is a **reference** to a theme token, never a raw number. When the theme changes, every styled widget in the app re-resolves its references and updates.

```dart
StyledBox(
  style: const StyleButton.primary(),
  interaction: Interaction(onTap: save),
  children: const [StyledIcon(AppIcons.save), StyledText('Save')],
)
```

```dart
static const primary = Style(
  box: BoxStyle(
    color: AppTokens.primary,
    padding: .symmetric(horizontal: AppTokens.paddingLg, vertical: AppTokens.paddingSm),
    border: StyledBorder(radius: AppTokens.radius),
  ),
  text: StyledTextStyle(color: AppTokens.onPrimary, fontWeight: AppTokens.fontWeightSemiBold),
);
```

The type system enforces this. `BoxStyle(color: Color(0xFFFFFFFF))` and `StyledBorder(radius: AppTokens.radius * 0.75)` do not compile, so components cannot drift onto one-off values.

It depends only on `package:flutter/widgets.dart`, so it works in Material, Cupertino and fully custom apps alike.

---

## Contents

1. [Concepts](#1-concepts)
2. [Installation](#2-installation)
3. [Quick start](#3-quick-start)
4. [Style values](#4-style-values)
5. [The Style model](#5-the-style-model)
6. [States](#6-states)
7. [Widgets](#7-widgets)
8. [Theming](#8-theming)
9. [Responsive styling](#9-responsive-styling)
10. [Style resolvers](#10-style-resolvers)
11. [Code generation: design tokens](#11-code-generation-design-tokens)
12. [Code generation: presets](#12-code-generation-presets)
13. [Building a design system](#13-building-a-design-system)
14. [Recipes](#14-recipes)
15. [Testing](#15-testing)
16. [Best practices](#16-best-practices)
17. [Troubleshooting](#17-troubleshooting)
18. [API reference](#18-api-reference)
19. [Migrating from the earlier API](#19-migrating-from-the-earlier-api)

Examples use `AppTokens` for a token class generated from your spec (section 11) and `AppIcons` as a stand-in for your icon font.

---

## 1. Concepts

| Concept | What it is |
|---|---|
| `ThemeToken<T>` | A typed key with a default, such as `AppTokens.primary` or `AppTokens.radius`. A const reference, not a value. |
| `StyleValue<T>` | What every design field in a style accepts: a `ThemeToken`, an `AlphaOf`, a `DataValue` or a layout constant. Sealed: there is no other kind. |
| `StyledTheme` | An immutable map from token keys to values. Switching themes swaps the map; the tokens never change. |
| `Style` | An immutable value holding five sub-styles (`box`, `flex`, `text`, `icon`, `image`) and state overrides. Contains references, so the same style works in every theme. |
| `StyleState` | A typed key such as `hovered`, `pressed`, `selected` or `mobile`. While a state is active, its override is merged over the style. |
| `StyledBox` | The one container widget: paints `style.box`, lays out `children` with `style.flex`, tracks interaction, and passes text and icon styling to descendants. |
| `@StyledTokens` | Generates tokens, theme getters, typed overrides and theme modes from a class of constants. |
| `@StyledPreset` | Generates a resolver class with named variants and state overrides from constant styles. |

The workspace contains three packages:

| Package | Purpose |
|---|---|
| `styled` | The runtime: values, styles, states, widgets, theming. Re-exports `styled_annotation`. |
| `styled_annotation` | The annotations used by the generator. You never import it directly. |
| `styled_generator` | The `build_runner` generator. A dev dependency only. |

### How a styled widget renders

```
Style (references) ──merge active states──▶ Style (references) ──resolve against StyledTheme──▶ Flutter values
    AppTokens.primary                            AppTokens.primaryVariant                         Color(0xFF1D4ED8)
                                                                                                         │
                                                         Container / AnimatedContainer + Flex / Wrap + InheritedStyle
```

States merge first, so a hovered button swaps one reference for another. Resolution happens last, against whatever theme is active, so the same constant style renders correctly in light, dark or a tenant's brand.

---

## 2. Installation

The packages are not published to pub.dev. Depend on them from git, pinned to a tag:

```yaml
dependencies:
  flutter:
    sdk: flutter
  styled:
    git:
      url: https://github.com/thomasclovis/styled.git
      path: packages/styled
      ref: v2.0.0   # pin a tag or commit, never a moving branch

dev_dependencies:
  build_runner: ^2.4.0
  styled_generator:
    git:
      url: https://github.com/thomasclovis/styled.git
      path: packages/styled_generator
      ref: v2.0.0
```

While developing against a local checkout, override all three packages with paths in the workspace root `pubspec.yaml`:

```yaml
dependency_overrides:
  styled:
    path: ../styled/packages/styled
  styled_annotation:
    path: ../styled/packages/styled_annotation
  styled_generator:
    path: ../styled/packages/styled_generator
```

A single import gives you the runtime and the annotations:

```dart
import 'package:styled/styled.dart';
```

---

## 3. Quick start

### 3.1 Declare tokens

Every style value comes from a token, so start with a few. For a real project, generate them ([section 11](#11-code-generation-design-tokens)); for a first try, declare them by hand:

```dart
abstract final class AppTokens {
  static const surface = ThemeToken<Color>('surface', Color(0xFFFFFFFF));
  static const border = ThemeToken<Color>('border', Color(0xFFE2E8F0));
  static const accent = ThemeToken<Color>('accent', Color(0xFF2563EB));
  static const ink = ThemeToken<Color>('ink', Color(0xFF0F172A));
  static const padding = ThemeToken<double>('padding', 20);
  static const gap = ThemeToken<double>('gap', 12);
  static const radius = ThemeToken<double>('radius', 12);
  static const stroke = ThemeToken<double>('stroke', 1);
  static const body = ThemeToken<double>('body', 14);
  static const title = ThemeToken<double>('title', 20);
  static const motion = ThemeToken<Duration>('motion', Duration(milliseconds: 180));
}
```

### 3.2 Describe a style

```dart
const card = Style(
  box: BoxStyle(
    padding: .all(AppTokens.padding),
    color: AppTokens.surface,
    border: .all(color: AppTokens.border, width: AppTokens.stroke, radius: AppTokens.radius),
    motion: Motion(AppTokens.motion, Curves.easeOutCubic),
  ),
  flex: FlexStyle(spacing: AppTokens.gap, crossAxisAlignment: .start),
  text: StyledTextStyle(color: AppTokens.ink, fontSize: AppTokens.body),
  states: {
    .hovered: Style(box: BoxStyle(border: StyledBorder(color: AppTokens.accent))),
  },
);
```

The whole style is a compile-time constant. The hovered override changes only the border colour; width and radius are kept.

### 3.3 Provide a theme and render

```dart
final themes = StyledThemeController();   // every token at its default

void main() {
  runApp(
    StyledThemeControllerProvider(
      controller: themes,
      child: const WidgetsApp(color: Color(0xFF2563EB), home: HomePage()),
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: StyledBox(
          style: card,
          interaction: Interaction(onTap: () {}),
          children: const [
            StyledText('Analytics Pro', style: Style(text: StyledTextStyle(fontSize: AppTokens.title))),
            StyledText('Hover me: the border turns blue and animates.'),
          ],
        ),
      );
}
```

Change the look of the whole app with one call:

```dart
themes.updateTheme(const StyledTheme().set(AppTokens.accent, const Color(0xFF7C3AED)).set(AppTokens.radius, 4));
```

---

## 4. Style values

Every design field in a style takes a `StyleValue<T>`. There are exactly four kinds:

| Kind | Example | Use for |
|---|---|---|
| `ThemeToken<T>` | `AppTokens.primary`, `AppTokens.paddingLg` | Every design decision. This is the default answer. |
| `AlphaOf` | `AlphaOf(AppTokens.primary, AppTokens.opacitySubtle)` | A colour at an opacity from the theme's opacity scale. |
| `DataValue<T>` | `DataValue(tag.color)` | Runtime data: user-chosen colours, chart series, a preset parameter such as a requested width. |
| Layout constants | `StyleValue.infinity`, `StyleValue.zero` | Structural values that are not design decisions. |

### 4.1 No arithmetic

There is no way to compute a value inside a style. `AppTokens.padding * 2`, `primary.withValues(alpha: 0.3)` and `Color(0xFF...)` are all type errors. If a component needs a value the scale does not have, add a token. This is deliberate: it stops one button from using 25% opacity and another 30%, or one card from using a 10px radius because `radius + 2` seemed right at the time.

### 4.2 AlphaOf

`AlphaOf(color, opacity)` sets the alpha of any colour value to an opacity token. The opacity must be a `ThemeToken<double>`, never a literal, so every translucent colour in the app comes from the same few levels:

```dart
color: AlphaOf(AppTokens.primary, AppTokens.opacitySubtle),               // a tinted fill
border: StyledBorder(color: AlphaOf(AppTokens.error, AppTokens.opacityMedium)),
color: AlphaOf(DataValue(tag.color), AppTokens.opacityFaint),              // data colour, scale opacity
```

Like `Color.withValues(alpha:)`, it replaces the alpha rather than multiplying it.

### 4.3 DataValue

`DataValue(value)` wraps a value that comes from outside the design system. It is the same in every theme. `DataValue.of(nullable)` returns null for null, which makes fallbacks to tokens concise:

```dart
color: DataValue.of(customColor) ?? AppTokens.primary,
width: DataValue.of(requestedWidth) ?? AppTokens.sidebarWidth,
```

Search for `DataValue(` to audit every place a style takes a value from outside the theme. A lint can restrict it to widgets that render user data.

### 4.4 Wrappers for composite types

Flutter's composite types take raw numbers, so `styled` provides token-aware mirrors with the same constructor and parameter names:

| Wrapper | Mirrors | Constructors |
|---|---|---|
| `StyledEdgeInsets` | `EdgeInsets` | `all`, `symmetric`, `only`, `fromLTRB`, `zero` |
| `StyledBoxConstraints` | `BoxConstraints` | `StyledBoxConstraints(minWidth:, maxWidth:, minHeight:, maxHeight:)`, `expand({width, height})`, `tightFor({width, height})` |
| `StyledBorderSide` | `BorderSide` | `StyledBorderSide(color:, width:, style:)`, `none` |
| `StyledBoxShadow` | `BoxShadow` | `level(color, shadowLevelToken)` only |
| `StyledTransform` | `Matrix4` | `translate(x:, y:)` only |
| `StyledBorder` | `Border` and `BorderRadius` | see 5.2 |
| `Motion` | duration and curve | `Motion([duration, curve])` |

Converting existing code is mostly a rename:

```dart
padding: EdgeInsets.symmetric(horizontal: t.paddingLg, vertical: t.paddingSm),         // Flutter
padding: StyledEdgeInsets.symmetric(horizontal: AppTokens.paddingLg, vertical: AppTokens.paddingSm), // styled
padding: .symmetric(horizontal: AppTokens.paddingLg, vertical: AppTokens.paddingSm),  // styled, with dot shorthand
```

Because each wrapper mirrors the Flutter class's constructor names, Dart's dot shorthand (Dart 3.10 and later) lets you leave the wrapper's name out wherever a field asks for it: `padding: .all(...)`, `border: .all(...)`, `boxShadow: [.level(...)]`, `transform: .translate(...)`, `width: .infinity`. The examples in this README use shorthand throughout.

Each wrapper offers only the shapes a design system should need. `StyledTransform` translates (hover lifts, pressed nudges) but cannot rotate or skew; a missing constructor is a design decision, not an oversight.

### 4.5 Shadow levels

`StyledBoxShadow.level(color, token)` applies a `ShadowLevel` (opacity, blur, spread, offset) from a token to a colour. It is the only way to build a shadow, so every shadow comes from the scale:

```dart
// In the token spec
static const ShadowLevel glowMd = ShadowLevel(opacity: 0.25, blurRadius: 12, dy: 4);

// In a style
boxShadow: [.level(AppTokens.primary, AppTokens.glowMd)],
```

A theme can retune every shadow at a level at once, for example softening glows in dark mode with `@Token(dark: ShadowLevel(...))`.

---

## 5. The Style model

```dart
const Style({
  BoxStyle box = const BoxStyle(),
  StyledTextStyle text = const StyledTextStyle(),
  IconStyle icon = const IconStyle(),
  FlexStyle flex = const FlexStyle(),
  ImageStyle image = const ImageStyle(),
  Map<StyleState, Style> states = const {},
})
```

Every field of every sub-style is nullable. Null means "not specified here", which is what makes merging work: a later style only replaces what it specifies. Themeable fields take `StyleValue`s; structural fields (alignment, axis, shape, curve, enums) take plain values.

### 5.1 BoxStyle

| Group | Themeable fields | Plain fields |
|---|---|---|
| Fill | `color`, `gradient` | `image` (`DecorationImage`, content), `backgroundBlendMode` |
| Edge | `border` (`StyledBorder`), `boxShadow` (`List<StyledBoxShadow>`) | `shape` |
| Size | `width`, `height`, `constraints` (`StyledBoxConstraints`) | |
| Spacing | `padding`, `margin` (`StyledEdgeInsets`) | `alignment` |
| Paint | `transform` (`StyledTransform`), `foregroundDecoration` | `clip`, `transformAlignment` |
| Motion | `motion` (`Motion`) | |

```dart
const panel = BoxStyle(
  color: AppTokens.surface,
  padding: .symmetric(horizontal: AppTokens.padding, vertical: AppTokens.paddingSm),
  constraints: StyledBoxConstraints(minWidth: AppTokens.minButtonWidth, maxWidth: AppTokens.modalWidth),
  border: .all(color: AppTokens.border, width: AppTokens.strokeWidth, radius: AppTokens.radius),
  boxShadow: [.level(AppTokens.shadow, AppTokens.shadowSm)],
  transform: .translate(y: AppTokens.hoverLift),
  motion: Motion(AppTokens.animationDuration, Curves.easeOutCubic),
);
```

`box.decoration(theme)` returns the `BoxDecoration` for a theme, for decorating a widget that is not a `StyledBox`.

### 5.2 StyledBorder

A border is sides plus a uniform corner radius. Its fields merge one by one, so a state override can change one property and keep the rest.

| Constructor | Meaning |
|---|---|
| `StyledBorder.all(color:, width:, style:, radius:)` | The same side on every edge. |
| `StyledBorder(top:, bottom:, left:, right:, radius:)` | Individual `StyledBorderSide`s. Any explicit side replaces the uniform side on that edge. |
| `StyledBorder(color:)` | Partial border, typically in a state override. |
| `StyledBorder(radius:)` | Rounded corners with no visible border. |
| `StyledBorder.symmetric(vertical:, horizontal:, radius:)` | `StyledBorderSide`s on the left and right, and on the top and bottom. |
| `StyledBorder.fromBorderSide(side, radius:)` | One `StyledBorderSide` on every edge. |
| `StyledBorder.none(radius:)` | No visible border, keeping the radius. |

A uniform border is drawn only when both `color` and `width` are known after merging. A base style can declare the geometry and a variant the colour:

```dart
const base = StyledBorder.all(width: AppTokens.strokeWidth, radius: AppTokens.radius);  // nothing drawn yet
const variant = StyledBorder(color: AppTokens.border);                                 // now drawn
const hovered = StyledBorder(color: AppTokens.borderFocus);                            // only the colour changes
```

### 5.3 Motion

```dart
const Motion([StyleValue<Duration> duration = StyledDefaults.motionDuration, Curve curve = Curves.linear])
```

A box animates every change between resolved styles, including state changes and theme switches, whenever `box.motion` is set. Put it on a component's base style so every state animates. The duration is a token, so a theme can slow every transition, or set it to zero for reduced motion.

### 5.4 FlexStyle

How a box lays out its `children`.

| Field | Default | Notes |
|---|---|---|
| `wrap` | `false` | `true` uses a `Wrap` instead of a `Flex`. |
| `direction` | vertical for `Flex`, horizontal for `Wrap` | |
| `spacing` | `0` | Gap between children (a `StyleValue<double>`). No spacer widgets needed. |
| `runSpacing` | `0` | Gap between runs of a `Wrap`. |
| `mainAxisAlignment`, `crossAxisAlignment`, `mainAxisSize` | `start`, `center`, `max` | |
| `wrapAlignment`, `wrapCrossAxisAlignment`, `runAlignment` | `start` | `Wrap` only. |
| `verticalDirection`, `textDirection`, `textBaseline`, `clipBehavior` | Flutter defaults | |

### 5.5 StyledTextStyle, IconStyle and ImageStyle

| Sub-style | Themeable fields | Plain fields |
|---|---|---|
| `StyledTextStyle` | `color`, `backgroundColor`, `fontFamily`, `fontSize`, `fontWeight`, `letterSpacing`, `wordSpacing`, `height`, `decorationColor`, `decorationThickness`, `selectionColor`, `shadows` | `fontStyle`, `fontFeatures`, `fontVariations`, `decoration`, `decorationStyle`, `textAlign`, `maxLines`, `overflow`, `softWrap`, `textDirection`, `textScaler`, `textWidthBasis`, `textHeightBehavior`, `locale`, `fontFamilyFallback`, `foreground`, `background` |
| `IconStyle` | `color`, `size`, `fill`, `weight`, `grade`, `opticalSize`, `shadows` | `textDirection`, `applyTextScaling` |
| `ImageStyle` | `width`, `height`, `color`, `opacity` | `fit`, `alignment`, `colorBlendMode`, `repeat`, `centerSlice`, `matchTextDirection`, `gaplessPlayback`, `isAntiAlias`, `filterQuality` |

`text.toTextStyle(theme)` and `icon.toIconTheme(theme)` convert to Flutter types for a given theme.

### 5.6 Combining styles

| Operation | Result |
|---|---|
| `a.merge(b)` or `a + b` | `b` merged over `a`. Sub-styles and borders merge field by field; state overrides merge per state. |
| `a.add(box: …, text: …)` | Shorthand for merging individual sub-styles. |
| `a.on(state, box: …, style: …)` | Attaches or extends the override for `state`. |
| `a.copyWith(box: …)` | Replaces whole sub-styles. Rarely needed. |

Merging never mutates and never resolves: it combines references. Build component styles in layers: shared geometry, then the variant's colours, then state deltas.

### 5.7 Cascading to descendants

Every `StyledBox` publishes its style (after states) through `InheritedStyle`. Descendant `StyledText`, `StyledIcon` and `StyledImage` widgets use the nearest box's `text`, `icon` and `image` properties, then merge their own `style` over them. A hovered button recolours its label and icon with no code in the label.

```dart
StyledBox(
  style: const Style(
    text: StyledTextStyle(color: AppTokens.onSurfaceSubtle, fontSize: AppTokens.fontSizeSm),
    states: {.hovered: Style(text: StyledTextStyle(color: AppTokens.onSurface))},
  ),
  interaction: Interaction(onTap: openSettings),
  children: const [
    StyledText('Settings'),                                                                   // subtle, darker on hover
    StyledText('Beta', style: Style(text: StyledTextStyle(fontSize: AppTokens.fontSizeXs))), // inherits colour
  ],
)
```

---

## 6. States

### 6.1 Declaring overrides

An override is a `Style` merged over the base while its state is active. Write overrides as deltas: only what changes.

```dart
const button = Style(
  box: BoxStyle(color: AppTokens.primary, border: StyledBorder(radius: AppTokens.radius), motion: Motion()),
  text: StyledTextStyle(color: AppTokens.onPrimary),
  states: {
    .hovered: Style(box: BoxStyle(color: AppTokens.primaryVariant)),
    .pressed: Style(box: BoxStyle(transform: .translate(y: AppTokens.pressOffset))),
    .focused: Style(box: BoxStyle(border: StyledBorder(color: AppTokens.borderFocus, width: AppTokens.strokeWidthThick))),
    .disabled: Style(
      box: BoxStyle(color: AppTokens.disabledFill),
      text: StyledTextStyle(color: AppTokens.onDisabled),
    ),
  },
);
```

The fluent form, `style.on(StyleState.hovered, box: ...)`, does the same and merges into an existing override for that state. Use the `states:` map when you want the whole style to stay `const`.

### 6.2 Built-in states

| State | Produced by |
|---|---|
| `StyleState.hovered` | `StyledBox` with an `Interaction`, while the pointer is over it |
| `StyleState.focused` | `StyledBox` with an `Interaction`, and `StyledTextField`, while focused |
| `StyleState.pressed` | `StyledBox` with an active `Interaction`, while pressed |
| `StyleState.error` | `StyledTextField` and `StyledInput`, while an error message is shown |
| `StyleState.disabled` | `StyledBox` when `Interaction.enabled` is false, and disabled text fields |
| `StyledScreen.mobile.state`, `.tablet.state`, `.desktop.state` | Every styled widget, from the current viewport width |

### 6.3 Application states

```dart
abstract final class AppState {
  static const selected = StyleState('selected');
  static const loading = StyleState('loading');
}

const tab = Style(
  text: StyledTextStyle(color: AppTokens.onSurfaceSubtle),
  states: {AppState.selected: Style(text: StyledTextStyle(color: AppTokens.primary, fontWeight: AppTokens.fontWeightSemiBold))},
);

StyledBox(
  style: tab,
  interaction: Interaction(onTap: () => select(index)),
  states: [if (index == current) AppState.selected],
  child: StyledText(label),
)
```

Prefer this to choosing between two styles in `build`: the style stays one constant, transitions animate, and hover still layers on top of selected.

### 6.4 Precedence

When several states are active their overrides apply in order, later ones winning on shared properties:

1. The current screen tier (`mobile`, `tablet` or `desktop`)
2. Application states, in the order you pass them
3. `hovered`
4. `focused`
5. `pressed`
6. `error` (text fields)
7. `disabled`

A pressed button shows its pressed style even while hovered, a selected tab still reacts to hover, and a disabled control always looks disabled.

---

## 7. Widgets

| Widget | Purpose |
|---|---|
| `StyledBox` | The container: decoration, layout, interaction and states. |
| `StyledRow`, `StyledColumn` | `StyledBox` with the flex direction fixed. |
| `StyledText`, `StyledIcon`, `StyledImage` | Content styled by the nearest box and its own `style`. |
| `StyledTextField` | A headless text field built on `EditableText`. |
| `StyledInput` | The text field's chassis (label, box, icons, hint, error) around any child. |
| `NoScrollbarBehavior` | A `ScrollBehavior` that hides scrollbars. |

Styled widgets resolve against `StyledTheme.of(context)`: the provided theme, or the default theme (every token at its default) when there is no provider. They rebuild when the theme changes.

### 7.1 StyledBox

```dart
const StyledBox({
  StyleResolver style = const Style(),
  Widget? child,
  List<Widget>? children,         // laid out from style.flex
  Interaction? interaction,       // gestures, focus, cursor
  Iterable<StyleState> states,    // application states
  String? semanticLabel,
  VoidCallback? onEnd,            // implicit animation finished
})
```

Pass `child` for a decorated box, or `children` for a layout, never both. `Expanded`, `Flexible` and `Spacer` work inside `children` as in a `Row` or `Column`.

### 7.2 Interaction

```dart
const Interaction({
  VoidCallback? onTap, onDoubleTap, onLongPress, onSecondaryTap,
  GestureTapDownCallback? onTapDown, GestureTapUpCallback? onTapUp, GestureTapCancelCallback? onTapCancel,
  ValueChanged<bool>? onHoverChange, onFocusChange, onPressedChange,
  bool enabled = true,
  bool? focused,
  FocusNode? focusNode,
  bool autofocus = false,
  bool canRequestFocus = true,
  bool enableFeedback = true,
  HitTestBehavior behavior = HitTestBehavior.opaque,
  MouseCursor? cursor,
  MouseCursor? disabledCursor,
  String? tooltip,                // exposed to assistive technology
})
```

- **Disabled is explicit.** `StyleState.disabled` is active only when `enabled` is false. A box with no handlers is not clickable and shows the basic cursor, but keeps its normal look. For Flutter's "null handler means disabled" convention, set `enabled: onPressed != null` in your component.
- **Keyboard.** A focused box with handlers calls `onTap` on Enter or Space.
- **Nested boxes.** The innermost interactive box that receives the pointer owns the press; its ancestors drop their pressed state.

### 7.3 Content widgets

```dart
const StyledText(String text, {StyleResolver? style, String? semanticsLabel})
const StyledIcon(IconData icon, {StyleResolver? style, String? semanticLabel})
const StyledImage(ImageProvider image, {StyleResolver? style, ...})   // also .network, .asset, .memory
```

Each uses only its own sub-style from the inherited style and from `style`. Compose interactive content instead of using special widgets:

```dart
StyledBox(
  style: const StyleIconButton.naked(),
  interaction: Interaction(onTap: refresh, tooltip: 'Refresh'),
  child: const StyledIcon(AppIcons.refresh),
)
```

### 7.4 StyledTextField and StyledInput

```dart
StyledTextField(
  style: const StyleInput(),
  label: 'Email',
  hint: 'name@company.com',
  icon: const StyledIcon(AppIcons.mail),
  error: emailError,                 // non-empty activates .error
  controller: emailController,
  keyboardType: TextInputType.emailAddress,
)
```

| Part | Styled by |
|---|---|
| Field box, typed text, hint | `style`, with `focused`, `error` and `disabled` applied |
| Gap between icons and the editable | `style.flex.spacing` |
| Label | inherited text, then `labelStyle` |
| Error message | the text of the style's `error` override, unless `errorStyle` is given |
| Cursor | `cursorColor`, then the ambient `DefaultSelectionStyle`, then the field's text colour |

`StyledInput` is the same chassis around any child, for pickers and selects that look like your text fields.

---

## 8. Theming

### 8.1 StyledTheme

```dart
const light = StyledTheme();                                   // every token at its default
final brand = light.set(AppTokens.primary, const Color(0xFF7C3AED));

brand.get(AppTokens.primary);    // Color(0xFF7C3AED): a token's value
brand.read(AppTokens.radius);    // 8.0: any StyleValue, or null for null
brand.has(AppTokens.radius);     // false: radius uses its default
```

| Member | Purpose |
|---|---|
| `get(token)`, `call(token)` | Typed read with default fallback |
| `read(styleValue)` | Resolve any `StyleValue` (token, `AlphaOf`, data, constant) |
| `has(token)` | Whether the theme sets the token explicitly |
| `set(token, value)` | Copy with one token changed |
| `copyWith(overrides:, metadata:)`, `merge(other)` | Copy with several keys changed |
| `mode`, `isDark` | Read `metadata['mode']` |
| `StyledTheme.of(context)` | The provided theme, or the default theme |
| `fromMap`, `fromJson`, `toJson` | Build and serialise. Colours are `#RRGGBB` / `#AARRGGBB`, font weights `w100`–`w900`. |

### 8.2 Providing and switching

```dart
final themes = StyledThemeController(const StyledTheme());   // a ValueNotifier<StyledTheme>

runApp(StyledThemeControllerProvider(controller: themes, child: const App()));

themes.updateTheme(AppTokens.dark);   // every styled widget re-resolves; boxes with motion animate
```

| Read | Behaviour |
|---|---|
| `context.theme` | The current theme, rebuilding on change. Throws a `FlutterError` naming the fix when no provider is above. |
| `StyledTheme.of(context)` | The same, but falls back to the default theme instead of throwing. |
| `StyledThemeControllerProvider.of(context)` | The controller. `of<AppThemeService>(context)` returns your subclass. |

Generated getters give concrete values for code outside styles, such as painters: `context.theme.primary` is a `Color`, `context.theme.padding` a `double`.

### 8.3 Theme-bound styles

A `Style` holds references, so producing a Flutter `TextStyle` needs a theme. `style.bind(theme)` returns a `ThemedStyle` that can:

```dart
final title = AppTypography.h2.bind(context.theme);
title.textStyle;    // TextStyle
title.iconTheme;    // IconThemeData
title.decoration;   // BoxDecoration
```

A `ThemedStyle` is still a `Style`, so it can also be passed to `style:`. Design systems often expose their type scale this way: `extension on StyledTheme { ThemedStyle get h2 => AppTypography.h2.bind(this); }` gives both `style: theme.h2` and `Text(..., style: theme.h2.textStyle)`.

---

## 9. Responsive styling

`StyledScreen.of(context)` returns `mobile`, `tablet` or `desktop` using `StyledBreakpoints.mobile` (650) and `StyledBreakpoints.tablet` (1360) from the theme. Change them like any token: `theme.set(StyledBreakpoints.mobile, 600)`. Shorthands: `context.screen`, `context.isMobile`, `context.isTablet`, `context.isDesktop`.

Each tier is also a state, applied automatically and below every other state:

```dart
final page = const Style(
  box: BoxStyle(padding: .all(AppTokens.paddingLg)),
  flex: FlexStyle(direction: .horizontal, spacing: AppTokens.paddingLg),
).on(
  StyledScreen.mobile.state,
  box: const BoxStyle(padding: .all(AppTokens.padding)),
  flex: const FlexStyle(direction: .vertical, spacing: AppTokens.padding, crossAxisAlignment: .stretch),
);
```

`StyledScreen.mobile.state` is not a constant expression, so screen overrides use `on` rather than the `states:` map. Widgets only listen to the viewport size when their style has screen overrides.

---

## 10. Style resolvers

`StyleResolver` is the interface every `style:` parameter accepts:

```dart
abstract class StyleResolver {
  Style resolve(BuildContext context);
  StyleResolver map(Style Function(Style) transform);  // deferred transform
  StyleResolver merge(Style? other);                   // deferred merge
  StyleResolver operator +(Style other);
}
```

A `Style` resolves to itself. Presets (`StyleButton.primary()`) are resolvers that pick a variant and apply their fields. Because styles contain only references, passing a `Style` directly is as theme-safe as passing a preset; resolution against the theme happens in the widget.

```dart
StyledBox(style: const StyleCard() + const Style(box: BoxStyle(padding: .zero)), child: chart)
```

Hand-written resolvers are still useful when a style depends on constructor arguments:

```dart
class StyleProgress extends StyleResolver {
  const StyleProgress({required this.complete});
  final bool complete;

  @override
  Style resolve(BuildContext context) => Style(
        box: BoxStyle(color: complete ? AppTokens.success : AppTokens.primary, border: const StyledBorder(radius: AppTokens.radiusFull)),
      );
}
```

For anything with variants or states, use `@StyledPreset` instead.

---

## 11. Code generation: design tokens

### 11.1 Setup

Add `styled_generator` and `build_runner` as dev dependencies, add a `part` directive to each annotated file, and run:

```bash
dart run build_runner build --delete-conflicting-outputs   # once
dart run build_runner watch --delete-conflicting-outputs   # while editing
```

Generated code goes to `<file>.styled.g.dart`. Commit it so consumers of your design system do not need to run the generator.

### 11.2 The spec

```dart
import 'package:flutter/widgets.dart';
import 'package:styled/styled.dart';

part 'app_tokens.styled.g.dart';

@StyledTokens(className: 'AppTokens')
abstract final class _AppTokensSpec {
  // Colour
  /// Primary brand colour for actions and focus.
  @Token(dark: Color(0xFF3B82F6))
  static const Color primary = Color(0xFF2563EB);
  @Token(dark: Color(0xFF60A5FA))
  static const Color primaryVariant = Color(0xFF1D4ED8); // Hover and pressed fills
  @Token(dark: Color(0xFF0B0F19), modes: {'contrast': Color(0xFF000000)})
  static const Color background = Color(0xFFF8FAFC);
  @Token(dark: Color(0x4D1E3A8A)) // 30% alpha baked in: annotation values must be const
  static const Color primarySubtle = Color(0xFFEFF6FF);

  // Spacing and geometry
  static const double paddingXs = 4.0;
  static const double paddingSm = 8.0;
  static const double padding = 16.0;
  static const double paddingLg = 24.0;
  static const double radius = 8.0;
  static const double strokeWidth = 1.0;

  // Typography
  static const String fontFamily = 'Inter';
  static const double fontSize = 14.0;
  static const FontWeight fontWeightSemiBold = .w600;

  // Opacity scale
  static const double opacityNone = 0.0;
  static const double opacityFaint = 0.08;
  static const double opacitySubtle = 0.18;
  static const double opacityMedium = 0.3;

  // Shadow scale
  static const ShadowLevel shadowSm = ShadowLevel(opacity: 0.04, blurRadius: 10, dy: 2);
  static const ShadowLevel glowMd = ShadowLevel(opacity: 0.25, blurRadius: 12, dy: 4);

  // Motion
  static const Duration animationDuration = Duration(milliseconds: 200);
  static const double pressOffset = 1.0;
}
```

Rules:

- Fields are `static const` with an initializer. Declare the type when the literal would infer the wrong one (`16.0` is a `double`, `16` an `int`).
- Any const type works: colours, numbers, strings, `FontWeight`, `Duration`, `ShadowLevel`, enums, your own const classes.
- `///` comments, or a trailing `//` on the same line, become documentation on the token and its getter.

### 11.3 What is generated

| Output | Example |
|---|---|
| A `ThemeToken` per field, `all`, `toDefaultMap()` | `AppTokens.primary` is a `ThemeToken<Color>`, usable directly in styles |
| Getters on `StyledTheme` | `context.theme.primary` is a `Color`, for painters and plain widgets |
| Typed overrides | `theme.withAppTokens(primary: tenantColor, radius: 4)`; a wrong type is a compile error |
| Theme modes | `AppTokens.dark`, `AppTokens.themeFor('contrast')`, `AppTokens.overridesFor(mode)`, `AppTokens.modeNames` |

| Option | Default | Effect |
|---|---|---|
| `@StyledTokens(className:)` | spec name without `_` and `Spec`, ending in `Tokens` | Name of the tokens class |
| `@StyledTokens(extensionName:)` | `${className}Extension` | Name of the getter extension |
| `@StyledTokens(generateDefaultMap:)` | `true` | Whether to emit `toDefaultMap()` |
| `@StyledTokens(prefix:)` | none | Prefix every key: `'charts'` makes `'charts.grid'` |
| `@Token(key:)` | field name | Explicit key, for example to match a server format |
| `@Token(dark:)` | none | Value in the generated `dark` theme |
| `@Token(modes:)` | none | Values for other named modes |

### 11.4 Designing the scales

Because styles cannot compute values, the token spec is the complete design specification. Organise it as scales:

| Scale | Typical steps |
|---|---|
| Spacing | `paddingXxs` 2, `paddingXs` 4, `paddingSm` 8, `padding` 16, `paddingLg` 24 |
| Radius | `radiusSm` 4, `radius` 8, `radiusLg` 12, `radiusFull` 999 |
| Opacity | `opacityNone`, `opacityFaint`, `opacitySubtle`, `opacityMedium`, `opacityBold`, `opacityMuted`, `opacityStrong` |
| Shadow | `shadowSm`, `shadowLg`, `glowSm`, `glowMd`, `glowLg`, `glowPressed` |
| Type | `fontSizeXs` … `h0FontSize`, weights, letter spacings, line heights |
| Motion | `animationDurationFast`, `animationDuration`, `animationDurationSlow`, lifts and offsets |
| Component sizes | `buttonHeight`, `iconSize`, `avatarSize`, `checkboxSize` |
| State colours | `primaryVariant` (hover and press), `disabledFill`, `onDisabled` |

When a component seems to need a new value, first check whether an existing step is close enough. Only add a step when the design calls for it, and name it by role or scale position, not by number.

---

## 12. Code generation: presets

A preset is a reusable, themeable style with named variants. You write a spec of constant styles; the generator writes the resolver class, constructors, equality and state wiring.

### 12.1 A first preset

```dart
import 'package:flutter/widgets.dart';
import 'package:styled/styled.dart';

import 'app_tokens.dart';

part 'badges.styled.g.dart';

/// Small status labels.
@StyledPreset()
abstract class _StyleBadgeSpec {
  /// Merged under every variant.
  static const base = Style(
    box: BoxStyle(
      padding: .symmetric(horizontal: AppTokens.paddingSm, vertical: AppTokens.paddingXxs),
      border: StyledBorder(radius: AppTokens.radiusFull),
    ),
    text: StyledTextStyle(fontSize: AppTokens.fontSizeXs, fontWeight: AppTokens.fontWeightSemiBold),
  );

  /// Neutral information.
  @Variant(isDefault: true)
  static const neutral = Style(box: BoxStyle(color: AppTokens.surfaceSubtle), text: StyledTextStyle(color: AppTokens.onSurface));

  /// Something went wrong.
  @Variant(aliases: ['danger'])
  static const error = Style(box: BoxStyle(color: AppTokens.errorSubtle), text: StyledTextStyle(color: AppTokens.error));
}
```

```dart
StyledBox(style: const StyleBadge(), child: const StyledText('Draft'))
StyledBox(style: const StyleBadge.danger(), child: const StyledText('Failed'))
StyledBox(style: StyleBadge.fromVariant(status.badge), child: StyledText(status.label))
```

### 12.2 Members

A spec member is a static `Style` field (preferably `static const`) or a static method returning `Style`. Members are classified by annotation and name:

| Member | Role |
|---|---|
| `@Variant()` | A variant: an enum value and a named constructor |
| `base` | Merged under every variant |
| `hovered`, `pressed`, `focused`, `disabled`, `error`, `mobile`, `tablet`, `desktop` | Override for that state, on every variant |
| `${variant}${State}`, such as `primaryHovered` | Override for that state, on one variant |
| `@On('selected')` | Override for an application state, on every variant |
| `@On('selected', variants: ['ghost'])` | Override for an application state, on the named variants |
| Any other public `Style` member | A variant |
| Private members (`_name`) | Ignored, unless annotated |

Annotate every variant with `@Variant()` even though it is optional. A public helper returning `Style` would otherwise become a variant, and a variant named like a state (for example `error`) must be annotated to stay a variant.

### 12.3 Fields, methods and recipes

Use a field (`static const`) when the style is fixed. Use a method when the preset has parameters: named parameters become fields on the generated class, with the same defaults.

```dart
@StyledPreset()
abstract class _StyleButtonSpec {
  static Style base({bool isExpanded = false}) => Style(
        box: BoxStyle(
          padding: const .symmetric(horizontal: AppTokens.paddingLg, vertical: AppTokens.paddingSm),
          constraints: isExpanded ? const StyledBoxConstraints(minWidth: .infinity) : null,
        ),
        flex: FlexStyle(direction: .horizontal, mainAxisSize: isExpanded ? .max : .min),
      );
  // ...
}

const StyleButton.primary(isExpanded: true)
```

When variants share a shape, write a private top-level recipe that takes tokens, and call it from `static final` members:

```dart
Style _solid(ThemeToken<Color> fill, ThemeToken<Color> onFill, ThemeToken<Color> hover) => Style(
      box: BoxStyle(color: fill, border: const StyledBorder(radius: AppTokens.radius)),
      text: StyledTextStyle(color: onFill),
      icon: IconStyle(color: onFill),
      states: {
        .hovered: Style(box: BoxStyle(color: hover)),
        .disabled: const Style(box: BoxStyle(color: AppTokens.disabledFill), text: StyledTextStyle(color: AppTokens.onDisabled)),
      },
    );

@StyledPreset()
abstract class _StyleButtonSpec {
  @Variant(isDefault: true)
  static final primary = _solid(AppTokens.primary, AppTokens.onPrimary, AppTokens.primaryVariant);
  @Variant()
  static final success = _solid(AppTokens.success, AppTokens.onSuccess, AppTokens.successVariant);
  @Variant()
  static final danger = _solid(AppTokens.error, AppTokens.onError, AppTokens.errorVariant);
}
```

A recipe that takes `ThemeToken`s guarantees every variant uses the same opacities, shadows and offsets: the recipe decides the shape, the variant only chooses colours.

Data parameters are wrapped once, at the boundary:

```dart
@Variant()
static Style tag({Color? customColor}) => _tag(DataValue.of(customColor) ?? AppTokens.primary);
```

Members never receive the theme. The only injected parameter is `StyledScreen screen`, for layouts that differ by tier in ways a `mobile` state cannot express:

```dart
@Variant(isDefault: true)
static Style page(StyledScreen screen) => Style(
      box: BoxStyle(padding: switch (screen) {
        .mobile => const .all(AppTokens.padding),
        _ => const .all(AppTokens.paddingLg),
      }),
    );
```

### 12.4 States by naming convention

```dart
@StyledPreset()
abstract class _StyleChipSpec {
  static const base = Style(box: BoxStyle(motion: Motion(AppTokens.animationDurationFast)));

  // Every variant
  static const pressed = Style(box: BoxStyle(transform: .translate(y: AppTokens.pressOffset)));
  static const disabled = Style(box: BoxStyle(color: AppTokens.disabledFill));

  @Variant(isDefault: true)
  static const neutral = Style(box: BoxStyle(color: AppTokens.surface, border: StyledBorder(color: AppTokens.border)));
  static const neutralHovered = Style(box: BoxStyle(color: AppTokens.surfaceHover));        // neutral only

  @Variant()
  static const accent = Style(box: BoxStyle(color: AppTokens.primarySubtle));
  @On('selected', variants: ['accent'])
  static const accentSelected = Style(box: BoxStyle(border: StyledBorder(color: AppTokens.primary)));
}
```

### 12.5 Precedence inside a preset

From lowest to highest: `base`; state members for every variant; the variant itself, including states it declares; state members for that variant. The more specific declaration always wins. At render time, the merged overrides follow the runtime precedence in [6.4](#64-precedence).

### 12.6 What is generated

For the spec in 12.4:

```dart
enum ChipVariant { neutral, accent }

class StyleChip extends StyleResolver {
  final ChipVariant variant;

  const StyleChip() : variant = ChipVariant.neutral;
  const StyleChip.neutral() : variant = ChipVariant.neutral;
  const StyleChip.accent() : variant = ChipVariant.accent;
  const StyleChip.fromVariant(this.variant);

  @override
  Style resolve(BuildContext context) {
    final base = _StyleChipSpec.base
        .on(StyleState.pressed, style: _StyleChipSpec.pressed)
        .on(StyleState.disabled, style: _StyleChipSpec.disabled);
    return switch (variant) {
      ChipVariant.neutral => base.merge(_StyleChipSpec.neutral).on(StyleState.hovered, style: _StyleChipSpec.neutralHovered),
      ChipVariant.accent => base.merge(_StyleChipSpec.accent).on(const StyleState('selected'), style: _StyleChipSpec.accentSelected),
    };
  }

  StyleChip copyWith({ChipVariant? variant}) => StyleChip.fromVariant(variant ?? this.variant);
  // operator ==, hashCode, toString => 'StyleChip.accent'
}
```

The generated `resolve` never reads the theme. It only merges references; widgets resolve them.

### 12.7 Options and validation

| Option | Default | Effect |
|---|---|---|
| `@StyledPreset(name:)` | spec name without `_`, `Spec` or `Preset`, prefixed with `Style` | Generated class name |
| `@StyledPreset(variantEnumName:)` | class name without `Style`, plus `Variant` | Enum name |
| `@Variant(isDefault:, aliases:)` | first variant, none | Default constructor and extra constructor names |
| `@On(state, variants:)` | all variants | Application state override |

The build fails, pointing at the member, when:

| Problem | Message (abridged) |
|---|---|
| A member takes a `StyledTheme`, `BuildContext` or `Size` | "must not read concrete theme values: reference tokens directly" |
| A member is not a `Style` | "must be a Style" |
| A parameter other than `StyledScreen` is positional | "must be named, or be `StyledScreen screen`" |
| Two variants are marked `isDefault` | "Only one variant can be the default" |
| An alias repeats a variant or alias | "clashes with another variant or alias" |
| `@On(variants:)` names a missing variant | "targets unknown variant" |
| No variants at all | "must declare at least one variant" |

---

## 13. Building a design system

Keep the design system in its own package and let applications consume presets by name.

```
packages/my_ui/
  lib/
    my_ui.dart                    // exports styled, tokens, typography, presets, widgets
    src/
      tokens/tokens.dart          // @StyledTokens: every scale, light and dark values
      theme/typography.dart       // AppTypography: the type scale as const styles, bound getters
      presets/recipes.dart        // shared recipes: glow, focus ring, disabled
      presets/buttons.dart        // @StyledPreset specs
      widgets/my_button.dart      // components: structure plus a default preset
```

| Layer | Contains | Example |
|---|---|---|
| Tokens | Every design value, as scales, with dark values | `primary`, `paddingSm`, `opacitySubtle`, `glowMd` |
| Typography | The type scale as constant styles | `AppTypography.h2` |
| Recipes | Shapes shared by components, taking tokens | `glow(color, level)`, `focusRing` |
| Presets | Variants and states per component | `StyleButton.ghost()` |
| Components | Structure plus a default preset | `MyButton(label:, onTap:)` |
| Application | Components and presets only | `MyButton(style: const StyleButton.danger(), ...)` |

Application code then contains no colours, no numbers, and ideally no `Style(...)` literals.

A component pairs structure with a preset:

```dart
class MyButton extends StatelessWidget {
  const MyButton({super.key, this.style = const StyleButton(), this.label, this.icon, this.onTap, this.loading = false});

  final StyleResolver style;
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) => StyledBox(
        style: style,
        interaction: Interaction(onTap: onTap, enabled: onTap != null && !loading),
        states: [if (loading) AppState.loading],
        children: [
          if (icon != null) StyledIcon(icon!),
          if (label != null) Flexible(child: StyledText(label!)),
        ],
      );
}
```

---

## 14. Recipes

### 14.1 Dark mode

```dart
final themes = StyledThemeController(const StyledTheme());
void toggleDark() => themes.updateTheme(themes.value.isDark ? const StyledTheme() : AppTokens.dark);
```

### 14.2 Tenant branding

```dart
StyledTheme brandFor(Tenant tenant) =>
    AppTokens.themeFor(tenant.prefersDark ? 'dark' : 'light').withAppTokens(primary: tenant.brandColor, fontFamily: tenant.fontFamily);
```

`themeFor` with an undeclared mode returns the defaults, so `'light'` needs no declaration.

### 14.3 Themes from a server

```dart
final remote = StyledTheme.fromJson(await api.fetchTheme());   // {"primary": "#7C3AED", "radius": 6}
themes.updateTheme(AppTokens.dark.merge(remote));
```

### 14.4 Reduced motion

```dart
themes.updateTheme(themes.value.withAppTokens(
  animationDurationFast: Duration.zero,
  animationDuration: Duration.zero,
  animationDurationSlow: Duration.zero,
));
```

Every `Motion` reads its duration from a token, so this disables animation everywhere.

### 14.5 Data-coloured tags

```dart
Style tagStyle(Color tagColor) => Style(
      box: BoxStyle(
        color: AlphaOf(DataValue(tagColor), AppTokens.opacityFaint),
        border: .all(color: AlphaOf(DataValue(tagColor), AppTokens.opacityMedium), width: AppTokens.strokeWidth, radius: AppTokens.radiusSm),
      ),
      text: StyledTextStyle(color: DataValue(tagColor), fontSize: AppTokens.fontSizeXs),
    );
```

The colour is data; the tint levels still come from the scale.

### 14.6 Painting with theme values

Code outside styles, such as a `CustomPainter`, reads concrete values from the theme:

```dart
final theme = context.theme;
ChartPainter(gridColor: theme.chartGrid, labelStyle: AppTypography.subscript.bind(theme).textStyle);
```

### 14.7 Adjusting a preset at the call site

```dart
const StyleCard() + const Style(box: BoxStyle(padding: .zero))
```

If you adjust the same preset the same way in several places, add a variant or a field instead.

---

## 15. Testing

Provide a theme with `StyledThemeControllerProvider.test`:

```dart
Widget harness(Widget child, {StyledTheme theme = const StyledTheme()}) => StyledThemeControllerProvider.test(
      theme: theme,
      child: Directionality(textDirection: .ltr, child: child),
    );
```

Style fields hold references, so compare references or resolve them:

```dart
final style = const StyleButton.primary().resolve(context).resolveStates([.hovered]);
expect(style.box.color, AppTokens.primaryVariant);                       // the reference
expect(context.theme.read(style.box.color), const Color(0xFF1D4ED8));      // the value
```

Rendered widgets hold concrete Flutter values:

```dart
final container = tester.widget<Container>(find.byType(Container));
expect((container.decoration! as BoxDecoration).color, AppTokens.surface.defaultValue);
```

Test theme switching by updating the controller and pumping:

```dart
controller.updateTheme(AppTokens.dark);
await tester.pump();
```

In tests, one-off values that are not tokens are `DataValue`s: `BoxStyle(width: DataValue(100.0))`.

---

## 16. Best practices

**Design values are tokens.**
- Never use `DataValue` to express a design decision. If the scale lacks a step, add the step.
- Declare dark values beside light values with `@Token(dark:)`, so no token is forgotten in dark mode.
- Name tokens by role or scale position (`opacitySubtle`, `paddingSm`, `primaryVariant`), never by number.
- Prefer state colour tokens (`primaryVariant`, `disabledFill`) to computed colour shifts.

**Styles are constants.**
- Write presets as `static const` members, with the `states:` map for overrides.
- Use recipes that take `ThemeToken`s for shared shapes, so variants differ only in which tokens they pass.
- Put `motion` on a component's base style.
- Write state overrides as deltas, and rely on field-wise border merging.

**Data enters once.**
- Wrap data at the preset boundary: `DataValue.of(customColor) ?? AppTokens.primary`.
- Apply scale opacities to data colours with `AlphaOf`, so data-coloured elements still follow the design.

**Respect the boundaries.**
- Application code uses components and presets. If it needs a `Style(...)`, the design system is missing a preset or a field.
- Read concrete values (`context.theme.primary`) only outside styles: painters, third-party widgets, layout logic.
- Mark interactivity explicitly with `Interaction(enabled: ...)`.

**Generated code.**
- Commit `*.styled.g.dart`, run `build_runner watch` while editing, and pin `styled` and `styled_generator` to the same tag.

---

## 17. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `The argument type 'Color' can't be assigned to the parameter type 'StyleValue<Color>?'` | A raw colour in a style. Use a token, or `AlphaOf(token, opacityToken)`. Use `DataValue` only for runtime data. |
| `The argument type 'double' can't be assigned to the parameter type 'StyleValue<double>?'` | A raw number. Use the scale token; `StyleValue.infinity` and `StyleValue.zero` cover layout constants. |
| `The operator '*' isn't defined for the type 'ThemeToken<double>'` | Arithmetic on a token. Add a scale step instead. |
| `The argument type 'EdgeInsets' can't be assigned to the parameter type 'StyledEdgeInsets?'` | Use the `Styled*` wrapper with the same constructor name. |
| `takes a StyledTheme. Spec members must not read concrete theme values` | Remove the theme parameter and reference tokens directly. |
| The border is not drawn | A uniform border needs both `color` and `width` after merging. |
| A colour is right in light mode but wrong in dark | The token has no `@Token(dark:)` value, or a `DataValue` is being used for a design colour. |
| A state override has no effect | The state is not active: interaction states need an `Interaction`, application states need `states: [...]`. |
| Hover does not animate | `box.motion` is not set. |
| `context.theme called with a context that does not contain a StyledThemeProvider` | Add `StyledThemeControllerProvider` above, or use `StyledTheme.of(context)`, which falls back to defaults. |
| `@Token(dark: ...)` rejects `color.withValues(alpha: ...)` | Annotation values must be const. Bake the alpha into the literal: `Color(0x4D1E3A8A)` is 30%. |

---

## 18. API reference

### Values (`package:styled/styled.dart`)

| Symbol | Summary |
|---|---|
| `StyleValue<T>` | Sealed. `resolve(theme)`; constants `StyleValue.zero`, `StyleValue.infinity` |
| `ThemeToken<T>` | `key`, `defaultValue`; resolves to the theme's value |
| `DataValue<T>` | `value`; `DataValue.of(nullable)` |
| `AlphaOf` | `color` (`StyleValue<Color>`), `opacity` (`ThemeToken<double>`) |
| `ShadowLevel` | `opacity`, `blurRadius`, `spreadRadius`, `dx`, `dy`; a token value type |
| `StyledEdgeInsets`, `StyledBoxConstraints`, `StyledBorderSide`, `StyledBoxShadow`, `StyledTransform` | Token-aware wrappers; each has `resolve(theme)` |
| `Motion` | `duration` (`StyleValue<Duration>`), `curve` |
| `StyledDefaults.motionDuration` | Default `Motion` duration token |

### Styles

| Symbol | Summary |
|---|---|
| `Style` | `box`, `text`, `icon`, `flex`, `image`, `states`; `merge`, `+`, `add`, `on`, `resolveStates`, `inheritFrom`, `hasState`, `copyWith`, `bind` |
| `ThemedStyle` | A `Style` bound to a theme; `textStyle`, `iconTheme`, `decoration` |
| `BoxStyle` | `decoration(theme)`, `merge` |
| `StyledBorder` | `boxBorder(theme)`, `borderRadius(theme)`, `merge` |
| `FlexStyle` | `build(children, theme)`, `merge` |
| `StyledTextStyle` | `toTextStyle(theme)`, `merge` |
| `IconStyle` | `toIconTheme(theme)`, `merge` |
| `ImageStyle` | `merge` |
| `StyleState` | `hovered`, `pressed`, `focused`, `disabled`, `error`, `interaction` |
| `StyleResolver` | `resolve`, `map`, `merge`, `+` |
| `InheritedStyle` | `of`, `maybeStyleOf` |

### Theme and widgets

| Symbol | Summary |
|---|---|
| `StyledTheme` | `get`, `read`, `call`, `has`, `set`, `copyWith`, `merge`, `of`, `fromMap`, `fromJson`, `toJson`, `mode`, `isDark` |
| `StyledThemeController`, `StyledThemeControllerProvider` | Provide and switch themes; `test`, `of` |
| `context.theme`, `context.screen`, `context.isMobile` … | Extensions |
| `StyledScreen`, `StyledBreakpoints` | Tiers and breakpoint tokens |
| `StyledBox`, `StyledRow`, `StyledColumn`, `Interaction` | Containers, layouts and behaviour |
| `StyledText`, `StyledIcon`, `StyledImage`, `StyledTextField`, `StyledInput` | Content and input |

### Annotations

| Annotation | Target | Parameters |
|---|---|---|
| `@StyledTokens` | class | `className`, `extensionName`, `generateDefaultMap`, `prefix` |
| `@Token` | field | `key`, `dark`, `modes` |
| `@StyledPreset` | class | `name`, `variantEnumName` |
| `@Variant` | field or method | `isDefault`, `aliases` |
| `@On` | field or method | `state`, `variants` |

---

## 19. Migrating from the earlier API

### From raw values to references

| Before | Now |
|---|---|
| `BoxStyle(color: theme.surface)` | `BoxStyle(color: AppTokens.surface)` |
| `color: theme.primary.withValues(alpha: 0.2)` | `color: AlphaOf(AppTokens.primary, AppTokens.opacitySubtle)` |
| `padding: EdgeInsets.all(theme.padding)` | `padding: .all(AppTokens.padding)` |
| `constraints: BoxConstraints(maxWidth: 600)` | `constraints: StyledBoxConstraints(maxWidth: AppTokens.modalWidth)` |
| `BorderSide(color: theme.border, width: theme.strokeWidth)` | `StyledBorderSide(color: AppTokens.border, width: AppTokens.strokeWidth)` |
| `boxShadow: [BoxShadow(color: c.withValues(alpha: 0.25), blurRadius: 12, offset: Offset(0, 4))]` | `boxShadow: [.level(AppTokens.primary, AppTokens.glowMd)]` |
| `transform: Matrix4.translationValues(0, -2, 0)` | `transform: .translate(y: AppTokens.cardHoverLift)` |
| `width: double.infinity` | `width: .infinity` |
| `radius: theme.radius * 0.75` | `radius: AppTokens.radiusChip` (a new scale step) |
| `motion: Motion(Duration(milliseconds: 200))` | `motion: Motion(AppTokens.animationDuration)` |
| `fontWeight: FontWeight.w600` | `fontWeight: AppTokens.fontWeightSemiBold` |
| Computed hover colours (HSL shifts) | State colour tokens such as `primaryVariant` |
| User-chosen colour `customColor` | `DataValue.of(customColor) ?? AppTokens.primary` |
| `style.textStyle` | `style.bind(theme).textStyle`, or `style.text.toTextStyle(theme)` |
| `style.box.decoration` | `style.box.decoration(theme)` |

### Presets

| Before | Now |
|---|---|
| `static Style primary(StyledTheme theme) => Style(box: BoxStyle(color: theme.primary))` | `static const primary = Style(box: BoxStyle(color: AppTokens.primary))` |
| `static Style base(StyledTheme theme, {bool isExpanded = false})` | `static Style base({bool isExpanded = false})` |
| `(StyledTheme theme, StyledScreen screen)` | `(StyledScreen screen)` |
| `@Variant()` on methods only | `@Variant()` and `@On()` on fields or methods |

### From the first release

| Before | Now |
|---|---|
| `StyledPressableBox(style:, onTap:, child:)` | `StyledBox(style:, interaction: Interaction(onTap:), child:)` |
| `StyledFlex`, `StyledWrap`, `StyledPressableRow/Column/Wrap` | `StyledBox(children:)` with `flex.direction` or `flex.wrap: true` |
| `StyledPressableText`, `StyledPressableIcon`, `StyledPressableImage` | An interactive `StyledBox` around the content widget |
| `disabled: true` | `Interaction(enabled: false)` |
| `StyledToken.hovered` (a `String`) | `StyleState.hovered` |
| `animates: true, animationDuration: d, curve: c` | `motion: Motion(durationToken, c)` |
| `borderRadius: BorderRadius.circular(r)` | `border: StyledBorder(radius: radiusToken)` |
| `resolver.mergeFlex(...)` | `resolver.map((s) => s.add(flex: FlexStyle(...)))` or `resolver + Style(...)` |
| `resolveTokens([...])` | `resolveStates([...])` |
| `@Responsive(mobile: '_mobile')` | A `mobile` state member, or a `StyledScreen screen` parameter |
| `@StyledPreset(mergeBase: false)` | Removed; `base` always merges |

---

## License

MIT
