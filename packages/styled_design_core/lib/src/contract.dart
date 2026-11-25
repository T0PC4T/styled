import 'dart:convert';

import 'package:meta/meta.dart';

import 'screen.dart';

/// The JSON kind of a scalar fixture value: string, number, bool or any (null).
String jsonKindName(Object? value) => switch (value) {
  String() => 'string',
  num() => 'number',
  bool() => 'bool',
  List<Object?>() => 'list',
  Map<Object?, Object?>() => 'object',
  _ => 'any',
};

/// The shape of a fixture value: keys and kinds, no values. An object maps
/// its keys to shapes; a list is `[shape of its first item]` (or `[]` when
/// no fixture has an item); a scalar is `string`, `number`, `bool` or `any`.
/// [alternates] are the values at the same place in the other fixtures: they
/// fill in what the default leaves open (an empty list, a null), and a null
/// default with a scalar elsewhere reads as nullable: `string?`.
Object? shapeOf(Object? value, [List<Object?> alternates = const []]) {
  final others = alternates.where((a) => a != null).toList();
  switch (value) {
    case final Map<String, Object?> map:
      return {
        for (final MapEntry(:key, value: v) in map.entries)
          key: shapeOf(v, [
            for (final a in others)
              if (a is Map<String, Object?> && a.containsKey(key)) a[key],
          ]),
      };
    case final List<Object?> list:
      final items = [
        ...list,
        for (final a in others)
          if (a is List<Object?>) ...a,
      ];
      if (items.isEmpty) return const <Object?>[];
      return [shapeOf(items.first, items.skip(1).toList())];
    case null:
      if (others.isEmpty) return 'any';
      final first = others.first;
      final shape = shapeOf(first, others.skip(1).toList());
      return shape is String ? '$shape?' : shape;
    default:
      return jsonKindName(value);
  }
}

/// The shape of [screen]'s data: its default fixture, refined by the others.
Object? dataShape(ScreenDoc screen) {
  final others = [
    for (final name in screen.fixtures.keys)
      if (name != 'default') screen.fixture(name),
  ];
  return shapeOf(screen.defaultFixture, others);
}

/// One emit in contract form.
Map<String, Object?> emitContract(String name, EmitSpec spec) => {
  'name': name,
  'description': spec.description,
  'payload': spec.payload,
  'returns': spec.returns,
};

/// What the app must supply for one screen: its route and params, its data,
/// the events it hands back, and the same for each modal it can open.
@immutable
final class ScreenContract {
  final ScreenDoc screen;
  final Object? data;

  /// The modals this screen can open, with their contracts.
  final Map<String, ScreenContract> modals;

  const ScreenContract(this.screen, this.data, this.modals);

  String get id => screen.id;

  Map<String, Object?> toJson() => {
    'id': screen.id,
    'kind': screen.kind.name,
    'title': screen.title,
    'route': ?screen.route,
    if (screen.params.isNotEmpty || screen.routeParams.isNotEmpty)
      'params': {
        for (final name in {...screen.routeParams, ...screen.params.keys})
          name: {'sample': ?screen.params[name]?.sample, 'description': ?screen.params[name]?.description},
      },
    if (screen.query.isNotEmpty)
      'query': {
        for (final MapEntry(:key, :value) in screen.query.entries)
          key: {
            'sample': ?value.sample,
            if (value.values.isNotEmpty) 'values': value.values,
            'description': ?value.description,
          },
      },
    'data': data,
    'emits': [for (final MapEntry(:key, :value) in screen.emits.entries) emitContract(key, value)],
    if (modals.isNotEmpty) 'modals': {for (final m in modals.values) m.id: m.toJson()..remove('id')},
  };

  /// A readable summary for the command line.
  String toText() {
    final b = StringBuffer();
    _write(b, '');
    return b.toString();
  }

  void _write(StringBuffer b, String indent) {
    b.writeln('$indent${screen.id} (${screen.kind.name}${screen.route == null ? '' : ' ${screen.route}'})');
    final params = {...screen.routeParams, ...screen.params.keys};
    if (params.isNotEmpty) {
      b.writeln('$indent  params:');
      for (final p in params) {
        final sample = screen.params[p]?.sample;
        b.writeln('$indent    $p: string${sample == null ? '' : ' (sample "$sample")'}');
      }
    }
    if (screen.query.isNotEmpty) {
      b.writeln('$indent  query:');
      for (final MapEntry(:key, :value) in screen.query.entries) {
        b.writeln('$indent    $key: string${value.values.isEmpty ? '' : ' (${value.values.join(' | ')})'}');
      }
    }
    b.writeln('$indent  data:');
    final lines = const JsonEncoder.withIndent('  ').convert(data).split('\n');
    for (final line in lines) {
      b.writeln('$indent    $line');
    }
    if (screen.emits.isNotEmpty) {
      b.writeln('$indent  emits:');
      for (final MapEntry(:key, :value) in screen.emits.entries) {
        final payload = value.payload.entries.map((e) => '${e.key}: ${e.value}').join(', ');
        b.writeln('$indent    $key($payload) → ${value.returns}  ${value.description}');
      }
    }
    for (final modal in modals.values) {
      b.writeln('$indent  opens modal:');
      modal._write(b, '$indent    ');
    }
  }
}

/// The ids of the modals [screen] can open, in document order.
List<String> openableModals(ScreenDoc screen) => [
  ...{
    for (final node in screen.nodes)
      for (final actions in node.on.values)
        for (final action in flattenActions(actions))
          if (action is OpenModalAction && action.screen.isNotEmpty) action.screen,
  },
];

/// The contract of [screen]. [screens] supplies the modals it opens.
ScreenContract screenContract(ScreenDoc screen, {Map<String, ScreenDoc> screens = const {}, Set<String>? seen}) {
  final visited = seen ?? {screen.id};
  return ScreenContract(screen, dataShape(screen), {
    for (final id in openableModals(screen))
      if (screens[id] case final modal? when modal.kind == ScreenKind.modal && visited.add(id))
        id: screenContract(modal, screens: screens, seen: visited),
  });
}
