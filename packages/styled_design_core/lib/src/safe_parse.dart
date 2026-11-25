import 'diagnostics.dart';
import 'json_util.dart';
import 'screen.dart';

/// [ScreenDoc.parse], made safe for any JSON: optional fields the parser
/// reads without a type check (a node's `note`, a screen's or param's
/// `description`, `repeat.index`, a query's `values`, and the `mode`,
/// `history`, `destructive` and `tone` of actions) are checked first. Those of
/// the wrong type are reported as E-schema and left out of the copy that is
/// parsed, so a mistyped field never throws. Never changes [json].
(ScreenDoc?, List<Diagnostic>) parseScreenSafely(Map<String, Object?> json, {String? file, bool partial = false}) {
  final problems = <Diagnostic>[];
  final copy = deepCopyJson(json)! as Map<String, Object?>;

  void check(Map<String, Object?> map, String key, String pointer, bool Function(Object?) ok, String expected) {
    if (!map.containsKey(key) || ok(map[key])) return;
    problems.add(
      Diagnostic.of(
        'E-schema',
        "'$key' must be $expected.",
        file: file,
        pointer: '$pointer/${pointerSegment(key)}',
        hint: 'Fix the value, or remove the field.',
      ),
    );
    map.remove(key);
  }

  bool isString(Object? v) => v is String;
  bool isBool(Object? v) => v is bool;

  check(copy, 'description', '', isString, 'text');
  for (final section in const ['params', 'query']) {
    if (copy[section] case final Map<String, Object?> entries) {
      for (final MapEntry(:key, :value) in entries.entries) {
        if (value is! Map<String, Object?>) continue;
        final at = '/$section/${pointerSegment(key)}';
        check(value, 'description', at, isString, 'text');
        if (section == 'query') {
          check(value, 'values', at, (v) => v is List<Object?> && v.every(isString), 'a list of text');
        }
      }
    }
  }

  void actions(Object? list, String pointer) {
    if (list is! List<Object?>) return;
    for (var i = 0; i < list.length; i++) {
      final action = list[i];
      if (action is! Map<String, Object?>) continue;
      final at = '$pointer/$i';
      switch (action['do']) {
        case 'navigate':
          check(action, 'mode', at, isString, 'push, replaceAll or replace');
        case 'setQuery':
          check(action, 'history', at, isBool, 'true or false');
        case 'confirm':
          check(action, 'destructive', at, isBool, 'true or false');
        case 'toast':
          check(action, 'tone', at, isString, 'success, error, warning or info');
      }
      actions(action['then'], '$at/then');
    }
  }

  void node(Object? value, String pointer) {
    if (value is! Map<String, Object?>) return;
    check(value, 'note', pointer, isString, 'text');
    if (value['repeat'] case final Map<String, Object?> repeat) {
      check(repeat, 'index', '$pointer/repeat', (v) => v is String && isIdent(v), "a lower-camel name, such as 'i'");
    }
    if (value['on'] case final Map<String, Object?> on) {
      for (final MapEntry(:key, value: list) in on.entries) {
        actions(list, '$pointer/on/${pointerSegment(key)}');
      }
    }
    if (value['children'] case final List<Object?> children) {
      for (var i = 0; i < children.length; i++) {
        node(children[i], '$pointer/children/$i');
      }
    }
    if (value['slots'] case final Map<String, Object?> slots) {
      for (final MapEntry(:key, value: list) in slots.entries) {
        if (list is! List<Object?>) continue;
        for (var i = 0; i < list.length; i++) {
          node(list[i], '$pointer/slots/${pointerSegment(key)}/$i');
        }
      }
    }
  }

  node(copy['root'], '/root');
  final (doc, found) = ScreenDoc.parse(copy, file: file, partial: partial);
  final all = [...problems, ...found];
  if (doc != null && !partial && problems.isNotEmpty) return (null, all);
  return (doc, all);
}
