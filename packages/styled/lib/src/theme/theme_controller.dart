import 'package:flutter/foundation.dart';
import 'package:styled/styled.dart';

/// Minimalist, lightweight theme controller backed by [ValueNotifier].
///
/// Can be used directly (e.g. in tests and widget previews) or subclassed by
/// application-specific theme services (e.g. `AppThemeService`) to combine theme
/// state with persistence, remote synchronization, and account preferences.
class StyledThemeController extends ValueNotifier<StyledTheme> {
  StyledThemeController([super.initialTheme = const StyledTheme()]);

  void updateTheme(StyledTheme theme) {
    value = theme;
  }
}
