import 'catalog.dart';
import 'fmt.dart';

/// A plausible JSON value for [def], for examples and hints.
Object? examplePropValue(DesignProp def, Catalog catalog) {
  if (def.defaultValue != null && def.kind != PropKind.integerList) return def.defaultValue;
  return switch (def.kind) {
    PropKind.string || PropKind.image => def.name == 'label' || def.name == 'title' ? 'Label' : '...',
    PropKind.boolean => true,
    PropKind.integer || PropKind.number => 1,
    PropKind.choice => def.values.isEmpty ? '...' : def.values.first,
    PropKind.icon => catalog.icons.isEmpty ? 'icon' : catalog.icons.first,
    PropKind.style => switch (def.families.isEmpty
        ? catalog.presets.values.firstOrNull
        : catalog.presets[def.families.first]) {
      final f? => '${f.name}.${f.defaultVariant ?? f.variants.first}',
      null => 'Family.variant',
    },
    PropKind.token =>
      catalog.tokens.values.where((t) => def.tokenType == null || t.type == def.tokenType).firstOrNull?.key ??
          'tokenKey',
    PropKind.date => '2026-11-25',
    PropKind.path => 'id',
    PropKind.rows => {r'$bind': 'data.items'},
    PropKind.stringList => ['...'],
    PropKind.integerList => [1],
    PropKind.json => null,
  };
}

/// A minimal valid node of [comp]: its catalog `example` when it has one,
/// else one built from its required props and slots, with its primary event
/// bound to an emit.
Map<String, Object?> exampleNode(DesignComponent comp, Catalog catalog) {
  if (comp.example case final example?) return example;
  final node = _exampleNode(comp, catalog, 0);
  // Placeholder children repeat their ids; number the repeats.
  final seen = <String>{};
  forEachNodeJson(node, (n) {
    final id = n['id']! as String;
    var unique = id;
    for (var k = 2; !seen.add(unique); k++) {
      unique = '$id$k';
    }
    n['id'] = unique;
  });
  return node;
}

Map<String, Object?> _exampleNode(DesignComponent comp, Catalog catalog, int depth) {
  if (comp.example case final example?) return example;
  final id = nodeIdBase(comp.type);
  final type = comp.hasDefaultConstructor || comp.constructors.isEmpty
      ? comp.type
      : '${comp.type}.${comp.constructors.first}';
  // A library rule that fixes a prop of this component (a page root's style)
  // gives the value to show.
  final ruled = <String, Object?>{
    for (final rule in [...catalog.rules, ...comp.rules])
      if (rule.types.contains(comp.type)) ...rule.props,
  };
  final props = {
    for (final p in comp.props.where((p) => p.required))
      p.name: ruled.containsKey(p.name) ? ruled[p.name] : examplePropValue(p, catalog),
  };
  final slots = <String, Object?>{};
  for (final slot in comp.slots.where((s) => s.required)) {
    final child = _exampleChild(slot, catalog, depth);
    if (child != null) slots[slot.name] = [child];
  }
  final primary = comp.primaryEvent;
  return {
    'id': id,
    'type': type,
    if (props.isNotEmpty) 'props': props,
    'children': ?slots['children'],
    if (slots.keys.any((k) => k != 'children'))
      'slots': {
        for (final MapEntry(:key, :value) in slots.entries)
          if (key != 'children') key: value,
      },
    if (primary != null)
      'on': {
        primary.name: [
          {'do': 'emit', 'name': '$id${primary.name[0].toUpperCase()}${primary.name.substring(1)}'},
        ],
      },
  };
}

Map<String, Object?>? _exampleChild(DesignSlot slot, Catalog catalog, int depth) {
  if (depth > 2) return null;
  for (final type in slot.accepts) {
    if (type == 'widget') continue;
    if (catalog.components[type] case final c?) return _exampleNode(c, catalog, depth + 1);
  }
  if (!slot.takesWidgets) return null;
  if (catalog.components['StyledText'] != null) {
    return {
      'id': '${slot.name}Text',
      'type': 'StyledText',
      'props': {'text': '...'},
    };
  }
  final simple = catalog.components.values.where(
    (c) =>
        c.kind == DesignKind.widget &&
        c.hasDefaultConstructor &&
        !c.props.any((p) => p.required) &&
        !c.slots.any((s) => s.required),
  );
  return simple.isEmpty ? null : {'id': nodeIdBase(simple.first.type), 'type': simple.first.type};
}
