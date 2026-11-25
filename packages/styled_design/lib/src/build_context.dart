import 'package:flutter/widgets.dart';
import 'package:styled/styled.dart';
import 'package:styled_design_core/styled_design_core.dart';

import 'studio_keys.dart';

/// What a [DesignBuildContext] needs from the screen that is building.
abstract interface class DesignNodeHost {
  /// The Flutter context of the screen being built.
  BuildContext get context;

  String get screenId;

  /// Reports a problem with a node and carries on.
  void report(NodeDoc node, String message, {Object? cause, StackTrace? stackTrace});

  /// The widgets for [nodes]: `when` applied, `repeat` expanded. With
  /// [keyed] false the nodes get no key of their own, for a template built
  /// once per item whose instances may end up side by side; in the studio
  /// they get a [DesignNodeKey] with [instance] instead.
  List<Widget> buildWidgets(List<NodeDoc> nodes, MapScope scope, {bool keyed = true, int? instance});

  /// The first widget among [nodes] whose `when` passes, or null.
  Widget? buildFirstWidget(List<NodeDoc> nodes, MapScope scope, {bool keyed = true, int? instance});

  /// The value objects for value [nodes].
  List<Object> buildValues(List<NodeDoc> nodes, MapScope scope);

  /// A callback that runs [node]'s actions for [event] with [payload] as
  /// `event`, or null when the event is unbound.
  Future<void> Function(Map<String, Object?> payload)? handler(NodeDoc node, String event, MapScope scope);

  IconData? icon(String name);
  StyleValue<T>? token<T>(String key);
  StyleResolver? preset(String id, Map<String, Object?> args);
  ImageProvider? image(String reference);
}

/// Everything a definition reads to build its widget: evaluated props, built
/// slots and bound events. The only API a definition needs.
final class DesignBuildContext {
  final DesignNodeHost host;
  final NodeDoc node;
  final DesignComponent spec;
  final MapScope scope;

  /// Pass this to the widget's `key`, so its state survives edits and
  /// reorders. Null for value components.
  final Key? key;

  DesignBuildContext({required this.host, required this.node, required this.spec, required this.scope, this.key});

  /// The Flutter context of the screen being built.
  BuildContext get context => host.context;

  /// The named constructor the node picked (`primary`), or null.
  String? get constructor => node.constructor;

  final Map<String, Object?> _evaluated = {};

  /// The evaluated prop [name], or the spec default when the node does not set it.
  Object? value(String name) => _evaluated.putIfAbsent(name, () {
    final expr = node.props[name];
    if (expr == null) return spec.prop(name)?.defaultValue;
    try {
      return expr.eval(scope);
    } catch (e, s) {
      host.report(node, "Prop '$name' could not be evaluated.", cause: e, stackTrace: s);
      return null;
    }
  });

  /// Whether the node sets [name].
  bool has(String name) => node.props.containsKey(name);

  T? _typed<T>(String name, String kind, T? Function(Object value) convert) {
    final v = value(name);
    if (v == null) return null;
    final converted = convert(v);
    if (converted == null) host.report(node, "Prop '$name' must be $kind, not ${v.runtimeType} ($v).");
    return converted;
  }

  String? string(String name) => _typed(name, 'text', (v) => v is String ? v : null);

  bool? boolean(String name) => _typed(name, 'true or false', (v) => v is bool ? v : null);

  int? integer(String name) => _typed(name, 'a whole number', (v) => switch (v) {
    final int i => i,
    final double d when d == d.roundToDouble() => d.toInt(),
    _ => null,
  });

  double? number(String name) => _typed(name, 'a number', (v) => v is num ? v.toDouble() : null);

  /// An enum value by name.
  E? choice<E extends Enum>(String name, List<E> values) => _typed(
    name,
    'one of ${values.map((e) => e.name).join(', ')}',
    (v) => v is String ? values.where((e) => e.name == v).firstOrNull : null,
  );

  /// One of the nine named [Alignment] constants.
  Alignment? alignment(String name) => _typed(name, 'an alignment name', (v) => _alignments[v]);

  IconData? icon(String name) => _typed(name, 'an icon name', (v) => v is String ? host.icon(v) : null);

  /// A token prop, resolved to its [StyleValue].
  StyleValue<T>? token<T>(String name) => _typed(name, 'a token key', (v) => v is String ? host.token<T>(v) : null);

  /// A style prop: a preset id, or `{"preset": id, "args": {...}}`.
  StyleResolver? style(String name) => _typed(name, 'a preset id', (v) => switch (v) {
    final String id => host.preset(id, const {}),
    {'preset': final String id, 'args': final Map<String, Object?> args} => host.preset(id, args),
    _ => null,
  });

  ImageProvider? image(String name) => _typed(name, 'an image reference', (v) => v is String ? host.image(v) : null);

  /// A list of JSON rows.
  List<Object?>? rows(String name) => _typed(name, 'a list', (v) => v is List<Object?> ? v : null);

  List<String>? stringList(String name) =>
      _typed(name, 'a list of text', (v) => v is List<Object?> && v.every((e) => e is String) ? v.cast<String>() : null);

  List<int>? integerList(String name) =>
      _typed(name, 'a list of whole numbers', (v) => v is List<Object?> && v.every((e) => e is int) ? v.cast<int>() : null);

  /// A set of strings, from a list.
  Set<String>? stringSet(String name) => stringList(name)?.toSet();

  /// A date from ISO 8601 text.
  DateTime? date(String name) => _typed(name, 'an ISO 8601 date', (v) => v is String ? DateTime.tryParse(v) : null);

  /// A path prop as a reader: `"idPath": "id"` → `(row) => row['id']` as text.
  String Function(Object? row)? path(String name) => _typed(name, 'a path inside a row', (v) {
    if (v is! String) return null;
    final p = DataPath.parse('row${v.isEmpty ? '' : '.$v'}');
    return (Object? row) => '${p.readFrom(row) ?? ''}';
  });

  /// Any JSON value, as is.
  Object? json(String name) => value(name);

  List<NodeDoc> _slot(String slot) => node.slots[slot] ?? const [];

  /// A single-child slot: the first node whose `when` passes.
  Widget? child(String slot) => host.buildFirstWidget(_slot(slot), scope);

  /// A list slot.
  List<Widget> children(String slot) => host.buildWidgets(_slot(slot), scope);

  /// A list slot, or null when the node does not fill it. For widgets whose
  /// list parameter is nullable and means something when absent.
  List<Widget>? childrenOrNull(String slot) => node.slots.containsKey(slot) ? children(slot) : null;

  /// A slot of value nodes, built into value objects of type [V].
  List<V> values<V>(String slot) {
    final out = <V>[];
    for (final value in host.buildValues(_slot(slot), scope)) {
      if (value is V) {
        out.add(value as V);
      } else {
        host.report(node, "Slot '$slot' holds a ${value.runtimeType}, not a $V.");
      }
    }
    return out;
  }

  /// A template slot, built once per item with the item bound to [as]
  /// (default: the spec's template variable). Builds the first node whose
  /// `when` passes, or an empty box.
  Widget Function(Object? item) template(String slot, {String? as}) {
    final variable = as ?? spec.slot(slot)?.template ?? 'item';
    final nodes = _slot(slot);
    final instances = TemplateInstances();
    return (item) =>
        host.buildFirstWidget(nodes, scope.extend({variable: item}), keyed: false, instance: instances.of(item)) ??
        const SizedBox.shrink();
  }

  /// A template slot that builds all its nodes per item.
  List<Widget> Function(Object? item) templateList(String slot, {String? as}) {
    final variable = as ?? spec.slot(slot)?.template ?? 'item';
    final nodes = _slot(slot);
    final instances = TemplateInstances();
    return (item) => host.buildWidgets(nodes, scope.extend({variable: item}), keyed: false, instance: instances.of(item));
  }

  /// A no-payload event as a [VoidCallback], or null when unbound.
  VoidCallback? callback(String event) {
    final h = host.handler(node, event, scope);
    return h == null ? null : () => h(const {});
  }

  /// A one-value event: the value arrives as `event.value`.
  ValueChanged<T>? valueCallback<T>(String event) {
    final h = host.handler(node, event, scope);
    return h == null ? null : (T value) => h({'value': _toJson(value)});
  }

  /// An event whose payload [toPayload] builds from the callback's argument.
  void Function(A)? callbackWith<A>(String event, Map<String, Object?> Function(A arg) toPayload) {
    final h = host.handler(node, event, scope);
    return h == null ? null : (A arg) => h(toPayload(arg));
  }

  /// A two-argument event, such as a reorder's old and new index.
  void Function(A, B)? callbackWith2<A, B>(String event, Map<String, Object?> Function(A a, B b) toPayload) {
    final h = host.handler(node, event, scope);
    return h == null ? null : (A a, B b) => h(toPayload(a, b));
  }

  /// Enums travel by name; everything else as is.
  static Object? _toJson(Object? value) => value is Enum ? value.name : value;
}

const _alignments = <Object?, Alignment>{
  'topLeft': Alignment.topLeft,
  'topCenter': Alignment.topCenter,
  'topRight': Alignment.topRight,
  'centerLeft': Alignment.centerLeft,
  'center': Alignment.center,
  'centerRight': Alignment.centerRight,
  'bottomLeft': Alignment.bottomLeft,
  'bottomCenter': Alignment.bottomCenter,
  'bottomRight': Alignment.bottomRight,
};
