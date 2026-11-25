import 'diagnostics.dart';
import 'expressions.dart';

/// The value at JSON [pointer] inside [root], or null when there is none.
Object? jsonAt(Object? root, String pointer) {
  if (pointer.isEmpty) return root;
  var current = root;
  for (final raw in pointer.substring(1).split('/')) {
    final segment = raw.replaceAll('~1', '/').replaceAll('~0', '~');
    current = switch (current) {
      final Map<String, Object?> map => map[segment],
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

/// A deep, mutable copy of a JSON value.
Object? deepCopyJson(Object? value) => switch (value) {
  final Map<String, Object?> map => <String, Object?>{
    for (final MapEntry(:key, :value) in map.entries) key: deepCopyJson(value),
  },
  final List<Object?> list => <Object?>[for (final item in list) deepCopyJson(item)],
  _ => value,
};

/// Compares two JSON pointers segment by segment, numbers by value, so
/// `/children/2` sorts before `/children/10`.
int comparePointers(String? a, String? b) {
  if (a == b) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  final x = a.isEmpty ? const <String>[] : a.substring(1).split('/');
  final y = b.isEmpty ? const <String>[] : b.substring(1).split('/');
  for (var i = 0; i < x.length && i < y.length; i++) {
    final m = int.tryParse(x[i]);
    final n = int.tryParse(y[i]);
    final c = (m != null && n != null) ? m.compareTo(n) : x[i].compareTo(y[i]);
    if (c != 0) return c;
  }
  return x.length.compareTo(y.length);
}

/// Sorts diagnostics by file, then pointer, then code, and drops exact repeats.
List<Diagnostic> sortDiagnostics(Iterable<Diagnostic> diagnostics) {
  final seen = <String>{};
  final unique = [
    for (final d in diagnostics)
      if (seen.add('${d.code}|${d.file}|${d.pointer}|${d.node}|${d.message}')) d,
  ];
  unique.sort((a, b) {
    final f = (a.file ?? '￿').compareTo(b.file ?? '￿');
    if (f != 0) return f;
    final p = comparePointers(a.pointer, b.pointer);
    if (p != 0) return p;
    return a.code.compareTo(b.code);
  });
  return unique;
}

/// One path an expression reads, where it is written, and the formatter of
/// its `$text` hole, if any.
typedef PathRef = ({String pointer, DataPath path, String? formatter});

/// Every path read by the raw expression JSON [value] written at [pointer]:
/// `$bind` paths and `$text` holes, at any depth. Malformed parts (reported
/// by the parser) are skipped.
Iterable<PathRef> pathRefs(Object? value, String pointer) sync* {
  switch (value) {
    case final List<Object?> list:
      for (var i = 0; i < list.length; i++) {
        yield* pathRefs(list[i], '$pointer/$i');
      }
    case final Map<String, Object?> map:
      final ops = map.keys.where((k) => k.startsWith(r'$')).toList();
      if (ops.isEmpty) {
        for (final MapEntry(:key, :value) in map.entries) {
          yield* pathRefs(value, '$pointer/${pointerSegment(key)}');
        }
        return;
      }
      if (map.length != 1) return;
      final op = ops.single;
      final arg = map[op];
      final at = '$pointer/${pointerSegment(op)}';
      if (op == r'$bind') {
        if (arg is String) {
          try {
            yield (pointer: at, path: DataPath.parse(arg), formatter: null);
          } on ExpressionError {
            // Reported by the parser.
          }
        }
      } else if (op == r'$text') {
        if (arg is String) {
          try {
            for (final hole in TextTemplate.parse(arg).parts.whereType<TextHole>()) {
              yield (pointer: at, path: hole.path, formatter: hole.formatter);
            }
          } on ExpressionError {
            // Reported by the parser.
          }
        }
      } else {
        yield* pathRefs(arg, at);
      }
    default:
      return;
  }
}

/// Whether the raw JSON [value] is an expression object: one `$` key.
bool isExpressionJson(Object? value) =>
    value is Map<String, Object?> && value.length == 1 && value.keys.single.startsWith(r'$');

/// Whether the raw JSON [value] holds an expression anywhere inside.
bool containsExpression(Object? value) => switch (value) {
  final Map<String, Object?> map => map.keys.any((k) => k.startsWith(r'$')) || map.values.any(containsExpression),
  final List<Object?> list => list.any(containsExpression),
  _ => false,
};

/// "Did you mean 'x'?" for the option nearest to [name], or null.
String? didYouMean(String name, Iterable<String> options, {String Function(String)? show}) {
  final near = nearestName(name, options);
  if (near == null || near == name) return null;
  return "Did you mean '${show == null ? near : show(near)}'?";
}

/// [options] when there are at most 12, for a diagnostic's `allowed`.
List<String>? shortList(Iterable<String> options) {
  final list = options.toList();
  return list.isEmpty || list.length > 12 ? null : list;
}

/// A screen title from the last segment of an id: automationEditor → Automation editor.
String titleFromId(String id) {
  final last = id.split('.').last;
  final words = last.replaceAllMapped(RegExp('[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}').trim();
  return words.isEmpty ? id : '${words[0].toUpperCase()}${words.substring(1)}';
}
