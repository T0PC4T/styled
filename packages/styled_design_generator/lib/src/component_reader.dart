import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

const _annotations = 'package:styled_design_core/src/annotations.dart';
const designableChecker = TypeChecker.fromUrl('$_annotations#Designable');
const notDesignableChecker = TypeChecker.fromUrl('$_annotations#NotDesignable');
const _templateChecker = TypeChecker.fromUrl('$_annotations#DesignTemplate');
const _pathChecker = TypeChecker.fromUrl('$_annotations#DesignPath');
const _ignoreChecker = TypeChecker.fromUrl('$_annotations#DesignIgnore');
const _anchorChecker = TypeChecker.fromUrl('$_annotations#DesignAnchor');

/// How one constructor parameter appears in a design document, and the Dart
/// expression that reads it from a `DesignBuildContext ctx`.
final class ParamPlan {
  final String name;
  final bool positional;

  /// The Dart expression passed for this parameter.
  final String expression;

  /// The catalog entry this parameter contributes (`DesignProp(...)`,
  /// `DesignSlot(...)`, `DesignEvent(...)` as const Dart code), or null.
  final String? propCode;
  final String? slotCode;
  final String? eventCode;

  /// The name the entry is listed under, for de-duplication across constructors.
  final String? entryName;

  const ParamPlan({
    required this.name,
    required this.positional,
    required this.expression,
    this.propCode,
    this.slotCode,
    this.eventCode,
    this.entryName,
  });
}

/// One public constructor of a designable class.
final class CtorPlan {
  /// Null for the unnamed constructor.
  final String? name;
  final List<ParamPlan> params;
  const CtorPlan(this.name, this.params);
}

/// Everything needed to write a definition for one `@Designable` class.
final class ComponentPlan {
  final String type;
  final String definitionName;
  final bool isValue;
  final String category;
  final String summary;
  final String? primaryEvent;

  /// `DesignRule(...)` const expressions.
  final List<String> rules;
  final List<CtorPlan> ctors;

  /// The class's type arguments when generic: `<Object?>`.
  final String typeArgs;

  /// A hand-written definition class to use instead, and its library URI.
  final String? handWritten;
  final String? handWrittenUri;

  const ComponentPlan({
    required this.type,
    required this.definitionName,
    required this.isValue,
    required this.category,
    required this.summary,
    required this.primaryEvent,
    required this.rules,
    required this.ctors,
    required this.typeArgs,
    this.handWritten,
    this.handWrittenUri,
  });
}

/// A class or parameter the generator cannot map. The message names the file,
/// the class and the parameter, and what to do.
InvalidGenerationSourceError _unmapped(ClassElement cls, String param, DartType type, String why) =>
    InvalidGenerationSourceError(
      '${cls.name}: parameter `$param` of type `${type.getDisplayString()}` $why '
      'Annotate the parameter with @DesignIgnore(), @DesignPath(...) or @DesignTemplate(...), '
      'or give the class a hand-written definition with @Designable(definition: ...).',
      element: cls,
    );

String _lowerFirst(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

String _str(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$').replaceAll('\n', r'\n')}'";

bool _nullable(DartType t) => t.nullabilitySuffix == NullabilitySuffix.question;

bool _isA(DartType type, String name) {
  if (type is! InterfaceType) return false;
  return type.element.name == name || type.allSupertypes.any((s) => s.element.name == name);
}

bool _isWidget(DartType t) => _isA(t, 'Widget');

/// The Dart source for [type], with the class's own type parameters erased to `Object?`.
String typeCode(DartType type) {
  final q = _nullable(type) ? '?' : '';
  if (type is TypeParameterType) return 'Object?';
  if (type is InterfaceType) {
    final args = type.typeArguments.isEmpty ? '' : '<${type.typeArguments.map(typeCode).join(', ')}>';
    return '${type.element.name}$args$q';
  }
  if (type is VoidType) return 'void';
  if (type is DynamicType) return 'dynamic';
  return type.getDisplayString();
}

/// JSON value of a constant default, when it has a simple one.
Object? _jsonDefault(DartObject? value) {
  if (value == null || value.isNull) return null;
  if (value.toBoolValue() case final b?) return b;
  if (value.toIntValue() case final i?) return i;
  if (value.toDoubleValue() case final d?) return d;
  if (value.toStringValue() case final s?) return s;
  final type = value.type;
  if (type is InterfaceType && type.element is EnumElement) {
    return value.getField('_name')?.toStringValue() ?? value.variable?.name;
  }
  // A named constant of a type documents name it by: Alignment.centerLeft, TablerIcons.inbox.
  if (type is InterfaceType && const {'Alignment', 'IconData'}.contains(type.element.name)) return value.variable?.name;
  if (value.toListValue() case final list?) {
    final items = [for (final item in list) _jsonDefault(item)];
    return items.every((i) => i is String || i is num || i is bool) ? items : null;
  }
  return null;
}

String _literal(Object? json) => switch (json) {
  null => 'null',
  final String s => _str(s),
  final num n => '$n',
  final bool b => '$b',
  final List<Object?> l => '[${l.map(_literal).join(', ')}]',
  _ => 'null',
};

/// Dart const code for a DartObject made of JSON-like values.
String _constCode(DartObject? o) {
  if (o == null || o.isNull) return 'null';
  if (o.toBoolValue() case final b?) return '$b';
  if (o.toIntValue() case final i?) return '$i';
  if (o.toDoubleValue() case final d?) return '$d';
  if (o.toStringValue() case final s?) return _str(s);
  if (o.toListValue() case final l?) return '[${l.map(_constCode).join(', ')}]';
  if (o.toMapValue() case final m?) {
    return '{${m.entries.map((e) => '${_constCode(e.key)}: ${_constCode(e.value)}').join(', ')}}';
  }
  return 'null';
}

String _ruleCode(DartObject rule) {
  final props = rule.getField('props');
  final message = rule.getField('message');
  return 'DesignRule(${_constCode(rule.getField('rule'))}, types: ${_constCode(rule.getField('types'))}, '
      'code: ${_constCode(rule.getField('code'))}'
      '${props != null && (props.toMapValue()?.isNotEmpty ?? false) ? ', props: ${_constCode(props)}' : ''}'
      '${message != null && !message.isNull ? ', message: ${_constCode(message)}' : ''})';
}

/// The JSON kind of a Dart type in an event payload.
String _payloadKind(DartType t) {
  if (t.isDartCoreString || (t is InterfaceType && t.element is EnumElement)) return 'string';
  if (t.isDartCoreInt || t.isDartCoreDouble || t.isDartCoreNum) return 'number';
  if (t.isDartCoreBool) return 'bool';
  if (t.isDartCoreList || t.isDartCoreSet) return 'list';
  if (t.isDartCoreMap) return 'object';
  return 'any';
}

/// The annotation on a parameter, or on the field a `this.x` parameter sets.
DartObject? _paramAnnotation(TypeChecker checker, FormalParameterElement p) =>
    checker.firstAnnotationOf(p, throwOnUnresolved: false) ??
    (p is FieldFormalParameterElement && p.field != null
        ? checker.firstAnnotationOf(p.field!, throwOnUnresolved: false)
        : null);

/// Reads a `@Designable` class into a [ComponentPlan].
ComponentPlan readComponent(ClassElement cls, DartObject annotation) {
  final reader = ConstantReader(annotation);
  final isValue = reader.read('isValue').boolValue;
  final category = reader.read('category').stringValue;
  final summary = reader.read('summary').stringValue;
  final primaryEvent = reader.read('primaryEvent').isNull ? null : reader.read('primaryEvent').stringValue;
  final rules = [for (final r in reader.read('rules').listValue) _ruleCode(r)];
  final handWritten = reader.read('definition').isNull ? null : reader.read('definition').typeValue;
  final typeArgs = cls.typeParameters.isEmpty ? '' : '<${cls.typeParameters.map((_) => 'Object?').join(', ')}>';
  final type = cls.name!;

  if (handWritten != null) {
    final element = handWritten.element!;
    return ComponentPlan(
      type: type,
      definitionName: element.name!,
      isValue: isValue,
      category: category,
      summary: summary,
      primaryEvent: primaryEvent,
      rules: rules,
      ctors: const [],
      typeArgs: typeArgs,
      handWritten: element.name,
      handWrittenUri: element.library!.uri.toString(),
    );
  }

  final ctors = <CtorPlan>[
    for (final c in cls.constructors)
      if (c.isPublic && c.name != 'fromJson')
        CtorPlan(c.name == 'new' || c.name == null || c.name!.isEmpty ? null : c.name, [
          for (final p in c.formalParameters) ?_planParam(cls, p, isValue: isValue, primaryEvent: primaryEvent),
        ]),
  ];
  if (ctors.isEmpty) {
    throw InvalidGenerationSourceError('${cls.name} has no public constructor.', element: cls);
  }
  return ComponentPlan(
    type: type,
    definitionName: '${type}Definition',
    isValue: isValue,
    category: category,
    summary: summary,
    primaryEvent: primaryEvent,
    rules: rules,
    ctors: ctors,
    typeArgs: typeArgs,
  );
}

/// The default expression for an optional parameter, from its source code.
String? _dartDefault(ClassElement cls, FormalParameterElement p) {
  if (!p.hasDefaultValue) return null;
  var code = p.defaultValueCode!;
  if (RegExp(r'(^|[^A-Za-z0-9_$.])_').hasMatch(code)) {
    throw InvalidGenerationSourceError(
      '${cls.name}: the default of `${p.name}` ($code) uses a private name the generated definition cannot reach.',
      todo: 'Make the default public, or give the class a hand-written definition.',
      element: cls,
    );
  }
  // A bare static member of the class itself must be qualified.
  if (RegExp(r'^[a-z][A-Za-z0-9_]*$').hasMatch(code) &&
      ((cls.getField(code)?.isStatic ?? false) || (cls.getGetter(code)?.isStatic ?? false))) {
    code = '${cls.name}.$code';
  }
  return code;
}

ParamPlan? _planParam(ClassElement cls, FormalParameterElement p, {required bool isValue, String? primaryEvent}) {
  final name = p.name!;
  final type = p.type;
  final nullable = _nullable(type);
  final required = p.isRequiredNamed || p.isRequiredPositional;
  final positional = p.isPositional;
  final dartDefault = _dartDefault(cls, p);
  final jsonDefault = _jsonDefault(p.computeConstantValue());
  final mustHaveValue = !nullable;

  ParamPlan plan(String expression, {String? prop, String? slot, String? event, String? entry}) => ParamPlan(
    name: name,
    positional: positional,
    expression: expression,
    propCode: prop,
    slotCode: slot,
    eventCode: event,
    entryName: entry ?? name,
  );

  // Fallback when a non-nullable value is absent: the Dart default, else a neutral value.
  String orDefault(String read, String neutral) {
    if (dartDefault != null) return '$read ?? $dartDefault';
    if (mustHaveValue) return '$read ?? $neutral';
    return read;
  }

  String common({bool withDefault = true}) => [
    if (required && !nullable) 'required: true',
    if (withDefault && jsonDefault != null) 'defaultValue: ${_literal(jsonDefault)}',
  ].map((s) => ', $s').join();

  // Keys.
  if (_isA(type, 'Key')) return isValue ? null : plan('ctx.key', entry: null);

  // Explicit annotations.
  if (_paramAnnotation(_ignoreChecker, p) != null) {
    if (required && !nullable) {
      throw InvalidGenerationSourceError(
        '${cls.name}: `$name` is required, so it cannot be @DesignIgnore()d.',
        element: cls,
      );
    }
    return null;
  }
  if (_paramAnnotation(_pathChecker, p) case final path?) {
    final propName = ConstantReader(path).read('name').stringValue;
    return plan("ctx.path('$propName')", prop: "DesignProp('$propName', PropKind.path)", entry: propName);
  }
  if (_paramAnnotation(_templateChecker, p) case final template?) {
    final r = ConstantReader(template);
    final as = r.read('as').stringValue;
    final slotName = r.read('name').isNull ? _slotNameFor(name) : r.read('name').stringValue;
    if (type is! FunctionType) throw _unmapped(cls, name, type, 'is marked @DesignTemplate but is not a function.');
    final args = type.formalParameters.map((fp) => _isA(fp.type, 'BuildContext') ? '_' : 'item').join(', ');
    final call = "(${args.replaceAll('item', r'$item')}) => ctx.template('$slotName', as: '$as')(\$item)";
    return plan(
      nullable ? "ctx.node.slots.containsKey('$slotName') ? $call : null" : call,
      slot: "DesignSlot('$slotName'${!nullable && required ? ', required: true' : ''}, template: '$as')",
      entry: slotName,
    );
  }

  // Ignored by rule: controllers, focus nodes, scroll physics.
  if (type is InterfaceType &&
      ((type.element.name ?? '').endsWith('Controller') ||
          _isA(type, 'FocusNode') ||
          _isA(type, 'ChangeNotifier') ||
          _isA(type, 'ScrollPhysics'))) {
    if (required && !nullable) throw _unmapped(cls, name, type, 'is required but designers cannot set it.');
    return null;
  }

  // Functions: events and builder slots.
  if (type is FunctionType) {
    final returnsWidget = _isWidget(type.returnType);
    final params = type.formalParameters;
    if (returnsWidget && params.every((fp) => _isA(fp.type, 'BuildContext'))) {
      final slotName = _slotNameFor(name);
      final builder = "(_) => ctx.child('$slotName') ?? const SizedBox.shrink()";
      return plan(
        nullable ? "ctx.node.slots.containsKey('$slotName') ? $builder : null" : builder,
        slot: "DesignSlot('$slotName'${!nullable ? ', required: true' : ''})",
        entry: slotName,
      );
    }
    if (returnsWidget) {
      throw _unmapped(cls, name, type, 'builds a widget from an item, so it needs @DesignTemplate(as: ...).');
    }
    final returnsVoid = type.returnType is VoidType || type.returnType.isDartAsyncFuture;
    if (!RegExp(r'^on[A-Z]').hasMatch(name) || !returnsVoid) {
      throw _unmapped(
        cls,
        name,
        type,
        'is a function that is not an event (events are on... callbacks returning void).',
      );
    }
    final event = _lowerFirst(name.substring(2));
    final primary = event == primaryEvent;
    final asyncBody = type.returnType.isDartAsyncFuture ? 'async ' : '';
    String fieldName(int i) {
      final n = params[i].name;
      return n == null || n.isEmpty || n.startsWith('_') ? (i == 0 ? 'value' : 'value${i + 1}') : n;
    }

    final String read;
    final payload = <String, String>{};
    switch (params.length) {
      case 0:
        read = "ctx.callback('$event')";
      case 1:
        final argType = typeCode(params[0].type);
        final field = fieldName(0);
        payload[field] = _payloadKind(params[0].type);
        read = field == 'value'
            ? "ctx.valueCallback<$argType>('$event')"
            : "ctx.callbackWith<$argType>('$event', (\$a) => {'$field': \$a is Enum ? \$a.name : \$a})";
      case 2:
        final a = typeCode(params[0].type);
        final b = typeCode(params[1].type);
        payload[fieldName(0)] = _payloadKind(params[0].type);
        payload[fieldName(1)] = _payloadKind(params[1].type);
        read = "ctx.callbackWith2<$a, $b>('$event', (\$a, \$b) => {'${fieldName(0)}': \$a, '${fieldName(1)}': \$b})";
      default:
        throw _unmapped(cls, name, type, 'takes more than two arguments.');
    }
    final noop = '(${List.filled(params.length, '_').join(', ')}) $asyncBody{}';
    final payloadCode = payload.isEmpty
        ? ''
        : ', payload: {${payload.entries.map((e) => "'${e.key}': '${e.value}'").join(', ')}}';
    return plan(
      nullable ? read : '$read ?? $noop',
      event: "DesignEvent('$event'${primary ? ', primary: true' : ''}$payloadCode)",
      entry: event,
    );
  }

  // Widgets: slots.
  if (_isWidget(type)) {
    final specific = (type as InterfaceType).element.name;
    final generic = specific == 'Widget' || specific == 'PreferredSizeWidget';
    final anchor = _paramAnnotation(_anchorChecker, p) != null;
    final slot =
        "DesignSlot('$name'${generic ? '' : ", accepts: ['$specific']"}${required && !nullable ? ', required: true' : ''}"
        "${anchor ? ', anchor: true' : ''})";
    final read = generic
        ? "ctx.child('$name')"
        : "switch (ctx.child('$name')) { final ${typeCode(type).replaceAll('?', '')} w => w, _ => null }";
    return plan(mustHaveValue ? '$read ?? const SizedBox.shrink()' : read, slot: slot);
  }
  if (type is InterfaceType && (type.isDartCoreList || type.isDartCoreIterable) && type.typeArguments.length == 1) {
    final item = type.typeArguments.single;
    if (_isWidget(item)) {
      return plan(
        nullable ? "ctx.childrenOrNull('$name')" : "ctx.children('$name')",
        slot: "DesignSlot('$name', many: true${required && !nullable ? ', required: true' : ''})",
      );
    }
    if (item.isDartCoreString) {
      return plan(
        orDefault("ctx.stringList('$name')", 'const []'),
        prop: "DesignProp('$name', PropKind.stringList${common()})",
      );
    }
    if (item.isDartCoreInt) {
      return plan(
        orDefault("ctx.integerList('$name')", 'const []'),
        prop: "DesignProp('$name', PropKind.integerList${common()})",
      );
    }
    if (item is TypeParameterType) {
      return plan(orDefault("ctx.rows('$name')", 'const []'), prop: "DesignProp('$name', PropKind.rows${common()})");
    }
    if (item is InterfaceType && _samePackage(item.element.library.uri, cls.library.uri)) {
      final valueType = typeCode(item);
      final read = "ctx.values<$valueType>('$name')";
      return plan(
        nullable ? "ctx.node.slots.containsKey('$name') ? $read : null" : read,
        slot:
            "DesignSlot('$name', accepts: ['${item.element.name}'], many: true${required && !nullable ? ', required: true' : ''})",
      );
    }
  }
  if (type is InterfaceType && type.isDartCoreSet && type.typeArguments.single.isDartCoreString) {
    return plan(
      orDefault("ctx.stringSet('$name')", 'const {}'),
      prop: "DesignProp('$name', PropKind.stringList${common(withDefault: false)})",
    );
  }

  // Scalars.
  if (type.isDartCoreString) {
    return plan(orDefault("ctx.string('$name')", "''"), prop: "DesignProp.string('$name'${common()})");
  }
  if (type.isDartCoreBool) {
    return plan(orDefault("ctx.boolean('$name')", 'false'), prop: "DesignProp.boolean('$name'${common()})");
  }
  if (type.isDartCoreInt) {
    return plan(orDefault("ctx.integer('$name')", '0'), prop: "DesignProp.integer('$name'${common()})");
  }
  if (type.isDartCoreDouble || type.isDartCoreNum) {
    return plan(orDefault("ctx.number('$name')", '0'), prop: "DesignProp.number('$name'${common()})");
  }
  if (type is InterfaceType && type.element is EnumElement) {
    final enumName = type.element.name!;
    final values = (type.element as EnumElement).constants.map((c) => _str(c.name!)).join(', ');
    return plan(
      orDefault("ctx.choice('$name', $enumName.values)", '$enumName.values.first'),
      prop: "DesignProp.choice('$name', values: [$values]${common()})",
    );
  }
  if (type is InterfaceType && type.element.name == 'Alignment') {
    const names =
        "'topLeft', 'topCenter', 'topRight', 'centerLeft', 'center', 'centerRight', 'bottomLeft', 'bottomCenter', 'bottomRight'";
    return plan(
      orDefault("ctx.alignment('$name')", 'Alignment.center'),
      prop: "DesignProp.choice('$name', values: [$names]${common()})",
    );
  }
  if (type is InterfaceType && type.element.name == 'IconData') {
    return plan(orDefault("ctx.icon('$name')", 'const IconData(0)'), prop: "DesignProp.icon('$name'${common()})");
  }
  if (_isA(type, 'StyleResolver')) {
    final families = _styleFamilies(type, p.computeConstantValue());
    return plan(
      orDefault("ctx.style('$name')", 'const Style()'),
      prop: "DesignProp.style('$name', families: [${families.map(_str).join(', ')}]${common(withDefault: false)})",
    );
  }
  if (type is InterfaceType && _isA(type, 'StyleValue')) {
    final arg = type.typeArguments.isEmpty ? null : type.typeArguments.single;
    final tokenType = switch (arg) {
      final t? when t.isDartCoreDouble => 'double',
      final InterfaceType t when t.element.name == 'Color' => 'color',
      _ => throw _unmapped(cls, name, type, 'is a StyleValue of a type with no token kind.'),
    };
    final dartType = tokenType == 'double' ? 'double' : 'Color';
    final tokenDefault = p.computeConstantValue()?.getField('key')?.toStringValue();
    return plan(
      dartDefault != null ? "ctx.token<$dartType>('$name') ?? $dartDefault" : "ctx.token<$dartType>('$name')",
      prop:
          "DesignProp.token('$name', tokenType: '$tokenType'${required && !nullable ? ', required: true' : ''}${tokenDefault != null ? ', defaultValue: ${_str(tokenDefault)}' : ''})",
    );
  }
  if (_isA(type, 'ImageProvider')) {
    return plan("ctx.image('$name')", prop: "DesignProp('$name', PropKind.image${common()})");
  }
  if (type is InterfaceType && type.element.name == 'DateTime') {
    return plan(orDefault("ctx.date('$name')", 'DateTime(0)'), prop: "DesignProp('$name', PropKind.date${common()})");
  }
  if (type is TypeParameterType) return plan("ctx.json('$name')", prop: "DesignProp('$name', PropKind.json)");

  throw _unmapped(cls, name, type, 'has no design rule.');
}

/// `emptyBuilder` → `empty`.
String _slotNameFor(String param) => param.endsWith('Builder') && param.length > 'Builder'.length
    ? param.substring(0, param.length - 'Builder'.length)
    : param;

/// The preset families a style parameter accepts: the parameter's own type
/// when it is a family, else the family of its default.
List<String> _styleFamilies(DartType type, DartObject? defaultValue) {
  bool isFamily(DartType t) => t is InterfaceType && t.element.getNamedConstructor('fromVariant') != null;
  final own = type is InterfaceType ? type.element.name : null;
  if (own != null && own != 'StyleResolver' && isFamily(type)) return [own];
  final d = defaultValue?.type;
  if (d is InterfaceType && isFamily(d)) return [d.element.name!];
  return const [];
}

bool _samePackage(Uri a, Uri b) =>
    a.scheme == 'package' && b.scheme == 'package' && a.pathSegments.first == b.pathSegments.first;
