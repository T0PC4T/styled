import 'package:meta/meta.dart';

import 'diagnostics.dart';
import 'fmt.dart';
import 'json_util.dart';

/// The structural edits [applyPatch] knows, with their fields.
const patchOps = {
  'insert': ['parent', 'slot', 'index?', 'node'],
  'remove': ['node'],
  'move': ['node', 'parent', 'slot', 'index?'],
  'setProp': ['node', 'prop', 'value'],
  'setEvent': ['node', 'event', 'actions'],
  'setWhen': ['node', 'when'],
  'wrap': ['node', 'with', 'slot'],
};

/// What [applyPatch] returns: the edited screen JSON, or null and the reasons
/// when any operation could not apply.
@immutable
final class PatchResult {
  final Map<String, Object?>? json;
  final List<Diagnostic> diagnostics;
  const PatchResult(this.json, this.diagnostics);

  bool get ok => json != null;
}

/// Applies structural edits, addressed by node id, to a screen's JSON:
///
/// * `{"op": "insert", "parent": id, "slot": name, "index"?: n, "node": {...}}`
/// * `{"op": "remove", "node": id}`
/// * `{"op": "move", "node": id, "parent": id, "slot": name, "index"?: n}`
///   (index counts after the node is taken out)
/// * `{"op": "setProp", "node": id, "prop": name, "value": v}` (null removes)
/// * `{"op": "setEvent", "node": id, "event": name, "actions": [...]}` (null removes)
/// * `{"op": "setWhen", "node": id, "when": v}` (null removes)
/// * `{"op": "wrap", "node": id, "with": {"id", "type", "props"?}, "slot": name}`
///
/// Operations apply in order. All or nothing: when any fails, [PatchResult.json]
/// is null and every failure is reported, with a pointer into [ops]. A node
/// inserted (or a wrapper added) without an id gets one at once, as
/// `design fmt` assigns them (`styledText`, `styledText2`), so later
/// operations can address it. Never changes [screen]; the caller validates
/// the result.
PatchResult applyPatch(Map<String, Object?> screen, Object? ops, {String? screenId}) {
  final problems = <Diagnostic>[];
  final doc = deepCopyJson(screen)! as Map<String, Object?>;
  final id = screenId ?? (screen['id'] is String ? screen['id']! as String : '?');
  if (ops is! List<Object?>) {
    return PatchResult(null, [
      Diagnostic.of(
        'E-patch-op',
        'The ops are a JSON list of operations, such as [{"op": "setProp", "node": "save", "prop": "label", "value": "Save"}].',
        pointer: '',
      ),
    ]);
  }
  for (var i = 0; i < ops.length; i++) {
    _Patcher(doc, id, i, problems).apply(ops[i]);
  }
  if (problems.isNotEmpty) return PatchResult(null, problems);
  return PatchResult(withNodeIds(doc), const []);
}

/// Where a node sits: its object, the list holding it and its index there
/// (null for the root).
typedef _Loc = ({Map<String, Object?> node, List<Object?>? list, int index});

final class _Patcher {
  final Map<String, Object?> doc;
  final String screenId;
  final int i;
  final List<Diagnostic> problems;
  String op = '?';

  _Patcher(this.doc, this.screenId, this.i, this.problems);

  void fail(String code, String message, String field, {String? node, String? hint, List<String>? allowed}) =>
      problems.add(
        Diagnostic.of(
          code,
          op == '?' ? 'Op $i: $message' : 'Op $i ($op): $message',
          pointer: field.isEmpty ? '/$i' : '/$i/$field',
          node: node == null ? null : '$screenId#$node',
          hint: hint,
          allowed: allowed,
        ),
      );

  Iterable<String> get ids sync* {
    final all = <String>[];
    forEachNodeJson(doc['root'], (n) {
      if (n['id'] case final String id) all.add(id);
    });
    yield* all;
  }

  _Loc? find(String id) {
    final root = doc['root'];
    if (root is Map<String, Object?> && root['id'] == id) return (node: root, list: null, index: -1);
    _Loc? found;
    forEachNodeJson(root, (n) {
      if (found != null) return;
      for (final list in childListsOf(n)) {
        for (var k = 0; k < list.length; k++) {
          final child = list[k];
          if (child is Map<String, Object?> && child['id'] == id) {
            found = (node: child, list: list, index: k);
            return;
          }
        }
      }
    });
    return found;
  }

  /// The node an op names in [field], or null after reporting why not.
  _Loc? node(Map<String, Object?> m, String field) {
    final id = m[field];
    if (id is! String) {
      fail('E-patch-op', "'$field' is the id of a node.", field, hint: 'Write "$field": "<node id>".');
      return null;
    }
    final loc = find(id);
    if (loc == null) {
      fail(
        'E-node-unknown',
        "${screenIdLabel()} has no node '$id'.",
        field,
        node: id,
        hint: didYouMean(id, ids) ?? 'Run design describe $screenId to list the node ids.',
      );
    }
    return loc;
  }

  String screenIdLabel() => "Screen '$screenId'";

  String? string(Map<String, Object?> m, String field) {
    final value = m[field];
    if (value is String && value.isNotEmpty) return value;
    if (!m.containsKey(field)) {
      fail('E-patch-op', "needs '$field'.", '', hint: 'Fields: ${patchOps[op]!.join(', ')}.');
    } else {
      fail('E-patch-op', "'$field' is a name.", field, hint: 'Write "$field": "<name>".');
    }
    return null;
  }

  bool has(Map<String, Object?> m, String field) {
    if (m.containsKey(field)) return true;
    fail('E-patch-op', "needs '$field'.", '', hint: 'Fields: ${patchOps[op]!.join(', ')}.');
    return false;
  }

  /// The list of [slot] on [parent], created when missing. `children` goes
  /// wherever the node already keeps it.
  List<Object?> slotList(Map<String, Object?> parent, String slot) {
    if (slot == 'children') {
      if (parent['children'] case final List<Object?> list) return list;
      if (parent['slots'] case {'children': final List<Object?> list}) return list;
      final list = <Object?>[];
      parent['children'] = list;
      return list;
    }
    var slots = parent['slots'];
    if (slots is! Map<String, Object?>) {
      slots = <String, Object?>{};
      parent['slots'] = slots;
    }
    if (slots[slot] case final List<Object?> list) return list;
    final list = <Object?>[];
    slots[slot] = list;
    return list;
  }

  int? index(Map<String, Object?> m, int length) {
    if (!m.containsKey('index') || m['index'] == null) return length;
    final value = m['index'];
    if (value is int && value >= 0 && value <= length) return value;
    fail('E-patch-op', 'index is a whole number from 0 to $length, not $value.', 'index');
    return null;
  }

  /// Reports ids of [subtree] that clash with the screen or with each other.
  bool uniqueIds(Object? subtree, String field) {
    final existing = ids.toSet();
    final seen = <String>{};
    var ok = true;
    forEachNodeJson(subtree, (n) {
      if (n['id'] case final String id) {
        if (existing.contains(id) || !seen.add(id)) {
          var k = 2;
          while (existing.contains('$id$k') || seen.contains('$id$k')) {
            k++;
          }
          fail(
            'E-duplicate-id',
            "node id '$id' is already used in $screenId.",
            field,
            node: id,
            hint: "Give the node its own id, such as '$id$k'.",
          );
          ok = false;
        }
      }
    });
    return ok;
  }

  /// Gives every node without an id one at once, so later operations can
  /// address a node inserted without an id.
  void assignIds() => doc['root'] = withNodeIds({'root': doc['root']})['root'];

  bool inside(Map<String, Object?> node, Map<String, Object?> ancestor) {
    var found = false;
    forEachNodeJson(ancestor, (n) => found = found || identical(n, node));
    return found;
  }

  void apply(Object? raw) {
    if (raw is! Map<String, Object?>) {
      fail('E-patch-op', 'An operation is an object with "op".', '');
      return;
    }
    final name = raw['op'];
    if (name is! String || !patchOps.containsKey(name)) {
      fail(
        'E-patch-op',
        name == null ? "an operation needs 'op'." : "there is no operation '$name'.",
        'op',
        hint: name is String ? didYouMean(name, patchOps.keys) : null,
        allowed: patchOps.keys.toList(),
      );
      return;
    }
    op = name;
    for (final key in raw.keys) {
      if (key == 'op' || patchOps[op]!.any((f) => f == key || f == '$key?')) continue;
      fail(
        'E-patch-op',
        "$op takes no field '$key'.",
        pointerSegment(key),
        hint: didYouMean(key, patchOps[op]!.map((f) => f.replaceAll('?', ''))),
        allowed: patchOps[op]!.map((f) => f.replaceAll('?', '')).toList(),
      );
    }
    switch (op) {
      case 'insert':
        if (!has(raw, 'node')) return;
        final parent = node(raw, 'parent');
        final slot = string(raw, 'slot');
        final child = raw['node'];
        if (child is! Map<String, Object?> || child['type'] is! String) {
          fail(
            'E-patch-op',
            'node is a node object with at least a type.',
            'node',
            hint: 'Write {"id": "...", "type": "..."}.',
          );
          return;
        }
        if (parent == null || slot == null || !uniqueIds(child, 'node')) return;
        final list = slotList(parent.node, slot);
        final at = index(raw, list.length);
        if (at == null) return;
        list.insert(at, deepCopyJson(child));
        assignIds();
      case 'remove':
        final loc = node(raw, 'node');
        if (loc == null) return;
        if (loc.list == null) {
          fail(
            'E-patch-op',
            'the root cannot be removed.',
            'node',
            hint: 'Wrap it, or replace the root by editing the file.',
          );
          return;
        }
        loc.list!.removeAt(loc.index);
      case 'move':
        final loc = node(raw, 'node');
        final parent = node(raw, 'parent');
        final slot = string(raw, 'slot');
        if (loc == null || parent == null || slot == null) return;
        if (loc.list == null) {
          fail('E-patch-op', 'the root cannot be moved.', 'node');
          return;
        }
        if (inside(parent.node, loc.node)) {
          fail('E-patch-op', 'a node cannot move into itself or below itself.', 'parent');
          return;
        }
        final moved = loc.list!.removeAt(loc.index);
        final list = slotList(parent.node, slot);
        final at = index(raw, list.length);
        if (at == null) {
          loc.list!.insert(loc.index, moved);
          return;
        }
        list.insert(at, moved);
      case 'setProp':
        final loc = node(raw, 'node');
        final prop = string(raw, 'prop');
        if (loc == null || prop == null || !has(raw, 'value')) return;
        final value = raw['value'];
        final props = loc.node['props'] is Map<String, Object?>
            ? loc.node['props']! as Map<String, Object?>
            : <String, Object?>{};
        if (value == null) {
          props.remove(prop);
        } else {
          props[prop] = deepCopyJson(value);
        }
        if (props.isEmpty) {
          loc.node.remove('props');
        } else {
          loc.node['props'] = props;
        }
      case 'setEvent':
        final loc = node(raw, 'node');
        final event = string(raw, 'event');
        if (loc == null || event == null || !has(raw, 'actions')) return;
        final actions = raw['actions'];
        if (actions != null && actions is! List<Object?>) {
          fail('E-patch-op', 'actions is a list of actions, or null to remove the event.', 'actions');
          return;
        }
        final on = loc.node['on'] is Map<String, Object?>
            ? loc.node['on']! as Map<String, Object?>
            : <String, Object?>{};
        if (actions == null) {
          on.remove(event);
        } else {
          on[event] = deepCopyJson(actions);
        }
        if (on.isEmpty) {
          loc.node.remove('on');
        } else {
          loc.node['on'] = on;
        }
      case 'setWhen':
        final loc = node(raw, 'node');
        if (loc == null || !has(raw, 'when')) return;
        if (raw['when'] == null) {
          loc.node.remove('when');
        } else {
          loc.node['when'] = deepCopyJson(raw['when']);
        }
      case 'wrap':
        final loc = node(raw, 'node');
        final slot = string(raw, 'slot');
        final wrapper = raw['with'];
        if (wrapper is! Map<String, Object?> || wrapper['type'] is! String) {
          fail(
            'E-patch-op',
            'with is {"id", "type", "props"?}.',
            'with',
            hint: 'Write {"id": "card", "type": "OnboardingCard"}.',
          );
          return;
        }
        for (final key in wrapper.keys.where((k) => !const {'id', 'type', 'props'}.contains(k))) {
          fail('E-patch-op', "with takes id, type and props, not '$key'.", 'with/${pointerSegment(key)}');
          return;
        }
        if (loc == null || slot == null || !uniqueIds(wrapper, 'with')) return;
        final outer = <String, Object?>{
          if (wrapper['id'] != null) 'id': wrapper['id'],
          'type': wrapper['type'],
          if (wrapper['props'] != null) 'props': deepCopyJson(wrapper['props']),
          if (slot == 'children')
            'children': [loc.node]
          else
            'slots': {
              slot: [loc.node],
            },
        };
        if (loc.list == null) {
          doc['root'] = outer;
        } else {
          loc.list![loc.index] = outer;
        }
        assignIds();
    }
  }
}
