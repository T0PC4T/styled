import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:styled/styled.dart';
import 'package:styled_design_core/styled_design_core.dart';

import 'build_context.dart';
import 'engine_definitions.dart';
import 'navigation.dart';
import 'scope.dart';

/// An event a screen hands to the app.
@immutable
final class DesignEmit {
  final String name;
  final Map<String, Object?> payload;
  final String screenId;
  final String? nodeId;

  const DesignEmit(this.name, this.payload, {required this.screenId, this.nodeId});

  /// The payload field [key] as text.
  String string(String key) => switch (payload[key]) {
    final String s => s,
    null => throw StateError("Emit '$name' has no '$key'."),
    final other => '$other',
  };

  /// The payload field [key] as a whole number.
  int integer(String key) => switch (payload[key]) {
    final int i => i,
    final num n => n.toInt(),
    final String s => int.parse(s),
    _ => throw StateError("Emit '$name' has no number '$key'."),
  };

  double number(String key) => switch (payload[key]) {
    final num n => n.toDouble(),
    _ => throw StateError("Emit '$name' has no number '$key'."),
  };

  bool boolean(String key) => payload[key] == true;

  Object? operator [](String key) => payload[key];

  @override
  String toString() => 'DesignEmit($name, $payload, from $screenId#${nodeId ?? '-'})';
}

/// Handles a screen's emits. Return false to stop the action list (a save the
/// controller rejected); anything else becomes `event.result`.
typedef DesignEmitHandler = FutureOr<Object?> Function(DesignEmit event);

/// Draws one screen of the bundle in [DesignScope] with [data] from the app,
/// and hands its events back through [onEmit].
class DesignScreen extends StatefulWidget {
  final String screenId;

  /// What the app supplies; must cover the default fixture's keys.
  final Map<String, Object?> data;

  /// Data for each modal this screen can open, by modal screen id.
  final Map<String, Map<String, Object?>> modalData;

  final DesignEmitHandler? onEmit;

  /// Route params, or a modal's open arguments.
  final Map<String, String> params;
  final Map<String, String> query;

  const DesignScreen(
    this.screenId, {
    super.key,
    this.data = const {},
    this.modalData = const {},
    this.onEmit,
    this.params = const {},
    this.query = const {},
  });

  @override
  State<DesignScreen> createState() => _DesignScreenState();
}

final class _Stop {
  const _Stop();
}

final class _Result {
  final Object? value;
  const _Result(this.value);
}

class _DesignScreenState extends State<DesignScreen> implements DesignNodeHost {
  late DesignScope _scope;
  ScreenDoc? _screen;
  Map<String, Object?> _state = const {};
  bool _stateReady = false;
  bool _contractChecked = false;
  final _modalData = ValueNotifier<Map<String, Map<String, Object?>>>(const {});

  @override
  String get screenId => widget.screenId;

  @override
  void initState() {
    super.initState();
    _modalData.value = widget.modalData;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = DesignScope.of(context);
    final screen = _scope.bundle.screens[widget.screenId];
    if (screen != _screen) {
      _screen = screen;
      _stateReady = false;
    }
  }

  @override
  void didUpdateWidget(DesignScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screenId != widget.screenId) {
      _screen = _scope.bundle.screens[widget.screenId];
      _stateReady = false;
    }
    if (!mapEquals(oldWidget.modalData, widget.modalData)) _modalData.value = widget.modalData;
  }

  @override
  void dispose() {
    _modalData.dispose();
    super.dispose();
  }

  MapScope get _roots {
    final outlet = _screen?.kind == ScreenKind.frame ? DesignOutletScope.of(context) : null;
    return MapScope({
      'data': widget.data,
      'state': _state,
      'params': widget.params,
      'query': widget.query,
      if (outlet != null) 'page': {'id': outlet.pageId, 'title': outlet.pageTitle},
    }, formatters: _scope.registry.formatters);
  }

  void _initState(ScreenDoc screen) {
    final initial = MapScope({
      'data': widget.data,
      'params': widget.params,
      'query': widget.query,
    }, formatters: _scope.registry.formatters);
    _state = {for (final MapEntry(:key, :value) in screen.state.entries) key: value.eval(initial)};
    _stateReady = true;
  }

  void _checkContract(ScreenDoc screen) {
    _contractChecked = true;
    if (!kDebugMode) return;
    final missing = screen.defaultFixture.keys.where((k) => !widget.data.containsKey(k)).toList();
    if (missing.isNotEmpty) {
      _scope.report(
        DesignRuntimeError(
          screen.id,
          null,
          'The app supplies no ${missing.map((k) => "'$k'").join(', ')}, which the default fixture has.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = _screen;
    if (screen == null) {
      _scope.report(DesignRuntimeError(widget.screenId, null, "The bundle has no screen '${widget.screenId}'."));
      return _scope.studio || kDebugMode
          ? DesignErrorBox(nodeId: widget.screenId, message: 'No such screen.')
          : const SizedBox.shrink();
    }
    if (!_stateReady) _initState(screen);
    if (!_contractChecked) _checkContract(screen);
    return buildFirstWidget([screen.root], _roots) ?? const SizedBox.shrink();
  }

  // ---------------------------------------------------------------------------
  // DesignNodeHost

  @override
  void report(NodeDoc node, String message, {Object? cause, StackTrace? stackTrace}) => _scope.report(
    DesignRuntimeError(widget.screenId, node.id, message, cause: cause, stackTrace: stackTrace),
  );

  /// Each instance of [node] in [scope]: `repeat` expanded, `when` applied.
  Iterable<(MapScope, Object?)> _instances(NodeDoc node, MapScope scope) sync* {
    final repeat = node.repeat;
    if (repeat == null) {
      if (_passes(node, scope)) yield (scope, null);
      return;
    }
    final over = repeat.over.eval(scope);
    if (over == null) return;
    if (over is! List<Object?>) {
      report(node, 'repeat.over must be a list, not ${over.runtimeType}.');
      return;
    }
    for (var i = 0; i < over.length; i++) {
      final s = scope.extend({repeat.as: over[i], ?repeat.index: i});
      if (!_passes(node, s)) continue;
      yield (s, repeat.key?.eval(s) ?? i);
    }
  }

  bool _passes(NodeDoc node, MapScope scope) {
    final when = node.when;
    if (when == null) return true;
    try {
      return isTruthy(when.eval(scope));
    } catch (e, s) {
      report(node, "'when' could not be evaluated.", cause: e, stackTrace: s);
      return false;
    }
  }

  @override
  List<Widget> buildWidgets(List<NodeDoc> nodes, MapScope scope, {bool keyed = true}) => [
    for (final node in nodes)
      for (final (s, repeatKey) in _instances(node, scope))
        ?_build(node, s, repeatKey, asValue: false, keyed: keyed || repeatKey != null) as Widget?,
  ];

  @override
  Widget? buildFirstWidget(List<NodeDoc> nodes, MapScope scope, {bool keyed = true}) {
    for (final node in nodes) {
      for (final (s, repeatKey) in _instances(node, scope)) {
        return _build(node, s, repeatKey, asValue: false, keyed: keyed) as Widget?;
      }
    }
    return null;
  }

  @override
  List<Object> buildValues(List<NodeDoc> nodes, MapScope scope) => [
    for (final node in nodes)
      for (final (s, repeatKey) in _instances(node, scope)) ?_build(node, s, repeatKey, asValue: true),
  ];

  Object? _build(NodeDoc node, MapScope scope, Object? repeatKey, {required bool asValue, bool keyed = true}) {
    final definition = _scope.registry[node.componentType];
    if (definition == null) {
      report(node, "Unknown component '${node.componentType}'.");
      if (asValue) return null;
      return _scope.studio ? DesignPlaceholder(node.type) : null;
    }
    final spec = definition.spec;
    final isValue = spec.kind == DesignKind.value;
    if (isValue != asValue) {
      report(node, isValue ? '${spec.type} is a value: put it in a slot that takes it.' : '${spec.type} is a widget, but this slot takes values.');
      return null;
    }
    if (node.constructor case final ctor? when !spec.constructors.contains(ctor)) {
      report(node, '${spec.type} has no constructor .$ctor.');
    }
    final ctx = DesignBuildContext(
      host: this,
      node: node,
      spec: spec,
      scope: scope,
      key: asValue || !keyed ? null : ValueKey<String>(repeatKey == null ? node.id : '${node.id}#$repeatKey'),
    );
    try {
      final built = definition.build(ctx);
      if (!asValue && built is! Widget) {
        report(node, '${spec.type} built a ${built.runtimeType}, not a widget.');
        return null;
      }
      return built;
    } catch (e, s) {
      report(node, '${spec.type} failed to build.', cause: e, stackTrace: s);
      if (asValue) return null;
      return _scope.studio || kDebugMode ? DesignErrorBox(nodeId: node.id, message: '$e') : null;
    }
  }

  @override
  IconData? icon(String name) => _scope.registry.icons[name];

  @override
  StyleValue<T>? token<T>(String key) {
    try {
      return _scope.tokens.typed<T>(key);
    } on DesignError catch (e) {
      _scope.report(DesignRuntimeError(widget.screenId, null, e.message));
      return null;
    }
  }

  @override
  StyleResolver? preset(String id, Map<String, Object?> args) {
    try {
      return _scope.presets.resolve(id, args: args);
    } on Object catch (e) {
      _scope.report(DesignRuntimeError(widget.screenId, null, 'Preset $id: $e', cause: e));
      return null;
    }
  }

  @override
  ImageProvider? image(String reference) => _scope.images?.call(reference);

  @override
  Future<void> Function(Map<String, Object?> payload)? handler(NodeDoc node, String event, MapScope scope) {
    final actions = node.on[event];
    if (actions != null) return (payload) => _run(actions, scope, payload, node);
    final spec = _scope.registry[node.componentType]?.spec;
    if (_scope.studio && spec?.event(event)?.primary == true) {
      return (payload) async => _scope.report(
        DesignRuntimeError(widget.screenId, node.id, "Unbound primary event '$event' pressed with $payload."),
      );
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Actions

  Future<void> _run(List<ActionDoc> actions, MapScope scope, Map<String, Object?> payload, NodeDoc node) async {
    var event = <String, Object?>{...payload};
    for (final action in actions) {
      if (!mounted) return;
      final s = scope.extend({'event': event, 'state': _state});
      try {
        final outcome = await _runOne(action, s, node);
        if (outcome is _Stop) return;
        if (outcome is _Result) event = {...event, 'result': outcome.value};
      } catch (e, st) {
        report(node, "Action '${action.kind}' failed.", cause: e, stackTrace: st);
        return;
      }
    }
  }

  Map<String, String> _strings(Map<String, Expr> values, MapScope scope) => {
    for (final MapEntry(:key, :value) in values.entries)
      if (value.eval(scope) case final v?) key: v is String ? v : '$v',
  };

  DesignDestination _destination(String screenId, Map<String, Expr> params, MapScope scope, [Map<String, Expr> query = const {}]) {
    final target = _scope.bundle.screen(screenId);
    final q = {
      for (final MapEntry(:key, :value) in query.entries) key: switch (value.eval(scope)) {
        null => null,
        final String s => s,
        final v => '$v',
      },
    };
    return DesignDestination(screenId, target.locationFor(params: _strings(params, scope), query: q));
  }

  Future<Object?> _runOne(ActionDoc action, MapScope scope, NodeDoc node) async {
    final navigator = _scope.navigator;
    switch (action) {
      case NavigateAction(:final to, :final mode, :final params, :final query):
        final destination = _destination(to, params, scope, query);
        switch (mode) {
          case NavigateMode.push:
            unawaited(navigator.push(context, destination));
          case NavigateMode.replaceAll:
            navigator.replaceAll(context, destination);
          case NavigateMode.replace:
            navigator.replace(context, destination);
        }
      case BackAction(:final fallback, :final params):
        navigator.back(context, _destination(fallback, params, scope));
      case BackToAction(:final to, :final params):
        navigator.backTo(context, _destination(to, params, scope));
      case SetQueryAction(:final set, :final history):
        navigator.setQuery(context, {
          for (final MapEntry(:key, :value) in set.entries) key: switch (value.eval(scope)) {
            null => null,
            final v => '$v',
          },
        }, history: history);
      case OpenModalAction(screen: final modalId, :final params, :final then):
        final overlays = _requireOverlays();
        final args = _strings(params, scope);
        final result = await overlays.openModal(
          context,
          (_) => ValueListenableBuilder<Map<String, Map<String, Object?>>>(
            valueListenable: _modalData,
            builder: (context, modalData, _) => DesignScreen(
              modalId,
              data: modalData[modalId] ?? const {},
              params: args,
              onEmit: widget.onEmit,
            ),
          ),
        );
        if (then.isNotEmpty && isTruthy(result) && mounted) {
          await _run(then, scope, {...?(scope.root('event') as Map<String, Object?>?), 'result': result}, node);
        }
        return _Result(result);
      case CloseModalAction(:final result):
        Navigator.of(context).pop(result?.eval(scope));
        return const _Stop();
      case ConfirmAction(:final title, :final message, :final confirmLabel, :final destructive, :final then):
        final ok = await _requireOverlays().confirm(
          context,
          title: '${title.eval(scope) ?? ''}',
          message: message?.eval(scope)?.toString(),
          confirmLabel: confirmLabel?.eval(scope)?.toString(),
          destructive: destructive,
        );
        if (ok && mounted) await _run(then, scope, {...?(scope.root('event') as Map<String, Object?>?)}, node);
        return _Result(ok);
      case ToastAction(:final message, :final tone):
        _requireOverlays().toast(context, '${message.eval(scope) ?? ''}', tone: tone);
      case SetStateAction(:final set):
        final next = {..._state, for (final MapEntry(:key, :value) in set.entries) key: value.eval(scope)};
        setState(() => _state = next);
      case EmitAction(:final name, :final payload):
        final values = {for (final MapEntry(:key, :value) in payload.entries) key: value.eval(scope)};
        final emit = DesignEmit(name, values, screenId: widget.screenId, nodeId: node.id);
        final handler = widget.onEmit;
        if (handler == null) {
          final spec = _screen?.emits[name];
          report(node, 'No onEmit handler for $emit.');
          return _Result(spec != null && spec.hasSample ? spec.sample : true);
        }
        final result = await handler(emit);
        if (result == false) return const _Stop();
        return _Result(result);
    }
    return null;
  }

  DesignOverlays _requireOverlays() =>
      _scope.overlays ?? (throw StateError('This screen opens a dialog or toast, but DesignScope has no overlays.'));
}
