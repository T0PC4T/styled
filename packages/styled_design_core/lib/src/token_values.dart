import 'dart:convert';

/// The token types a token document may declare.
const tokenTypes = ['color', 'double', 'duration', 'fontWeight', 'string', 'shadow'];

final _hexColor = RegExp(r'^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$');
final _fontWeight = RegExp(r'^w[1-9]00$');
final tokenKeyPattern = RegExp(r'^[a-z][A-Za-z0-9]*$');

/// An example value of each token type, for messages.
const tokenTypeExamples = {
  'color': '"#59B0E3"',
  'double': '8',
  'duration': '200',
  'fontWeight': '"w600"',
  'string': '"Inter"',
  'shadow': '{"opacity": 0.04, "blurRadius": 10, "dy": 2}',
};

/// Why [value] is not a value of token [type], as one sentence, or null when
/// it fits. Follows tokens.schema.json: color #RRGGBB or #AARRGGBB, double a
/// number, duration whole milliseconds, fontWeight w100..w900, string text,
/// shadow an object with opacity and blurRadius.
String? tokenValueProblem(String type, Object? value) {
  switch (type) {
    case 'color':
      return value is String && _hexColor.hasMatch(value)
          ? null
          : 'A color token value is #RRGGBB or #AARRGGBB, not ${_show(value)}.';
    case 'double':
      return value is num ? null : 'A double token value is a number, not ${_show(value)}.';
    case 'duration':
      return value is num && value == value.roundToDouble() && value >= 0
          ? null
          : 'A duration token value is whole milliseconds, such as 200, not ${_show(value)}.';
    case 'fontWeight':
      return value is String && _fontWeight.hasMatch(value)
          ? null
          : 'A fontWeight token value is w100..w900, not ${_show(value)}.';
    case 'string':
      return value is String ? null : 'A string token value is text, not ${_show(value)}.';
    case 'shadow':
      if (value is! Map<String, Object?>) {
        return 'A shadow token value is an object such as ${tokenTypeExamples['shadow']}, not ${_show(value)}.';
      }
      const fields = {'opacity', 'blurRadius', 'spreadRadius', 'dx', 'dy'};
      for (final key in value.keys) {
        if (!fields.contains(key)) return "A shadow has no field '$key'; it takes ${fields.join(', ')}.";
      }
      for (final key in const ['opacity', 'blurRadius']) {
        if (!value.containsKey(key)) return "A shadow needs '$key'.";
      }
      for (final MapEntry(:key, value: v) in value.entries) {
        if (v is! num) return "A shadow's '$key' is a number, not ${_show(v)}.";
      }
      final opacity = value['opacity']! as num;
      if (opacity < 0 || opacity > 1) return "A shadow's opacity is between 0 and 1, not $opacity.";
      if ((value['blurRadius']! as num) < 0) return "A shadow's blurRadius is 0 or more.";
      return null;
    default:
      return "'$type' is not a token type; use one of ${tokenTypes.join(', ')}.";
  }
}

/// Reads a value typed on the command line as a token value of [type]:
/// numbers for double and duration, JSON for shadow, text otherwise.
Object? parseTokenLiteral(String type, String text) => switch (type) {
  'double' => num.tryParse(text) ?? text,
  'duration' => int.tryParse(text) ?? num.tryParse(text) ?? text,
  'shadow' => _tryJson(text),
  _ => text,
};

Object? _tryJson(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return text;
  }
}

String _show(Object? value) => switch (value) {
  null => 'null',
  final String s => '"$s"',
  num() || bool() => '$value',
  List<Object?>() => 'a list',
  _ => 'an object',
};
