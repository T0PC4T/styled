import 'package:flutter/widgets.dart';

/// Scroll behavior that removes scrollbars.
class NoScrollbarBehavior extends ScrollBehavior {
  const NoScrollbarBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}
