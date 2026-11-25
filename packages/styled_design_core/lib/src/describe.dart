import 'dart:convert';

import 'catalog.dart';
import 'expressions.dart';
import 'screen.dart';

/// The resolved tree of [screen] against one of its fixtures, as an indented
/// outline: each node `#id Type.ctor` with its props evaluated, nodes a
/// `when` hides marked, repeats expanded one line per item, template slots
/// shown for the first [templateRows] items, and where each event leads.
/// A screenshot for a reader that cannot see.
String describeScreen(ScreenDoc screen, Catalog catalog, {String fixture = 'default', int templateRows = 3}) =>
    _Describer(screen, catalog, templateRows).run(fixture);

final class _Describer {
  final ScreenDoc screen;
  final Catalog catalog;
  final int templateRows;
  final b = StringBuffer();

  _Describer(this.screen, this.catalog, this.templateRows);

  String run(String fixture) {
    final data = screen.fixture(fixture);
    final params = <String, Object?>{
      for (final p in screen.routeParams) p: p,
      for (final MapEntry(:key, :value) in screen.params.entries) key: value.sample,
    };
    final query = <String, Object?>{
      for (final MapEntry(:key, :value) in screen.query.entries)
        key: value.sample ?? (value.values.isEmpty ? null : value.values.first),
    };
    var scope = MapScope({
      'data': data,
      'params': params,
      'query': query,
      if (screen.kind == ScreenKind.frame) 'page': const {'id': null},
    });
    final state = {for (final MapEntry(:key, :value) in screen.state.entries) key: value.eval(scope)};
    scope = scope.extend({'state': state});
    final where = screen.route == null ? screen.kind.name : '${screen.kind.name} ${screen.route}';
    b.writeln('${screen.id} "${screen.title}" ($where), fixture $fixture');
    if (state.isNotEmpty) b.writeln('state: ${_props(state)}');
    node(screen.root, scope, '', const []);
    return b.toString();
  }

  void node(NodeDoc n, MapScope scope, String indent, List<(NodeDoc, MapScope)> ancestors) {
    final repeat = n.repeat;
    if (repeat == null) {
      drawn(n, scope, indent, '', ancestors);
      return;
    }
    final items = repeat.over.eval(scope);
    if (items is! List<Object?> || items.isEmpty) {
      b.writeln('$indent#${n.id} ${n.type} [repeat: no items]');
      return;
    }
    for (var i = 0; i < items.length; i++) {
      final itemScope = scope.extend({repeat.as: items[i], ?repeat.index: i});
      final key = repeat.key?.eval(itemScope) ?? i;
      drawn(n, itemScope, indent, '[$key]', ancestors);
    }
  }

  /// One node as drawn; returns whether its `when` let it show.
  bool drawn(NodeDoc n, MapScope scope, String indent, String suffix, List<(NodeDoc, MapScope)> ancestors) {
    final head = '$indent#${n.id}$suffix ${n.type}';
    if (n.when != null && !isTruthy(n.when!.eval(scope))) {
      b.writeln('$head [hidden: when]');
      return false;
    }
    final props = {for (final MapEntry(:key, :value) in n.props.entries) key: value.eval(scope)};
    final text = _props(props);
    b.writeln(text.isEmpty ? head : '$head $text');
    for (final MapEntry(:key, :value) in n.on.entries) {
      b.writeln('$indent  $key → ${_actions(value)}');
    }
    final comp = catalog.components[n.componentType];
    final below = [...ancestors, (n, scope)];
    for (final MapEntry(key: slot, value: children) in n.slots.entries) {
      final def = comp?.slot(slot);
      final childIndent = slot == 'children' ? '$indent  ' : '$indent    ';
      final template = def?.template;
      if (template == null) {
        if (slot != 'children') b.writeln('$indent  $slot:');
        list(children, scope, childIndent, below, single: def != null && !def.many);
        continue;
      }
      final (value, perItem) = templateValue(n, comp!, template, scope, ancestors);
      if (!perItem) {
        b.writeln('$indent  $slot ($template = ${_value(value)}):');
        list(children, scope.extend({template: value}), childIndent, below, single: !def!.many);
        continue;
      }
      final rows = value is List<Object?> ? value : const <Object?>[];
      if (rows.isEmpty) {
        b.writeln('$indent  $slot: [no ${template}s]');
        continue;
      }
      for (var i = 0; i < rows.length && i < templateRows; i++) {
        b.writeln('$indent  $slot ($template ${i + 1} of ${rows.length}):');
        list(children, scope.extend({template: rows[i]}), childIndent, below, single: !def!.many);
      }
      if (rows.length > templateRows) b.writeln('$indent  $slot: (${rows.length - templateRows} more)');
    }
    return true;
  }

  void list(
    List<NodeDoc> children,
    MapScope scope,
    String indent,
    List<(NodeDoc, MapScope)> ancestors, {
    required bool single,
  }) {
    var shown = false;
    for (final child in children) {
      if (single && shown) {
        b.writeln('$indent#${child.id} ${child.type} [not drawn: the slot shows one node]');
        continue;
      }
      if (single && child.repeat == null) {
        shown = drawn(child, scope, indent, '', ancestors);
      } else {
        node(child, scope, indent, ancestors);
        shown = true;
      }
    }
  }

  /// A template slot's variable: the owner's prop of the same name, given
  /// whole; or the nearest list prop up the tree, given per item.
  (Object?, bool) templateValue(
    NodeDoc owner,
    DesignComponent comp,
    String name,
    MapScope scope,
    List<(NodeDoc, MapScope)> ancestors,
  ) {
    if (comp.prop(name) != null) return (owner.props[name]?.eval(scope), false);
    for (final (n, s) in [(owner, scope), ...ancestors.reversed]) {
      final c = catalog.components[n.componentType];
      if (c == null) continue;
      for (final prop in c.props) {
        if ((prop.kind == PropKind.rows || prop.name == '${name}s') && n.props.containsKey(prop.name)) {
          return (n.props[prop.name]!.eval(s), true);
        }
      }
    }
    return (null, false);
  }

  String _props(Map<String, Object?> props) => [
    for (final MapEntry(:key, :value) in props.entries)
      if (value != null) '$key=${_value(value)}',
  ].join(' ');

  String _value(Object? value) => switch (value) {
    final String s => jsonEncode(s.length > 60 ? '${s.substring(0, 57)}...' : s),
    final List<Object?> l =>
      l.every((x) => x is! Map && x is! List) && l.length <= 5
          ? jsonEncode(l)
          : '[${l.length} item${l.length == 1 ? '' : 's'}]',
    final Map<Object?, Object?> m =>
      m.length <= 3 && m.values.every((x) => x is! Map && x is! List) ? jsonEncode(m) : '{${m.keys.join(', ')}}',
    _ => '$value',
  };

  String _expr(Expr e) => switch (e) {
    Literal(:final value) => _value(value),
    Bind(:final path) => '$path',
    TextTemplate() => '\$text',
    _ => 'expression',
  };

  String _params(Map<String, Expr> params) =>
      params.isEmpty ? '' : ' ${params.entries.map((p) => '${p.key}=${_expr(p.value)}').join(' ')}';

  String _actions(List<ActionDoc> actions) => actions
      .map(
        (a) => switch (a) {
          NavigateAction() => 'navigate ${a.to} (${a.mode.name})${_params(a.params)}',
          BackAction() => 'back (fallback ${a.fallback})${_params(a.params)}',
          BackToAction() => 'backTo ${a.to}${_params(a.params)}',
          SetQueryAction() => 'setQuery${_params(a.set)}',
          OpenModalAction() =>
            'openModal ${a.screen}${_params(a.params)}${a.then.isEmpty ? '' : ', then ${_actions(a.then)}'}',
          CloseModalAction() => a.result == null ? 'closeModal' : 'closeModal result=${_expr(a.result!)}',
          ConfirmAction() => 'confirm ${_expr(a.title)}, then ${_actions(a.then)}',
          ToastAction() => 'toast ${_expr(a.message)}',
          SetStateAction() => 'setState${_params(a.set)}',
          EmitAction() => 'emit ${a.name}${_params(a.payload)}',
        },
      )
      .join('; ');
}
