import 'package:flutter/widgets.dart';

import 'styled_theme.dart';
import 'theme_controller.dart';

/// Reactive theme provider using Flutter's built-in [InheritedNotifier].
/// Automatically triggers rebuilds when the [StyledThemeController] notifies listeners.
class StyledThemeControllerProvider
    extends InheritedNotifier<StyledThemeController> {
  const StyledThemeControllerProvider({
    super.key,
    required StyledThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Dedicated test wrapper for unit and widget tests.
  /// Isolates each test case with an explicit theme without requiring global state.
  StyledThemeControllerProvider.test({
    super.key,
    StyledTheme theme = const StyledTheme(),
    required super.child,
  }) : super(notifier: StyledThemeController(theme));

  /// Retrieves the active [StyledThemeController] (or specific subclass [C]) from the
  /// nearest [StyledThemeControllerProvider] ancestor.
  ///
  /// Matches the workspace provider convention (e.g. `AuthControllerProvider.of`,
  /// `EnvironmentProvider.of`).
  static C? of<C extends StyledThemeController>(
    BuildContext context, {
    bool listen = false,
  }) {
    final notifier = listen
        ? context
              .dependOnInheritedWidgetOfExactType<
                StyledThemeControllerProvider
              >()
              ?.notifier
        : context
              .getInheritedWidgetOfExactType<StyledThemeControllerProvider>()
              ?.notifier;
    return notifier is C ? notifier : null;
  }
}

/// Extension on [BuildContext] to easily access the active [StyledTheme].
extension StyledThemeContextExtension on BuildContext {
  /// Retrieves the active [StyledTheme] tokens, or throws a [FlutterError] if none is provided.
  StyledTheme get theme {
    final controller = StyledThemeControllerProvider.of(this, listen: true);
    if (controller == null) {
      throw FlutterError(
        'context.theme called with a context that does not contain a StyledThemeProvider.\n'
        'No ancestor StyledThemeProvider was found starting from context: $this.\n'
        'Ensure that a StyledThemeProvider is mounted above widgets that depend on theme tokens.',
      );
    }
    return controller.value;
  }
}
