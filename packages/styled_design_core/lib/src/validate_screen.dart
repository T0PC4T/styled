part of 'validator.dart';

/// A value whose shape the validator cannot know, such as an event payload.
/// Paths below it are not checked.
final class _Unknown {
  const _Unknown();
}

const _unknown = _Unknown();

/// The roots an expression may read at one place, with a sample value each
/// (from the default fixture) and words to name it in messages.
final class _Scope {
  final Map<String, Object?> values;
  final Map<String, String> labels;
  const _Scope(this.values, this.labels);

  _Scope add(String root, Object? value, String label) => _Scope({...values, root: value}, {...labels, root: label});
}

/// An ancestor of the node being checked, and the slot position the walk
/// took below it.
final class _Anc {
  final NodeDoc node;
  final DesignComponent? comp;
  final _Scope scope;
  final String slot;
  final int index;
  final int count;
  const _Anc(this.node, this.comp, this.scope, this.slot, this.index, this.count);
}

sealed class _Res {
  const _Res();
}

final class _Found extends _Res {
  final Object? value;
  const _Found(this.value);
}

final class _Miss extends _Res {
  final int index;
  final Object? container;
  const _Miss(this.index, this.container);
}

final class _Opaque extends _Res {
  const _Opaque();
}

/// Walks [segments] below [root]. A list is entered through the item an
/// index names, or its first item when the sample is shorter; null, an empty
/// list or an unknown value end the walk without a verdict.
_Res _resolve(Object? root, List<String> segments) {
  var current = root;
  for (var i = 0; i < segments.length; i++) {
    if (current == null || current is _Unknown) return const _Opaque();
    final segment = segments[i];
    switch (current) {
      case final Map<String, Object?> map:
        if (!map.containsKey(segment)) return _Miss(i, current);
        current = map[segment];
      case final List<Object?> list:
        final index = int.tryParse(segment);
        if (index == null) return _Miss(i, current);
        if (list.isEmpty) return const _Opaque();
        current = index < list.length ? list[index] : list.first;
      default:
        return _Miss(i, current);
    }
  }
  return _Found(current);
}

/// The sample value of raw expression JSON in [scope]: a literal, or what a
/// `$bind` reads; unknown for anything computed.
Object? _sample(Object? raw, _Scope scope) {
  if (raw is Map<String, Object?> && raw.length == 1 && raw.containsKey(r'$bind')) {
    final text = raw[r'$bind'];
    if (text is! String) return _unknown;
    final DataPath path;
    try {
      path = DataPath.parse(text);
    } on ExpressionError {
      return _unknown;
    }
    if (!scope.values.containsKey(path.root)) return _unknown;
    return switch (_resolve(scope.values[path.root], path.segments)) {
      _Found(:final value) => value ?? _unknown,
      _ => _unknown,
    };
  }
  return containsExpression(raw) ? _unknown : raw;
}

String _exprText(Object? raw) {
  if (raw is Map<String, Object?> && raw[r'$bind'] is String) return raw[r'$bind']! as String;
  return 'the list';
}

String _show(Object? value) => switch (value) {
  null => 'null',
  final String s => s.length > 40 ? '"${s.substring(0, 37)}..."' : '"$s"',
  num() || bool() => '$value',
  List<Object?>() => 'a list',
  _ => 'an object',
};

final _rowPath = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*|[0-9]+)(\.([A-Za-z_][A-Za-z0-9_]*|[0-9]+))*$');

const _structuralActionKeys = {
  'do',
  'to',
  'mode',
  'screen',
  'fallback',
  'name',
  'history',
  'destructive',
  'tone',
  'then',
};
const _screenRuleKinds = {'pageRoot', 'modalRoot', 'frameRoot', 'singleScroll'};
const _boolOps = {
  r'$not', r'$empty', r'$and', r'$or', r'$eq', r'$ne', r'$gt', r'$gte', r'$lt', r'$lte', r'$in', //
};

/// What one prop kind takes, in words.
String propKindText(DesignProp def) => switch (def.kind) {
  PropKind.string => 'text',
  PropKind.boolean => 'true or false',
  PropKind.integer => 'a whole number',
  PropKind.number => 'a number',
  PropKind.choice => def.values.isEmpty ? 'a name' : 'one of ${def.values.join(', ')}',
  PropKind.icon => 'an icon name',
  PropKind.style => def.families.isEmpty ? 'a preset id' : 'a ${def.families.join(' or ')} preset id',
  PropKind.token => def.tokenType == null ? 'a token key' : 'a ${def.tokenType} token key',
  PropKind.image => 'an image reference',
  PropKind.date => 'an ISO 8601 date',
  PropKind.path => 'a path inside a row, such as "id"',
  PropKind.rows => 'a list of rows',
  PropKind.stringList => 'a list of text',
  PropKind.integerList => 'a list of whole numbers',
  PropKind.json => 'any JSON value',
};

/// What a slot takes, in words.
String slotAcceptsText(DesignSlot slot) =>
    slot.accepts.length == 1 && slot.accepts.single == 'widget' ? 'widgets' : slot.accepts.join(' or ');

/// Whether [slot] takes a node of component [comp].
bool slotAccepts(DesignSlot slot, DesignComponent comp) =>
    slot.accepts.contains(comp.type) || (comp.kind == DesignKind.widget && slot.accepts.contains('widget'));

bool _typeIn(NodeDoc node, List<String> types) => types.contains(node.componentType) || types.contains(node.type);

final class _ScreenCheck {
  final _Validator v;
  final _Screen s;

  /// Variable name → where it exists, for E-bind-root messages.
  final homes = <String, String>{};

  _ScreenCheck(this.v, this.s);

  ScreenDoc get screen => s.doc;
  String get file => s.path;
  Map<String, Object?> get json => screen.json;
  Catalog get catalog => v.catalog;

  void report(String code, String message, String pointer, {String? node, String? hint, List<String>? allowed}) =>
      v.report(code, message, file: file, pointer: pointer, node: node, hint: hint, allowed: allowed);

  bool brokenAt(String pointer) => s.broken.any((b) => b == pointer || b.startsWith('$pointer/'));

  Map<String, Object?> rawNode(NodeDoc node) => switch (jsonAt(json, node.pointer)) {
    final Map<String, Object?> m => m,
    _ => const {},
  };

  void run() {
    collectHomes();
    final base = baseScope();
    final state = json['state'];
    if (state is Map<String, Object?>) {
      for (final MapEntry(:key, :value) in state.entries) {
        checkValue(value, '/state/${pointerSegment(key)}', base, null);
      }
    }
    walk(screen.root, base, const []);
    screenRules();
  }

  _Scope baseScope() {
    final params = {...screen.params.keys, if (screen.kind == ScreenKind.page) ...screen.routeParams};
    return _Scope(
      {
        'data': screen.defaultFixture,
        'state': {for (final k in screen.state.keys) k: _unknown},
        'params': {for (final k in params) k: _unknown},
        'query': {for (final k in screen.query.keys) k: _unknown},
        if (screen.kind == ScreenKind.frame) 'page': _unknown,
      },
      const {
        'data': 'the default fixture',
        'state': "the screen's state",
        'params': "the screen's params",
        'query': "the screen's query",
        'page': 'the page in the frame',
      },
    );
  }

  void collectHomes() {
    for (final node in screen.nodes) {
      if (node.repeat case final r?) {
        homes.putIfAbsent(r.as, () => 'inside #${node.id} and below (its repeat)');
        if (r.index case final i?) homes.putIfAbsent(i, () => 'inside #${node.id} and below (its repeat index)');
      }
      final comp = v.component(node.componentType);
      for (final slot in node.slots.keys) {
        if (comp?.slot(slot)?.template case final t?) {
          homes.putIfAbsent(t, () => "inside the '$slot' slot of #${node.id}");
        }
      }
    }
  }

  // ------------------------------------------------------------ expressions

  void checkValue(Object? raw, String pointer, _Scope scope, String? node) {
    for (final ref in pathRefs(raw, pointer)) {
      checkPath(ref.path, ref.pointer, scope, node);
      final f = ref.formatter;
      if (f != null && !v.formatterNames.contains(f)) {
        report(
          'E-formatter-unknown',
          "There is no formatter '$f'.",
          ref.pointer,
          node: node,
          hint: didYouMean(f, v.formatterNames),
          allowed: shortList(v.formatterNames),
        );
      }
    }
  }

  void checkPath(DataPath path, String pointer, _Scope scope, String? node) {
    final root = path.root;
    if (!scope.values.containsKey(root)) {
      final inScope = scope.values.keys.toList();
      final message = switch (root) {
        'event' => "'event' exists only inside an action list (under on).",
        'page' => "'page' exists only in frame screens.",
        _ when homes.containsKey(root) => "'$root' is not in scope here; it exists only ${homes[root]}.",
        _ => "'$root' is not a root here. A path starts at ${inScope.join(', ')}.",
      };
      report('E-bind-root', message, pointer, node: node, hint: didYouMean(root, inScope), allowed: shortList(inScope));
      return;
    }
    final result = _resolve(scope.values[root], path.segments);
    if (result is! _Miss) return;
    final i = result.index;
    final segment = path.segments[i];
    final parent = [root, ...path.segments.take(i)].join('.');
    final container = result.container;
    final keys = container is Map<String, Object?> ? container.keys.toList() : const <String>[];
    final parentName = i == 0 && root != 'data' ? '$root (${scope.labels[root]})' : parent;
    final what = switch (container) {
      Map<String, Object?>() => "$parentName has no '$segment'",
      List<Object?>() => '$parentName is a list; reach an item by index, such as $parent.0.$segment',
      _ => "$parentName is ${_jsonKindOf(container)}, so it has no '$segment'",
    };
    final message = switch (root) {
      'state' when i == 0 => "'$path' reads '$segment', which the screen does not declare in state.",
      'params' when i == 0 =>
        "'$path' reads '$segment', which is neither in the screen's params nor a :param of its route.",
      'query' when i == 0 => "'$path' reads '$segment', which the screen's query does not declare.",
      'data' => "'$path' does not resolve against the default fixture: $what.",
      _ => "'$path' does not resolve: $what.",
    };
    final fallback = switch (root) {
      'data' => "Add '$segment' to fixtures.default (the data contract), or fix the path.",
      'state' => "Declare '$segment' under state with an initial value.",
      'params' => "Declare '$segment' under params with a sample.",
      'query' => "Declare '$segment' under query.",
      _ => null,
    };
    report(
      'E-bind-path',
      message,
      pointer,
      node: node,
      hint: didYouMean(segment, keys, show: (k) => '$parent.$k') ?? fallback,
      allowed: shortList(keys),
    );
  }

  // ------------------------------------------------------------------ nodes

  void walk(NodeDoc node, _Scope outer, List<_Anc> ancestors) {
    final p = node.pointer;
    final ref = '${screen.id}#${node.id}';
    final raw = rawNode(node);
    final comp = v.component(node.componentType);
    checkType(node, comp, ref);

    var scope = outer;
    final repeat = raw['repeat'];
    if (node.repeat != null && repeat is Map<String, Object?>) {
      checkValue(repeat['over'], '$p/repeat/over', outer, ref);
      final over = _sample(repeat['over'], outer);
      final element = over is List<Object?> && over.isNotEmpty ? over.first : _unknown;
      scope = scope.add(node.repeat!.as, element, 'the first item of ${_exprText(repeat['over'])}');
      if (node.repeat!.index case final index?) scope = scope.add(index, _unknown, 'the item index');
      if (repeat.containsKey('key')) checkValue(repeat['key'], '$p/repeat/key', scope, ref);
    }
    if (raw.containsKey('when')) checkValue(raw['when'], '$p/when', scope, ref);
    checkProps(node, comp, raw, scope, ref);
    if (comp != null) checkSlots(node, comp, raw, ref);
    checkEvents(node, comp, raw, scope, ref);
    if (comp != null) nodeRules(node, comp, raw, ancestors, ref);

    for (final MapEntry(key: slot, value: children) in node.slots.entries) {
      var childScope = scope;
      if (comp?.slot(slot)?.template case final t?) {
        final (value, label) = templateValue(node, comp!, t, raw, scope, ancestors);
        childScope = childScope.add(t, value, label);
      }
      for (var i = 0; i < children.length; i++) {
        walk(children[i], childScope, [...ancestors, _Anc(node, comp, scope, slot, i, children.length)]);
      }
    }
  }

  /// The value a template slot's variable takes: the owner's prop of the same
  /// name (CrudView's `items`), or the first item of the nearest list prop
  /// (a column's `row` is an item of the table's `rows`). Unknown otherwise.
  (Object?, String) templateValue(
    NodeDoc owner,
    DesignComponent comp,
    String name,
    Map<String, Object?> raw,
    _Scope scope,
    List<_Anc> ancestors,
  ) {
    final unknown = (_unknown as Object?, "the '$name' of #${owner.id}");
    if (comp.prop(name) != null) {
      final props = raw['props'];
      if (props is Map<String, Object?> && props.containsKey(name)) {
        return (_sample(props[name], scope), "the $name of #${owner.id}");
      }
      return unknown;
    }
    final chain = [
      (owner, comp as DesignComponent?, scope),
      for (final a in ancestors.reversed) (a.node, a.comp, a.scope),
    ];
    for (final (node, c, nodeScope) in chain) {
      if (c == null) continue;
      final props = rawNode(node)['props'];
      if (props is! Map<String, Object?>) continue;
      for (final prop in c.props) {
        if ((prop.kind == PropKind.rows || prop.name == '${name}s') && props.containsKey(prop.name)) {
          final list = _sample(props[prop.name], nodeScope);
          return (
            list is List<Object?> && list.isNotEmpty ? list.first : _unknown,
            'the first item of #${node.id}.${prop.name}',
          );
        }
      }
    }
    return unknown;
  }

  void checkType(NodeDoc node, DesignComponent? comp, String ref) {
    final at = '${node.pointer}/type';
    if (brokenAt(at)) return;
    if (comp == null) {
      report(
        'E-component-unknown',
        "There is no component '${node.componentType}' in the catalog.",
        at,
        node: ref,
        hint:
            didYouMean(node.componentType, catalog.components.keys) ??
            'Search with design catalog <words>; if nothing fits, design request "<what you need>".',
      );
      return;
    }
    final names = [if (comp.hasDefaultConstructor) comp.type, for (final c in comp.constructors) '${comp.type}.$c'];
    final ctor = node.constructor;
    if (ctor != null && !comp.constructors.contains(ctor)) {
      report(
        'E-ctor-unknown',
        "${comp.type} has no named constructor '$ctor'.",
        at,
        node: ref,
        hint:
            didYouMean(ctor, comp.constructors, show: (c) => '${comp.type}.$c') ??
            (comp.hasDefaultConstructor ? "Write '${comp.type}' for the unnamed constructor." : null),
        allowed: shortList(names),
      );
    } else if (ctor == null && !comp.hasDefaultConstructor) {
      report(
        'E-ctor-unknown',
        '${comp.type} has no unnamed constructor; pick a named one.',
        at,
        node: ref,
        hint: comp.constructors.isEmpty ? null : "Write '${comp.type}.${comp.constructors.first}'.",
        allowed: shortList(names),
      );
    }
  }

  // ------------------------------------------------------------------ props

  void checkProps(NodeDoc node, DesignComponent? comp, Map<String, Object?> raw, _Scope scope, String ref) {
    final p = node.pointer;
    final props = raw['props'];
    if (props is Map<String, Object?>) {
      for (final MapEntry(:key, :value) in props.entries) {
        final pp = '$p/props/${pointerSegment(key)}';
        checkValue(value, pp, scope, ref);
        if (comp == null) continue;
        final def = comp.prop(key);
        if (def == null) {
          final names = comp.props.map((d) => d.name);
          report(
            'E-prop-unknown',
            "${comp.type} has no prop '$key'.",
            pp,
            node: ref,
            hint: didYouMean(key, names) ?? (comp.slot(key) != null ? "'$key' is a slot: write it under slots." : null),
            allowed: shortList(names),
          );
        } else if (!brokenAt(pp)) {
          propValue(def, value, pp, ref, comp.type);
        }
      }
    }
    if (comp == null || (raw.containsKey('props') && props is! Map<String, Object?>)) return;
    for (final def in comp.props.where((d) => d.required)) {
      if (props is Map<String, Object?> && props.containsKey(def.name)) continue;
      report(
        'E-prop-required',
        "${comp.type} needs prop '${def.name}' (${propKindText(def)}).",
        props is Map<String, Object?> ? '$p/props' : p,
        node: ref,
        hint: 'Add "${def.name}": ${exampleValue(def)}.',
      );
    }
  }

  /// A plausible value of [def], for hints.
  String exampleValue(DesignProp def) => switch (def.kind) {
    PropKind.string || PropKind.image => '"..."',
    PropKind.boolean => 'true',
    PropKind.integer || PropKind.number => '1',
    PropKind.choice => def.values.isEmpty ? '"..."' : '"${def.values.first}"',
    PropKind.icon => catalog.icons.isEmpty ? '"..."' : '"${catalog.icons.first}"',
    PropKind.style => switch (def.families.isEmpty ? null : catalog.presets[def.families.first]) {
      final f? => '"${f.name}.${f.defaultVariant ?? f.variants.first}"',
      null => '"Family.variant"',
    },
    PropKind.token => '"${v.tokensOfType(def.tokenType).firstOrNull ?? 'tokenKey'}"',
    PropKind.date => '"2026-11-25"',
    PropKind.path => '"id"',
    PropKind.rows => r'{"$bind": "data.items"}',
    PropKind.stringList => '["..."]',
    PropKind.integerList => '[1]',
    PropKind.json => 'null',
  };

  /// The values an expression may give, as far as they show without data:
  /// literals of its branches, text from `$text`, booleans from tests.
  Iterable<(String, Object?, String)> staticResults(Object? raw, String p) sync* {
    if (!isExpressionJson(raw)) {
      yield containsExpression(raw) ? ('any', null, p) : ('literal', raw, p);
      return;
    }
    final map = raw! as Map<String, Object?>;
    final op = map.keys.single;
    final arg = map[op];
    final at = '$p/${pointerSegment(op)}';
    if (op == r'$text') {
      yield ('text', null, at);
    } else if (_boolOps.contains(op)) {
      yield ('bool', null, at);
    } else if (op == r'$if' && arg is List<Object?> && arg.length == 3) {
      yield* staticResults(arg[1], '$at/1');
      yield* staticResults(arg[2], '$at/2');
    } else if (op == r'$match' && arg is List<Object?> && arg.length >= 2 && arg[1] is Map<String, Object?>) {
      for (final MapEntry(:key, :value) in (arg[1]! as Map<String, Object?>).entries) {
        yield* staticResults(value, '$at/1/${pointerSegment(key)}');
      }
      if (arg.length == 3) yield* staticResults(arg[2], '$at/2');
    } else {
      yield ('any', null, at);
    }
  }

  void propValue(DesignProp def, Object? raw, String pp, String ref, String owner) {
    final what = 'props.${def.name} of $owner';
    final hasExpr = containsExpression(raw);
    if (hasExpr && !def.bindable) {
      report(
        'E-prop-bind',
        '$what is fixed when the screen loads; write a literal, not an expression.',
        pp,
        node: ref,
        hint: def.kind == PropKind.choice && def.values.isNotEmpty ? 'Write one of ${def.values.join(', ')}.' : null,
        allowed: def.kind == PropKind.choice ? shortList(def.values) : null,
      );
      return;
    }
    if (isExpressionJson(raw)) {
      for (final (kind, value, at) in staticResults(raw, pp)) {
        switch (kind) {
          case 'literal':
            literal(def, value, at, ref, owner);
          case 'text'
              when const {
                PropKind.boolean,
                PropKind.integer,
                PropKind.number,
                PropKind.rows,
                PropKind.stringList,
                PropKind.integerList,
              }.contains(def.kind):
            report('E-prop-kind', '$what takes ${propKindText(def)}, but \$text gives text.', at, node: ref);
          case 'bool' when def.kind != PropKind.boolean && def.kind != PropKind.json:
            report(
              'E-prop-kind',
              '$what takes ${propKindText(def)}, but this test gives true or false.',
              at,
              node: ref,
              hint: def.kind == PropKind.string ? r'Use $if to choose text: {"$if": [test, "yes", "no"]}.' : null,
            );
        }
      }
      return;
    }
    if (hasExpr) {
      switch (def.kind) {
        case PropKind.rows || PropKind.stringList || PropKind.integerList:
          if (raw is! List<Object?>) {
            report('E-prop-kind', '$what takes ${propKindText(def)}, not ${_show(raw)}.', pp, node: ref);
          }
        case PropKind.style:
          styleRef(def, raw, pp, ref, owner);
        case PropKind.json:
          break;
        default:
          report('E-prop-kind', '$what takes ${propKindText(def)}, not ${_show(raw)}.', pp, node: ref);
      }
      return;
    }
    literal(def, raw, pp, ref, owner);
  }

  void literal(DesignProp def, Object? value, String at, String ref, String owner) {
    if (value == null) return;
    final what = 'props.${def.name} of $owner';
    void wrong({String? hint}) =>
        report('E-prop-kind', '$what takes ${propKindText(def)}, not ${_show(value)}.', at, node: ref, hint: hint);
    bool whole(Object? x) => x is num && x == x.roundToDouble();
    switch (def.kind) {
      case PropKind.string:
        if (value is! String) wrong(hint: value is num || value is bool ? 'Write "$value" in quotes.' : null);
      case PropKind.boolean:
        if (value is! bool) {
          wrong(hint: value == 'true' || value == 'false' ? 'Write $value without quotes.' : null);
        }
      case PropKind.integer:
        if (!whole(value)) {
          wrong(hint: value is String && num.tryParse(value) != null ? 'Write it without quotes.' : null);
        }
      case PropKind.number:
        if (value is! num) {
          wrong(hint: value is String && num.tryParse(value) != null ? 'Write it without quotes.' : null);
        }
      case PropKind.choice:
        if (value is! String || (def.values.isNotEmpty && !def.values.contains(value))) {
          report(
            'E-prop-kind',
            '$what is one of the allowed names, not ${_show(value)}.',
            at,
            node: ref,
            hint: value is String ? didYouMean(value, def.values) : null,
            allowed: shortList(def.values),
          );
        }
      case PropKind.icon:
        if (value is! String) {
          wrong();
        } else if (catalog.icons.isNotEmpty && !catalog.icons.contains(value)) {
          report(
            'E-icon-unknown',
            "There is no icon '$value'.",
            at,
            node: ref,
            hint: didYouMean(value, catalog.icons) ?? 'Search icons with design catalog <word> --kind icon.',
            allowed: shortList(catalog.icons),
          );
        }
      case PropKind.style:
        styleRef(def, value, at, ref, owner);
      case PropKind.token:
        tokenRef(def, value, at, ref, owner);
      case PropKind.image:
        if (value is! String) wrong();
      case PropKind.date:
        if (value is! String || DateTime.tryParse(value) == null) {
          wrong(hint: 'Write "2026-11-25" or "2026-11-25T09:00:00Z".');
        }
      case PropKind.path:
        if (value is! String || !_rowPath.hasMatch(value)) {
          wrong(hint: 'Write a dotted path inside a row, such as "id".');
        }
      case PropKind.rows:
        if (value is! List<Object?>) wrong(hint: r'Bind it to a list: {"$bind": "data.items"}.');
      case PropKind.stringList:
        if (value is! List<Object?> || value.any((x) => x is! String)) wrong();
      case PropKind.integerList:
        if (value is! List<Object?> || value.any((x) => !whole(x))) wrong();
      case PropKind.json:
        break;
    }
  }

  void tokenRef(DesignProp def, Object? value, String at, String ref, String owner) {
    final what = 'props.${def.name} of $owner';
    final type = def.tokenType;
    final ofType = v.tokensOfType(type).toList();
    if (value is num) {
      final near = _StyleCheck(v, file).nearestTokenFor(value, type ?? 'double');
      report(
        'E-prop-kind',
        '$what takes ${propKindText(def)}, not the raw number $value.',
        at,
        node: ref,
        hint: near != null ? "Use the token '$near', whose light value is $value." : 'Use a token key.',
        allowed: shortList(ofType),
      );
      return;
    }
    if (value is! String) {
      report('E-prop-kind', '$what takes ${propKindText(def)}, not ${_show(value)}.', at, node: ref);
      return;
    }
    final actual = v.tokens[value];
    if (actual == null) {
      report(
        'E-token-unknown',
        "There is no token '$value'.",
        at,
        node: ref,
        hint: didYouMean(value, ofType) ?? didYouMean(value, v.tokens.keys),
        allowed: shortList(ofType),
      );
      return;
    }
    v.usedTokens.add(value);
    if (type != null && actual != type) {
      report(
        'E-prop-kind',
        "'$value' is a $actual token; $what takes a $type token.",
        at,
        node: ref,
        hint: didYouMean(value, ofType),
        allowed: shortList(ofType),
      );
    }
  }

  /// Every preset id of [family]: built-in variants and designer presets.
  List<String> presetIds(String family) => [
    for (final variant in catalog.presets[family]?.variants ?? const <String>[]) '$family.$variant',
    for (final p in v.presets.values)
      if (p.family == family) p.id,
  ];

  void styleRef(DesignProp def, Object? value, String at, String ref, String owner) {
    final what = 'props.${def.name} of $owner';
    String id;
    var idAt = at;
    Object? args;
    if (value is String) {
      id = value;
    } else if (value is Map<String, Object?>) {
      for (final key in value.keys.where((k) => k != 'preset' && k != 'args')) {
        report(
          'E-prop-kind',
          "A style reference has 'preset' and 'args', not '$key'.",
          '$at/${pointerSegment(key)}',
          node: ref,
          hint: didYouMean(key, const ['preset', 'args']),
          allowed: const ['preset', 'args'],
        );
      }
      final preset = value['preset'];
      if (preset is! String) {
        report(
          'E-prop-kind',
          '$what needs "preset": "Family.variant" in its object form.',
          at,
          node: ref,
          hint: 'Write {"preset": ${exampleValue(def)}, "args": {...}}.',
        );
        return;
      }
      id = preset;
      idAt = '$at/preset';
      args = value['args'];
    } else {
      report(
        'E-prop-kind',
        '$what takes ${propKindText(def)}, not ${_show(value)}.',
        at,
        node: ref,
        hint: 'Write ${exampleValue(def)}.',
      );
      return;
    }
    final families = def.families;
    final searched = families.isEmpty ? catalog.presets.keys.toList() : families;
    final split = Catalog.splitPreset(id);
    if (split == null) {
      final guesses = [
        for (final f in searched)
          if (catalog.presets[f]?.variants.contains(id) ?? false) '$f.$id',
      ];
      report(
        'E-prop-kind',
        "$what takes a preset id written Family.variant, not '$id'.",
        idAt,
        node: ref,
        hint: guesses.isEmpty ? 'Write ${exampleValue(def)}.' : "Did you mean '${guesses.first}'?",
        allowed: families.length == 1 ? shortList(presetIds(families.single)) : null,
      );
      return;
    }
    final (family, variant) = split;
    if ((families.isNotEmpty && !families.contains(family)) || catalog.presets[family] == null) {
      final guesses = [
        for (final f in searched)
          if (presetIds(f).contains('$f.$variant')) '$f.$variant',
      ];
      report(
        'E-style-family',
        families.isNotEmpty && !families.contains(family)
            ? '$what takes a preset of ${families.join(' or ')}, not of $family.'
            : "There is no preset family '$family'.",
        idAt,
        node: ref,
        hint: guesses.isNotEmpty
            ? "Did you mean '${guesses.first}'?"
            : didYouMean(family, searched, show: (f) => '$f.$variant'),
        allowed: shortList(searched),
      );
      return;
    }
    final ids = presetIds(family);
    if (!ids.contains(id)) {
      report(
        'E-prop-kind',
        "$family has no variant '$variant'.",
        idAt,
        node: ref,
        hint: didYouMean(id, ids) ?? 'Add one with design new preset $id --extends <a $family variant>.',
        allowed: shortList(ids),
      );
      return;
    }
    if (v.presets.containsKey(id)) v.usedPresets.add(id);
    if (args == null) return;
    final familyArgs = catalog.presets[family]!.args;
    if (args is! Map<String, Object?>) {
      report('E-prop-kind', 'A style reference\'s args is an object of $family args.', '$at/args', node: ref);
      return;
    }
    for (final MapEntry(:key, value: argValue) in args.entries) {
      final argAt = '$at/args/${pointerSegment(key)}';
      final argDef = familyArgs.where((a) => a.name == key).firstOrNull;
      if (argDef == null) {
        final names = familyArgs.map((a) => a.name);
        report(
          'E-prop-unknown',
          "$family takes no arg '$key'.",
          argAt,
          node: ref,
          hint: didYouMean(key, names) ?? (names.isEmpty ? '$family takes no args; write the preset id alone.' : null),
          allowed: shortList(names),
        );
      } else if (!containsExpression(argValue)) {
        literal(argDef, argValue, argAt, ref, family);
      }
    }
  }

  // ------------------------------------------------------------------ slots

  String slotPointer(NodeDoc node, Map<String, Object?> raw, String name) =>
      name == 'children' && raw.containsKey('children')
      ? '${node.pointer}/children'
      : '${node.pointer}/slots/${pointerSegment(name)}';

  List<Object?>? rawSlot(Map<String, Object?> raw, String name) {
    final list = name == 'children' && raw.containsKey('children')
        ? raw['children']
        : switch (raw['slots']) {
            final Map<String, Object?> slots => slots[name],
            _ => null,
          };
    return list is List<Object?> ? list : null;
  }

  void checkSlots(NodeDoc node, DesignComponent comp, Map<String, Object?> raw, String ref) {
    final names = comp.slots.map((s) => s.name);
    for (final MapEntry(key: name, value: children) in node.slots.entries) {
      final sp = slotPointer(node, raw, name);
      final def = comp.slot(name);
      if (def == null) {
        report(
          'E-slot-unknown',
          "${comp.type} has no slot '$name'.",
          sp,
          node: ref,
          hint:
              didYouMean(name, names) ??
              (comp.prop(name) != null
                  ? "'$name' is a prop: write it under props."
                  : comp.slots.isEmpty
                  ? '${comp.type} takes no child nodes.'
                  : null),
          allowed: shortList(names),
        );
        continue;
      }
      for (final child in children) {
        final cc = v.component(child.componentType);
        if (cc == null || slotAccepts(def, cc)) continue;
        final takesValues = def.accepts.any((a) => catalog.components[a]?.kind == DesignKind.value);
        report(
          'E-slot-accepts',
          "Slot '$name' of ${comp.type} takes ${slotAcceptsText(def)}; ${cc.type} is "
              "${cc.kind == DesignKind.value
                  ? 'a value component'
                  : takesValues
                  ? 'a widget'
                  : 'not one of them'}.",
          '${child.pointer}/type',
          node: '${screen.id}#${child.id}',
          hint: def.accepts.length == 1 && def.accepts.single != 'widget'
              ? 'Use a ${def.accepts.single} node here.'
              : didYouMean(cc.type, def.accepts),
          allowed: shortList(def.accepts),
        );
      }
      if (!def.many && children.length > 1) {
        final unconditional = children.where((c) => c.when == null).length;
        if (unconditional > 1) {
          report(
            'W-slot-single',
            "Slot '$name' of ${comp.type} draws one node, the first whose when passes; $unconditional of its "
                'nodes have no when, so only the first of them can show.',
            sp,
            node: ref,
            hint: 'Give every node but the last a when, or keep one node.',
          );
        }
      }
    }
    for (final def in comp.slots.where((s) => s.required)) {
      final list = rawSlot(raw, def.name);
      if (list != null && list.isNotEmpty) continue;
      final sp = slotPointer(node, raw, def.name);
      if (brokenAt(sp)) continue;
      report(
        'E-slot-required',
        "${comp.type} needs slot '${def.name}' (${slotAcceptsText(def)}).",
        list == null ? node.pointer : sp,
        node: ref,
        hint: def.name == 'children'
            ? 'Add "children": [ ... ].'
            : 'Add "slots": {"${def.name}": [ ... ]} with ${def.many ? '' : 'one of '}${slotAcceptsText(def)}.',
      );
    }
  }

  // ----------------------------------------------------------------- events

  void checkEvents(NodeDoc node, DesignComponent? comp, Map<String, Object?> raw, _Scope scope, String ref) {
    final eventScope = scope.add('event', _unknown, 'the event');
    for (final MapEntry(key: name, value: actions) in node.on.entries) {
      final ep = '${node.pointer}/on/${pointerSegment(name)}';
      if (comp != null && comp.event(name) == null) {
        final names = comp.events.map((e) => e.name);
        report(
          'E-event-unknown',
          "${comp.type} has no event '$name'.",
          ep,
          node: ref,
          hint: didYouMean(name, names) ?? (names.isEmpty ? '${comp.type} has no events.' : null),
          allowed: shortList(names),
        );
      }
      checkActions(actions, eventScope, ref);
    }
    final primary = comp?.primaryEvent;
    if (comp == null || primary == null || node.on.containsKey(primary.name)) return;
    final props = raw['props'];
    final disabled = props is Map<String, Object?> && (props['disabled'] == true || props['enabled'] == false);
    if (disabled) return;
    report(
      'W-unbound-primary',
      "${node.type} #${node.id} has no action for its primary event '${primary.name}'; export refuses it.",
      node.pointer,
      node: ref,
      hint: 'Add "on": {"${primary.name}": [ ... ]}, or set "disabled": true.',
    );
  }

  // ---------------------------------------------------------------- actions

  void checkActions(List<ActionDoc> actions, _Scope scope, String ref) {
    for (final a in flattenActions(actions)) {
      final raw = switch (jsonAt(json, a.pointer)) {
        final Map<String, Object?> m => m,
        _ => const <String, Object?>{},
      };
      for (final MapEntry(:key, :value) in raw.entries) {
        if (!_structuralActionKeys.contains(key)) {
          checkValue(value, '${a.pointer}/${pointerSegment(key)}', scope, ref);
        }
      }
      switch (a) {
        case NavigateAction():
          final t = target(a.to, '${a.pointer}/to', ref);
          if (t != null && pageTarget(t, a.kind, '${a.pointer}/to', ref)) routeParams(t, a.params, raw, a, ref);
          if (screen.kind == ScreenKind.frame && a.mode != NavigateMode.replaceAll) {
            report(
              'W-frame-nav-mode',
              'A navigate in frame ${screen.id} changes section, so it uses mode replaceAll, not ${a.mode.name}.',
              raw.containsKey('mode') ? '${a.pointer}/mode' : a.pointer,
              node: ref,
              hint: 'Set "mode": "replaceAll".',
            );
          }
        case BackAction():
          final t = target(a.fallback, '${a.pointer}/fallback', ref);
          if (t != null && pageTarget(t, a.kind, '${a.pointer}/fallback', ref)) routeParams(t, a.params, raw, a, ref);
        case BackToAction():
          final t = target(a.to, '${a.pointer}/to', ref);
          if (t != null && pageTarget(t, a.kind, '${a.pointer}/to', ref)) {
            routeParams(t, a.params, raw, a, ref);
            final here = screen.route;
            final there = t.route;
            if (screen.kind == ScreenKind.page && here != null && there != null && !isRoutePrefix(there, here)) {
              report(
                'W-backto-not-ancestor',
                'backTo ${t.id} ($there) is not an ancestor of ${screen.id} ($here); backTo returns to a page above this one.',
                '${a.pointer}/to',
                node: ref,
                hint: 'Use navigate with mode replaceAll to change section, or back with a fallback.',
              );
            }
          }
        case SetQueryAction():
          final set = raw['set'];
          if (set is Map<String, Object?>) {
            for (final key in set.keys.where((k) => !screen.query.containsKey(k))) {
              report(
                'W-query-undeclared',
                "setQuery sets '$key', which ${screen.id}'s query does not declare.",
                '${a.pointer}/set/${pointerSegment(key)}',
                node: ref,
                hint: didYouMean(key, screen.query.keys) ?? "Declare '$key' under query.",
                allowed: shortList(screen.query.keys),
              );
            }
          }
        case OpenModalAction():
          final t = target(a.screen, '${a.pointer}/screen', ref);
          if (t != null && t.kind != ScreenKind.modal) {
            report(
              'E-modal-target',
              'openModal opens a modal; ${t.id} is a ${t.kind.name}.',
              '${a.pointer}/screen',
              node: ref,
              hint: t.kind == ScreenKind.page ? 'Go to a page with {"do": "navigate", "to": "${t.id}"}.' : null,
            );
          }
        case CloseModalAction():
          if (screen.kind != ScreenKind.modal) {
            report(
              'E-modal-target',
              'closeModal closes the modal it runs in; ${screen.id} is a ${screen.kind.name}.',
              a.pointer,
              node: ref,
              hint: 'Use back, or navigate to another page.',
            );
          }
        case EmitAction():
          emit(a, raw, ref);
        case SetStateAction():
          final set = raw['set'];
          if (set is Map<String, Object?>) {
            for (final key in set.keys.where((k) => !screen.state.containsKey(k))) {
              report(
                'E-bind-path',
                "setState sets '$key', which the screen does not declare in state.",
                '${a.pointer}/set/${pointerSegment(key)}',
                node: ref,
                hint: didYouMean(key, screen.state.keys) ?? "Declare '$key' under state with an initial value.",
                allowed: shortList(screen.state.keys),
              );
            }
          }
        case ConfirmAction() || ToastAction():
          break;
      }
    }
  }

  ScreenDoc? target(String id, String pointer, String ref) {
    if (id.isEmpty || brokenAt(pointer)) return null;
    final t = v.screens[id]?.doc;
    if (t != null) return t;
    report(
      'E-screen-unknown',
      "There is no screen '$id'.",
      pointer,
      node: ref,
      hint: didYouMean(id, v.screens.keys) ?? 'Create it with design new screen $id --from <template>.',
    );
    return null;
  }

  /// Reports a navigate, back or backTo whose target is not a page.
  bool pageTarget(ScreenDoc t, String kind, String pointer, String ref) {
    if (t.kind == ScreenKind.page) return true;
    report(
      'E-modal-target',
      t.kind == ScreenKind.modal
          ? '$kind goes to a page; ${t.id} is a modal.'
          : '$kind goes to a page; ${t.id} is a frame, which only wraps pages.',
      pointer,
      node: ref,
      hint: t.kind == ScreenKind.modal
          ? 'Open it with {"do": "openModal", "screen": "${t.id}"}.'
          : 'Go to a page that names this frame.',
    );
    return false;
  }

  void routeParams(ScreenDoc t, Map<String, Expr> params, Map<String, Object?> raw, ActionDoc a, String ref) {
    final missing = t.routeParams.where((k) => !params.containsKey(k)).toList();
    if (missing.isEmpty) return;
    report(
      'E-param-missing',
      "${t.id}'s route ${t.route} needs ${missing.map((k) => 'params.$k').join(', ')}, which this ${a.kind} does not supply.",
      raw.containsKey('params') ? '${a.pointer}/params' : a.pointer,
      node: ref,
      hint: 'Add "params": {${missing.map((k) => '"$k": {"\$bind": "..."}').join(', ')}}.',
      allowed: shortList(t.routeParams),
    );
  }

  void emit(EmitAction a, Map<String, Object?> raw, String ref) {
    if (a.name.isEmpty || brokenAt('${a.pointer}/name')) return;
    final decl = screen.emits[a.name];
    if (decl == null) {
      report(
        'E-emit-undeclared',
        "Emit '${a.name}' is not declared in ${screen.id}'s emits"
            "${screen.kind == ScreenKind.modal ? ' (a modal declares its own emits)' : ''}.",
        '${a.pointer}/name',
        node: ref,
        hint:
            didYouMean(a.name, screen.emits.keys) ??
            'Declare it: "emits": {"${a.name}": {"description": "...", "payload": { ... }}}.',
        allowed: shortList(screen.emits.keys),
      );
      return;
    }
    final payload = raw['payload'];
    final given = payload is Map<String, Object?> ? payload.keys.toSet() : <String>{};
    final declared = decl.payload.keys.toSet();
    final missing = declared.difference(given);
    for (final extra in given.difference(declared)) {
      report(
        'E-emit-undeclared',
        "Emit '${a.name}' sends '$extra', which its declaration's payload does not list.",
        '${a.pointer}/payload/${pointerSegment(extra)}',
        node: ref,
        hint: didYouMean(extra, missing) ?? "Add '$extra' to emits.${a.name}.payload, or remove it here.",
        allowed: shortList(declared),
      );
    }
    if (missing.isNotEmpty) {
      report(
        'E-emit-undeclared',
        "Emit '${a.name}' does not send ${missing.join(', ')}, which its declaration's payload lists.",
        payload is Map<String, Object?> ? '${a.pointer}/payload' : a.pointer,
        node: ref,
        hint: 'Add ${missing.map((k) => '"$k"').join(', ')} to the payload.',
        allowed: shortList(declared),
      );
    }
  }

  // ------------------------------------------------------------------ rules

  void ruleReport(DesignRule rule, String fallback, String pointer, {String? node, String? hint}) =>
      report(rule.code, rule.message ?? fallback, pointer, node: node, hint: hint, allowed: shortList(rule.types));

  /// The props of [rule] that [node] does not set to the expected value.
  List<String> mismatched(NodeDoc node, DesignComponent? comp, Map<String, Object?> expected) {
    final props = rawNode(node)['props'];
    return [
      for (final MapEntry(:key, :value) in expected.entries)
        if (!jsonEquals(
          props is Map<String, Object?> && props.containsKey(key) ? props[key] : comp?.prop(key)?.defaultValue,
          value,
        ))
          key,
    ];
  }

  String propsText(Map<String, Object?> props) =>
      props.entries.map((e) => '${e.key}: ${e.value is String ? '"${e.value}"' : e.value}').join(', ');

  void propRule(DesignRule rule, NodeDoc node, DesignComponent? comp, String fallback) {
    for (final key in mismatched(node, comp, rule.props)) {
      final props = rawNode(node)['props'];
      ruleReport(
        rule,
        fallback,
        props is Map<String, Object?> && props.containsKey(key)
            ? '${node.pointer}/props/${pointerSegment(key)}'
            : node.pointer,
        node: '${screen.id}#${node.id}',
        hint: 'Set "$key": ${rule.props[key] is String ? '"${rule.props[key]}"' : rule.props[key]}.',
      );
    }
  }

  void nodeRules(NodeDoc node, DesignComponent comp, Map<String, Object?> raw, List<_Anc> ancestors, String ref) {
    for (final rule in comp.rules) {
      switch (rule.rule) {
        case 'notInside':
          final hit = ancestors.lastWhere((a) => _typeIn(a.node, rule.types), orElse: () => _noAnc);
          if (!identical(hit, _noAnc)) {
            ruleReport(
              rule,
              '${comp.type} must not sit inside ${hit.node.componentType} (#${hit.node.id}).',
              node.pointer,
              node: ref,
              hint: 'Move #${node.id} out of #${hit.node.id}.',
            );
          }
        case 'onlyInside':
          if (!ancestors.any((a) => _typeIn(a.node, rule.types))) {
            ruleReport(
              rule,
              '${comp.type} must sit inside ${rule.types.join(' or ')}.',
              node.pointer,
              node: ref,
              hint: 'Move #${node.id} into a ${rule.types.first}.',
            );
          }
        case 'lastColumnProps':
          final inLast = ancestors.any(
            (a) => _typeIn(a.node, rule.types) && a.slot == 'columns' && a.index == a.count - 1,
          );
          if (inLast) {
            propRule(
              rule,
              node,
              comp,
              'In the last column of ${rule.types.join(' or ')}, ${comp.type} sets ${propsText(rule.props)}.',
            );
          }
        case 'rootOf':
          if (!rule.types.contains(screen.kind.name)) {
            ruleReport(
              rule,
              '${comp.type} belongs only in ${rule.types.join(' or ')} screens; ${screen.id} is a ${screen.kind.name}.',
              node.pointer,
              node: ref,
              hint: 'Remove #${node.id}.',
            );
          }
      }
    }
  }

  void screenRules() {
    final seen = <String>{};
    final rules = [
      for (final r in [...catalog.rules, for (final c in catalog.components.values) ...c.rules])
        if (_screenRuleKinds.contains(r.rule) && seen.add('${r.rule}|${r.code}|${r.types}|${r.props}')) r,
    ];
    final root = screen.root;
    final rootComp = v.component(root.componentType);
    for (final rule in rules) {
      final kind = switch (rule.rule) {
        'pageRoot' || 'singleScroll' => ScreenKind.page,
        'modalRoot' => ScreenKind.modal,
        _ => ScreenKind.frame,
      };
      if (screen.kind != kind) continue;
      final ref = '${screen.id}#${root.id}';
      if (rule.rule == 'singleScroll') {
        if (!_typeIn(root, rule.types)) continue;
        for (final node in root.descendantsAndSelf.skip(1).where((n) => _typeIn(n, rule.types))) {
          propRule(
            rule,
            node,
            v.component(node.componentType),
            'The page root is the only scroll; ${node.componentType} inside it sets ${propsText(rule.props)}.',
          );
        }
        continue;
      }
      if (!_typeIn(root, rule.types)) {
        ruleReport(
          rule,
          "A ${kind.name}'s root is ${rule.types.join(' or ')}; ${screen.id}'s root is ${root.type}.",
          '${root.pointer}/type',
          node: ref,
          hint: 'Make the root a ${rule.types.first}${rule.props.isEmpty ? '' : ' with ${propsText(rule.props)}'}.',
        );
      } else if (rule.props.isNotEmpty) {
        propRule(rule, root, rootComp, "A ${kind.name}'s root sets ${propsText(rule.props)}.");
      }
    }
  }
}

const _noAnc = _Anc(NodeDoc(id: '', type: '', pointer: ''), null, _Scope({}, {}), '', -1, 0);

/// Whether route [ancestor] is a prefix of route [route], segment by
/// segment; a `:param` matches a `:param`.
bool isRoutePrefix(String ancestor, String route) {
  final a = ancestor.split('/').where((s) => s.isNotEmpty).toList();
  final b = route.split('/').where((s) => s.isNotEmpty).toList();
  if (a.length > b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] == b[i] || (a[i].startsWith(':') && b[i].startsWith(':'))) continue;
    return false;
  }
  return true;
}
