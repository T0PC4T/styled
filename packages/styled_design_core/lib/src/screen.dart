import 'package:meta/meta.dart';

import 'catalog.dart';
import 'diagnostics.dart';
import 'expressions.dart';
import 'merge_patch.dart';

/// A page has a route; a modal opens over a page; a frame is a shell with one
/// `DesignOutlet`, used by the studio to preview pages.
enum ScreenKind { page, modal, frame }

final _ident = RegExp(r'^[a-z][A-Za-z0-9]*$');
final _screenId = RegExp(r'^[a-z][A-Za-z0-9]*(\.[a-z][A-Za-z0-9]*)*$');
final _route = RegExp(r'^/([A-Za-z0-9_-]+|:[a-z][A-Za-z0-9]*)?(/([A-Za-z0-9_-]+|:[a-z][A-Za-z0-9]*))*$');
final _nodeType = RegExp(r'^[A-Z][A-Za-z0-9]*(\.[a-z][A-Za-z0-9]*)?$');

bool isIdent(String s) => _ident.hasMatch(s);
bool isScreenId(String s) => _screenId.hasMatch(s);

/// A route param, an open argument of a modal, or a query key the screen reads.
@immutable
final class ParamSpec {
  final String? sample;
  final String? description;

  /// For query keys: the values the key may take, when it is a fixed set.
  final List<String> values;

  const ParamSpec({this.sample, this.description, this.values = const []});
}

/// An event the screen hands to the app.
@immutable
final class EmitSpec {
  final String description;

  /// Payload field → `string`, `number`, `bool`, `list`, `object` or `any`.
  final Map<String, String> payload;

  /// `none`, `bool` or `any`.
  final String returns;

  /// What the studio returns in place of the app. Defaults to true.
  final Object? sample;
  final bool hasSample;

  const EmitSpec({
    required this.description,
    this.payload = const {},
    this.returns = 'none',
    this.sample,
    this.hasSample = false,
  });
}

/// `{"over": list, "as": "item", "index": "i", "key": expr}`.
@immutable
final class RepeatDoc {
  final Expr over;
  final String as;
  final String? index;
  final Expr? key;
  const RepeatDoc({required this.over, required this.as, this.index, this.key});
}

/// One node of a screen's tree.
@immutable
final class NodeDoc {
  final String id;

  /// As written: `OnboardingButton.primary`.
  final String type;

  final Map<String, Expr> props;

  /// Child nodes by slot. `children` at the top of a node lands here as
  /// `slots['children']`.
  final Map<String, List<NodeDoc>> slots;

  final Map<String, List<ActionDoc>> on;
  final Expr? when;
  final RepeatDoc? repeat;
  final String? note;

  /// JSON pointer of this node in its file.
  final String pointer;

  const NodeDoc({
    required this.id,
    required this.type,
    required this.pointer,
    this.props = const {},
    this.slots = const {},
    this.on = const {},
    this.when,
    this.repeat,
    this.note,
  });

  /// The component class: `OnboardingButton`.
  String get componentType => Catalog.splitType(type).$1;

  /// The named constructor, if any: `primary`.
  String? get constructor => Catalog.splitType(type).$2;

  /// This node and every node below it, depth first.
  Iterable<NodeDoc> get descendantsAndSelf sync* {
    yield this;
    for (final children in slots.values) {
      for (final child in children) {
        yield* child.descendantsAndSelf;
      }
    }
  }
}

/// One step of an event's action list.
@immutable
sealed class ActionDoc {
  /// JSON pointer of this action in its file.
  final String pointer;
  const ActionDoc(this.pointer);

  /// The `do` name.
  String get kind;

  /// Every expression in this action, nested `then` lists included.
  Iterable<Expr> get expressions;

  /// Nested action lists (`then`).
  List<ActionDoc> get nested => const [];
}

/// push = drill down, replaceAll = change section, replace = same slot
/// changes identity.
enum NavigateMode { push, replaceAll, replace }

final class NavigateAction extends ActionDoc {
  final String to;
  final NavigateMode mode;
  final Map<String, Expr> params;
  final Map<String, Expr> query;
  const NavigateAction(
    super.pointer, {
    required this.to,
    this.mode = NavigateMode.push,
    this.params = const {},
    this.query = const {},
  });

  @override
  String get kind => 'navigate';

  @override
  Iterable<Expr> get expressions => [...params.values, ...query.values];
}

final class BackAction extends ActionDoc {
  final String fallback;
  final Map<String, Expr> params;
  const BackAction(super.pointer, {required this.fallback, this.params = const {}});

  @override
  String get kind => 'back';

  @override
  Iterable<Expr> get expressions => params.values;
}

final class BackToAction extends ActionDoc {
  final String to;
  final Map<String, Expr> params;
  const BackToAction(super.pointer, {required this.to, this.params = const {}});

  @override
  String get kind => 'backTo';

  @override
  Iterable<Expr> get expressions => params.values;
}

final class SetQueryAction extends ActionDoc {
  final Map<String, Expr> set;
  final bool history;
  const SetQueryAction(super.pointer, {required this.set, this.history = false});

  @override
  String get kind => 'setQuery';

  @override
  Iterable<Expr> get expressions => set.values;
}

final class OpenModalAction extends ActionDoc {
  final String screen;
  final Map<String, Expr> params;
  final List<ActionDoc> then;
  const OpenModalAction(super.pointer, {required this.screen, this.params = const {}, this.then = const []});

  @override
  String get kind => 'openModal';

  @override
  Iterable<Expr> get expressions => [...params.values, ...then.expand((a) => a.expressions)];

  @override
  List<ActionDoc> get nested => then;
}

final class CloseModalAction extends ActionDoc {
  final Expr? result;
  const CloseModalAction(super.pointer, {this.result});

  @override
  String get kind => 'closeModal';

  @override
  Iterable<Expr> get expressions => [?result];
}

final class ConfirmAction extends ActionDoc {
  final Expr title;
  final Expr? message;
  final Expr? confirmLabel;
  final bool destructive;
  final List<ActionDoc> then;
  const ConfirmAction(
    super.pointer, {
    required this.title,
    required this.then,
    this.message,
    this.confirmLabel,
    this.destructive = false,
  });

  @override
  String get kind => 'confirm';

  @override
  Iterable<Expr> get expressions => [title, ?message, ?confirmLabel, ...then.expand((a) => a.expressions)];

  @override
  List<ActionDoc> get nested => then;
}

enum ToastTone { success, error, warning, info }

final class ToastAction extends ActionDoc {
  final Expr message;
  final ToastTone tone;
  const ToastAction(super.pointer, {required this.message, this.tone = ToastTone.success});

  @override
  String get kind => 'toast';

  @override
  Iterable<Expr> get expressions => [message];
}

final class SetStateAction extends ActionDoc {
  final Map<String, Expr> set;
  const SetStateAction(super.pointer, {required this.set});

  @override
  String get kind => 'setState';

  @override
  Iterable<Expr> get expressions => set.values;
}

final class EmitAction extends ActionDoc {
  final String name;
  final Map<String, Expr> payload;
  const EmitAction(super.pointer, {required this.name, this.payload = const {}});

  @override
  String get kind => 'emit';

  @override
  Iterable<Expr> get expressions => payload.values;
}

/// Every action in [actions], nested `then` lists included, depth first.
Iterable<ActionDoc> flattenActions(List<ActionDoc> actions) sync* {
  for (final action in actions) {
    yield action;
    yield* flattenActions(action.nested);
  }
}

/// A screen document: a tree of nodes, the data it expects, the events it
/// hands back, and sample data to draw it with.
@immutable
final class ScreenDoc {
  final String id;
  final ScreenKind kind;
  final String title;
  final String? description;
  final String? route;
  final String? frame;
  final Map<String, ParamSpec> params;
  final Map<String, ParamSpec> query;

  /// Initial value of each state key, evaluated once on mount.
  final Map<String, Expr> state;

  /// Raw fixtures. `default` is the data contract; every other fixture is a
  /// JSON merge patch over it.
  final Map<String, Map<String, Object?>> fixtures;
  final Map<String, EmitSpec> emits;
  final NodeDoc root;

  /// The document as read.
  final Map<String, Object?> json;

  const ScreenDoc({
    required this.id,
    required this.kind,
    required this.title,
    required this.root,
    required this.json,
    this.description,
    this.route,
    this.frame,
    this.params = const {},
    this.query = const {},
    this.state = const {},
    this.fixtures = const {},
    this.emits = const {},
  });

  /// The default fixture: what the app must supply.
  Map<String, Object?> get defaultFixture => fixtures['default'] ?? const {};

  /// The named fixture, merged over the default one.
  Map<String, Object?> fixture(String name) {
    if (name == 'default') return defaultFixture;
    final patch = fixtures[name];
    if (patch == null) throw DesignError("Screen '$id' has no fixture '$name'.");
    return mergePatch(defaultFixture, patch)! as Map<String, Object?>;
  }

  /// Every node, depth first from the root.
  Iterable<NodeDoc> get nodes => root.descendantsAndSelf;

  /// The node with [id], or null.
  NodeDoc? node(String id) => nodes.where((n) => n.id == id).firstOrNull;

  /// The `:name` segments of [route].
  List<String> get routeParams => [
    for (final segment in (route ?? '').split('/'))
      if (segment.startsWith(':')) segment.substring(1),
  ];

  /// [route] with [params] filled in and [query] appended. Throws a
  /// [DesignError] when a route param is missing.
  Uri locationFor({Map<String, String> params = const {}, Map<String, String?> query = const {}}) {
    final path = [
      for (final segment in (route ?? '/').split('/'))
        if (segment.startsWith(':'))
          Uri.encodeComponent(
            params[segment.substring(1)] ??
                (throw DesignError("Route '$route' of '$id' needs param '${segment.substring(1)}'.")),
          )
        else
          segment,
    ].join('/');
    final q = {
      for (final MapEntry(:key, :value) in query.entries)
        if (value != null && value.isNotEmpty) key: value,
    };
    return Uri(path: path.isEmpty ? '/' : path, queryParameters: q.isEmpty ? null : q);
  }

  /// Parses a screen document. Returns the screen, or null when its structure
  /// is too broken to use, and every structural problem found.
  ///
  /// With [partial], returns whatever screen could be built despite errors
  /// (bad values read as null, unusable nodes and actions left out), so the
  /// validator can check the rest of the document in the same run.
  static (ScreenDoc?, List<Diagnostic>) parse(Map<String, Object?> json, {String? file, bool partial = false}) {
    final p = _Parser(file);
    final doc = p.screen(json);
    return (!partial && p.problems.any((d) => d.isError) ? null : doc, p.problems);
  }

  /// Parses a screen document and throws a [DesignError] on any error.
  factory ScreenDoc.fromJson(Map<String, Object?> json, {String? file}) {
    final (doc, problems) = parse(json, file: file);
    if (doc == null) throw DesignError("Screen ${json['id'] ?? file ?? ''} does not parse.", problems);
    return doc;
  }
}

/// Structural parsing with pointers, following screen.schema.json.
final class _Parser {
  final String? file;
  final problems = <Diagnostic>[];
  String _screen = '?';

  _Parser(this.file);

  void _error(String pointer, String message, {String code = 'E-schema', String? node, String? hint}) =>
      problems.add(Diagnostic.of(code, message, file: file, pointer: pointer, node: node, hint: hint));

  T? _as<T>(Object? value, String pointer, String what) {
    if (value is T) return value;
    _error(pointer, '$what must be ${_jsonType<T>()}, not ${_describe(value)}.');
    return null;
  }

  Map<String, Object?> _map(Object? value, String pointer, String what) =>
      _as<Map<String, Object?>>(value, pointer, what) ?? const {};

  void _onlyKeys(Map<String, Object?> json, Set<String> allowed, String pointer, String what) {
    for (final key in json.keys) {
      if (!allowed.contains(key)) {
        _error(
          '$pointer/${pointerSegment(key)}',
          "$what has no field '$key'.",
          hint: switch (nearestName(key, allowed)) {
            final n? => "Did you mean '$n'?",
            null => 'Allowed: ${allowed.join(', ')}.',
          },
        );
      }
    }
  }

  Expr _expr(Object? json, String pointer) {
    try {
      return Expr.compile(json);
    } on ExpressionError catch (e) {
      _error('$pointer${e.pointer}', e.message);
      return const Literal(null);
    }
  }

  Map<String, Expr> _valueMap(Object? json, String pointer, String what) => {
    for (final MapEntry(:key, :value) in _map(json, pointer, what).entries)
      key: _identKey(key, '$pointer/${pointerSegment(key)}', what)
          ? _expr(value, '$pointer/${pointerSegment(key)}')
          : const Literal(null),
  };

  bool _identKey(String key, String pointer, String what) {
    if (isIdent(key)) return true;
    _error(pointer, "'$key' is not a valid name in $what. Use lower camel case: ^[a-z][A-Za-z0-9]*\$.");
    return false;
  }

  String? _screenRef(Object? value, String pointer, String what) {
    final s = _as<String>(value, pointer, what);
    if (s != null && !isScreenId(s)) {
      _error(pointer, "'$s' is not a screen id. Write dotted lower camel: admin.automations.");
    }
    return s;
  }

  ScreenDoc? screen(Map<String, Object?> json) {
    const allowed = {
      r'$schema', 'format', 'id', 'kind', 'title', 'description', 'route', 'frame', 'params', 'query', //
      'state', 'fixtures', 'emits', 'root',
    };
    _onlyKeys(json, allowed, '', 'A screen');
    for (final key in const ['format', 'id', 'kind', 'title', 'root']) {
      if (!json.containsKey(key)) _error('', "A screen needs '$key'.");
    }
    if (json.containsKey('format') && json['format'] != 1) _error('/format', 'format must be 1.');

    final id = _as<String>(json['id'], '/id', 'id') ?? '';
    if (id.isNotEmpty && !isScreenId(id)) {
      _error('/id', "'$id' is not a screen id. Write dotted lower camel: admin.automations.");
    }
    _screen = id;
    final kindName = _as<String>(json['kind'], '/kind', 'kind');
    final kind = ScreenKind.values.where((k) => k.name == kindName).firstOrNull;
    if (kindName != null && kind == null) _error('/kind', "kind must be page, modal or frame, not '$kindName'.");
    final title = _as<String>(json['title'], '/title', 'title') ?? '';

    final route = json.containsKey('route') ? _as<String>(json['route'], '/route', 'route') : null;
    if (route != null && !_route.hasMatch(route)) _error('/route', "'$route' is not a route. Write /segment/:param.");
    final frame = json.containsKey('frame') ? _screenRef(json['frame'], '/frame', 'frame') : null;
    if (kind == ScreenKind.page && route == null && !problems.any((d) => d.pointer == '/route')) {
      _error('', "A page needs a 'route'.");
    }
    if (kind != null && kind != ScreenKind.page && (json.containsKey('route') || json.containsKey('frame'))) {
      _error(json.containsKey('route') ? '/route' : '/frame', 'Only a page has a route or a frame.');
    }

    final params = _params(json['params'], '/params', sample: true);
    final query = _params(json['query'], '/query', sample: false);
    final state = json.containsKey('state') ? _valueMap(json['state'], '/state', 'state') : const <String, Expr>{};

    final fixtures = <String, Map<String, Object?>>{};
    if (json.containsKey('fixtures')) {
      final raw = _map(json['fixtures'], '/fixtures', 'fixtures');
      if (!raw.containsKey('default')) _error('/fixtures', "fixtures needs a 'default' fixture: the data contract.");
      for (final MapEntry(:key, :value) in raw.entries) {
        final at = '/fixtures/${pointerSegment(key)}';
        if (_identKey(key, at, 'fixtures')) fixtures[key] = _map(value, at, 'A fixture');
      }
    }

    final emits = <String, EmitSpec>{};
    if (json.containsKey('emits')) {
      for (final MapEntry(:key, :value) in _map(json['emits'], '/emits', 'emits').entries) {
        final at = '/emits/${pointerSegment(key)}';
        if (!_identKey(key, at, 'emits')) continue;
        final e = _map(value, at, 'An emit');
        _onlyKeys(e, const {'description', 'payload', 'returns', 'sample'}, at, 'An emit');
        final description = _as<String>(e['description'], '$at/description', 'description') ?? '';
        final payload = <String, String>{};
        for (final MapEntry(key: field, value: kindOf) in _map(
          e['payload'] ?? const <String, Object?>{},
          '$at/payload',
          'payload',
        ).entries) {
          final kindText = _as<String>(kindOf, '$at/payload/$field', 'A payload kind');
          if (kindText != null && !const {'string', 'number', 'bool', 'list', 'object', 'any'}.contains(kindText)) {
            _error('$at/payload/$field', 'A payload kind is string, number, bool, list, object or any.');
          }
          payload[field] = kindText ?? 'any';
        }
        final returns = e.containsKey('returns')
            ? _as<String>(e['returns'], '$at/returns', 'returns') ?? 'none'
            : 'none';
        if (!const {'none', 'bool', 'any'}.contains(returns)) _error('$at/returns', 'returns is none, bool or any.');
        emits[key] = EmitSpec(
          description: description,
          payload: payload,
          returns: returns,
          sample: e['sample'],
          hasSample: e.containsKey('sample'),
        );
      }
    }

    final rootJson = json['root'];
    final root = rootJson == null ? null : node(rootJson, '/root');
    if (root == null || kind == null) return null;
    return ScreenDoc(
      id: id,
      kind: kind,
      title: title,
      description: json['description'] as String?,
      route: route,
      frame: frame,
      params: params,
      query: query,
      state: state,
      fixtures: fixtures,
      emits: emits,
      root: root,
      json: json,
    );
  }

  Map<String, ParamSpec> _params(Object? json, String pointer, {required bool sample}) {
    if (json == null) return const {};
    return {
      for (final MapEntry(:key, :value) in _map(json, pointer, pointer.substring(1)).entries)
        if (_identKey(key, '$pointer/$key', pointer.substring(1))) key: _param(value, '$pointer/$key', sample: sample),
    };
  }

  ParamSpec _param(Object? json, String pointer, {required bool sample}) {
    final m = _map(json, pointer, 'A param');
    _onlyKeys(
      m,
      sample ? const {'sample', 'description'} : const {'sample', 'values', 'description'},
      pointer,
      'A param',
    );
    if (sample && !m.containsKey('sample')) _error(pointer, "A route param or modal argument needs a 'sample'.");
    return ParamSpec(
      sample: m.containsKey('sample') ? _as<String>(m['sample'], '$pointer/sample', 'sample') : null,
      description: m['description'] as String?,
      values: [for (final v in (m['values'] as List<Object?>?) ?? const []) '$v'],
    );
  }

  NodeDoc? node(Object? json, String pointer) {
    final m = _as<Map<String, Object?>>(json, pointer, 'A node');
    if (m == null) return null;
    _onlyKeys(m, const {'id', 'type', 'props', 'children', 'slots', 'on', 'when', 'repeat', 'note'}, pointer, 'A node');
    final id = _as<String>(m['id'], '$pointer/id', 'A node id');
    final type = _as<String>(m['type'], '$pointer/type', 'A node type');
    if (id != null && !isIdent(id)) _error('$pointer/id', "Node id '$id' must be lower camel: ^[a-z][A-Za-z0-9]*\$.");
    if (type != null && !_nodeType.hasMatch(type)) {
      _error(
        '$pointer/type',
        "Node type '$type' must be a Dart class, optionally with a named constructor: OnboardingButton.primary.",
      );
    }
    final nodeRef = '$_screen#${id ?? '?'}';

    final props = m.containsKey('props') ? _valueMap(m['props'], '$pointer/props', 'props') : const <String, Expr>{};
    final slots = <String, List<NodeDoc>>{};
    if (m.containsKey('children')) slots['children'] = _nodeList(m['children'], '$pointer/children');
    if (m.containsKey('slots')) {
      for (final MapEntry(:key, :value) in _map(m['slots'], '$pointer/slots', 'slots').entries) {
        final at = '$pointer/slots/${pointerSegment(key)}';
        if (!_identKey(key, at, 'slots')) continue;
        if (key == 'children' && slots.containsKey('children')) {
          _error(at, "Write children once: either 'children' on the node or 'slots.children'.", node: nodeRef);
        }
        slots[key] = _nodeList(value, at);
      }
    }

    final on = <String, List<ActionDoc>>{};
    if (m.containsKey('on')) {
      for (final MapEntry(:key, :value) in _map(m['on'], '$pointer/on', 'on').entries) {
        final at = '$pointer/on/${pointerSegment(key)}';
        if (_identKey(key, at, 'on')) on[key] = _actions(value, at, minOne: true);
      }
    }

    final when = m.containsKey('when') ? _expr(m['when'], '$pointer/when') : null;
    RepeatDoc? repeat;
    if (m.containsKey('repeat')) {
      final r = _map(m['repeat'], '$pointer/repeat', 'repeat');
      _onlyKeys(r, const {'over', 'as', 'index', 'key'}, '$pointer/repeat', 'repeat');
      if (!r.containsKey('over') || !r.containsKey('as')) _error('$pointer/repeat', "repeat needs 'over' and 'as'.");
      final as = _as<String>(r['as'], '$pointer/repeat/as', 'repeat.as');
      if (as != null && !isIdent(as)) _error('$pointer/repeat/as', "repeat.as must be lower camel, such as 'item'.");
      repeat = RepeatDoc(
        over: _expr(r['over'], '$pointer/repeat/over'),
        as: as ?? 'item',
        index: r['index'] as String?,
        key: r.containsKey('key') ? _expr(r['key'], '$pointer/repeat/key') : null,
      );
    }
    if (id == null || type == null) return null;
    return NodeDoc(
      id: id,
      type: type,
      pointer: pointer,
      props: props,
      slots: slots,
      on: on,
      when: when,
      repeat: repeat,
      note: m['note'] as String?,
    );
  }

  List<NodeDoc> _nodeList(Object? json, String pointer) {
    final list = _as<List<Object?>>(json, pointer, 'A slot');
    if (list == null) return const [];
    return [for (var i = 0; i < list.length; i++) ?node(list[i], '$pointer/$i')];
  }

  List<ActionDoc> _actions(Object? json, String pointer, {bool minOne = false}) {
    final list = _as<List<Object?>>(json, pointer, 'An action list');
    if (list == null) return const [];
    if (minOne && list.isEmpty) _error(pointer, 'An action list needs at least one action.');
    return [for (var i = 0; i < list.length; i++) ?action(list[i], '$pointer/$i')];
  }

  static const _actionFields = {
    'navigate': {'do', 'to', 'mode', 'params', 'query'},
    'back': {'do', 'fallback', 'params'},
    'backTo': {'do', 'to', 'params'},
    'setQuery': {'do', 'set', 'history'},
    'openModal': {'do', 'screen', 'params', 'then'},
    'closeModal': {'do', 'result'},
    'confirm': {'do', 'title', 'message', 'confirmLabel', 'destructive', 'then'},
    'toast': {'do', 'message', 'tone'},
    'setState': {'do', 'set'},
    'emit': {'do', 'name', 'payload'},
  };

  static const _actionRequired = {
    'navigate': ['to'],
    'back': ['fallback'],
    'backTo': ['to'],
    'setQuery': ['set'],
    'openModal': ['screen'],
    'confirm': ['title', 'then'],
    'toast': ['message'],
    'setState': ['set'],
    'emit': ['name'],
  };

  ActionDoc? action(Object? json, String p) {
    final m = _as<Map<String, Object?>>(json, p, 'An action');
    if (m == null) return null;
    final kind = m['do'];
    if (kind is! String || !_actionFields.containsKey(kind)) {
      _error(
        '$p/do',
        kind == null ? "An action needs 'do'." : "Unknown action '$kind'.",
        hint: kind is String
            ? switch (nearestName(kind, _actionFields.keys)) {
                final n? => "Did you mean '$n'?",
                null => null,
              }
            : null,
      );
      return null;
    }
    _onlyKeys(m, _actionFields[kind]!, p, "A '$kind' action");
    var missing = false;
    for (final field in _actionRequired[kind] ?? const <String>[]) {
      if (!m.containsKey(field)) {
        _error(p, "A '$kind' action needs '$field'.");
        missing = true;
      }
    }
    if (missing) return null;
    Map<String, Expr> values(String key) => m.containsKey(key) ? _valueMap(m[key], '$p/$key', key) : const {};
    List<ActionDoc> then() => m.containsKey('then') ? _actions(m['then'], '$p/then', minOne: true) : const [];

    switch (kind) {
      case 'navigate':
        final modeName = m['mode'] as String? ?? 'push';
        final mode = NavigateMode.values.where((v) => v.name == modeName).firstOrNull;
        if (mode == null) _error('$p/mode', 'mode is push, replaceAll or replace.');
        return NavigateAction(
          p,
          to: _screenRef(m['to'], '$p/to', 'to') ?? '',
          mode: mode ?? NavigateMode.push,
          params: values('params'),
          query: values('query'),
        );
      case 'back':
        return BackAction(
          p,
          fallback: _screenRef(m['fallback'], '$p/fallback', 'fallback') ?? '',
          params: values('params'),
        );
      case 'backTo':
        return BackToAction(p, to: _screenRef(m['to'], '$p/to', 'to') ?? '', params: values('params'));
      case 'setQuery':
        return SetQueryAction(p, set: values('set'), history: m['history'] as bool? ?? false);
      case 'openModal':
        return OpenModalAction(
          p,
          screen: _screenRef(m['screen'], '$p/screen', 'screen') ?? '',
          params: values('params'),
          then: then(),
        );
      case 'closeModal':
        return CloseModalAction(p, result: m.containsKey('result') ? _expr(m['result'], '$p/result') : null);
      case 'confirm':
        return ConfirmAction(
          p,
          title: _expr(m['title'], '$p/title'),
          message: m.containsKey('message') ? _expr(m['message'], '$p/message') : null,
          confirmLabel: m.containsKey('confirmLabel') ? _expr(m['confirmLabel'], '$p/confirmLabel') : null,
          destructive: m['destructive'] as bool? ?? false,
          then: then(),
        );
      case 'toast':
        final toneName = m['tone'] as String? ?? 'success';
        final tone = ToastTone.values.where((t) => t.name == toneName).firstOrNull;
        if (tone == null) _error('$p/tone', 'tone is success, error, warning or info.');
        return ToastAction(p, message: _expr(m['message'], '$p/message'), tone: tone ?? ToastTone.success);
      case 'setState':
        return SetStateAction(p, set: values('set'));
      default:
        final name = _as<String>(m['name'], '$p/name', 'name') ?? '';
        if (name.isNotEmpty && !isIdent(name)) {
          _error('$p/name', "An emit name must be lower camel, such as 'saveAutomation'.");
        }
        return EmitAction(p, name: name, payload: values('payload'));
    }
  }
}

String _jsonType<T>() => switch (T) {
  const (String) => 'text',
  const (bool) => 'true or false',
  const (num) || const (int) || const (double) => 'a number',
  const (List<Object?>) => 'a list',
  _ => 'an object',
};

String _describe(Object? value) => switch (value) {
  null => 'null',
  String() => 'text',
  bool() => 'a boolean',
  num() => 'a number',
  List<Object?>() => 'a list',
  _ => 'an object',
};
