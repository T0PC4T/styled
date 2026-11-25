import 'package:meta/meta.dart';

/// Whether a component draws a widget or builds a value object that a slot of
/// another component holds, such as a table column or a menu item.
enum DesignKind { widget, value }

/// What a prop holds and how a document writes it.
enum PropKind {
  /// Text.
  string,

  /// true or false.
  boolean,

  /// A whole number.
  integer,

  /// Any number.
  number,

  /// One name from [DesignProp.values]: an enum value or a named constant.
  choice,

  /// A name from the icon catalogue.
  icon,

  /// A preset id from one of [DesignProp.families]: `StyleButton.primary`.
  style,

  /// A token key of [DesignProp.tokenType]: `paddingSm`.
  token,

  /// A reference the host's image resolver turns into an image provider.
  image,

  /// ISO 8601 text.
  date,

  /// A path inside a row, such as `id`, replacing a function that reads a row.
  path,

  /// A list of JSON rows for a generic collection widget.
  rows,

  /// A list of strings.
  stringList,

  /// A list of whole numbers.
  integerList,

  /// Any JSON value, handed to the widget as is.
  json;

  static PropKind byName(String name) => values.byName(name);
}

/// One parameter of a component that a document sets under `props`.
@immutable
final class DesignProp {
  final String name;
  final PropKind kind;

  /// The document must set it.
  final bool required;

  /// The JSON value used when the document does not set it, if it has one.
  final Object? defaultValue;

  /// For [PropKind.style]: the preset families the prop accepts.
  final List<String> families;

  /// For [PropKind.choice]: the allowed names.
  final List<String> values;

  /// For [PropKind.token]: the token type, such as `double` or `color`.
  final String? tokenType;

  /// Whether a binding may stand in for a literal. True unless the widget
  /// needs the value fixed, such as the variant of a value class.
  final bool bindable;

  final String? doc;

  const DesignProp(
    this.name,
    this.kind, {
    this.required = false,
    this.defaultValue,
    this.families = const [],
    this.values = const [],
    this.tokenType,
    this.bindable = true,
    this.doc,
  });

  const DesignProp.string(this.name, {this.required = false, this.defaultValue, this.bindable = true, this.doc})
    : kind = PropKind.string,
      families = const [],
      values = const [],
      tokenType = null;

  const DesignProp.boolean(this.name, {this.required = false, this.defaultValue, this.bindable = true, this.doc})
    : kind = PropKind.boolean,
      families = const [],
      values = const [],
      tokenType = null;

  const DesignProp.integer(this.name, {this.required = false, this.defaultValue, this.bindable = true, this.doc})
    : kind = PropKind.integer,
      families = const [],
      values = const [],
      tokenType = null;

  const DesignProp.number(this.name, {this.required = false, this.defaultValue, this.bindable = true, this.doc})
    : kind = PropKind.number,
      families = const [],
      values = const [],
      tokenType = null;

  const DesignProp.choice(
    this.name, {
    required this.values,
    this.required = false,
    this.defaultValue,
    this.bindable = true,
    this.doc,
  }) : kind = PropKind.choice,
       families = const [],
       tokenType = null;

  const DesignProp.icon(this.name, {this.required = false, this.defaultValue, this.bindable = true, this.doc})
    : kind = PropKind.icon,
      families = const [],
      values = const [],
      tokenType = null;

  const DesignProp.style(
    this.name, {
    required this.families,
    this.required = false,
    this.defaultValue,
    this.bindable = true,
    this.doc,
  }) : kind = PropKind.style,
       values = const [],
       tokenType = null;

  const DesignProp.token(
    this.name, {
    required String this.tokenType,
    this.required = false,
    this.defaultValue,
    this.bindable = true,
    this.doc,
  }) : kind = PropKind.token,
       families = const [],
       values = const [];

  factory DesignProp.fromJson(Map<String, Object?> json) => DesignProp(
    json['name']! as String,
    PropKind.byName(json['kind']! as String),
    required: json['required'] as bool? ?? false,
    defaultValue: json['default'],
    families: _strings(json['families']),
    values: _strings(json['values']),
    tokenType: json['tokenType'] as String?,
    bindable: json['bindable'] as bool? ?? true,
    doc: json['doc'] as String?,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'kind': kind.name,
    if (required) 'required': true,
    if (defaultValue != null) 'default': defaultValue,
    if (families.isNotEmpty) 'families': families,
    if (values.isNotEmpty) 'values': values,
    'tokenType': ?tokenType,
    if (!bindable) 'bindable': false,
    'doc': ?doc,
  };
}

/// A named place where a component takes child nodes.
@immutable
final class DesignSlot {
  final String name;

  /// What the slot holds: `widget` for any widget, or the types of the value
  /// components it takes, such as `OnboardingTableColumn`.
  final List<String> accepts;

  /// A list (`children`, `actions`) rather than a single child (`leading`).
  final bool many;

  final bool required;

  /// For a template slot, built once per item: the variable each build adds,
  /// such as `row` for a table cell or `items` for a collection view.
  final String? template;

  final String? doc;

  const DesignSlot(
    this.name, {
    this.accepts = const ['widget'],
    this.many = false,
    this.required = false,
    this.template,
    this.doc,
  });

  /// Whether the slot takes widgets, as opposed to value nodes.
  bool get takesWidgets => accepts.contains('widget');

  factory DesignSlot.fromJson(Map<String, Object?> json) => DesignSlot(
    json['name']! as String,
    accepts: _strings(json['accepts'], fallback: const ['widget']),
    many: json['many'] as bool? ?? false,
    required: json['required'] as bool? ?? false,
    template: (json['template'] as Map<String, Object?>?)?['as'] as String?,
    doc: json['doc'] as String?,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'accepts': accepts,
    'many': many,
    if (required) 'required': true,
    if (template != null) 'template': {'as': template},
    'doc': ?doc,
  };
}

/// A callback of a component that a document links under `on`.
@immutable
final class DesignEvent {
  final String name;

  /// The event the component exists for, such as a button's `tap`. The studio
  /// draws an unbound primary event as enabled; export refuses it.
  final bool primary;

  /// Payload fields readable as `event.<field>`, with their JSON kinds:
  /// `string`, `number`, `bool`, `object`, `list`, `any`.
  final Map<String, String> payload;

  final String? doc;

  const DesignEvent(this.name, {this.primary = false, this.payload = const {}, this.doc});

  factory DesignEvent.fromJson(Map<String, Object?> json) => DesignEvent(
    json['name']! as String,
    primary: json['primary'] as bool? ?? false,
    payload: {
      for (final MapEntry(:key, :value) in ((json['payload'] as Map<String, Object?>?) ?? const {}).entries)
        key: value! as String,
    },
    doc: json['doc'] as String?,
  );

  Map<String, Object?> toJson() => {'name': name, if (primary) 'primary': true, 'payload': payload, 'doc': ?doc};
}

/// A lint the library declares: on one component (its `rules`), or for the
/// whole library (the catalog's `rules`). The engine knows these kinds:
///
/// | rule | meaning |
/// |---|---|
/// | `notInside` | the component must not have an ancestor of [types] |
/// | `onlyInside` | it must have an ancestor of [types] |
/// | `pageRoot` | a page's root is one of [types], with [props] when given |
/// | `modalRoot` | a modal's root is one of [types] |
/// | `frameRoot` | a frame's root is one of [types] |
/// | `singleScroll` | below a page root of [types], another of [types] must set [props] (an inner, non-scrolling variant) |
/// | `lastColumnProps` | inside the last of the `columns` of a [types] component, this component sets [props] |
/// | `rootOf` | the component may appear only in screens of the kinds in [types] |
@immutable
final class DesignRule {
  final String rule;
  final List<String> types;

  /// Prop values the rule expects, in document JSON form: `{"style": "StyleContentList.normal"}`.
  final Map<String, Object?> props;

  /// The diagnostic code reported when the rule breaks: `W-table-in-card`.
  final String code;

  /// What the diagnostic says, when the engine's default sentence is not enough.
  final String? message;

  const DesignRule(this.rule, {required this.types, required this.code, this.props = const {}, this.message});

  const DesignRule.notInside(this.types, {required this.code, this.message}) : rule = 'notInside', props = const {};

  factory DesignRule.fromJson(Map<String, Object?> json) => DesignRule(
    json['rule']! as String,
    types: _strings(json['types']),
    code: json['code']! as String,
    props: (json['props'] as Map<String, Object?>?) ?? const {},
    message: json['message'] as String?,
  );

  Map<String, Object?> toJson() => {
    'rule': rule,
    'types': types,
    if (props.isNotEmpty) 'props': props,
    'code': code,
    'message': ?message,
  };
}

/// Everything a document may know about one component. Pure data: it
/// serialises into catalog.json, and generated definitions hold it as a const.
@immutable
final class DesignComponent {
  /// The Dart class name: `OnboardingButton`.
  final String type;
  final DesignKind kind;

  /// layout, primitives, cards, inputs, ...
  final String category;

  /// One line an agent reads when choosing a component.
  final String summary;

  /// Named constructors a document can pick with `"type": "OnboardingButton.primary"`.
  final List<String> constructors;

  /// Whether the unnamed constructor exists. False for a widget that has only
  /// named ones.
  final bool hasDefaultConstructor;

  final List<DesignProp> props;
  final List<DesignSlot> slots;
  final List<DesignEvent> events;
  final List<DesignRule> rules;

  /// A minimal valid node, for agents.
  final Map<String, Object?>? example;

  const DesignComponent({
    required this.type,
    this.kind = DesignKind.widget,
    this.category = 'other',
    this.summary = '',
    this.constructors = const [],
    this.hasDefaultConstructor = true,
    this.props = const [],
    this.slots = const [],
    this.events = const [],
    this.rules = const [],
    this.example,
  });

  DesignProp? prop(String name) => _byName(props, name, (p) => p.name);
  DesignSlot? slot(String name) => _byName(slots, name, (s) => s.name);
  DesignEvent? event(String name) => _byName(events, name, (e) => e.name);

  /// The event marked primary, if any.
  DesignEvent? get primaryEvent => events.where((e) => e.primary).firstOrNull;

  factory DesignComponent.fromJson(Map<String, Object?> json) => DesignComponent(
    type: json['type']! as String,
    kind: DesignKind.values.byName(json['kind'] as String? ?? 'widget'),
    category: json['category'] as String? ?? 'other',
    summary: json['summary'] as String? ?? '',
    constructors: _strings(json['constructors']),
    hasDefaultConstructor: json['hasDefaultConstructor'] as bool? ?? true,
    props: [for (final p in _maps(json['props'])) DesignProp.fromJson(p)],
    slots: [for (final s in _maps(json['slots'])) DesignSlot.fromJson(s)],
    events: [for (final e in _maps(json['events'])) DesignEvent.fromJson(e)],
    rules: [for (final r in _maps(json['rules'])) DesignRule.fromJson(r)],
    example: json['example'] as Map<String, Object?>?,
  );

  Map<String, Object?> toJson() => {
    'type': type,
    'kind': kind.name,
    'category': category,
    'summary': summary,
    'constructors': constructors,
    if (!hasDefaultConstructor) 'hasDefaultConstructor': false,
    'props': [for (final p in props) p.toJson()],
    'slots': [for (final s in slots) s.toJson()],
    'events': [for (final e in events) e.toJson()],
    'rules': [for (final r in rules) r.toJson()],
    'example': ?example,
  };
}

/// One design token as the catalog lists it.
@immutable
final class CatalogToken {
  final String key;

  /// color, double, duration, fontWeight, string or shadow.
  final String type;

  /// Light value in token JSON form (see tokens.schema.json).
  final Object? light;

  /// Value per other mode, where the library sets one.
  final Map<String, Object?> modes;

  final String? doc;
  final String? group;

  const CatalogToken({
    required this.key,
    required this.type,
    required this.light,
    this.modes = const {},
    this.doc,
    this.group,
  });

  factory CatalogToken.fromJson(String key, Map<String, Object?> json) => CatalogToken(
    key: key,
    type: json['type']! as String,
    light: json['light'],
    modes: {
      for (final MapEntry(:key, :value) in json.entries)
        if (!const {'type', 'light', 'doc', 'group'}.contains(key)) key: value,
    },
    doc: json['doc'] as String?,
    group: json['group'] as String?,
  );

  Map<String, Object?> toJson() => {'type': type, 'light': light, ...modes, 'doc': ?doc, 'group': ?group};
}

/// A preset family: a `@StyledPreset` class and its variants.
@immutable
final class CatalogPresetFamily {
  final String name;
  final String? doc;

  /// The variant the unnamed constructor gives.
  final String? defaultVariant;
  final List<String> variants;

  /// Extra arguments a reference may pass, such as `StyleIconToken`'s `size`.
  final List<DesignProp> args;

  const CatalogPresetFamily({
    required this.name,
    required this.variants,
    this.doc,
    this.defaultVariant,
    this.args = const [],
  });

  factory CatalogPresetFamily.fromJson(String name, Map<String, Object?> json) => CatalogPresetFamily(
    name: name,
    doc: json['doc'] as String?,
    defaultVariant: json['default'] as String?,
    variants: _strings(json['variants']),
    args: [
      for (final MapEntry(:key, :value) in ((json['args'] as Map<String, Object?>?) ?? const {}).entries)
        DesignProp.fromJson({'name': key, ...value! as Map<String, Object?>}),
    ],
  );

  Map<String, Object?> toJson() => {
    'doc': ?doc,
    'default': ?defaultVariant,
    'variants': variants,
    if (args.isNotEmpty) 'args': {for (final a in args) a.name: a.toJson()..remove('name')},
  };
}

/// Everything there is to build with: what an agent searches and what the
/// validator checks documents against. Written by the library's build as
/// catalog.json.
@immutable
final class Catalog {
  static const currentFormat = 1;

  final int format;

  /// Bumped when the library removes or renames something a document may use.
  final int version;
  final String? hash;
  final List<String> modes;
  final Map<String, CatalogToken> tokens;
  final Map<String, CatalogPresetFamily> presets;
  final List<String> states;
  final List<String> icons;
  final List<String> formatters;
  final Map<String, DesignComponent> components;

  /// Library-wide lints, such as the page root rule.
  final List<DesignRule> rules;

  const Catalog({
    this.format = currentFormat,
    this.version = 1,
    this.hash,
    this.modes = const ['light'],
    this.tokens = const {},
    this.presets = const {},
    this.states = const [],
    this.icons = const [],
    this.formatters = const [],
    this.components = const {},
    this.rules = const [],
  });

  factory Catalog.fromJson(Map<String, Object?> json) => Catalog(
    format: json['format'] as int? ?? currentFormat,
    version: json['version'] as int? ?? 1,
    hash: json['hash'] as String?,
    modes: _strings(json['modes'], fallback: const ['light']),
    tokens: {
      for (final MapEntry(:key, :value) in ((json['tokens'] as Map<String, Object?>?) ?? const {}).entries)
        key: CatalogToken.fromJson(key, value! as Map<String, Object?>),
    },
    presets: {
      for (final MapEntry(:key, :value) in ((json['presets'] as Map<String, Object?>?) ?? const {}).entries)
        key: CatalogPresetFamily.fromJson(key, value! as Map<String, Object?>),
    },
    states: _strings(json['states']),
    icons: _strings(json['icons']),
    formatters: _strings(json['formatters']),
    components: {
      for (final MapEntry(:key, :value) in ((json['components'] as Map<String, Object?>?) ?? const {}).entries)
        key: DesignComponent.fromJson({'type': key, ...value! as Map<String, Object?>}),
    },
    rules: [for (final r in _maps(json['rules'])) DesignRule.fromJson(r)],
  );

  Map<String, Object?> toJson() => {
    'format': format,
    'version': version,
    'hash': ?hash,
    'modes': modes,
    'tokens': {for (final t in tokens.values) t.key: t.toJson()},
    'presets': {for (final p in presets.values) p.name: p.toJson()},
    'states': states,
    'icons': icons,
    'formatters': formatters,
    'components': {for (final c in components.values) c.type: c.toJson()..remove('type')},
    if (rules.isNotEmpty) 'rules': [for (final r in rules) r.toJson()],
  };

  /// The component for a node type, with any named constructor split off:
  /// `OnboardingButton.primary` → (OnboardingButton, primary).
  static (String type, String? constructor) splitType(String nodeType) {
    final dot = nodeType.indexOf('.');
    return dot < 0 ? (nodeType, null) : (nodeType.substring(0, dot), nodeType.substring(dot + 1));
  }

  /// A preset id split into family and variant: `StyleCard.highlight` → (StyleCard, highlight).
  static (String family, String variant)? splitPreset(String id) {
    final dot = id.indexOf('.');
    if (dot <= 0 || dot == id.length - 1) return null;
    return (id.substring(0, dot), id.substring(dot + 1));
  }
}

T? _byName<T>(List<T> items, String name, String Function(T) nameOf) {
  for (final item in items) {
    if (nameOf(item) == name) return item;
  }
  return null;
}

List<String> _strings(Object? json, {List<String> fallback = const []}) =>
    json == null ? fallback : [for (final s in json as List<Object?>) s! as String];

List<Map<String, Object?>> _maps(Object? json) =>
    json == null ? const [] : [for (final m in json as List<Object?>) m! as Map<String, Object?>];
