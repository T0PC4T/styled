---
name: flutter-styled
description: Guidelines and instructions for using the custom styled library for building UI components.
---

# Styled Widgets & Composition Guidelines

This skill provides mandatory architectural patterns and guidelines for building UI components using the headless `styled` package (`package:styled`) and design system presets (`package:analytics_ui`).

---

## Core Directives & Architecture

### 1. Strict Single Source of Truth (SSoT)
All visual appearance, layout structure, typography, spacing, motion, and interactive state changes **MUST** live exclusively in `Style` models or `StyleResolver` presets.
- **NEVER** pass layout or styling parameters (e.g., `mainAxisAlignment`, `crossAxisAlignment`, `spacing`, `padding`, `fontSize`, `color`) into widget constructors.
- Widget constructors accept ONLY structural children and interactive callbacks (e.g. `onTap`, `controller`, `child`, `children`, `disabled`, `focused`).

### 2. Preset Styles First
When building UI components, **ALWAYS** default to using predefined component presets from `package:analytics_ui`:
- Buttons: `const StyleButton.primary()`, `const StyleButton.ghost()`, `const StyleButton.secondary()`, `const StyleButton.success()`, `const StyleButton.danger()`, `const StyleButton.warning()`, `const StyleTextButton()`, `const StyleSidebarButton()`
- Icon Buttons: `const StyleIconButton()`, `const StyleIconButton.theme()`, `const StyleIconButton.success()`, `const StyleIconButton.danger()`, `const StyleIconButton.naked()`
- Cards: `const StyleCard()`, `const StyleCard.selected()`, `const StyleCard.interactive()`, `const StyleCard.error()`, `const StyleCard.success()`, `const StyleCard.warning()`
- Tags & Chips: `const StyleTag()`, `const StyleTag.theme()`, `const StyleTag.success()`, `const StyleTag.warning()`, `const StyleTag.error()`, `const StyleTagPill()`, `const StyleChip()`, `const StyleChip.inclusive()`
- Inputs & Forms: `const StyleInput()`, `const StyleInput.error()`, `const StyleTextSwitch()`, `const StyleRadioOptionButton()`
- Layout: `AnalyticsColumn`, `AnalyticsRow`, `AnalyticsWrap`, `AnalyticsGrid`, `const StylePage()`, `const StyleAppbar()`, `const StyleSidebar()`
- Typography: `const StyleText.body()`, `const StyleText.h1()`, `const StyleText.h2()`, `const StyleText.bold()`, `const StyleMetric()`, `const StyleMetricSm()`

### 3. Creating Reusable Component Presets (`StyleResolver`)
If a reusable UI element requires custom styling, create a `StyleResolver` class in `packages/analytics_ui/lib/src/presets/` rather than inlining complex styles in the view layer:
```dart
class StyleCustomBadge extends StyleResolver {
  final bool isFeatured;
  const StyleCustomBadge({this.isFeatured = false});

  @override
  Style resolve(BuildContext context) {
    final theme = context.theme;
    return Style(
      box: BoxStyle(
        padding: EdgeInsets.symmetric(horizontal: theme.paddingSm, vertical: theme.paddingXs),
        color: isFeatured ? theme.primarySubtle : theme.surfaceSubtle,
        border: StyledBorder.all(
          color: isFeatured ? theme.primary : theme.border,
          radius: theme.radiusSm,
        ),
        animates: true,
        animationDuration: const Duration(milliseconds: 150),
      ),
      text: StyledTextStyle(
        color: isFeatured ? theme.primary : theme.onSurfaceSubtle,
        fontWeight: FontWeight.w600,
        fontSize: theme.fontSizeSm,
        fontFamily: theme.generalFontFamily,
      ),
      flex: FlexStyle(direction: Axis.horizontal, spacing: theme.paddingXs, mainAxisSize: MainAxisSize.min),
    );
  }
}
```

### 4. No Magic Numbers or Hardcoded Colors
You **MUST NOT** hardcode raw hex colors or numerical values (e.g., `Color(0xFF2563EB)`, `16.0`, `EdgeInsets.all(12)`) in UI widgets.
- Always retrieve tokens dynamically from `context.theme` (or `StyledThemeProvider.of(context).theme` / `theme.get(Token)`).
- Ensure background colors match their designated high-contrast foreground colors (e.g., `surface` with `onSurface`, `primary` with `onPrimary`, `error` with `onError`).

### 5. Use Native Flex Spacing (No `SizedBox` for gaps)
Use `FlexStyle(spacing: ...)` on `StyledRow`, `StyledColumn`, `StyledFlex`, and `StyledWrap` instead of inserting empty `SizedBox(width: ...)` or `SizedBox(height: ...)` spacer widgets.

### 6. Interactive Pressable Primitives
Use the dedicated pressable widget variants for interactive elements:
- `StyledPressableBox`
- `StyledPressableRow`, `StyledPressableColumn`, `StyledPressableWrap`
- `StyledPressableText`, `StyledPressableIcon`, `StyledPressableImage`

These widgets automatically manage hover, press, focus, and disabled states and apply matching `.on(StyledToken.*, ...)` modifiers.

---

## Standard Components Reference

| Widget | Purpose | SSoT Style Configuration |
| :--- | :--- | :--- |
| `StyledBox` | Container / Surface replacement | `BoxStyle` (color, border, shadows, dimensions, padding, transform, animation) |
| `StyledPressableBox` | Interactive container with gestures | `BoxStyle` + state overrides (`StyledToken.hovered`, `pressed`, `disabled`) |
| `StyledFlex` | Universal directional flex | `FlexStyle` (`direction`, `mainAxisAlignment`, `crossAxisAlignment`, `spacing`) |
| `StyledRow` | Horizontal flex row | `FlexStyle(direction: Axis.horizontal, spacing: ...)` |
| `StyledColumn` | Vertical flex column | `FlexStyle(direction: Axis.vertical, spacing: ...)` |
| `StyledWrap` | Multi-line wrapping layout | `FlexStyle(wrapSpacing: ..., wrapRunSpacing: ...)` |
| `StyledPressableRow` / `Column` / `Wrap` | Interactive flex layouts with state | `FlexStyle` + `BoxStyle` state overrides |
| `StyledText` | Themed text rendering | `StyledTextStyle` (color, fontSize, weight, fontFeatures) |
| `StyledSelectableText` | Selectable / copyable text | `StyledTextStyle` |
| `StyledPressableText` | Clickable / link text | `StyledTextStyle` + hover/press states |
| `StyledIcon` | Themed icon element | `IconStyle` (color, size, opticalSize, weight) |
| `StyledPressableIcon` | Clickable icon button | `IconStyle` + `BoxStyle` hover/press states |
| `StyledImage` | Themed image / asset | `ImageStyle` (fit, opacity, 9-slice, filterQuality) |
| `StyledTextField` | Themed text field input | `InputStyle` + `BoxStyle` (focus/error ring states) |
| `StyledMaxWidth` | Centered layout container | `BoxStyle(constraints: BoxConstraints(maxWidth: ...))` |

---

## State-Driven Styling (`StyledToken`)

Apply state transitions on any `Style` using `.on(StyledToken.*, ...)`:

```dart
final interactiveStyle = Style(
  box: BoxStyle(
    color: theme.primary,
    border: StyledBorder.all(radius: theme.radius),
    animates: true,
    animationDuration: const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
  ),
  text: StyledTextStyle(color: theme.onPrimary, fontWeight: FontWeight.w600),
  icon: IconStyle(color: theme.onPrimary),
)
.on(
  StyledToken.hovered,
  box: BoxStyle(
    boxShadow: electricGlow(theme.primary, opacity: 0.35, blurRadius: 16),
    transform: Matrix4.translationValues(0, -1.5, 0),
  ),
)
.on(
  StyledToken.pressed,
  box: BoxStyle(
    transform: Matrix4.translationValues(0, 1.0, 0),
  ),
)
.on(
  StyledToken.disabled,
  box: BoxStyle(color: theme.surfaceSubtle),
  text: StyledTextStyle(color: theme.onSurfaceMuted),
  icon: IconStyle(color: theme.onSurfaceMuted),
);
```

### Available Built-in Tokens:
- `StyledToken.hovered`: Mouse pointer hover (produced by `StyledPressableBox`)
- `StyledToken.pressed`: Pointer touch down / press (produced by `StyledPressableBox`)
- `StyledToken.focused`: Keyboard focus (produced by `StyledPressableBox` and `StyledTextField`)
- `StyledToken.disabled`: Inactive / disabled interaction (produced by `StyledPressableBox` and `StyledTextField`)
- `StyledToken.error`: Form validation error (produced by `StyledTextField`)

### Application-Level Domain Tokens (`package:analytics_ui`):
- `AnalyticsStyledTokenExtension.active`: Navigation/route active state
- `AnalyticsStyledTokenExtension.selected`: Tab, row, radio, or card selection
- `AnalyticsStyledTokenExtension.loading`: Async operation in progress

Use `AnalyticsPressableBox`, `AnalyticsButton`, `AnalyticsIconButton`, and `AnalyticsCard` when you need widgets that accept `selected` and `loading` directly, or use `.onSelected(...)` and `.onLoading(...)` style modifiers.

---

## Responsive Breakpoints (`StyledScreen`)

Adapt layout styles seamlessly to different screen viewports:

```dart
final responsiveStyle = Style(
  flex: FlexStyle(
    direction: Axis.horizontal,
    spacing: theme.padding,
    crossAxisAlignment: CrossAxisAlignment.center,
  ),
)
.on(
  StyledScreen.tablet.name,
  flex: FlexStyle(
    direction: Axis.vertical,
    spacing: theme.margin,
    crossAxisAlignment: CrossAxisAlignment.stretch,
  ),
)
.on(
  StyledScreen.mobile.name,
  flex: FlexStyle(
    direction: Axis.vertical,
    spacing: theme.marginSm,
    crossAxisAlignment: CrossAxisAlignment.stretch,
  ),
);
```

Query breakpoints programmatically in `build`:
```dart
final (screen: StyledScreen screen, size: Size size) = StyledScreen.fromContext(context);
if (screen == StyledScreen.mobile) {
  // Mobile-specific widget structure
}
```

---

## Practical Code Patterns

### 1. Interactive Button with Icon & Text
```dart
StyledPressableBox(
  style: const StyleButton.primary(),
  onTap: () => _handleAction(context),
  child: const StyledRow(
    children: [
      StyledIcon(Icons.add),
      StyledText('Create Project'),
    ],
  ),
)
```

### 2. Interactive KPI Metric Card
```dart
StyledPressableBox(
  style: const StyleCard.variable(),
  onTap: () => _openMetricDetails(context),
  child: StyledColumn(
    children: [
      StyledText('TOTAL REVENUE', style: const StyleText.subscript()),
      StyledText('\$1,248,500.00', style: const StyleMetric()),
      StyledRow(
        children: [
          const StyledIcon(Icons.arrow_upward, style: StyleIconToken.success()),
          StyledText('+14.2% vs last month', style: const StyleText.bold(customColor: Color(0xFF10B981))),
        ],
      ),
    ],
  ),
)
```

### 3. Responsive Screen Header / App Bar
```dart
StyledBox(
  style: const StyleAppbar(),
  child: StyledRow(
    children: [
      StyledText('Dashboard', style: const StyleText.h2()),
      StyledRow(
        children: [
          StyledPressableIcon(
            Icons.notifications_none,
            style: const StyleIconButton.naked(),
            onTap: () => _openNotifications(context),
          ),
          StyledPressableBox(
            style: const StyleAppbarAvatar(),
            onTap: () => _openProfile(context),
            child: const StyledIcon(Icons.person),
          ),
        ],
      ),
    ],
  ),
)
```

### 4. Modal Dialog
```dart
Navigator.of(context).push(
  PageRouteBuilder(
    opaque: false,
    barrierDismissible: true,
    pageBuilder: (context, _, __) {
      return Center(
        child: StyledSingleChildScrollView(
          style: const StyleModal(),
          child: StyledColumn(
            children: [
              StyledRow(
                children: [
                  Expanded(child: StyledText('Confirm Action', style: const StyleText.h2())),
                  StyledPressableIcon(
                    Icons.close,
                    style: const StyleIconButton.naked(),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              StyledText('Are you sure you want to delete this resource?', style: const StyleText.body()),
              StyledRow(
                children: [
                  StyledPressableBox(
                    style: const StyleButton.ghost(),
                    onTap: () => Navigator.of(context).pop(),
                    child: const StyledText('Cancel'),
                  ),
                  StyledPressableBox(
                    style: const StyleButton.danger(),
                    onTap: () => _deleteResource(context),
                    child: const StyledText('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  ),
);
```