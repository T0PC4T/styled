/// Turns a value into text for a `$text` hole: `{{data.total|number}}`.
typedef DesignFormatter = String Function(Object? value);

/// The formatters a `$text` hole may name. The runtime ships [standard];
/// an app adds its own with [extend].
final class DesignFormatters {
  final Map<String, DesignFormatter> formatters;

  const DesignFormatters(this.formatters);

  static const standard = DesignFormatters({
    'date': _date,
    'dateTime': _dateTime,
    'number': _number,
    'percent': _percent,
    'currency': _currency,
    'count': _count,
    'upper': _upper,
    'lower': _lower,
    'initials': _initials,
  });

  Iterable<String> get names => formatters.keys;

  bool has(String name) => formatters.containsKey(name);

  /// These formatters with [extra] added or replaced.
  DesignFormatters extend(Map<String, DesignFormatter> extra) => DesignFormatters({...formatters, ...extra});

  /// [value] as text, through [formatter] when one is named. Null is empty
  /// text; an unknown formatter falls back to plain text (the validator
  /// reports it).
  String format(Object? value, String? formatter) {
    if (value == null) return '';
    final f = formatter == null ? null : formatters[formatter];
    return f == null ? _plain(value) : f(value);
  }
}

String _plain(Object? value) => switch (value) {
  null => '',
  final double d when d == d.roundToDouble() && d.abs() < 1e15 => d.toInt().toString(),
  _ => '$value',
};

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

DateTime? _parseDate(Object? value) => switch (value) {
  final DateTime d => d,
  final String s => DateTime.tryParse(s),
  final int ms => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
  _ => null,
};

String _two(int n) => n.toString().padLeft(2, '0');

/// `25 Nov 2026`.
String _date(Object? value) {
  final d = _parseDate(value);
  return d == null ? _plain(value) : '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// `25 Nov 2026, 09:00`, in the time zone the value carries.
String _dateTime(Object? value) {
  final d = _parseDate(value);
  return d == null ? _plain(value) : '${_date(d)}, ${_two(d.hour)}:${_two(d.minute)}';
}

/// `1,234` or `1,234.5`.
String _number(Object? value) {
  if (value is! num) return _plain(value);
  final negative = value < 0;
  final text = _plain(value.abs());
  final dot = text.indexOf('.');
  final whole = dot < 0 ? text : text.substring(0, dot);
  final fraction = dot < 0 ? '' : text.substring(dot);
  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
    grouped.write(whole[i]);
  }
  return '${negative ? '-' : ''}$grouped$fraction';
}

/// A fraction as a percentage: 0.25 → `25%`.
String _percent(Object? value) => value is num ? '${_number((value * 100).round())}%' : _plain(value);

/// Pounds with pence: 1234.5 → `£1,234.50`.
String _currency(Object? value) {
  if (value is! num) return _plain(value);
  final pence = (value.abs() * 100).round();
  return '${value < 0 ? '-' : ''}£${_number(pence ~/ 100)}.${_two(pence % 100)}';
}

/// The length of a list or map, or the number itself.
String _count(Object? value) => switch (value) {
  final List<Object?> l => '${l.length}',
  final Map<Object?, Object?> m => '${m.length}',
  final num n => _number(n),
  _ => _plain(value),
};

String _upper(Object? value) => _plain(value).toUpperCase();
String _lower(Object? value) => _plain(value).toLowerCase();

/// `Ada Lovelace` → `AL`.
String _initials(Object? value) =>
    _plain(value).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
