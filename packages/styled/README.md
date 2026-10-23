# Styled

A headless, token-driven styling engine and component framework for Flutter.

`styled` decouples visual design and styling logic from widget trees. It provides a composable `Style` system, type-safe design tokens, state-driven styling (hover, pressed, focused, disabled), responsive layout resolution, and dynamic runtime theming while enforcing a strict **Single Source of Truth (SSoT)** architecture.

---

## Key Features

- 🎯 **Single Source of Truth (SSoT)**: All visual and layout properties (padding, alignment, spacing, typography, decoration, animations) live entirely inside `Style` definitions—never duplicated across widget constructor parameters.
- ⚡ **State-Driven Styling**: Seamlessly apply interactive states (`hovered`, `pressed`, `focused`, `disabled`, `error`) using `style.on(token, ...)`.
- 📱 **Responsive Screen Resolution**: Define breakpoint-adaptive layouts (`mobile`, `tablet`, `desktop`) directly in styles without cluttered `MediaQuery` logic in your UI widgets.
- 🛠️ **Code Generation (`styled_generator`)**: Zero-boilerplate component presets and token extensions with `@StyledPreset`, `@Variant`, `@Responsive`, and `@StyledTokens`.
- 🎨 **Type-Safe Design Tokens**: Create custom tokens (`ThemeToken<Color>`, `ThemeToken<double>`, `ThemeToken<FontWeight>`) with safe defaults and dynamic overrides.
- 🌓 **Dynamic Runtime Theming**: Switch between light, dark, high-contrast, or tenant-branded themes with `ThemeController` and `StyledThemeProvider`.
- 🧩 **Comprehensive Headless Widgets**: Drop-in primitives including `StyledBox`, `StyledFlex`, `StyledRow`, `StyledColumn`, `StyledWrap`, `StyledText`, `StyledIcon`, `StyledImage`, `StyledTextField`, and their full-featured `StyledPressable*` variants.
- ✨ **Built-in Micro-Motion**: Native support for implicit animations, custom curves, and durations directly in `BoxStyle` and `ImageStyle`.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Core Architecture & Philosophy](#core-architecture--philosophy)
3. [The `Style` Object](#the-style-object)
   - [BoxStyle](#boxstyle)
   - [FlexStyle](#flexstyle)
   - [StyledTextStyle](#styledtextstyle)
   - [IconStyle](#iconstyle)
   - [ImageStyle](#imagestyle)
   - [InputStyle](#inputstyle)
4. [State-Driven Styles & Tokens](#state-driven-styles--tokens)
   - [Interactive States (`StyledToken`)](#interactive-states-styledtoken)
   - [Responsive Breakpoints (`StyledScreen`)](#responsive-breakpoints-styledscreen)
5. [Theming System](#theming-system)
   - [Defining Design Tokens (`ThemeToken<T>`)](#defining-design-tokens-themetokent)
   - [Configuring Themes (`StyledTheme`)](#configuring-themes-styledtheme)
   - [Providing & Switching Themes (`ThemeController`)](#providing--switching-themes-themecontroller)
6. [Code Generation (`styled_generator`)](#code-generation-styledgenerator)
   - [Installation & Setup](#installation--setup)
   - [Component Presets (`@StyledPreset` & `@Variant`)](#component-presets-styledpreset--variant)
   - [Responsive Presets (`@Responsive`)](#responsive-presets-responsive)
   - [Design Tokens & Theme Getters (`@StyledTokens` & `@Token`)](#design-tokens--theme-getters-styledtokens--token)
   - [IDE Hover Documentation Propagation](#ide-hover-documentation-propagation)
7. [Manual Component Presets (`StyleResolver`)](#manual-component-presets-styleresolver)
8. [Widget Catalog](#widget-catalog)
   - [Boxes & Containers](#boxes--containers)
   - [Flex, Rows, Columns & Wrap](#flex-rows-columns--wrap)
   - [Text & Typography](#text--typography)
   - [Icons & Images](#icons--images)
   - [Form Inputs](#form-inputs)
9. [Complete End-to-End Example](#complete-end-to-end-example)

---

## Quick Start

### 1. Setup Theme Provider

Wrap your app with `StyledThemeProvider` and pass a `ThemeController`:

```dart
import 'package:flutter/widgets.dart';
import 'package:styled/styled.dart';

void main() {
  final themeController = ThemeController(const StyledTheme());

  runApp(
    StyledThemeProvider(
      controller: themeController,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomeScreen(),
    );
  }
}
```

### 2. Build with Styled Components

```dart
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Define a composable Style
    final cardStyle = Style(
      box: BoxStyle(
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        border: StyledBorder.all(color: const Color(0xFFE2E8F0), radius: 12),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
        animates: true,
        animationDuration: const Duration(milliseconds: 180),
      ),
      flex: const FlexStyle(
        direction: Axis.vertical,
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
      ),
    ).on(
      StyledToken.hovered,
      box: BoxStyle(
        boxShadow: [
          BoxShadow(color: Colors.blue.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6)),
        ],
        transform: Matrix4.translationValues(0, -2, 0),
      ),
    );

    // 2. Render using Headless Styled Widgets
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: StyledPressableBox(
          style: cardStyle,
          onTap: () => print('Card tapped!'),
          child: const StyledColumn(
            children: [
              StyledText(
                'Analytics Pro',
                style: Style(
                  text: StyledTextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              StyledText(
                'Interactive state-driven component with hover glow.',
                style: Style(
                  text: StyledTextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## Core Architecture & Philosophy

`styled` is built on three foundational tenets:

### 1. Strict Single Source of Truth (SSoT)
In conventional Flutter widget libraries, layout and styling properties are split arbitrarily between container parameters, decoration objects, and widget constructors (`Row(mainAxisAlignment: ...)`, `Text(style: ...)`, `Container(padding: ...)`). 

In `styled`, **all styling, layout, motion, and typography rules reside strictly in `Style` models**. Widget constructors only receive structural children and behavioral callbacks (`onTap`, `controller`, `child`).

### 2. Composable Sub-Styles
A `Style` instance is a composite of focused sub-style models:
- `box`: Dimensions, padding, margins, borders, shadows, shape, transform, animations.
- `flex`: Axis direction, alignment, item spacing, wrapping, clipping.
- `text`: Font size, weight, color, line height, letter spacing, font features.
- `icon`: Icon size, color, fill, grade, optical size.
- `image`: Fit, alignment, repeat, filter quality, opacity, center slice.
- `input`: Text selection, cursor color, input decoration, placeholder styling.

### 3. Immutable Layering & Cascading
Styles can be combined using `.add()`, `.merge()`, or `.copyWith()`, allowing design systems to build deep preset hierarchies with zero side effects:

```dart
final baseButton = Style(box: BoxStyle(padding: EdgeInsets.all(12), animates: true));
final primaryButton = baseButton.add(box: BoxStyle(color: Colors.blue));
final hoveredPrimary = primaryButton.on(StyledToken.hovered, box: BoxStyle(color: Colors.blueAccent));
```

---

## The `Style` Object

### BoxStyle
Encapsulates container sizing, spacing, borders, shadows, transforms, and animations:

```dart
BoxStyle(
  color: Colors.white,
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  margin: const EdgeInsets.all(8),
  width: 200,
  height: 60,
  constraints: const BoxConstraints(minWidth: 100, maxWidth: 300),
  alignment: Alignment.center,
  border: StyledBorder.all(color: Colors.blue, width: 1.5, radius: 8),
  borderRadius: const BorderRadius.all(Radius.circular(8)),
  shape: BoxShape.rectangle,
  boxShadow: const [
    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
  ],
  gradient: const LinearGradient(colors: [Colors.blue, Colors.purple]),
  transform: Matrix4.translationValues(0, -2, 0),
  transformAlignment: Alignment.center,
  clip: Clip.antiAlias,
  animates: true,
  animationDuration: const Duration(milliseconds: 200),
  curve: Curves.easeOutCubic,
)
```

#### `StyledBorder` Utility
Provides fluent constructors for borders and border radii:
- `StyledBorder.all(color: ..., width: ..., radius: ...)`
- `StyledBorder.only(top: ..., bottom: ..., radiusTopLeft: ...)`
- `StyledBorder(bottom: BorderSide(color: Colors.grey))`

---

### FlexStyle
Controls flex directions, item alignment, native item spacing, and wrap parameters:

```dart
FlexStyle(
  direction: Axis.horizontal,
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  crossAxisAlignment: CrossAxisAlignment.center,
  mainAxisSize: MainAxisSize.max,
  spacing: 12.0, // Spacing between flex items (no SizedBox needed!)
  clipBehavior: Clip.none,
  // Wrap properties (used when rendered with StyledWrap)
  wrapSpacing: 8.0,
  wrapRunSpacing: 8.0,
  wrapAlignment: WrapAlignment.start,
  wrapCrossAlignment: WrapCrossAlignment.center,
)
```

---

### StyledTextStyle
Provides typography configuration, text features, and line metrics:

```dart
StyledTextStyle(
  color: Color(0xFF0F172A),
  fontSize: 16,
  fontWeight: FontWeight.w600,
  fontFamily: 'Inter',
  letterSpacing: -0.2,
  height: 1.4,
  textAlign: TextAlign.left,
  softWrap: true,
  overflow: TextOverflow.ellipsis,
  maxLines: 2,
  fontFeatures: const [
    FontFeature.tabularFigures(), // Monospaced numeric alignment for tables & metrics
  ],
)
```

---

### IconStyle
Controls icon rendering, font sizing, and visual weights:

```dart
IconStyle(
  color: Colors.blue,
  size: 20,
  weight: 600,
  fill: 1.0,
  grade: 0.25,
  opticalSize: 20,
)
```

---

### ImageStyle
Controls image rendering, opacity transitions, 9-slice center slicing, and filter quality:

```dart
ImageStyle(
  width: 48,
  height: 48,
  fit: BoxFit.cover,
  alignment: Alignment.center,
  filterQuality: FilterQuality.medium,
  opacity: 0.9,
  animates: true,
  animationDuration: const Duration(milliseconds: 150),
)
```

---

### InputStyle
Customizes input borders, hints, cursor metrics, and text selection:

```dart
InputStyle(
  placeholder: 'Enter account email...',
  placeholderStyle: StyledTextStyle(color: Colors.grey),
  cursorColor: Colors.blue,
  cursorWidth: 2.0,
  cursorRadius: const Radius.circular(2),
  obscureText: false,
)
```

---

## State-Driven Styles & Tokens

### Interactive States (`StyledToken`)

Add state modifiers to any `Style` using `.on(token, ...)`:

```dart
final buttonStyle = Style(
  box: BoxStyle(
    color: Colors.blue,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    border: StyledBorder.all(radius: 8),
    animates: true,
    animationDuration: const Duration(milliseconds: 150),
  ),
  text: const StyledTextStyle(color: Colors.white, fontWeight: FontWeight.w600),
)
// Hover state
.on(
  StyledToken.hovered,
  box: BoxStyle(
    color: Colors.blueAccent,
    transform: Matrix4.translationValues(0, -1.5, 0),
    boxShadow: [
      BoxShadow(color: Colors.blue.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
    ],
  ),
)
// Active press state
.on(
  StyledToken.pressed,
  box: BoxStyle(
    color: Colors.blue[800],
    transform: Matrix4.translationValues(0, 1.0, 0),
  ),
)
// Focus state
.on(
  StyledToken.focused,
  box: BoxStyle(
    border: StyledBorder.all(color: Colors.lightBlueAccent, width: 2, radius: 8),
  ),
)
// Disabled state
.on(
  StyledToken.disabled,
  box: const BoxStyle(color: Color(0xFFCBD5E1)),
  text: const StyledTextStyle(color: Color(0xFF94A3B8)),
);
```

#### Available Built-in Tokens:
- `StyledToken.hovered`: Mouse pointer enters widget boundary (produced by `StyledPressableBox`).
- `StyledToken.pressed`: Pointer is pressed down (produced by `StyledPressableBox`).
- `StyledToken.focused`: Input or widget holds keyboard focus (produced by `StyledPressableBox` and `StyledTextField`).
- `StyledToken.disabled`: Widget interaction disabled (produced by `StyledPressableBox` and `StyledTextField`).
- `StyledToken.error`: Validation error state (produced by `StyledTextField`).

> [!NOTE]
> Domain-specific states (such as `active`, `selected`, `loading`, `success`, `warning`) should be defined in application-level token extensions (e.g. `extension CustomTokens on StyledToken { static const String selected = 'selected'; }`) to maintain clean separation between headless widget gestures and application logic.

---

### Responsive Breakpoints (`StyledScreen`)

Define adaptive styles that trigger based on screen width:

```dart
final layoutStyle = Style(
  flex: const FlexStyle(
    direction: Axis.horizontal,
    spacing: 24,
    crossAxisAlignment: CrossAxisAlignment.start,
  ),
)
// Tablet breakpoint (< 1024px)
.on(
  StyledScreen.tablet.name,
  flex: const FlexStyle(
    direction: Axis.vertical,
    spacing: 16,
  ),
)
// Mobile breakpoint (< 600px)
.on(
  StyledScreen.mobile.name,
  flex: const FlexStyle(
    direction: Axis.vertical,
    spacing: 8,
  ),
);
```

Breakpoints can also be queried programmatically via `BuildContext` extensions or `StyledScreen.fromContext`:
```dart
if (context.isMobile) {
  // Mobile specific logic (< 650px)
}

// Or access the screen tier and size directly:
final screen = context.screen;       // StyledScreen.mobile | tablet | desktop
final screenSize = context.screenSize; // Size(width, height)
```

---

## Theming System

### Defining Design Tokens (`ThemeToken<T>`)

> [!TIP]
> **Automate with Code Generation**: Use `@StyledTokens` from `styled_generator` to automatically declare `ThemeToken` constants, `StyledTheme` extension getters, and a default map from a single spec class. See [Design Tokens & Theme Getters (`@StyledTokens`)](#design-tokens--theme-getters-styledtokens--token).

Create typed token identifiers with default fallback values:

```dart
abstract final class AppTokens {
  // Brand Colors
  static const primary = ThemeToken<Color>('primary', Color(0xFF2563EB));
  static const secondary = ThemeToken<Color>('secondary', Color(0xFF64748B));
  static const background = ThemeToken<Color>('background', Color(0xFFF8FAFC));
  static const surface = ThemeToken<Color>('surface', Color(0xFFFFFFFF));
  static const error = ThemeToken<Color>('error', Color(0xFFEF4444));

  // Geometry
  static const radius = ThemeToken<double>('radius', 8.0);
  static const cardRadius = ThemeToken<double>('cardRadius', 12.0);
  static const padding = ThemeToken<double>('padding', 16.0);

  // Typography
  static const fontFamily = ThemeToken<String>('fontFamily', 'Inter');
  static const monoFontFamily = ThemeToken<String>('monoFontFamily', 'JetBrains Mono');
}
```

---

### Configuring Themes (`StyledTheme`)

Create custom light, dark, and specialized brand themes:

```dart
// Light Theme
const lightTheme = StyledTheme();

// Dark Theme with Overrides
final darkTheme = const StyledTheme().copyWith(
  overrides: {
    AppTokens.background.key: const Color(0xFF0B0F19),
    AppTokens.surface.key: const Color(0xFF111827),
    AppTokens.primary.key: const Color(0xFF3B82F6),
  },
  metadata: const {'mode': 'dark'},
);
```

#### Accessing Tokens in Code:
Use `theme.get(token)` or create concise extension getters:
```dart
extension AppThemeX on StyledTheme {
  Color get primary => get(AppTokens.primary);
  Color get background => get(AppTokens.background);
  Color get surface => get(AppTokens.surface);
  double get radius => get(AppTokens.radius);
}

// In any BuildContext:
final theme = context.theme; // or StyledThemeProvider.of(context).theme
final primaryColor = theme.primary;
```

---

### Providing & Switching Themes (`ThemeController`)

`ThemeController` extends `ChangeNotifier`, enabling seamless theme changes without restarting the app:

```dart
final themeController = ThemeController(lightTheme);

// Toggle Dark Mode
void toggleDarkMode() {
  themeController.theme = themeController.theme.isDark ? lightTheme : darkTheme;
}

// Override specific tokens dynamically
void updateBrandColor(Color newBrandColor) {
  themeController.updateTokens({
    AppTokens.primary.key: newBrandColor,
  });
}
```

---

## Code Generation (`styled_generator`)

While you can write `StyleResolver` presets and `ThemeToken` extensions manually, `package:styled_generator` (backed by `package:styled_annotation`) provides compile-time code generators that eliminate 60–70% of boilerplate code:

- **`@StyledPreset`**: Automatically generates typed `StyleResolver` preset classes, variant enums, default and named constructors, aliases, base style merging, `copyWith`, `operator ==`, and `hashCode`.
- **`@Responsive`**: Declaratively maps viewport breakpoints (`mobile`, `tablet`, `desktop`) to separate methods or automatically injects `StyledScreen` into variant methods.
- **`@StyledTokens`**: Generates typed `ThemeToken<T>` constant containers, `toDefaultMap()` fallback dictionaries, and `StyledTheme` extension getters.
- **IDE Hover Documentation**: Propagates `///` doc comments from your specification classes and methods directly onto generated classes, enum values, and constructors.

---

### Installation & Setup

Add `styled` to your dependencies, and `styled_generator` with `build_runner` to your `dev_dependencies`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  styled: ^1.0.0
  # Note: styled_annotation is re-exported directly from package:styled

dev_dependencies:
  build_runner: ^2.4.0
  styled_generator: ^1.0.0
```

Add the `part` directive to your preset or token file:

```dart
import 'package:flutter/widgets.dart';
import 'package:styled/styled.dart';

part 'buttons.styled.g.dart';
```

Run `build_runner` to generate code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

### Component Presets (`@StyledPreset` & `@Variant`)

Annotate a private or abstract spec class (e.g. `_StyleButtonSpec`) with `@StyledPreset`:

```dart
import 'package:flutter/widgets.dart';
import 'package:styled/styled.dart';

part 'buttons.styled.g.dart';

/// Interactive button component presets with primary, secondary, and danger styles.
@StyledPreset(name: 'StyleButton')
abstract class _StyleButtonSpec {
  /// Base button geometry and micro-motion shared by all variants.
  static Style base(StyledTheme theme, {bool isExpanded = false}) => Style(
    box: BoxStyle(
      padding: EdgeInsets.symmetric(horizontal: theme.paddingLg, vertical: theme.padding),
      border: StyledBorder.all(radius: theme.radius),
      width: isExpanded ? double.infinity : null,
      animates: true,
      animationDuration: const Duration(milliseconds: 150),
    ),
    flex: const FlexStyle(
      direction: Axis.horizontal,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
    ),
  );

  /// Primary call-to-action button for prominent user actions.
  @Variant(isDefault: true)
  static Style primary(StyledTheme theme) => Style(
    box: BoxStyle(color: theme.primary),
    text: const StyledTextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
  ).on(
    StyledToken.hovered,
    box: BoxStyle(
      boxShadow: [
        BoxShadow(color: theme.primary.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4)),
      ],
      transform: Matrix4.translationValues(0, -1.5, 0),
    ),
  );

  /// Secondary muted button for auxiliary actions.
  @Variant()
  static Style secondary(StyledTheme theme) => Style(
    box: BoxStyle(
      color: theme.surface,
      border: StyledBorder.all(color: theme.border, width: theme.strokeWidth),
    ),
    text: StyledTextStyle(color: theme.onSurface),
  );

  /// Destructive action button.
  @Variant(aliases: ['danger'])
  static Style error(StyledTheme theme) => Style(
    box: BoxStyle(color: theme.error),
    text: const StyledTextStyle(color: Color(0xFFFFFFFF)),
  );
}
```

#### What Gets Generated (`buttons.styled.g.dart`):

1. **Variant Enum**:
   ```dart
   /// Variant options for [StyleButton].
   enum ButtonVariant {
     /// Primary call-to-action button for prominent user actions.
     primary,
     /// Secondary muted button for auxiliary actions.
     secondary,
     /// Destructive action button.
     error,
   }
   ```
2. **Preset Class with Constructors & Aliases**:
   ```dart
   class StyleButton extends StyleResolver {
     final ButtonVariant variant;
     final bool isExpanded;

     const StyleButton({this.isExpanded = false}) : variant = ButtonVariant.primary;
     const StyleButton.primary({this.isExpanded = false}) : variant = ButtonVariant.primary;
     const StyleButton.secondary({this.isExpanded = false}) : variant = ButtonVariant.secondary;
     const StyleButton.error({this.isExpanded = false}) : variant = ButtonVariant.error;
     const StyleButton.danger({this.isExpanded = false}) : variant = ButtonVariant.error; // Alias constructor!
     const StyleButton.fromVariant(this.variant, {this.isExpanded = false});
     ...
   ```
3. **Context Resolution with Theme & Base Style Merging**:
   ```dart
     @override
     Style resolve(BuildContext context) {
       final theme = context.theme;
       final baseStyle = _StyleButtonSpec.base(theme, isExpanded: isExpanded);
       final variantStyle = switch (variant) {
         ButtonVariant.primary => _StyleButtonSpec.primary(theme),
         ButtonVariant.secondary => _StyleButtonSpec.secondary(theme),
         ButtonVariant.error => _StyleButtonSpec.error(theme),
       };
       return baseStyle.merge(variantStyle) as Style;
     }
   ```
4. **Value Semantics**: Full `copyWith`, `operator ==`, and `hashCode` implementations.

#### Usage in Widgets:
```dart
// Using default constructor (primary)
StyledPressableBox(
  style: const StyleButton(),
  onTap: () {},
  child: const StyledText('Save'),
)

// Using named variant
StyledPressableBox(
  style: const StyleButton.secondary(),
  onTap: () {},
  child: const StyledText('Cancel'),
)

// Using alias constructor with custom preset property
StyledPressableBox(
  style: const StyleButton.danger(isExpanded: true),
  onTap: () {},
  child: const StyledText('Delete Account'),
)
```

---

### Responsive Presets (`@Responsive`)

`styled_generator` provides two clean ways to define responsive styles that adapt automatically to `StyledScreen` viewports (`mobile` < 650px, `tablet` < 1360px, `desktop` >= 1360px):

#### Pattern A: Method Delegation (`@Responsive`)
Separate responsive variations into static methods and link them declaratively:

```dart
@StyledPreset(name: 'StyleFlex', mergeBase: false)
abstract class _StyleFlexSpec {
  @Variant(isDefault: true)
  static Style row(StyledTheme theme) => Style(
    flex: FlexStyle(direction: Axis.horizontal, spacing: theme.margin),
  );

  /// Responsive flex container: horizontal on desktop, vertical on tablet and mobile.
  @Variant()
  @Responsive(
    tablet: 'colrowVertical',
    mobile: 'colrowVertical',
    attachStates: true,
  )
  static Style colrow(StyledTheme theme) => Style(
    flex: FlexStyle(direction: Axis.horizontal, spacing: theme.padding),
  );

  static Style colrowVertical(StyledTheme theme) => Style(
    flex: FlexStyle(
      direction: Axis.vertical,
      spacing: theme.padding,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
    ),
  );
}
```

* **Convention Auto-Detection**: If you omit `mobile:` or `tablet:` from `@Responsive()`, the generator automatically searches for `${name}Mobile`, `${name}Tablet`, or `${name}Desktop` (or prefixed with `_`).
* **Sub-Method Filtering**: Delegate sub-methods like `colrowVertical` are automatically detected and omitted from top-level `FlexVariant` values and public constructors.
* **`attachStates: true`**: In addition to returning the active screen style at build time, it registers `.on(StyledScreen.tablet.name, ...)` and `.on(StyledScreen.mobile.name, ...)` for token inspection and state inheritance.

#### Pattern B: Direct `StyledScreen` Parameter Injection
If you prefer handling breakpoints inside a single method with an inline `switch` expression, declare `StyledScreen screen` on your spec method:

```dart
@StyledPreset(name: 'StylePage', mergeBase: false)
abstract class _StylePageSpec {
  /// Responsive page layout with dynamic edge padding per viewport breakpoint.
  @Variant(isDefault: true)
  static Style normal(StyledTheme theme, StyledScreen screen) {
    final EdgeInsets pagePadding = switch (screen) {
      StyledScreen.mobile => EdgeInsets.all(theme.margin),
      StyledScreen.tablet => EdgeInsets.all(theme.margin * 2),
      StyledScreen.desktop => EdgeInsets.symmetric(
        horizontal: theme.margin * 4,
        vertical: theme.margin * 3,
      ),
    };

    return Style(
      box: BoxStyle(
        padding: pagePadding,
        color: theme.background,
        constraints: BoxConstraints(maxWidth: theme.largeWidth),
      ),
    );
  }
}
```

The generator recognizes `StyledScreen screen` (and `Size size`) and automatically injects:
```dart
final (screen: screen, size: _) = StyledScreen.fromContext(context);
final variantStyle = switch (variant) {
  PageVariant.normal => _StylePageSpec.normal(theme, screen),
};
```
No `BuildContext` or manual `MediaQuery.sizeOf(context)` boilerplate is needed!

---

### Design Tokens & Theme Getters (`@StyledTokens` & `@Token`)

Define design tokens in a central specification class:

```dart
import 'dart:ui';
import 'package:styled/styled.dart';

part 'tokens.styled.g.dart';

@StyledTokens(className: 'AppTokens', extensionName: 'AppThemeGetters')
abstract class _AppTokensSpec {
  static const primary = Color(0xFF2563EB);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF8FAFC);
  static const onBackground = Color(0xFF0F172A);
  static const padding = 16.0;
  static const radius = 8.0;

  // Custom key override
  @Token(key: 'brand_accent')
  static const accent = Color(0xFF8B5CF6);
}
```

#### What Gets Generated (`tokens.styled.g.dart`):

1. **Typed `ThemeToken<T>` Constants & Helper Map**:
   ```dart
   abstract final class AppTokens {
     static const primary = ThemeToken<Color>('primary', Color(0xFF2563EB));
     static const surface = ThemeToken<Color>('surface', Color(0xFFFFFFFF));
     static const padding = ThemeToken<double>('padding', 16.0);
     static const accent = ThemeToken<Color>('brand_accent', Color(0xFF8B5CF6));

     static const all = <ThemeToken<Object>>[primary, surface, padding, accent, ...];

     /// Returns a default token-to-value map for theme initialization.
     static Map<ThemeToken<Object>, Object> toDefaultMap() => { ... };
   }
   ```
2. **`StyledTheme` Extension Getters**:
   ```dart
   extension AppThemeGetters on StyledTheme {
     Color get primary => get(AppTokens.primary);
     Color get surface => get(AppTokens.surface);
     double get padding => get(AppTokens.padding);
     Color get accent => get(AppTokens.accent);
   }
   ```

#### Initializing Your Theme:
```dart
final theme = StyledTheme(
  overrides: AppTokens.toDefaultMap(),
);

// Access tokens anywhere with zero ceremony:
final primaryColor = context.theme.primary;
final padding = context.theme.padding;
```

---

### IDE Hover Documentation Propagation

`styled_generator` inspects analyzer `documentationComment` metadata and automatically copies your `///` doc comments to:
- Generated variant enum values (`ButtonVariant.primary`)
- Generated default constructors (`StyleButton()`)
- Generated named variant constructors (`StyleButton.secondary()`, `StyleButton.danger()`)
- Generated preset class definitions (`class StyleButton extends StyleResolver`)

Consuming developers receive full hover documentation and IntelliSense tooltips in VS Code and Android Studio without extra maintenance.

---

## Manual Component Presets (`StyleResolver`)

> [!TIP]
> **Prefer Code Generation**: Use `@StyledPreset` from `styled_generator` to automatically generate the `StyleResolver` class, variant enum, named constructors, aliases, responsive breakpoints, `copyWith`, and equality methods from a clean static spec. See [Component Presets (`@StyledPreset`)](#component-presets-styledpreset--variant).

You can also construct `StyleResolver` presets manually without code generation:

```dart
enum ButtonVariant { primary, secondary, danger }

class StyleButton extends StyleResolver {
  final ButtonVariant variant;

  const StyleButton({this.variant = ButtonVariant.primary});
  const StyleButton.primary() : variant = ButtonVariant.primary;
  const StyleButton.secondary() : variant = ButtonVariant.secondary;
  const StyleButton.danger() : variant = ButtonVariant.danger;

  @override
  Style resolve(BuildContext context) {
    final theme = context.theme;

    final base = Style(
      box: BoxStyle(
        padding: EdgeInsets.symmetric(horizontal: theme.padding * 1.5, vertical: theme.padding * 0.75),
        border: StyledBorder.all(radius: theme.radius),
        animates: true,
        animationDuration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      ),
      text: StyledTextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontFamily: theme.fontFamily,
      ),
      flex: const FlexStyle(
        direction: Axis.horizontal,
        spacing: 8,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
      ),
    );

    return switch (variant) {
      ButtonVariant.primary => base
          .add(
            box: BoxStyle(color: theme.primary),
            text: const StyledTextStyle(color: Colors.white),
          )
          .on(
            StyledToken.hovered,
            box: BoxStyle(
              boxShadow: [
                BoxShadow(color: theme.primary.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4)),
              ],
              transform: Matrix4.translationValues(0, -1.5, 0),
            ),
          ),
      ButtonVariant.secondary => base
          .add(
            box: BoxStyle(
              color: theme.surface,
              border: StyledBorder.all(color: Colors.grey[300]!, radius: theme.radius),
            ),
            text: StyledTextStyle(color: Colors.black87),
          ),
      ButtonVariant.danger => base
          .add(
            box: BoxStyle(color: theme.error),
            text: const StyledTextStyle(color: Colors.white),
          ),
    };
  }
}
```

#### Usage with Styled Widgets:
```dart
StyledPressableBox(
  style: const StyleButton.primary(),
  onTap: () => handleSave(),
  child: const StyledRow(
    children: [
      StyledIcon(Icons.save),
      StyledText('Save Changes'),
    ],
  ),
)
```

---

## Widget Catalog

All widgets in `styled` accept either a raw `Style` or a `StyleResolver`:

### Boxes & Containers
- `StyledBox(style: ..., child: ...)`: Standard container with full decoration, sizing, and transforms.
- `StyledAnimatedBox(style: ..., duration: ..., child: ...)`: Explicitly animated box.
- `StyledPressableBox(style: ..., onTap: ..., disabled: ..., focused: ..., child: ...)`: Full gesture detector with automatic `hovered`, `pressed`, `focused`, and `disabled` token resolution.
- `StyledMaxWidth(style: ..., maxWidth: ..., child: ...)`: Centered max-width viewport container.

### Flex, Rows, Columns & Wrap
- `StyledFlex(style: ..., children: ...)`: Configurable flex layout with native `spacing`.
- `StyledRow(style: ..., children: ...)`: Horizontal flex container.
- `StyledColumn(style: ..., children: ...)`: Vertical flex container.
- `StyledWrap(style: ..., children: ...)`: Wrapping layout container with `wrapSpacing` and `wrapRunSpacing`.
- `StyledPressableRow`, `StyledPressableColumn`, `StyledPressableWrap`: Interactive flex layouts.

### Text & Typography
- `StyledText('Hello World', style: ...)`: Text rendering with style resolution.
- `StyledSelectableText('Selectable Text', style: ...)`: Copyable/selectable text.
- `StyledPressableText('Clickable Link', style: ..., onTap: ...)`: Text with hover and tap interactions.

### Icons & Images
- `StyledIcon(Icons.analytics, style: ...)`: Icon rendering with size, weight, and color tokens.
- `StyledPressableIcon(Icons.refresh, style: ..., onTap: ...)`: Interactive icon button.
- `StyledImage(image: ..., style: ...)`: Image provider with fit, 9-slice, and opacity styling.
- `StyledPressableImage(image: ..., style: ..., onTap: ...)`: Interactive image.

### Form Inputs
- `StyledTextField(style: ..., controller: ..., onChanged: ..., enabled: ...)`: Styled text input with automatic focus, hover, disabled, and error state styling.

---

## Complete End-to-End Example

Here is a complete, self-contained dashboard card example demonstrating tokens, resolvers, responsive screen layout, and interactive pressable widgets:

```dart
import 'package:flutter/widgets.dart';
import 'package:styled/styled.dart';

// 1. Tokens
abstract final class Tokens {
  static const primary = ThemeToken<Color>('primary', Color(0xFF2563EB));
  static const surface = ThemeToken<Color>('surface', Color(0xFFFFFFFF));
  static const onSurface = ThemeToken<Color>('onSurface', Color(0xFF0F172A));
  static const onSurfaceMuted = ThemeToken<Color>('onSurfaceMuted', Color(0xFF64748B));
  static const border = ThemeToken<Color>('border', Color(0xFFE2E8F0));
  static const radius = ThemeToken<double>('radius', 12.0);
}

// 2. Card Preset Resolver
class MetricCardStyle extends StyleResolver {
  const MetricCardStyle();

  @override
  Style resolve(BuildContext context) {
    final theme = context.theme;

    return Style(
      box: BoxStyle(
        padding: const EdgeInsets.all(20),
        color: theme.get(Tokens.surface),
        border: StyledBorder.all(
          color: theme.get(Tokens.border),
          radius: theme.get(Tokens.radius),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
        animates: true,
        animationDuration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      ),
      flex: const FlexStyle(
        direction: Axis.vertical,
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.start,
      ),
    )
    .on(
      StyledToken.hovered,
      box: BoxStyle(
        border: StyledBorder.all(
          color: theme.get(Tokens.primary).withValues(alpha: 0.4),
          radius: theme.get(Tokens.radius),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.get(Tokens.primary).withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        transform: Matrix4.translationValues(0, -2, 0),
      ),
    );
  }
}

// 3. UI Implementation
class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String trend;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return StyledPressableBox(
      style: const MetricCardStyle(),
      onTap: () => print('Card tapped: $title'),
      child: StyledColumn(
        children: [
          StyledText(
            title,
            style: const Style(
              text: StyledTextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          StyledText(
            value,
            style: const Style(
              text: StyledTextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          StyledRow(
            style: const Style(
              flex: FlexStyle(spacing: 4, crossAxisAlignment: CrossAxisAlignment.center),
            ),
            children: [
              const StyledIcon(
                Icons.trending_up,
                style: Style(icon: IconStyle(color: Color(0xFF10B981), size: 16)),
              ),
              StyledText(
                trend,
                style: const Style(
                  text: StyledTextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

---

## License

MIT
