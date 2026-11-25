part of 'style.dart';

// The JSON form of a [Style]: the `styleWithStates` definition of the design
// engine's preset schema. Every design value is a token key; the decoder
// checks each token's type itself, because `StyledTheme.get` silently falls
// back to a token's default when the stored value has the wrong type.

/// Finds the design token for a key while decoding a style.
abstract interface class StyleTokenLookup {
  /// The token stored under [key], or null when there is none.
  ThemeToken<Object?>? token(String key);
}

/// A JSON style that cannot be decoded or encoded.
class StyleJsonError implements Exception {
  /// JSON pointer to the offending value, relative to the style object, such
  /// as `/box/border/color`. Empty for the style object itself.
  final String path;

  /// What is wrong, in one sentence.
  final String message;

  const StyleJsonError(this.path, this.message);

  @override
  String toString() => path.isEmpty ? 'StyleJsonError: $message' : 'StyleJsonError at $path: $message';
}

// Field names in schema order. The encoder emits keys in this order.
const _styleFields = ['box', 'flex', 'text', 'icon', 'image'];
const _styleWithStatesFields = [..._styleFields, 'states'];
const _boxFields = [
  'color',
  'border',
  'padding',
  'margin',
  'boxShadow',
  'width',
  'height',
  'constraints',
  'alignment',
  'clip',
  'shape',
  'transform',
  'motion',
];
const _flexFields = ['direction', 'spacing', 'mainAxisAlignment', 'crossAxisAlignment', 'mainAxisSize'];
const _textFields = [
  'color',
  'fontFamily',
  'fontSize',
  'fontWeight',
  'letterSpacing',
  'height',
  'textAlign',
  'maxLines',
  'overflow',
  'softWrap',
  'fontStyle',
  'decoration',
  'decorationColor',
];
const _iconFields = ['color', 'size'];
const _imageFields = ['fit', 'width', 'height'];
const _borderFields = ['none', 'color', 'width', 'radius', 'top', 'right', 'bottom', 'left'];
const _borderSideFields = ['color', 'width'];
const _insetsFields = ['all', 'horizontal', 'vertical', 'left', 'top', 'right', 'bottom'];
const _symmetricFields = ['horizontal', 'vertical'];
const _onlyFields = ['left', 'top', 'right', 'bottom'];
const _constraintsFields = ['minWidth', 'maxWidth', 'minHeight', 'maxHeight'];
const _shadowFields = ['color', 'level'];
const _transformFields = ['translate'];
const _translateFields = ['x', 'y'];
const _motionFields = ['duration', 'curve'];

/// State names the schema lists, in the order the encoder emits them. Other
/// states follow in alphabetical order.
const _schemaStates = [
  'hovered',
  'focused',
  'pressed',
  'error',
  'disabled',
  'selected',
  'active',
  'loading',
  'approved',
  'mobile',
  'tablet',
  'desktop',
];
final _stateName = RegExp(r'^[a-z][A-Za-z0-9]*$');

const _alignments = <String, Alignment>{
  'topLeft': Alignment.topLeft,
  'topCenter': Alignment.topCenter,
  'topRight': Alignment.topRight,
  'centerLeft': Alignment.centerLeft,
  'center': Alignment.center,
  'centerRight': Alignment.centerRight,
  'bottomLeft': Alignment.bottomLeft,
  'bottomCenter': Alignment.bottomCenter,
  'bottomRight': Alignment.bottomRight,
};
const _clips = <String, Clip>{
  'none': Clip.none,
  'hardEdge': Clip.hardEdge,
  'antiAlias': Clip.antiAlias,
  'antiAliasWithSaveLayer': Clip.antiAliasWithSaveLayer,
};
const _shapes = <String, BoxShape>{'rectangle': BoxShape.rectangle, 'circle': BoxShape.circle};
const _axes = <String, Axis>{'horizontal': Axis.horizontal, 'vertical': Axis.vertical};
const _mainAxisAlignments = <String, MainAxisAlignment>{
  'start': MainAxisAlignment.start,
  'end': MainAxisAlignment.end,
  'center': MainAxisAlignment.center,
  'spaceBetween': MainAxisAlignment.spaceBetween,
  'spaceAround': MainAxisAlignment.spaceAround,
  'spaceEvenly': MainAxisAlignment.spaceEvenly,
};
const _crossAxisAlignments = <String, CrossAxisAlignment>{
  'start': CrossAxisAlignment.start,
  'end': CrossAxisAlignment.end,
  'center': CrossAxisAlignment.center,
  'stretch': CrossAxisAlignment.stretch,
  'baseline': CrossAxisAlignment.baseline,
};
const _mainAxisSizes = <String, MainAxisSize>{'min': MainAxisSize.min, 'max': MainAxisSize.max};
const _textAligns = <String, TextAlign>{
  'left': TextAlign.left,
  'right': TextAlign.right,
  'center': TextAlign.center,
  'justify': TextAlign.justify,
  'start': TextAlign.start,
  'end': TextAlign.end,
};
const _overflows = <String, TextOverflow>{
  'clip': TextOverflow.clip,
  'fade': TextOverflow.fade,
  'ellipsis': TextOverflow.ellipsis,
  'visible': TextOverflow.visible,
};
const _fontStyles = <String, FontStyle>{'normal': FontStyle.normal, 'italic': FontStyle.italic};
const _decorations = <String, TextDecoration>{
  'none': TextDecoration.none,
  'underline': TextDecoration.underline,
  'overline': TextDecoration.overline,
  'lineThrough': TextDecoration.lineThrough,
};
const _fits = <String, BoxFit>{
  'fill': BoxFit.fill,
  'contain': BoxFit.contain,
  'cover': BoxFit.cover,
  'fitWidth': BoxFit.fitWidth,
  'fitHeight': BoxFit.fitHeight,
  'none': BoxFit.none,
  'scaleDown': BoxFit.scaleDown,
};
const _curves = <String, Curve>{
  'linear': Curves.linear,
  'easeIn': Curves.easeIn,
  'easeOut': Curves.easeOut,
  'easeInOut': Curves.easeInOut,
  'easeOutCubic': Curves.easeOutCubic,
  'easeInOutCubic': Curves.easeInOutCubic,
};

/// The curve of a motion that does not name one, per the schema's default.
const _defaultCurve = Curves.easeOutCubic;

/// [path] extended by one JSON pointer segment.
String _at(String path, Object segment) => '$path/${'$segment'.replaceAll('~', '~0').replaceAll('/', '~1')}';

String _describe(Object? json) => switch (json) {
  String() => '"$json"',
  null || num() || bool() => '$json',
  List() => 'a list',
  Map() when _asObject(json) == null => 'a map with a non-string key',
  Map() => 'an object',
  _ => 'a ${json.runtimeType}',
};

String _quoted(Iterable<String> names) => names.map((name) => '"$name"').join(', ');

/// [json] as a JSON object, a map whose keys are all strings, or null.
Map<String, Object?>? _asObject(Object? json) => switch (json) {
  Map<String, Object?>() => json,
  Map() when json.keys.every((key) => key is String) => json.cast<String, Object?>(),
  _ => null,
};

/// [json] as an object whose keys are all in [fields].
Map<String, Object?> _object(Object? json, String path, List<String> fields) {
  final object = _asObject(json);
  if (object == null) throw StyleJsonError(path, 'Expected an object, found ${_describe(json)}.');
  for (final key in object.keys) {
    if (!fields.contains(key)) {
      throw StyleJsonError(_at(path, key), 'Unknown field "$key"; expected one of ${_quoted(fields)}.');
    }
  }
  return object;
}

/// The value of the required field [key] in [object].
Object? _required(Map<String, Object?> object, String path, String key) {
  if (!object.containsKey(key)) throw StyleJsonError(path, 'Missing required field "$key".');
  return object[key];
}

T _enum<T>(Object? json, String path, Map<String, T> names) {
  final value = json is String ? names[json] : null;
  if (value == null) throw StyleJsonError(path, 'Expected one of ${_quoted(names.keys)}, found ${_describe(json)}.');
  return value;
}

String _name<T>(T value, Map<String, T> names, String path) {
  for (final MapEntry(:key, value: named) in names.entries) {
    if (named == value) return key;
  }
  throw StyleJsonError(path, '$value has no JSON form; the schema allows only ${_quoted(names.keys)}.');
}

int _compareStates(String a, String b) {
  int rank(String name) {
    final index = _schemaStates.indexOf(name);
    return index < 0 ? _schemaStates.length : index;
  }

  final byRank = rank(a).compareTo(rank(b));
  return byRank != 0 ? byRank : a.compareTo(b);
}

final class _StyleJsonDecoder {
  final StyleTokenLookup tokens;

  const _StyleJsonDecoder(this.tokens);

  Style style(Object? json, String path, {bool inState = false}) {
    if (inState && (_asObject(json)?.containsKey('states') ?? false)) {
      throw StyleJsonError(_at(path, 'states'), 'A state style cannot have states of its own.');
    }
    final object = _object(json, path, inState ? _styleFields : _styleWithStatesFields);
    T? field<T>(String key, T Function(Object? json, String path) read) =>
        object.containsKey(key) ? read(object[key], _at(path, key)) : null;

    final box = field('box', this.box);
    final flex = field('flex', this.flex);
    final text = field('text', this.text);
    final icon = field('icon', this.icon);
    final image = field('image', this.image);
    final states = field('states', this.states);
    return Style(
      box: box ?? const BoxStyle(),
      text: text ?? const StyledTextStyle(),
      icon: icon ?? const IconStyle(),
      flex: flex ?? const FlexStyle(),
      image: image ?? const ImageStyle(),
      states: states ?? const {},
    );
  }

  /// Each state's override, built as `Style.on` builds it: one style per
  /// state, without nested states.
  Map<StyleState, Style> states(Object? json, String path) {
    final object = _asObject(json);
    if (object == null) throw StyleJsonError(path, 'Expected an object, found ${_describe(json)}.');
    if (object.isEmpty) return const {};
    return Map.unmodifiable({
      for (final MapEntry(:key, :value) in object.entries)
        StyleState(_stateKey(key, _at(path, key))): style(value, _at(path, key), inState: true),
    });
  }

  String _stateKey(String key, String path) {
    if (_stateName.hasMatch(key)) return key;
    throw StyleJsonError(
      path,
      'State name "$key" must start with a lowercase letter and contain only letters and digits.',
    );
  }

  BoxStyle box(Object? json, String path) {
    final object = _object(json, path, _boxFields);
    T? field<T>(String key, T Function(Object? json, String path) read) =>
        object.containsKey(key) ? read(object[key], _at(path, key)) : null;

    return BoxStyle(
      color: field('color', color),
      border: field('border', border),
      padding: field('padding', insets),
      margin: field('margin', insets),
      boxShadow: field('boxShadow', shadows),
      width: field('width', size),
      height: field('height', size),
      constraints: field('constraints', constraints),
      alignment: field('alignment', (json, path) => _enum(json, path, _alignments)),
      clip: field('clip', (json, path) => _enum(json, path, _clips)),
      shape: field('shape', (json, path) => _enum(json, path, _shapes)),
      transform: field('transform', transform),
      motion: field('motion', motion),
    );
  }

  FlexStyle flex(Object? json, String path) {
    final object = _object(json, path, _flexFields);
    T? field<T>(String key, T Function(Object? json, String path) read) =>
        object.containsKey(key) ? read(object[key], _at(path, key)) : null;

    return FlexStyle(
      direction: field('direction', (json, path) => _enum(json, path, _axes)),
      spacing: field('spacing', size),
      mainAxisAlignment: field('mainAxisAlignment', (json, path) => _enum(json, path, _mainAxisAlignments)),
      crossAxisAlignment: field('crossAxisAlignment', (json, path) => _enum(json, path, _crossAxisAlignments)),
      mainAxisSize: field('mainAxisSize', (json, path) => _enum(json, path, _mainAxisSizes)),
    );
  }

  StyledTextStyle text(Object? json, String path) {
    final object = _object(json, path, _textFields);
    T? field<T>(String key, T Function(Object? json, String path) read) =>
        object.containsKey(key) ? read(object[key], _at(path, key)) : null;

    return StyledTextStyle(
      color: field('color', color),
      fontFamily: field('fontFamily', (json, path) => token<String>(json, path, 'a font family')),
      fontSize: field('fontSize', (json, path) => token<double>(json, path, 'a font size')),
      fontWeight: field('fontWeight', (json, path) => token<FontWeight>(json, path, 'a font weight')),
      letterSpacing: field('letterSpacing', (json, path) => token<double>(json, path, 'a letter spacing')),
      height: field('height', (json, path) => token<double>(json, path, 'a line height')),
      textAlign: field('textAlign', (json, path) => _enum(json, path, _textAligns)),
      maxLines: field('maxLines', maxLines),
      overflow: field('overflow', (json, path) => _enum(json, path, _overflows)),
      softWrap: field('softWrap', boolean),
      fontStyle: field('fontStyle', (json, path) => _enum(json, path, _fontStyles)),
      decoration: field('decoration', (json, path) => _enum(json, path, _decorations)),
      decorationColor: field('decorationColor', color),
    );
  }

  IconStyle icon(Object? json, String path) {
    final object = _object(json, path, _iconFields);
    T? field<T>(String key, T Function(Object? json, String path) read) =>
        object.containsKey(key) ? read(object[key], _at(path, key)) : null;

    return IconStyle(
      color: field('color', color),
      size: field('size', (json, path) => token<double>(json, path, 'an icon size')),
    );
  }

  ImageStyle image(Object? json, String path) {
    final object = _object(json, path, _imageFields);
    T? field<T>(String key, T Function(Object? json, String path) read) =>
        object.containsKey(key) ? read(object[key], _at(path, key)) : null;

    return ImageStyle(
      fit: field('fit', (json, path) => _enum(json, path, _fits)),
      width: field('width', size),
      height: field('height', size),
    );
  }

  /// `{"none": true}` is [StyledBorder.none]; anything else is a field-by-field
  /// [StyledBorder], which merges like [StyledBorder.all] when it has no sides.
  StyledBorder border(Object? json, String path) {
    final object = _object(json, path, _borderFields);
    T? field<T>(String key, T Function(Object? json, String path) read) =>
        object.containsKey(key) ? read(object[key], _at(path, key)) : null;

    if (object.containsKey('none')) {
      if (object['none'] != true) {
        throw StyleJsonError(_at(path, 'none'), 'Expected true, found ${_describe(object['none'])}.');
      }
      for (final key in object.keys) {
        if (key != 'none' && key != 'radius') {
          throw StyleJsonError(path, 'A border with "none" can only also set "radius", not "$key".');
        }
      }
      return StyledBorder.none(radius: field('radius', size));
    }
    return StyledBorder(
      color: field('color', color),
      width: field('width', size),
      radius: field('radius', size),
      top: field('top', borderSide),
      right: field('right', borderSide),
      bottom: field('bottom', borderSide),
      left: field('left', borderSide),
    );
  }

  StyledBorderSide borderSide(Object? json, String path) {
    final object = _object(json, path, _borderSideFields);
    T? field<T>(String key, T Function(Object? json, String path) read) =>
        object.containsKey(key) ? read(object[key], _at(path, key)) : null;

    return StyledBorderSide(color: field('color', color), width: field('width', size));
  }

  StyledEdgeInsets insets(Object? json, String path) {
    final object = _object(json, path, _insetsFields);
    T? field<T>(String key, T Function(Object? json, String path) read) =>
        object.containsKey(key) ? read(object[key], _at(path, key)) : null;

    final symmetric = object.keys.where(_symmetricFields.contains);
    final only = object.keys.where(_onlyFields.contains);
    if (object.containsKey('all')) {
      final other = object.keys.where((key) => key != 'all');
      if (other.isNotEmpty) throw StyleJsonError(path, 'Insets cannot combine "all" with "${other.first}".');
      return StyledEdgeInsets.all(field('all', size)!);
    }
    if (symmetric.isNotEmpty) {
      if (only.isNotEmpty) {
        throw StyleJsonError(path, 'Insets cannot combine "${symmetric.first}" with "${only.first}".');
      }
      return StyledEdgeInsets.symmetric(horizontal: field('horizontal', size), vertical: field('vertical', size));
    }
    return StyledEdgeInsets.only(
      left: field('left', size),
      top: field('top', size),
      right: field('right', size),
      bottom: field('bottom', size),
    );
  }

  StyledBoxConstraints constraints(Object? json, String path) {
    final object = _object(json, path, _constraintsFields);
    T? field<T>(String key, T Function(Object? json, String path) read) =>
        object.containsKey(key) ? read(object[key], _at(path, key)) : null;

    return StyledBoxConstraints(
      minWidth: field('minWidth', size),
      maxWidth: field('maxWidth', size),
      minHeight: field('minHeight', size),
      maxHeight: field('maxHeight', size),
    );
  }

  /// An empty list stays empty: merged over a style, it removes the shadow.
  List<StyledBoxShadow> shadows(Object? json, String path) {
    if (json is! List<Object?>) throw StyleJsonError(path, 'Expected a list, found ${_describe(json)}.');
    return List.unmodifiable([for (var i = 0; i < json.length; i++) shadow(json[i], _at(path, i))]);
  }

  StyledBoxShadow shadow(Object? json, String path) {
    final object = _object(json, path, _shadowFields);
    final shadowColor = color(_required(object, path, 'color'), _at(path, 'color'));
    final level = token<ShadowLevel>(_required(object, path, 'level'), _at(path, 'level'), 'a shadow level');
    return StyledBoxShadow.level(shadowColor, level);
  }

  StyledTransform transform(Object? json, String path) {
    final object = _object(json, path, _transformFields);
    final translatePath = _at(path, 'translate');
    final translate = _object(_required(object, path, 'translate'), translatePath, _translateFields);
    T? field<T>(String key, T Function(Object? json, String path) read) =>
        translate.containsKey(key) ? read(translate[key], _at(translatePath, key)) : null;

    return StyledTransform.translate(
      x: field('x', (json, path) => token<double>(json, path, 'a translation')),
      y: field('y', (json, path) => token<double>(json, path, 'a translation')),
    );
  }

  Motion motion(Object? json, String path) {
    final object = _object(json, path, _motionFields);
    final duration = token<Duration>(_required(object, path, 'duration'), _at(path, 'duration'), 'a duration');
    final curve = object.containsKey('curve') ? _enum(object['curve'], _at(path, 'curve'), _curves) : _defaultCurve;
    return Motion(duration, curve);
  }

  /// A colour token key, or `{"alpha": [colourKey, opacityKey]}`.
  StyleValue<Color> color(Object? json, String path) {
    if (json is String) return token<Color>(json, path, 'a colour');
    if (json is Map) {
      final object = _object(json, path, const ['alpha']);
      final alphaPath = _at(path, 'alpha');
      final alpha = _required(object, path, 'alpha');
      if (alpha is! List<Object?> || alpha.length != 2) {
        throw StyleJsonError(alphaPath, 'Expected a list of a colour token key and an opacity token key.');
      }
      return AlphaOf(
        token<Color>(alpha[0], _at(alphaPath, 0), 'a colour'),
        token<double>(alpha[1], _at(alphaPath, 1), 'an opacity'),
      );
    }
    throw StyleJsonError(path, 'Expected a colour token key or an "alpha" object, found ${_describe(json)}.');
  }

  /// A double token key, or `{"const": "infinity" | "zero"}`.
  StyleValue<double> size(Object? json, String path) {
    if (json is String) return token<double>(json, path, 'a size');
    if (json is Map) {
      final object = _object(json, path, const ['const']);
      return switch (_required(object, path, 'const')) {
        'infinity' => StyleValue.infinity,
        'zero' => StyleValue.zero,
        final other => throw StyleJsonError(
          _at(path, 'const'),
          'Expected "infinity" or "zero", found ${_describe(other)}.',
        ),
      };
    }
    throw StyleJsonError(path, 'Expected a size token key or a "const" object, found ${_describe(json)}.');
  }

  /// The token under the key [json], which must hold a `T`. [kind] names the
  /// expected token in messages, such as "a colour".
  ThemeToken<T> token<T>(Object? json, String path, String kind) {
    if (json is! String) throw StyleJsonError(path, 'Expected $kind token key, found ${_describe(json)}.');
    final token = tokens.token(json);
    if (token == null) {
      throw StyleJsonError(
        path,
        T == Color && json.startsWith('#')
            ? 'Raw colour "$json" is not allowed; use a colour token key.'
            : 'Unknown token "$json".',
      );
    }
    if (token is! ThemeToken<T>) {
      throw StyleJsonError(path, 'Token "$json" is a ${token.runtimeType}, but $kind needs a ThemeToken<$T>.');
    }
    return token;
  }

  int maxLines(Object? json, String path) {
    if (json is int && json >= 1) return json;
    throw StyleJsonError(path, 'Expected a whole number of at least 1, found ${_describe(json)}.');
  }

  bool boolean(Object? json, String path) {
    if (json is bool) return json;
    throw StyleJsonError(path, 'Expected true or false, found ${_describe(json)}.');
  }
}

final class _StyleJsonEncoder {
  const _StyleJsonEncoder();

  Map<String, Object?> style(Style style, String path, {bool inState = false}) {
    if (inState && style.states.isNotEmpty) {
      throw StyleJsonError(_at(path, 'states'), 'A state style cannot have states of its own.');
    }
    final box = this.box(style.box, _at(path, 'box'));
    final flex = this.flex(style.flex, _at(path, 'flex'));
    final text = this.text(style.text, _at(path, 'text'));
    final icon = this.icon(style.icon, _at(path, 'icon'));
    final image = this.image(style.image, _at(path, 'image'));
    return {
      if (box.isNotEmpty) 'box': box,
      if (flex.isNotEmpty) 'flex': flex,
      if (text.isNotEmpty) 'text': text,
      if (icon.isNotEmpty) 'icon': icon,
      if (image.isNotEmpty) 'image': image,
      if (style.states.isNotEmpty) 'states': states(style.states, _at(path, 'states')),
    };
  }

  Map<String, Object?> states(Map<StyleState, Style> states, String path) {
    final names = [for (final state in states.keys) state.key]..sort(_compareStates);
    final json = <String, Object?>{};
    for (final name in names) {
      final statePath = _at(path, name);
      if (!_stateName.hasMatch(name)) {
        throw StyleJsonError(
          statePath,
          'State name "$name" must start with a lowercase letter and contain only letters and digits.',
        );
      }
      json[name] = style(states[StyleState(name)]!, statePath, inState: true);
    }
    return json;
  }

  Map<String, Object?> box(BoxStyle box, String path) {
    String at(String key) => _at(path, key);
    _unsupported(path, 'BoxStyle', {
      'gradient': box.gradient,
      'image': box.image,
      'backgroundBlendMode': box.backgroundBlendMode,
      'foregroundDecoration': box.foregroundDecoration,
      'transformAlignment': box.transformAlignment,
    });
    return {
      if (box.color case final v?) 'color': color(v, at('color')),
      if (box.border case final v?) 'border': border(v, at('border')),
      if (box.padding case final v?) 'padding': insets(v, at('padding')),
      if (box.margin case final v?) 'margin': insets(v, at('margin')),
      if (box.boxShadow case final v?)
        'boxShadow': <Object?>[for (var i = 0; i < v.length; i++) shadow(v[i], _at(at('boxShadow'), i))],
      if (box.width case final v?) 'width': size(v, at('width')),
      if (box.height case final v?) 'height': size(v, at('height')),
      if (box.constraints case final v?) 'constraints': constraints(v, at('constraints')),
      if (box.alignment case final v?) 'alignment': _name<AlignmentGeometry>(v, _alignments, at('alignment')),
      if (box.clip case final v?) 'clip': _name(v, _clips, at('clip')),
      if (box.shape case final v?) 'shape': _name(v, _shapes, at('shape')),
      if (box.transform case final v?) 'transform': transform(v, at('transform')),
      if (box.motion case final v?) 'motion': motion(v, at('motion')),
    };
  }

  Map<String, Object?> flex(FlexStyle flex, String path) {
    String at(String key) => _at(path, key);
    _unsupported(path, 'FlexStyle', {
      'wrap': flex.wrap,
      'runSpacing': flex.runSpacing,
      'wrapAlignment': flex.wrapAlignment,
      'wrapCrossAxisAlignment': flex.wrapCrossAxisAlignment,
      'runAlignment': flex.runAlignment,
      'verticalDirection': flex.verticalDirection,
      'textDirection': flex.textDirection,
      'textBaseline': flex.textBaseline,
      'clipBehavior': flex.clipBehavior,
    });
    return {
      if (flex.direction case final v?) 'direction': _name(v, _axes, at('direction')),
      if (flex.spacing case final v?) 'spacing': size(v, at('spacing')),
      if (flex.mainAxisAlignment case final v?)
        'mainAxisAlignment': _name(v, _mainAxisAlignments, at('mainAxisAlignment')),
      if (flex.crossAxisAlignment case final v?)
        'crossAxisAlignment': _name(v, _crossAxisAlignments, at('crossAxisAlignment')),
      if (flex.mainAxisSize case final v?) 'mainAxisSize': _name(v, _mainAxisSizes, at('mainAxisSize')),
    };
  }

  Map<String, Object?> text(StyledTextStyle text, String path) {
    String at(String key) => _at(path, key);
    _unsupported(path, 'StyledTextStyle', {
      'backgroundColor': text.backgroundColor,
      'fontFamilyFallback': text.fontFamilyFallback,
      'wordSpacing': text.wordSpacing,
      'textBaseline': text.textBaseline,
      'leadingDistribution': text.leadingDistribution,
      'locale': text.locale,
      'foreground': text.foreground,
      'background': text.background,
      'shadows': text.shadows,
      'fontFeatures': text.fontFeatures,
      'fontVariations': text.fontVariations,
      'decorationStyle': text.decorationStyle,
      'decorationThickness': text.decorationThickness,
      'textDirection': text.textDirection,
      'textScaler': text.textScaler,
      'textWidthBasis': text.textWidthBasis,
      'textHeightBehavior': text.textHeightBehavior,
      'selectionColor': text.selectionColor,
    });
    return {
      if (text.color case final v?) 'color': color(v, at('color')),
      if (text.fontFamily case final v?) 'fontFamily': token(v, at('fontFamily')),
      if (text.fontSize case final v?) 'fontSize': token(v, at('fontSize')),
      if (text.fontWeight case final v?) 'fontWeight': token(v, at('fontWeight')),
      if (text.letterSpacing case final v?) 'letterSpacing': token(v, at('letterSpacing')),
      if (text.height case final v?) 'height': token(v, at('height')),
      if (text.textAlign case final v?) 'textAlign': _name(v, _textAligns, at('textAlign')),
      if (text.maxLines case final v?)
        'maxLines': v >= 1 ? v : throw StyleJsonError(at('maxLines'), 'maxLines must be at least 1, found $v.'),
      if (text.overflow case final v?) 'overflow': _name(v, _overflows, at('overflow')),
      'softWrap': ?text.softWrap,
      if (text.fontStyle case final v?) 'fontStyle': _name(v, _fontStyles, at('fontStyle')),
      if (text.decoration case final v?) 'decoration': _name(v, _decorations, at('decoration')),
      if (text.decorationColor case final v?) 'decorationColor': color(v, at('decorationColor')),
    };
  }

  Map<String, Object?> icon(IconStyle icon, String path) {
    _unsupported(path, 'IconStyle', {
      'fill': icon.fill,
      'weight': icon.weight,
      'grade': icon.grade,
      'opticalSize': icon.opticalSize,
      'shadows': icon.shadows,
      'textDirection': icon.textDirection,
      'applyTextScaling': icon.applyTextScaling,
    });
    return {
      if (icon.color case final v?) 'color': color(v, _at(path, 'color')),
      if (icon.size case final v?) 'size': token(v, _at(path, 'size')),
    };
  }

  Map<String, Object?> image(ImageStyle image, String path) {
    _unsupported(path, 'ImageStyle', {
      'alignment': image.alignment,
      'color': image.color,
      'colorBlendMode': image.colorBlendMode,
      'repeat': image.repeat,
      'centerSlice': image.centerSlice,
      'matchTextDirection': image.matchTextDirection,
      'gaplessPlayback': image.gaplessPlayback,
      'isAntiAlias': image.isAntiAlias,
      'filterQuality': image.filterQuality,
      'opacity': image.opacity,
    });
    return {
      if (image.fit case final v?) 'fit': _name(v, _fits, _at(path, 'fit')),
      if (image.width case final v?) 'width': size(v, _at(path, 'width')),
      if (image.height case final v?) 'height': size(v, _at(path, 'height')),
    };
  }

  /// Only the exact shape [StyledBorder.none] builds is `{"none": true}`.
  Map<String, Object?> border(StyledBorder border, String path) {
    String at(String key) => _at(path, key);
    final isNone =
        border.style == BorderStyle.none &&
        border.width == StyleValue.zero &&
        border.color == null &&
        border.top == null &&
        border.right == null &&
        border.bottom == null &&
        border.left == null;
    if (isNone) {
      return {'none': true, if (border.radius case final v?) 'radius': size(v, at('radius'))};
    }
    if (border.style case final style?) {
      throw StyleJsonError(at('style'), 'A border style of $style has no JSON form outside StyledBorder.none.');
    }
    return {
      if (border.color case final v?) 'color': color(v, at('color')),
      if (border.width case final v?) 'width': size(v, at('width')),
      if (border.radius case final v?) 'radius': size(v, at('radius')),
      if (border.top case final v?) 'top': borderSide(v, at('top')),
      if (border.right case final v?) 'right': borderSide(v, at('right')),
      if (border.bottom case final v?) 'bottom': borderSide(v, at('bottom')),
      if (border.left case final v?) 'left': borderSide(v, at('left')),
    };
  }

  Map<String, Object?> borderSide(StyledBorderSide side, String path) {
    if (side.style != BorderStyle.solid) {
      throw StyleJsonError(_at(path, 'style'), 'A border side style of ${side.style} has no JSON form.');
    }
    return {
      if (side.color case final v?) 'color': color(v, _at(path, 'color')),
      if (side.width case final v?) 'width': size(v, _at(path, 'width')),
    };
  }

  /// `all` when every side is the same, `horizontal`/`vertical` when opposite
  /// sides match, and the sides themselves otherwise.
  Map<String, Object?> insets(StyledEdgeInsets insets, String path) {
    final StyledEdgeInsets(:left, :top, :right, :bottom) = insets;
    String at(String key) => _at(path, key);
    if (left != null && left == top && left == right && left == bottom) return {'all': size(left, at('all'))};
    if (left == right && top == bottom) {
      return {
        if (left case final v?) 'horizontal': size(v, at('horizontal')),
        if (top case final v?) 'vertical': size(v, at('vertical')),
      };
    }
    return {
      if (left case final v?) 'left': size(v, at('left')),
      if (top case final v?) 'top': size(v, at('top')),
      if (right case final v?) 'right': size(v, at('right')),
      if (bottom case final v?) 'bottom': size(v, at('bottom')),
    };
  }

  Map<String, Object?> constraints(StyledBoxConstraints constraints, String path) => {
    if (constraints.minWidth case final v?) 'minWidth': size(v, _at(path, 'minWidth')),
    if (constraints.maxWidth case final v?) 'maxWidth': size(v, _at(path, 'maxWidth')),
    if (constraints.minHeight case final v?) 'minHeight': size(v, _at(path, 'minHeight')),
    if (constraints.maxHeight case final v?) 'maxHeight': size(v, _at(path, 'maxHeight')),
  };

  Map<String, Object?> shadow(StyledBoxShadow shadow, String path) => {
    'color': color(shadow.color, _at(path, 'color')),
    'level': shadow.shadowLevel.key,
  };

  Map<String, Object?> transform(StyledTransform transform, String path) {
    final translatePath = _at(path, 'translate');
    return {
      'translate': <String, Object?>{
        if (transform.x case final v?) 'x': token(v, _at(translatePath, 'x')),
        if (transform.y case final v?) 'y': token(v, _at(translatePath, 'y')),
      },
    };
  }

  Map<String, Object?> motion(Motion motion, String path) => {
    'duration': token(motion.duration, _at(path, 'duration')),
    'curve': _name(motion.curve, _curves, _at(path, 'curve')),
  };

  Object color(StyleValue<Color> value, String path) => switch (value) {
    ThemeToken(:final key) => key,
    AlphaOf(color: ThemeToken(key: final colorKey), :final opacity) => <String, Object?>{
      'alpha': <Object?>[colorKey, opacity.key],
    },
    AlphaOf(:final color) => throw StyleJsonError(
      _at(_at(path, 'alpha'), 0),
      'An AlphaOf colour must be a token to have a JSON form, found $color.',
    ),
    _ => throw _noForm(value, path),
  };

  Object size(StyleValue<double> value, String path) {
    if (value is ThemeToken<double>) return value.key;
    if (value == StyleValue.infinity) return <String, Object?>{'const': 'infinity'};
    if (value == StyleValue.zero) return <String, Object?>{'const': 'zero'};
    throw _noForm(value, path);
  }

  /// The key of [value], for fields that take only a token.
  String token<T>(StyleValue<T> value, String path) {
    if (value is ThemeToken<T>) return value.key;
    throw _noForm(value, path);
  }

  StyleJsonError _noForm(StyleValue<Object?> value, String path) => StyleJsonError(path, switch (value) {
    DataValue() => '$value is runtime data and has no JSON form; use a design token.',
    _ when value == StyleValue.zero || value == StyleValue.infinity =>
      '$value has no JSON form here; this field takes a token key.',
    _ => '$value has no JSON form.',
  });

  void _unsupported(String path, String type, Map<String, Object?> fields) {
    for (final MapEntry(:key, :value) in fields.entries) {
      if (value != null) {
        throw StyleJsonError(_at(path, key), '$type.$key is not in the style JSON schema, so it has no JSON form.');
      }
    }
  }
}
