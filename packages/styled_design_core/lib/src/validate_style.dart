part of 'validator.dart';

/// The interaction, application and screen-tier states of preset.schema.json.
const styleStates = [
  'hovered', 'focused', 'pressed', 'error', 'disabled', 'selected', 'active', 'loading', 'approved', //
  'mobile', 'tablet', 'desktop',
];

const _alignments = [
  'topLeft', 'topCenter', 'topRight', 'centerLeft', 'center', 'centerRight', 'bottomLeft', 'bottomCenter', //
  'bottomRight',
];

typedef _Check = void Function(Object? value, String pointer);

/// Checks a Style JSON object as preset.schema.json `$defs/styleWithStates`
/// describes it, Flutter-free: every design value is a token of the right
/// type, every enum one of its values.
final class _StyleCheck {
  final _Validator v;
  final String file;
  _StyleCheck(this.v, this.file);

  void report(String code, String message, String pointer, {String? hint, List<String>? allowed}) =>
      v.report(code, message, file: file, pointer: pointer, hint: hint, allowed: allowed);

  // ------------------------------------------------------------ the groups

  void style(Object? json, String p, {required bool withStates}) {
    final groups = <String, _Check>{
      'box': box,
      'flex': flex,
      'text': text,
      'icon': icon,
      'image': image,
      if (withStates) 'states': states,
    };
    group(json, p, 'A style', groups, minOne: true);
  }

  void states(Object? json, String p) {
    final names = v.catalog.states.isNotEmpty ? v.catalog.states : styleStates;
    group(json, p, 'states', {for (final s in names) s: (value, at) => style(value, at, withStates: false)});
  }

  void box(Object? json, String p) => group(json, p, 'box', {
    'color': color,
    'border': border,
    'padding': insets,
    'margin': insets,
    'boxShadow': boxShadow,
    'width': size,
    'height': size,
    'constraints': (value, at) => group(value, at, 'constraints', {
      'minWidth': size,
      'maxWidth': size,
      'minHeight': size,
      'maxHeight': size,
    }, minOne: true),
    'alignment': enumOf(_alignments),
    'clip': enumOf(const ['none', 'hardEdge', 'antiAlias', 'antiAliasWithSaveLayer']),
    'shape': enumOf(const ['rectangle', 'circle']),
    'transform': (value, at) => group(
      value,
      at,
      'transform',
      {
        'translate': (t, tp) => group(t, tp, 'translate', {'x': token('double'), 'y': token('double')}, minOne: true),
      },
      required: const ['translate'],
    ),
    'motion': (value, at) => group(
      value,
      at,
      'motion',
      {
        'duration': token('duration'),
        'curve': enumOf(const ['linear', 'easeIn', 'easeOut', 'easeInOut', 'easeOutCubic', 'easeInOutCubic']),
      },
      required: const ['duration'],
    ),
  });

  void flex(Object? json, String p) => group(json, p, 'flex', {
    'direction': enumOf(const ['horizontal', 'vertical']),
    'spacing': size,
    'mainAxisAlignment': enumOf(const ['start', 'end', 'center', 'spaceBetween', 'spaceAround', 'spaceEvenly']),
    'crossAxisAlignment': enumOf(const ['start', 'end', 'center', 'stretch', 'baseline']),
    'mainAxisSize': enumOf(const ['min', 'max']),
  });

  void text(Object? json, String p) => group(json, p, 'text', {
    'color': color,
    'fontFamily': token('string'),
    'fontSize': token('double'),
    'fontWeight': token('fontWeight'),
    'letterSpacing': token('double'),
    'height': token('double'),
    'textAlign': enumOf(const ['left', 'right', 'center', 'justify', 'start', 'end']),
    'maxLines': (value, at) {
      if (value is! int || value < 1) {
        report(
          'E-style-value',
          'maxLines is a whole number of 1 or more, not ${_jsonKindOf(value)}.',
          at,
          hint: 'Write a whole number such as 2.',
        );
      }
    },
    'overflow': enumOf(const ['clip', 'fade', 'ellipsis', 'visible']),
    'softWrap': (value, at) {
      if (value is! bool) report('E-style-value', 'softWrap is true or false.', at);
    },
    'fontStyle': enumOf(const ['normal', 'italic']),
    'decoration': enumOf(const ['none', 'underline', 'overline', 'lineThrough']),
    'decorationColor': color,
  });

  void icon(Object? json, String p) => group(json, p, 'icon', {'color': color, 'size': token('double')});

  void image(Object? json, String p) => group(json, p, 'image', {
    'fit': enumOf(const ['fill', 'contain', 'cover', 'fitWidth', 'fitHeight', 'none', 'scaleDown']),
    'width': size,
    'height': size,
  });

  // ---------------------------------------------------------- compound values

  void insets(Object? json, String p) {
    if (json is num) {
      report(
        'E-style-raw',
        'Insets take token keys, not the raw number $json.',
        p,
        hint: 'Write {"all": "${nearestTokenFor(json, 'double') ?? 'paddingSm'}"}.',
      );
      return;
    }
    if (json is String) {
      report('E-style-value', 'Insets are an object of sides, not text.', p, hint: 'Write {"all": "$json"}.');
      return;
    }
    group(json, p, 'Insets', {
      for (final side in const ['all', 'horizontal', 'vertical', 'left', 'top', 'right', 'bottom']) side: size,
    }, minOne: true);
    if (json is! Map<String, Object?>) return;
    final keys = json.keys.toSet();
    final symmetric = keys.intersection(const {'horizontal', 'vertical'});
    final only = keys.intersection(const {'left', 'top', 'right', 'bottom'});
    if (keys.contains('all') && keys.length > 1) {
      report(
        'E-style-value',
        "Insets with 'all' take no other side.",
        p,
        hint: 'Write all alone, or horizontal/vertical, or left/top/right/bottom.',
      );
    } else if (symmetric.isNotEmpty && only.isNotEmpty) {
      report(
        'E-style-value',
        'Insets mix horizontal/vertical with single sides (${only.join(', ')}).',
        p,
        hint: 'Write horizontal/vertical, or left/top/right/bottom, not both.',
      );
    }
  }

  void border(Object? json, String p) {
    group(json, p, 'border', {
      'none': (value, at) {
        if (value != true) report('E-style-value', 'border.none is true, or left out.', at);
      },
      'color': color,
      'width': size,
      'radius': size,
      for (final side in const ['top', 'right', 'bottom', 'left'])
        side: (value, at) => group(value, at, 'A border side', {'color': color, 'width': size}),
    }, minOne: true);
    // StyledBorder.none keeps an optional radius, so `none` combines with
    // `radius` and nothing else (the codec decodes exactly this).
    if (json is Map<String, Object?> &&
        json.containsKey('none') &&
        json.keys.any((k) => k != 'none' && k != 'radius')) {
      report(
        'E-style-value',
        'border.none removes the border, so it takes no other field than radius.',
        p,
        hint: 'Write {"none": true} with at most a radius, or drop none.',
      );
    }
  }

  void boxShadow(Object? json, String p) {
    if (json is! List<Object?>) {
      report(
        'E-style-value',
        'boxShadow is a list of {color, level}; an empty list removes the shadow.',
        p,
        hint: 'Write [{"color": "shadow", "level": "shadowSm"}].',
      );
      return;
    }
    for (var i = 0; i < json.length; i++) {
      group(
        json[i],
        '$p/$i',
        'A shadow',
        {'color': color, 'level': token('shadow')},
        required: const ['color', 'level'],
      );
    }
  }

  // ------------------------------------------------------------- leaf values

  /// A colour token, or {"alpha": [colour token, double token]}.
  void color(Object? json, String p) {
    if (json is Map<String, Object?>) {
      group(
        json,
        p,
        'A colour',
        {
          'alpha': (value, at) {
            if (value is! List<Object?> || value.length != 2) {
              report(
                'E-style-value',
                'alpha is [colour token, opacity token].',
                at,
                hint: 'Write {"alpha": ["primary", "opacityFaint"]}.',
              );
              return;
            }
            token('color')(value[0], '$at/0');
            token('double')(value[1], '$at/1');
          },
        },
        required: const ['alpha'],
      );
      return;
    }
    token('color')(json, p);
  }

  /// A double token, or {"const": "infinity" | "zero"}.
  void size(Object? json, String p) {
    if (json is Map<String, Object?>) {
      group(
        json,
        p,
        'A size',
        {
          'const': enumOf(const ['infinity', 'zero']),
        },
        required: const ['const'],
      );
      return;
    }
    token('double')(json, p);
  }

  _Check enumOf(List<String> values) => (value, p) {
    if (value is String && values.contains(value)) return;
    report(
      'E-style-value',
      value is String
          ? "'$value' is not one of the allowed values."
          : 'Write one of the allowed names, not ${_jsonKindOf(value)}.',
      p,
      hint: value is String ? didYouMean(value, values) : null,
      allowed: shortList(values),
    );
  };

  /// A token key of [type].
  _Check token(String type) => (value, p) {
    if (value is num) {
      final near = nearestTokenFor(value, type);
      report(
        'E-style-raw',
        'A style takes a $type token key, not the raw number $value.',
        p,
        hint: near != null ? "Use the token '$near', whose light value is $value." : "Use a $type token key.",
        allowed: shortList(v.tokensOfType(type)),
      );
      return;
    }
    if (value is String && value.startsWith('#')) {
      final near = nearestTokenFor(value, type);
      report(
        'E-style-raw',
        type == 'color'
            ? "A style takes a colour token key, not the raw colour '$value'."
            : "A style takes a $type token key, not '$value'.",
        p,
        hint: near != null
            ? "Use the token '$near', whose light value is $value."
            : "Use a $type token key, or add one with design new token.",
      );
      return;
    }
    if (value is! String || !tokenKeyPattern.hasMatch(value)) {
      report('E-style-value', 'A style takes a $type token key here, not ${_jsonKindOf(value)}.', p);
      return;
    }
    final actual = v.tokens[value];
    if (actual == null) {
      report(
        'E-token-unknown',
        "There is no token '$value'.",
        p,
        hint: didYouMean(value, v.tokensOfType(type)) ?? didYouMean(value, v.tokens.keys),
        allowed: shortList(v.tokensOfType(type)),
      );
      return;
    }
    v.usedTokens.add(value);
    if (actual != type) {
      report(
        'E-style-token-type',
        "'$value' is a $actual token; this field takes a $type token.",
        p,
        hint: didYouMean(value, v.tokensOfType(type)),
        allowed: shortList(v.tokensOfType(type)),
      );
    }
  };

  /// A token of [type] whose light value equals [raw], to suggest in place of it.
  String? nearestTokenFor(Object raw, String type) {
    for (final MapEntry(:key, value: light) in v.lightValues.entries) {
      if (v.tokens[key] != type) continue;
      if (light is num && raw is num && light == raw) return key;
      if (light is String && raw is String && light.toLowerCase() == raw.toLowerCase()) return key;
    }
    return null;
  }

  /// An object with only the [fields] given, each checked by its function.
  void group(
    Object? json,
    String p,
    String what,
    Map<String, _Check> fields, {
    bool minOne = false,
    List<String> required = const [],
  }) {
    if (json is! Map<String, Object?>) {
      report(
        json is num ? 'E-style-raw' : 'E-style-value',
        '$what is an object with ${fields.keys.take(6).join(', ')}${fields.length > 6 ? ', ...' : ''}; not ${_jsonKindOf(json)}.',
        p,
        allowed: shortList(fields.keys),
      );
      return;
    }
    if (minOne && json.isEmpty) {
      report(
        'E-style-value',
        '$what is empty.',
        p,
        hint: 'Give at least one of ${fields.keys.join(', ')}, or remove it.',
      );
    }
    for (final key in required) {
      if (!json.containsKey(key)) report('E-style-value', "$what needs '$key'.", p, hint: "Add '$key'.");
    }
    for (final MapEntry(:key, :value) in json.entries) {
      final at = '$p/${pointerSegment(key)}';
      final check = fields[key];
      if (check == null) {
        report(
          'E-style-field',
          "$what has no field '$key'.",
          at,
          hint: didYouMean(key, fields.keys),
          allowed: shortList(fields.keys),
        );
      } else {
        check(value, at);
      }
    }
  }
}
