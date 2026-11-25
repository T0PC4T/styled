import 'package:meta/meta.dart';

enum Severity { error, warning }

/// One problem found in a design document, written for a reader that will act
/// on it without asking: where it is, what is wrong, and what would be right.
@immutable
final class Diagnostic {
  /// Stable code, listed in AGENTS.md: `E-prop-unknown`. Codes starting `E-`
  /// are errors, `W-` warnings.
  final String code;
  final Severity severity;

  /// The workspace-relative file, such as `screens/admin/automations.json`.
  final String? file;

  /// JSON pointer inside [file]: `/root/children/0/props/heading`.
  final String? pointer;

  /// The node as `screen#node`, when the problem is in a node.
  final String? node;

  /// One sentence: what is wrong.
  final String message;

  /// What would be right, such as the nearest valid name.
  final String? hint;

  /// The full set of valid values, when it is short.
  final List<String>? allowed;

  const Diagnostic({
    required this.code,
    required this.message,
    this.severity = Severity.error,
    this.file,
    this.pointer,
    this.node,
    this.hint,
    this.allowed,
  });

  /// An error, or a warning when [code] starts with `W-`.
  factory Diagnostic.of(
    String code,
    String message, {
    String? file,
    String? pointer,
    String? node,
    String? hint,
    List<String>? allowed,
  }) => Diagnostic(
    code: code,
    message: message,
    severity: code.startsWith('W-') ? Severity.warning : Severity.error,
    file: file,
    pointer: pointer,
    node: node,
    hint: hint,
    allowed: allowed,
  );

  bool get isError => severity == Severity.error;

  Diagnostic copyWith({String? file, String? node, String? pointer}) => Diagnostic(
    code: code,
    message: message,
    severity: severity,
    file: file ?? this.file,
    pointer: pointer ?? this.pointer,
    node: node ?? this.node,
    hint: hint,
    allowed: allowed,
  );

  Map<String, Object?> toJson() => {
    'code': code,
    'severity': severity.name,
    'file': ?file,
    'pointer': ?pointer,
    'node': ?node,
    'message': message,
    'hint': ?hint,
    'allowed': ?allowed,
  };

  factory Diagnostic.fromJson(Map<String, Object?> json) => Diagnostic(
    code: json['code']! as String,
    severity: Severity.values.byName(json['severity'] as String? ?? 'error'),
    file: json['file'] as String?,
    pointer: json['pointer'] as String?,
    node: json['node'] as String?,
    message: json['message']! as String,
    hint: json['hint'] as String?,
    allowed: (json['allowed'] as List<Object?>?)?.cast<String>(),
  );

  /// One line for a terminal: `screens/a.json /root/props/x  E-code  message  (hint)`.
  @override
  String toString() {
    final where = [?file, ?pointer].join(' ');
    final extra = [?hint, if (allowed != null) 'allowed: ${allowed!.join(', ')}'].join('; ');
    return '${severity.name.padRight(7)} $code  ${where.isEmpty ? '' : '$where  '}$message${extra.isEmpty ? '' : '  ($extra)'}';
  }
}

/// A design document the engine cannot use, at runtime or in a command.
class DesignError implements Exception {
  final String message;
  final List<Diagnostic> diagnostics;
  const DesignError(this.message, [this.diagnostics = const []]);

  @override
  String toString() =>
      diagnostics.isEmpty ? 'DesignError: $message' : 'DesignError: $message\n${diagnostics.join('\n')}';
}

/// Escapes one JSON pointer segment.
String pointerSegment(Object key) => '$key'.replaceAll('~', '~0').replaceAll('/', '~1');

/// The candidate in [options] nearest to [name], when it is close enough to
/// be a likely typo.
String? nearestName(String name, Iterable<String> options) {
  String? best;
  var bestDistance = 1 << 30;
  final lower = name.toLowerCase();
  for (final option in options) {
    final d = _levenshtein(lower, option.toLowerCase());
    if (d < bestDistance) {
      bestDistance = d;
      best = option;
    }
  }
  if (best == null) return null;
  final limit = name.length <= 4 ? 1 : (name.length / 3).ceil();
  final contains = best.toLowerCase().contains(lower) || lower.contains(best.toLowerCase());
  return bestDistance <= limit || contains ? best : null;
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      current[j + 1] = [current[j] + 1, previous[j + 1] + 1, previous[j] + cost].reduce((x, y) => x < y ? x : y);
    }
    previous = current;
  }
  return previous[b.length];
}
