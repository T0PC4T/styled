import 'dart:async';

import 'package:flutter/widgets.dart';

import 'navigation.dart';

/// One page on a [PrototypeNavigator]'s stack.
@immutable
final class PrototypePage {
  /// Unique within its navigator, so two visits to one screen keep separate
  /// state: use it to key the page's widgets.
  final int key;
  final String screenId;

  /// The route with params filled in, and the page's query.
  final Uri location;

  /// The route params, read back from [location] against the screen's route.
  final Map<String, String> params;

  /// The fixture the page draws with; null for the screen's default fixture.
  final String? fixture;

  const PrototypePage({
    required this.key,
    required this.screenId,
    required this.location,
    this.params = const {},
    this.fixture,
  });

  /// The page's query: from the destination, then changed by `setQuery`.
  Map<String, String> get query => location.queryParameters;

  PrototypePage _withLocation(Uri location) =>
      PrototypePage(key: key, screenId: screenId, location: location, params: params, fixture: fixture);

  @override
  String toString() => 'PrototypePage($screenId, $location)';
}

/// A [DesignNavigator] over an in-memory page stack, for the studio and other
/// previews: a prototype that can be clicked through without the app's router.
///
/// It behaves like the app's router: `back` pops or shows its fallback,
/// `backTo` pops down to the ancestor when it is on the stack and shows it
/// otherwise, and `setQuery` changes the top page's query only. Listen to it
/// to redraw when the stack changes.
class PrototypeNavigator extends ChangeNotifier implements DesignNavigator {
  /// The route of a screen (`/admin/automations/:id`), to read a destination's
  /// params back from its location; null when the screen has none.
  final String? Function(String screenId) routeOf;

  /// Called with each navigation, as `push /admin/automations/auto_welcome`.
  final void Function(String call)? onNavigate;

  PrototypeNavigator({required this.routeOf, this.onNavigate});

  final List<PrototypePage> _pages = [];
  final Map<int, Completer<Object?>> _completers = {};
  int _nextKey = 0;

  /// The stack, bottom first.
  List<PrototypePage> get pages => List.unmodifiable(_pages);

  /// The page on top, or null when the stack is empty.
  PrototypePage? get top => _pages.lastOrNull;

  /// Starts over with [to] as the only page, drawn with [fixture].
  void start(DesignDestination to, {String? fixture}) {
    _removeWhere((_) => true);
    _pages.add(_page(to, fixture: fixture));
    notifyListeners();
  }

  /// Empties the stack.
  void clear() {
    _removeWhere((_) => true);
    notifyListeners();
  }

  /// Pops the top page when there is one below it, completing its `push`
  /// with [result]. Returns whether it popped.
  bool pop([Object? result]) {
    if (_pages.length < 2) return false;
    final page = _pages.removeLast();
    _completers.remove(page.key)?.complete(result);
    notifyListeners();
    return true;
  }

  @override
  Future<Object?> push(BuildContext context, DesignDestination to) {
    _log('push', to);
    final page = _page(to);
    final completer = Completer<Object?>();
    _completers[page.key] = completer;
    _pages.add(page);
    notifyListeners();
    return completer.future;
  }

  @override
  void replaceAll(BuildContext context, DesignDestination to) {
    _log('replaceAll', to);
    _replaceAll(to);
  }

  @override
  void replace(BuildContext context, DesignDestination to) {
    _log('replace', to);
    if (_pages.isNotEmpty) {
      final old = _pages.removeLast();
      _completers.remove(old.key)?.complete(null);
    }
    _pages.add(_page(to));
    notifyListeners();
  }

  @override
  void back(BuildContext context, DesignDestination fallback) {
    _log('back', fallback);
    if (!pop()) _replaceAll(fallback);
  }

  @override
  void backTo(BuildContext context, DesignDestination ancestor) {
    _log('backTo', ancestor);
    final index = _pages.lastIndexWhere((p) => p.location.path == ancestor.location.path);
    if (index < 0) {
      _replaceAll(ancestor);
      return;
    }
    final above = _pages.sublist(index + 1);
    if (above.isEmpty) return;
    _pages.removeRange(index + 1, _pages.length);
    for (final page in above.reversed) {
      _completers.remove(page.key)?.complete(null);
    }
    notifyListeners();
  }

  @override
  void setQuery(BuildContext context, Map<String, String?> query, {required bool history}) {
    final top = this.top;
    onNavigate?.call('setQuery ${Uri(queryParameters: {for (final e in query.entries) e.key: e.value ?? ''}).query}');
    if (top == null) return;
    final next = {...top.query};
    for (final MapEntry(:key, :value) in query.entries) {
      if (value == null || value.isEmpty) {
        next.remove(key);
      } else {
        next[key] = value;
      }
    }
    _pages[_pages.length - 1] = top._withLocation(
      Uri(path: top.location.path, queryParameters: next.isEmpty ? null : next),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _removeWhere((_) => true);
    super.dispose();
  }

  void _replaceAll(DesignDestination to) {
    _removeWhere((_) => true);
    _pages.add(_page(to));
    notifyListeners();
  }

  void _removeWhere(bool Function(PrototypePage) test) {
    final removed = _pages.where(test).toList();
    _pages.removeWhere(test);
    for (final page in removed.reversed) {
      _completers.remove(page.key)?.complete(null);
    }
  }

  void _log(String what, DesignDestination to) => onNavigate?.call('$what ${to.location}');

  PrototypePage _page(DesignDestination to, {String? fixture}) => PrototypePage(
    key: _nextKey++,
    screenId: to.screenId,
    location: to.location,
    params: routeParams(routeOf(to.screenId), to.location),
    fixture: fixture,
  );

  /// The params of [route] (`/admin/automations/:id`) in [location]
  /// (`/admin/automations/auto_welcome` → `{id: auto_welcome}`). Empty when
  /// the location does not follow the route.
  static Map<String, String> routeParams(String? route, Uri location) {
    if (route == null) return const {};
    final pattern = route.split('/').where((s) => s.isNotEmpty).toList();
    final segments = location.pathSegments.where((s) => s.isNotEmpty).toList();
    if (pattern.length != segments.length) return const {};
    final params = <String, String>{};
    for (var i = 0; i < pattern.length; i++) {
      if (pattern[i].startsWith(':')) {
        params[pattern[i].substring(1)] = segments[i];
      } else if (pattern[i] != segments[i]) {
        return const {};
      }
    }
    return params;
  }
}
