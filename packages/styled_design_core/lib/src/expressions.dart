import 'package:meta/meta.dart';

import 'formatters.dart';

/// A value or expression that does not compile. [pointer] is a JSON pointer
/// relative to the value that was compiled.
class ExpressionError implements Exception {
  final String pointer;
  final String message;
  const ExpressionError(this.pointer, this.message);

  @override
  String toString() => 'ExpressionError(${pointer.isEmpty ? '/' : pointer}): $message';
}

/// A dotted path such as `data.paging.total` or `row.id`: a root and the
/// segments below it. A numeric segment indexes a list.
@immutable
final class DataPath {
  final String root;
  final List<String> segments;

  const DataPath(this.root, [this.segments = const []]);

  static final _pattern = RegExp(r'^[a-z][A-Za-z0-9]*(\.([A-Za-z_][A-Za-z0-9_]*|[0-9]+))*$');

  /// Parses [text], or throws [ExpressionError] when it is not a path.
  factory DataPath.parse(String text) {
    if (!_pattern.hasMatch(text)) {
      throw ExpressionError('', "'$text' is not a path. Write root.segment.segment, such as data.paging.total.");
    }
    final parts = text.split('.');
    return DataPath(parts.first, parts.sublist(1));
  }

  /// The value at this path below [rootValue], or null when any step is missing.
  Object? readFrom(Object? rootValue) {
    var current = rootValue;
    for (final segment in segments) {
      current = switch (current) {
        final Map<Object?, Object?> map => map[segment],
        final List<Object?> list => switch (int.tryParse(segment)) {
          final int i when i >= 0 && i < list.length => list[i],
          _ => null,
        },
        _ => null,
      };
      if (current == null) return null;
    }
    return current;
  }

  @override
  String toString() => [root, ...segments].join('.');

  @override
  bool operator ==(Object other) => other is DataPath && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;
}

/// Where an expression finds its roots: `data`, `state`, `params`, `query`,
/// `event`, `page`, and variables a repeat or template slot introduces.
abstract interface class ExprScope {
  /// The value of [root], or null when the scope has no such root.
  Object? root(String root);

  /// Whether [root] exists in this scope at all.
  bool hasRoot(String root);

  /// Formatters a `$text` hole may name after a bar.
  DesignFormatters get formatters;
}

/// A scope over a plain map of roots.
final class MapScope implements ExprScope {
  final Map<String, Object?> roots;
  @override
  final DesignFormatters formatters;

  const MapScope(this.roots, {this.formatters = DesignFormatters.standard});

  @override
  Object? root(String root) => roots[root];

  @override
  bool hasRoot(String root) => roots.containsKey(root);

  /// This scope with [extra] roots added over it.
  MapScope extend(Map<String, Object?> extra) => MapScope({...roots, ...extra}, formatters: formatters);
}

/// Whether [value] counts as true in `when`, `$not`, `$and`, `$or` and `$if`:
/// everything except null, false, 0, "", [] and {}.
bool isTruthy(Object? value) => switch (value) {
  null || false => false,
  final num n => n != 0,
  final String s => s.isNotEmpty,
  final List<Object?> l => l.isNotEmpty,
  final Map<Object?, Object?> m => m.isNotEmpty,
  _ => true,
};

/// Whether [value] is empty for `$empty`: null, "", [] or {}.
bool isEmptyValue(Object? value) => switch (value) {
  null => true,
  final String s => s.isEmpty,
  final List<Object?> l => l.isEmpty,
  final Map<Object?, Object?> m => m.isEmpty,
  _ => false,
};

/// A compiled prop value: a literal, a list or object of values, or one of
/// the `$` expressions. Compile once when a document loads; evaluate on every
/// build.
@immutable
sealed class Expr {
  const Expr();

  /// The operators an expression object may use.
  static const operators = {
    r'$bind', r'$text', r'$not', r'$empty', r'$and', r'$or', //
    r'$eq', r'$ne', r'$gt', r'$gte', r'$lt', r'$lte', r'$in', r'$if', r'$match',
  };

  /// Compiles a JSON value. Throws [ExpressionError] with the pointer of the
  /// first problem.
  static Expr compile(Object? json) => _compile(json, '');

  /// Evaluates this expression in [scope].
  Object? eval(ExprScope scope);

  /// Every path this expression reads, `$text` holes included.
  Iterable<DataPath> get paths;

  /// Every formatter a `$text` hole names.
  Iterable<String> get formatterNames => children.expand((e) => e.formatterNames);

  /// The expressions directly inside this one.
  Iterable<Expr> get children => const [];

  /// Whether this is a plain literal, with no expression anywhere inside.
  bool get isLiteral => false;
}

Expr _compile(Object? json, String pointer) {
  switch (json) {
    case null || bool() || num() || String():
      return Literal(json);
    case final List<Object?> list:
      final items = [for (var i = 0; i < list.length; i++) _compile(list[i], '$pointer/$i')];
      return items.every((e) => e.isLiteral) ? Literal(list) : ListExpr(items);
    case final Map<String, Object?> map:
      final dollarKeys = map.keys.where((k) => k.startsWith(r'$')).toList();
      if (dollarKeys.isEmpty) {
        final entries = {for (final MapEntry(:key, :value) in map.entries) key: _compile(value, '$pointer/$key')};
        return entries.values.every((e) => e.isLiteral) ? Literal(map) : MapExpr(entries);
      }
      if (map.length != 1) {
        throw ExpressionError(
          pointer,
          'An expression object has exactly one key, a \$ operator. Found ${map.keys.join(', ')}.',
        );
      }
      final op = dollarKeys.single;
      final arg = map[op];
      final at = '$pointer/${op.replaceAll('~', '~0').replaceAll('/', '~1')}';
      return switch (op) {
        r'$bind' => Bind(_path(arg, at)),
        r'$text' => TextTemplate.parse(_string(arg, at, op), at),
        r'$not' => Not(_compile(arg, at)),
        r'$empty' => Empty(_compile(arg, at)),
        r'$and' => And(_list(arg, at, op, min: 2)),
        r'$or' => Or(_list(arg, at, op, min: 2)),
        r'$eq' ||
        r'$ne' ||
        r'$gt' ||
        r'$gte' ||
        r'$lt' ||
        r'$lte' => Compare(op.substring(1), _pair(arg, at, op).$1, _pair(arg, at, op).$2),
        r'$in' => In(_pair(arg, at, op).$1, _pair(arg, at, op).$2),
        r'$if' => _if(arg, at),
        r'$match' => _match(arg, at),
        _ => throw ExpressionError(at, "Unknown operator '$op'. Use one of ${Expr.operators.join(', ')}."),
      };
    default:
      throw ExpressionError(pointer, 'Not a JSON value: ${json.runtimeType}.');
  }
}

DataPath _path(Object? arg, String at) {
  if (arg is! String) throw ExpressionError(at, r'$bind takes a path string, such as "data.paging.total".');
  try {
    return DataPath.parse(arg);
  } on ExpressionError catch (e) {
    throw ExpressionError(at, e.message);
  }
}

String _string(Object? arg, String at, String op) =>
    arg is String ? arg : throw ExpressionError(at, '$op takes a string.');

List<Expr> _list(Object? arg, String at, String op, {required int min}) {
  if (arg is! List<Object?> || arg.length < min) throw ExpressionError(at, '$op takes a list of at least $min values.');
  return [for (var i = 0; i < arg.length; i++) _compile(arg[i], '$at/$i')];
}

(Expr, Expr) _pair(Object? arg, String at, String op) {
  if (arg is! List<Object?> || arg.length != 2) throw ExpressionError(at, '$op takes a list of exactly two values.');
  return (_compile(arg[0], '$at/0'), _compile(arg[1], '$at/1'));
}

Expr _if(Object? arg, String at) {
  if (arg is! List<Object?> || arg.length != 3) {
    throw ExpressionError(at, r'$if takes [condition, then, else].');
  }
  return If(_compile(arg[0], '$at/0'), _compile(arg[1], '$at/1'), _compile(arg[2], '$at/2'));
}

Expr _match(Object? arg, String at) {
  if (arg is! List<Object?> || arg.length < 2 || arg.length > 3 || arg[1] is! Map<String, Object?>) {
    throw ExpressionError(at, r'$match takes [value, { case: result }, default].');
  }
  final cases = arg[1]! as Map<String, Object?>;
  return Match(_compile(arg[0], '$at/0'), {
    for (final MapEntry(:key, :value) in cases.entries) key: _compile(value, '$at/1/$key'),
  }, arg.length == 3 ? _compile(arg[2], '$at/2') : const Literal(null));
}

final class Literal extends Expr {
  final Object? value;
  const Literal(this.value);

  @override
  Object? eval(ExprScope scope) => value;

  @override
  Iterable<DataPath> get paths => const [];

  @override
  bool get isLiteral => true;
}

final class ListExpr extends Expr {
  final List<Expr> items;
  const ListExpr(this.items);

  @override
  Object? eval(ExprScope scope) => [for (final item in items) item.eval(scope)];

  @override
  Iterable<DataPath> get paths => items.expand((e) => e.paths);

  @override
  Iterable<Expr> get children => items;
}

final class MapExpr extends Expr {
  final Map<String, Expr> entries;
  const MapExpr(this.entries);

  @override
  Object? eval(ExprScope scope) => {for (final MapEntry(:key, :value) in entries.entries) key: value.eval(scope)};

  @override
  Iterable<DataPath> get paths => entries.values.expand((e) => e.paths);

  @override
  Iterable<Expr> get children => entries.values;
}

final class Bind extends Expr {
  final DataPath path;
  const Bind(this.path);

  @override
  Object? eval(ExprScope scope) => path.readFrom(scope.root(path.root));

  @override
  Iterable<DataPath> get paths => [path];
}

/// One `{{path}}` or `{{path|formatter}}` hole in a `$text` template.
@immutable
final class TextHole {
  final DataPath path;
  final String? formatter;
  const TextHole(this.path, this.formatter);
}

/// `{"$text": "Last run {{data.automation.lastRun|dateTime}}"}`: text with
/// holes. A null value fills its hole with nothing.
final class TextTemplate extends Expr {
  /// Alternating literal text ([String]) and [TextHole]s.
  final List<Object> parts;
  const TextTemplate(this.parts);

  static final _hole = RegExp(r'\{\{\s*([^}|\s]+)\s*(?:\|\s*([A-Za-z][A-Za-z0-9]*)\s*)?\}\}');

  factory TextTemplate.parse(String text, [String pointer = '']) {
    final parts = <Object>[];
    var last = 0;
    for (final match in _hole.allMatches(text)) {
      if (match.start > last) parts.add(text.substring(last, match.start));
      try {
        parts.add(TextHole(DataPath.parse(match.group(1)!), match.group(2)));
      } on ExpressionError catch (e) {
        throw ExpressionError(pointer, e.message);
      }
      last = match.end;
    }
    if (last < text.length) parts.add(text.substring(last));
    if (text.contains('{{') && parts.whereType<TextHole>().isEmpty) {
      throw ExpressionError(pointer, 'A {{ hole holds a path, optionally with |formatter: {{data.total|number}}.');
    }
    return TextTemplate(parts);
  }

  @override
  Object? eval(ExprScope scope) {
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is TextHole) {
        final value = part.path.readFrom(scope.root(part.path.root));
        buffer.write(scope.formatters.format(value, part.formatter));
      } else {
        buffer.write(part);
      }
    }
    return buffer.toString();
  }

  @override
  Iterable<DataPath> get paths => parts.whereType<TextHole>().map((h) => h.path);

  @override
  Iterable<String> get formatterNames => parts.whereType<TextHole>().map((h) => h.formatter).nonNulls;
}

final class Not extends Expr {
  final Expr value;
  const Not(this.value);

  @override
  Iterable<Expr> get children => [value];

  @override
  Object? eval(ExprScope scope) => !isTruthy(value.eval(scope));

  @override
  Iterable<DataPath> get paths => value.paths;
}

final class Empty extends Expr {
  final Expr value;
  const Empty(this.value);

  @override
  Iterable<Expr> get children => [value];

  @override
  Object? eval(ExprScope scope) => isEmptyValue(value.eval(scope));

  @override
  Iterable<DataPath> get paths => value.paths;
}

final class And extends Expr {
  final List<Expr> values;
  const And(this.values);

  @override
  Iterable<Expr> get children => values;

  @override
  Object? eval(ExprScope scope) => values.every((v) => isTruthy(v.eval(scope)));

  @override
  Iterable<DataPath> get paths => values.expand((e) => e.paths);
}

final class Or extends Expr {
  final List<Expr> values;
  const Or(this.values);

  @override
  Iterable<Expr> get children => values;

  @override
  Object? eval(ExprScope scope) => values.any((v) => isTruthy(v.eval(scope)));

  @override
  Iterable<DataPath> get paths => values.expand((e) => e.paths);
}

/// `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte`. Equality is deep for lists and
/// maps. Ordering compares two numbers or two strings, and is false otherwise.
final class Compare extends Expr {
  final String op;
  final Expr left;
  final Expr right;
  const Compare(this.op, this.left, this.right);

  @override
  Iterable<Expr> get children => [left, right];

  @override
  Object? eval(ExprScope scope) {
    final a = left.eval(scope);
    final b = right.eval(scope);
    if (op == 'eq') return jsonEquals(a, b);
    if (op == 'ne') return !jsonEquals(a, b);
    final order = switch ((a, b)) {
      (final num x, final num y) => x.compareTo(y),
      (final String x, final String y) => x.compareTo(y),
      _ => null,
    };
    if (order == null) return false;
    return switch (op) {
      'gt' => order > 0,
      'gte' => order >= 0,
      'lt' => order < 0,
      _ => order <= 0,
    };
  }

  @override
  Iterable<DataPath> get paths => [...left.paths, ...right.paths];
}

/// `{"$in": [x, list]}`: whether the list holds x.
final class In extends Expr {
  final Expr value;
  final Expr list;
  const In(this.value, this.list);

  @override
  Iterable<Expr> get children => [value, list];

  @override
  Object? eval(ExprScope scope) {
    final x = value.eval(scope);
    final items = list.eval(scope);
    return items is List<Object?> && items.any((item) => jsonEquals(item, x));
  }

  @override
  Iterable<DataPath> get paths => [...value.paths, ...list.paths];
}

final class If extends Expr {
  final Expr condition;
  final Expr then;
  final Expr otherwise;
  const If(this.condition, this.then, this.otherwise);

  @override
  Iterable<Expr> get children => [condition, then, otherwise];

  @override
  Object? eval(ExprScope scope) => isTruthy(condition.eval(scope)) ? then.eval(scope) : otherwise.eval(scope);

  @override
  Iterable<DataPath> get paths => [...condition.paths, ...then.paths, ...otherwise.paths];
}

/// `{"$match": [x, {"enabled": "success"}, "neutral"]}`: looks x up by its
/// text form, with a default.
final class Match extends Expr {
  final Expr value;
  final Map<String, Expr> cases;
  final Expr fallback;
  const Match(this.value, this.cases, this.fallback);

  @override
  Iterable<Expr> get children => [value, ...cases.values, fallback];

  @override
  Object? eval(ExprScope scope) {
    final key = value.eval(scope);
    final hit = key == null ? null : cases['$key'];
    return (hit ?? fallback).eval(scope);
  }

  @override
  Iterable<DataPath> get paths => [...value.paths, ...cases.values.expand((e) => e.paths), ...fallback.paths];
}

/// Deep equality over JSON values. Numbers compare by value, so 1 == 1.0.
bool jsonEquals(Object? a, Object? b) {
  if (a is num && b is num) return a == b;
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map<Object?, Object?> && b is Map<Object?, Object?>) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !jsonEquals(a[key], b[key])) return false;
    }
    return true;
  }
  return a == b;
}
