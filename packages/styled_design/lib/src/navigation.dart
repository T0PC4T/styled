import 'package:flutter/widgets.dart';
import 'package:styled_design_core/styled_design_core.dart';

/// The target screen, and its route with params and query filled in.
@immutable
final class DesignDestination {
  final String screenId;
  final Uri location;
  const DesignDestination(this.screenId, this.location);

  @override
  bool operator ==(Object other) =>
      other is DesignDestination && other.screenId == screenId && other.location == location;

  @override
  int get hashCode => Object.hash(screenId, location);

  @override
  String toString() => 'DesignDestination($screenId, $location)';
}

/// How the engine navigates. The app implements it over its router; the
/// studio over an in-memory page stack. The engine never names a router.
abstract interface class DesignNavigator {
  /// Drill down: mount [to] on top. Completes when it is popped.
  Future<Object?> push(BuildContext context, DesignDestination to);

  /// Change section: leave [to] as the only page.
  void replaceAll(BuildContext context, DesignDestination to);

  /// Same slot, new identity: swap the top page for [to].
  void replace(BuildContext context, DesignDestination to);

  /// Back button: pop, or show [fallback] when there is nothing to pop.
  void back(BuildContext context, DesignDestination fallback);

  /// Breadcrumb: pop down to [ancestor], or show it when it is not on the stack.
  void backTo(BuildContext context, DesignDestination ancestor);

  /// Merge [query] into the current page's query. A null value removes a key.
  void setQuery(BuildContext context, Map<String, String?> query, {required bool history});
}

/// Dialogs and toasts. The engine names no component library, so the library
/// implements these with its own modal, confirm dialog and toast.
abstract interface class DesignOverlays {
  /// Opens [builder]'s screen as a modal. Completes with the value it closes with.
  Future<Object?> openModal(BuildContext context, WidgetBuilder builder);

  /// Asks the user to confirm. Completes with true when confirmed.
  Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String? confirmLabel,
    bool destructive = false,
  });

  /// Shows a short message.
  void toast(BuildContext context, String message, {ToastTone tone = ToastTone.success});
}

/// A navigator that does nothing but record, for tests and previews.
class RecordingDesignNavigator implements DesignNavigator {
  /// Each call as `push /admin/automations/auto_welcome`.
  final calls = <String>[];
  final destinations = <DesignDestination>[];

  void _record(String what, DesignDestination to) {
    calls.add('$what ${to.location}');
    destinations.add(to);
  }

  @override
  Future<Object?> push(BuildContext context, DesignDestination to) async {
    _record('push', to);
    return null;
  }

  @override
  void replaceAll(BuildContext context, DesignDestination to) => _record('replaceAll', to);

  @override
  void replace(BuildContext context, DesignDestination to) => _record('replace', to);

  @override
  void back(BuildContext context, DesignDestination fallback) => _record('back', fallback);

  @override
  void backTo(BuildContext context, DesignDestination ancestor) => _record('backTo', ancestor);

  @override
  void setQuery(BuildContext context, Map<String, String?> query, {required bool history}) =>
      calls.add('setQuery ${Uri(queryParameters: {for (final e in query.entries) e.key: e.value ?? ''}).query}');
}
