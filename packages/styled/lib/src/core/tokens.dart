import 'package:flutter/widgets.dart';

import '../theme/styled_theme.dart';
import '../theme/theme_provider.dart';

/// A named state that switches on part of a [Style] (see `Style.on`).
///
/// Built-in interaction states are produced by styled widgets. Applications add
/// their own as constants:
///
/// ```dart
/// abstract final class AppState {
///   static const selected = StyleState('selected');
/// }
/// ```
extension type const StyleState(String key) {
  /// Pointer is over the widget. Produced by an interactive `StyledBox`.
  static const hovered = StyleState('hovered');

  /// Pointer is pressed on the widget. Produced by an interactive `StyledBox`.
  static const pressed = StyleState('pressed');

  /// Widget holds keyboard focus. Produced by `StyledBox` and `StyledTextField`.
  static const focused = StyleState('focused');

  /// Interaction is disabled. Produced by `StyledBox` and `StyledTextField`.
  static const disabled = StyleState('disabled');

  /// Validation failed. Produced by `StyledTextField`.
  static const error = StyleState('error');

  /// Built-in interaction states, lowest precedence first.
  ///
  /// When several are active, later entries win on any property they share:
  /// a pressed button shows its pressed style even while hovered, and a
  /// disabled one always shows its disabled style.
  static const interaction = [hovered, focused, pressed, error, disabled];
}

/// Breakpoint keys read from the active [StyledTheme].
abstract final class StyledBreakpoints {
  /// Widths below this are [StyledScreen.mobile].
  static const mobile = ThemeToken<double>('styled.breakpointMobile', 650);

  /// Widths below this (and at least [mobile]) are [StyledScreen.tablet].
  static const tablet = ThemeToken<double>('styled.breakpointTablet', 1360);
}

/// Screen size tiers for responsive styling.
///
/// Each tier is also a [StyleState]: `style.on(StyledScreen.mobile.state, ...)`
/// applies whenever the viewport is in that tier. Breakpoints come from
/// [StyledBreakpoints] on the active theme.
enum StyledScreen {
  mobile,
  tablet,
  desktop;

  /// The [StyleState] that is active while the viewport is in this tier.
  StyleState get state => StyleState(name);

  /// Whether [state] is one of the screen-tier states.
  static bool isScreenState(StyleState state) =>
      state == mobile.state || state == tablet.state || state == desktop.state;

  /// Classifies [width] using the breakpoints in [theme].
  static StyledScreen forWidth(double width, [StyledTheme theme = const StyledTheme()]) {
    if (width < theme.get(StyledBreakpoints.mobile)) return mobile;
    if (width < theme.get(StyledBreakpoints.tablet)) return tablet;
    return desktop;
  }

  /// The tier of the current viewport. Uses the theme's breakpoints when a
  /// theme provider is present, and the defaults otherwise.
  static StyledScreen of(BuildContext context) => forWidth(
        MediaQuery.sizeOf(context).width,
        StyledThemeControllerProvider.of(context, listen: true)?.value ?? const StyledTheme(),
      );

  bool get isMobile => this == mobile;
  bool get isTablet => this == tablet;
  bool get isDesktop => this == desktop;

  bool operator >(StyledScreen other) => index > other.index;
  bool operator <(StyledScreen other) => index < other.index;
  bool operator >=(StyledScreen other) => index >= other.index;
  bool operator <=(StyledScreen other) => index <= other.index;
}

/// Screen tier inspection on [BuildContext].
extension StyledScreenContextExtension on BuildContext {
  /// The current [StyledScreen] tier.
  StyledScreen get screen => StyledScreen.of(this);

  /// The current viewport size.
  Size get screenSize => MediaQuery.sizeOf(this);

  bool get isMobile => screen.isMobile;
  bool get isTablet => screen.isTablet;
  bool get isDesktop => screen.isDesktop;
}
