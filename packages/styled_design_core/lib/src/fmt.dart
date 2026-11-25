import 'dart:convert';

import 'json_util.dart';

/// The key order of a screen document.
const screenKeyOrder = [
  r'$schema', 'format', 'id', 'kind', 'title', 'description', 'route', 'frame', 'params', 'query', 'state', //
  'fixtures', 'emits', 'root',
];

/// The key order of a node.
const nodeKeyOrder = ['id', 'type', 'note', 'when', 'repeat', 'props', 'children', 'slots', 'on'];

/// Whether [json] is a screen document: by its [path] (`screens/...`) when
/// given, else by its shape.
bool isScreenDocument(Map<String, Object?> json, {String? path}) =>
    path != null ? path.startsWith('screens/') : json.containsKey('root') && json.containsKey('kind');

/// JSON text in the canonical layout: two-space indent and a trailing newline.
String canonicalJsonText(Object? json) => '${const JsonEncoder.withIndent('  ').convert(json)}\n';

/// The canonical form of a design document: for a screen, keys in the fixed
/// order and an id on every node; anything else as it is. Never changes
/// [json].
Map<String, Object?> canonicalDocument(Map<String, Object?> json, {String? path}) {
  if (!isScreenDocument(json, path: path)) return deepCopyJson(json)! as Map<String, Object?>;
  final withIds = withNodeIds(json);
  return {
    for (final key in _ordered(withIds.keys, screenKeyOrder))
      key: key == 'root' ? _orderNode(withIds[key]) : withIds[key],
  };
}

/// [json] as canonical text. The same design always gives the same bytes.
String formatDocument(Map<String, Object?> json, {String? path}) =>
    canonicalJsonText(canonicalDocument(json, path: path));

/// A copy of [screen] in which every node without an id gets one: lower
/// camel from its type (`onboardingButton`, then `onboardingButton2`),
/// unique in the screen. Nodes are visited depth first, in document order.
Map<String, Object?> withNodeIds(Map<String, Object?> screen) {
  final copy = deepCopyJson(screen)! as Map<String, Object?>;
  final taken = <String>{};
  forEachNodeJson(copy['root'], (node) {
    if (node['id'] case final String id) taken.add(id);
  });
  forEachNodeJson(copy['root'], (node) {
    if (node['id'] != null) return;
    final base = nodeIdBase(node['type']);
    var id = base;
    for (var n = 2; taken.contains(id); n++) {
      id = '$base$n';
    }
    taken.add(id);
    final rest = {...node}..remove('id');
    node
      ..clear()
      ..['id'] = id
      ..addAll(rest);
  });
  return copy;
}

/// The id stem for a node of [type]: `OnboardingButton.primary` → `onboardingButton`.
String nodeIdBase(Object? type) {
  if (type is! String || type.isEmpty) return 'node';
  final component = type.split('.').first.replaceAll(RegExp('[^A-Za-z0-9]'), '');
  if (component.isEmpty || !RegExp('^[A-Za-z]').hasMatch(component)) return 'node';
  return '${component[0].toLowerCase()}${component.substring(1)}';
}

/// Calls [visit] on every node object below and including [node], depth
/// first in document order: `children`, then each slot.
void forEachNodeJson(Object? node, void Function(Map<String, Object?> node) visit) {
  if (node is! Map<String, Object?>) return;
  visit(node);
  for (final list in childListsOf(node)) {
    for (final child in list) {
      forEachNodeJson(child, visit);
    }
  }
}

/// The child lists of a node object: `children`, then each slot's list.
Iterable<List<Object?>> childListsOf(Map<String, Object?> node) sync* {
  if (node['children'] case final List<Object?> children) yield children;
  if (node['slots'] case final Map<String, Object?> slots) {
    for (final list in slots.values) {
      if (list is List<Object?>) yield list;
    }
  }
}

Object? _orderNode(Object? node) {
  if (node is! Map<String, Object?>) return node;
  List<Object?> list(Object? value) => value is List<Object?> ? [for (final n in value) _orderNode(n)] : [value];
  return {
    for (final key in _ordered(node.keys, nodeKeyOrder))
      key: switch (key) {
        'children' when node[key] is List<Object?> => list(node[key]),
        'slots' when node[key] is Map<String, Object?> => {
          for (final MapEntry(:key, :value) in (node['slots']! as Map<String, Object?>).entries)
            key: value is List<Object?> ? list(value) : value,
        },
        _ => node[key],
      },
  };
}

Iterable<String> _ordered(Iterable<String> keys, List<String> order) => [
  for (final k in order)
    if (keys.contains(k)) k,
  for (final k in keys)
    if (!order.contains(k)) k,
];
