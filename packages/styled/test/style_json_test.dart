import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:styled/styled.dart';

/// A handful of tokens of every type the style JSON uses. The first group
/// carries the key names of the kit presets.
abstract final class _T {
  static const accentSubtle = ThemeToken<Color>('accentSubtle', Color(0xFFFFF4D6));
  static const accent = ThemeToken<Color>('accent', Color(0xFFE0A800));
  static const onSurfaceMuted = ThemeToken<Color>('onSurfaceMuted', Color(0xFF6B7280));
  static const primary = ThemeToken<Color>('primary', Color(0xFF2563EB));
  static const opacityMedium = ThemeToken<double>('opacityMedium', 0.4);
  static const opacityFaint = ThemeToken<double>('opacityFaint', 0.08);
  static const strokeWidth = ThemeToken<double>('strokeWidth', 1);
  static const cardRadius = ThemeToken<double>('cardRadius', 12);
  static const padding = ThemeToken<double>('padding', 16);

  static const surface = ThemeToken<Color>('surface', Color(0xFFFFFFFF));
  static const line = ThemeToken<Color>('line', Color(0xFFE5E7EB));
  static const paddingSm = ThemeToken<double>('paddingSm', 8);
  static const gap = ThemeToken<double>('gap', 12);
  static const lift = ThemeToken<double>('lift', -2);
  static const fontBody = ThemeToken<String>('fontBody', 'Inter');
  static const fontSizeMd = ThemeToken<double>('fontSizeMd', 14);
  static const weightBold = ThemeToken<FontWeight>('weightBold', FontWeight.w700);
  static const tracking = ThemeToken<double>('tracking', 0.2);
  static const lineHeight = ThemeToken<double>('lineHeight', 1.4);
  static const iconSize = ThemeToken<double>('iconSize', 20);
  static const durationFast = ThemeToken<Duration>('durationFast', Duration(milliseconds: 120));
  static const shadowMd = ThemeToken<ShadowLevel>('shadowMd', ShadowLevel(opacity: 0.2, blurRadius: 8, dy: 2));

  /// Tokens whose type no style field takes.
  static const columns = ThemeToken<int>('columns', 3);
  static const loose = ThemeToken<Object?>('loose', Color(0xFF000000));

  static const all = <ThemeToken<Object?>>[
    accentSubtle,
    accent,
    onSurfaceMuted,
    primary,
    opacityMedium,
    opacityFaint,
    strokeWidth,
    cardRadius,
    padding,
    surface,
    line,
    paddingSm,
    gap,
    lift,
    fontBody,
    fontSizeMd,
    weightBold,
    tracking,
    lineHeight,
    iconSize,
    durationFast,
    shadowMd,
    columns,
    loose,
    StyledDefaults.motionDuration,
  ];
}

final class _Lookup implements StyleTokenLookup {
  final Map<String, ThemeToken<Object?>> _tokens;

  _Lookup(Iterable<ThemeToken<Object?>> tokens) : _tokens = {for (final token in tokens) token.key: token};

  @override
  ThemeToken<Object?>? token(String key) => _tokens[key];
}

final _lookup = _Lookup(_T.all);

Style _decode(Map<String, Object?> json) => Style.fromJson(json, _lookup);

Map<String, Object?> _parse(String text) => jsonDecode(text) as Map<String, Object?>;

/// Decodes [json] after a trip through JSON text.
Style _decodeText(Map<String, Object?> json) => _decode(_parse(jsonEncode(json)));

Matcher _throwsAt(String path) => throwsA(
  isA<StyleJsonError>()
      .having((e) => e.path, 'path', path)
      .having((e) => e.message, 'message', allOf(isNotEmpty, endsWith('.'))),
);

const _quietPreset = r'''
{
  "$schema": "../../../schemas/preset.schema.json",
  "format": 1,
  "id": "StyleButton.quiet",
  "extends": "StyleButton.ghost",
  "description": "Lowest-emphasis action beside a primary button.",
  "style": {
    "text": { "color": "onSurfaceMuted" },
    "icon": { "color": "onSurfaceMuted" },
    "states": {
      "hovered": {
        "box": { "color": { "alpha": ["primary", "opacityFaint"] } },
        "text": { "color": "primary" },
        "icon": { "color": "primary" }
      }
    }
  }
}
''';

const _highlightPreset = r'''
{
  "$schema": "../../../schemas/preset.schema.json",
  "format": 1,
  "id": "StyleCard.highlight",
  "extends": "StyleCard.surface",
  "description": "A card that draws the eye: gold tint, gold hairline, no shadow.",
  "style": {
    "box": {
      "color": "accentSubtle",
      "border": { "color": { "alpha": ["accent", "opacityMedium"] }, "width": "strokeWidth", "radius": "cardRadius" },
      "boxShadow": []
    },
    "states": {
      "mobile": { "box": { "padding": { "all": "padding" } } }
    }
  }
}
''';

Map<String, Object?> _presetStyle(String document) => _parse(document)['style']! as Map<String, Object?>;

final _quietStyle =
    const Style(
      text: StyledTextStyle(color: _T.onSurfaceMuted),
      icon: IconStyle(color: _T.onSurfaceMuted),
    ).on(
      StyleState.hovered,
      box: const BoxStyle(color: AlphaOf(_T.primary, _T.opacityFaint)),
      text: const StyledTextStyle(color: _T.primary),
      icon: const IconStyle(color: _T.primary),
    );

final _highlightStyle = const Style(
  box: BoxStyle(
    color: _T.accentSubtle,
    border: StyledBorder.all(color: AlphaOf(_T.accent, _T.opacityMedium), width: _T.strokeWidth, radius: _T.cardRadius),
    boxShadow: [],
  ),
).on(StyledScreen.mobile.state, box: const BoxStyle(padding: StyledEdgeInsets.all(_T.padding)));

/// Every field of the schema, keys in schema order.
const _everyFieldText = '''
{
  "box": {
    "color": "surface",
    "border": {
      "color": "line", "width": "strokeWidth", "radius": "cardRadius",
      "top": { "color": "primary", "width": "strokeWidth" },
      "right": { "color": "accent" },
      "bottom": { "width": { "const": "zero" } },
      "left": {}
    },
    "padding": { "horizontal": "padding", "vertical": "paddingSm" },
    "margin": { "left": "gap", "top": "paddingSm", "right": { "const": "zero" }, "bottom": "padding" },
    "boxShadow": [
      { "color": "primary", "level": "shadowMd" },
      { "color": { "alpha": ["accent", "opacityFaint"] }, "level": "shadowMd" }
    ],
    "width": { "const": "infinity" },
    "height": "gap",
    "constraints": { "minWidth": "gap", "maxWidth": { "const": "infinity" }, "minHeight": { "const": "zero" }, "maxHeight": "padding" },
    "alignment": "center",
    "clip": "antiAlias",
    "shape": "rectangle",
    "transform": { "translate": { "x": "lift", "y": "lift" } },
    "motion": { "duration": "durationFast", "curve": "easeInOut" }
  },
  "flex": {
    "direction": "horizontal", "spacing": "gap", "mainAxisAlignment": "spaceBetween",
    "crossAxisAlignment": "stretch", "mainAxisSize": "min"
  },
  "text": {
    "color": "onSurfaceMuted", "fontFamily": "fontBody", "fontSize": "fontSizeMd", "fontWeight": "weightBold",
    "letterSpacing": "tracking", "height": "lineHeight", "textAlign": "center", "maxLines": 2, "overflow": "ellipsis",
    "softWrap": false, "fontStyle": "italic", "decoration": "underline",
    "decorationColor": { "alpha": ["primary", "opacityMedium"] }
  },
  "icon": { "color": "primary", "size": "iconSize" },
  "image": { "fit": "cover", "width": "gap", "height": { "const": "infinity" } },
  "states": {
    "hovered": { "box": { "color": "accentSubtle" }, "text": { "color": "primary" } },
    "desktop": { "flex": { "direction": "vertical" } }
  }
}
''';

final _everyFieldStyle =
    const Style(
          box: BoxStyle(
            color: _T.surface,
            border: StyledBorder(
              color: _T.line,
              width: _T.strokeWidth,
              radius: _T.cardRadius,
              top: StyledBorderSide(color: _T.primary, width: _T.strokeWidth),
              right: StyledBorderSide(color: _T.accent),
              bottom: StyledBorderSide(width: StyleValue.zero),
              left: StyledBorderSide(),
            ),
            padding: StyledEdgeInsets.symmetric(horizontal: _T.padding, vertical: _T.paddingSm),
            margin: StyledEdgeInsets.only(left: _T.gap, top: _T.paddingSm, right: StyleValue.zero, bottom: _T.padding),
            boxShadow: [
              StyledBoxShadow.level(_T.primary, _T.shadowMd),
              StyledBoxShadow.level(AlphaOf(_T.accent, _T.opacityFaint), _T.shadowMd),
            ],
            width: StyleValue.infinity,
            height: _T.gap,
            constraints: StyledBoxConstraints(
              minWidth: _T.gap,
              maxWidth: StyleValue.infinity,
              minHeight: StyleValue.zero,
              maxHeight: _T.padding,
            ),
            alignment: Alignment.center,
            clip: Clip.antiAlias,
            shape: BoxShape.rectangle,
            transform: StyledTransform.translate(x: _T.lift, y: _T.lift),
            motion: Motion(_T.durationFast, Curves.easeInOut),
          ),
          flex: FlexStyle(
            direction: Axis.horizontal,
            spacing: _T.gap,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
          ),
          text: StyledTextStyle(
            color: _T.onSurfaceMuted,
            fontFamily: _T.fontBody,
            fontSize: _T.fontSizeMd,
            fontWeight: _T.weightBold,
            letterSpacing: _T.tracking,
            height: _T.lineHeight,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            fontStyle: FontStyle.italic,
            decoration: TextDecoration.underline,
            decorationColor: AlphaOf(_T.primary, _T.opacityMedium),
          ),
          icon: IconStyle(color: _T.primary, size: _T.iconSize),
          image: ImageStyle(fit: BoxFit.cover, width: _T.gap, height: StyleValue.infinity),
        )
        .on(
          StyleState.hovered,
          box: const BoxStyle(color: _T.accentSubtle),
          text: const StyledTextStyle(color: _T.primary),
        )
        .on(StyledScreen.desktop.state, flex: const FlexStyle(direction: Axis.vertical));

/// Decoding errors: a name, a style as JSON text, and the pointer the error
/// must name.
const _decodeErrors = <(String, String, String)>[
  ('unknown token', '{"box": {"color": "nope"}}', '/box/color'),
  ('raw colour', '{"box": {"color": "#FF0000"}}', '/box/color'),
  ('raw number as a colour', '{"box": {"color": 16711680}}', '/box/color'),
  ('size token as a colour', '{"box": {"color": "padding"}}', '/box/color'),
  ('untyped token as a colour', '{"box": {"color": "loose"}}', '/box/color'),
  ('null colour', '{"box": {"color": null}}', '/box/color'),
  ('colour token as a size', '{"box": {"width": "primary"}}', '/box/width'),
  ('int token as a size', '{"box": {"height": "columns"}}', '/box/height'),
  ('raw number as a size', '{"box": {"width": 16}}', '/box/width'),
  ('raw number in insets', '{"box": {"padding": {"all": 8}}}', '/box/padding/all'),
  ('unknown size constant', '{"box": {"width": {"const": "half"}}}', '/box/width/const'),
  ('size object without const', '{"box": {"width": {}}}', '/box/width'),
  ('size object with an extra field', '{"box": {"width": {"const": "zero", "unit": "px"}}}', '/box/width/unit'),
  ('alpha over a size token', '{"box": {"color": {"alpha": ["padding", "opacityFaint"]}}}', '/box/color/alpha/0'),
  ('alpha with a colour as opacity', '{"box": {"color": {"alpha": ["primary", "accent"]}}}', '/box/color/alpha/1'),
  ('alpha with a raw opacity', '{"box": {"color": {"alpha": ["primary", 0.5]}}}', '/box/color/alpha/1'),
  ('alpha with one item', '{"box": {"color": {"alpha": ["primary"]}}}', '/box/color/alpha'),
  ('alpha that is not a list', '{"box": {"color": {"alpha": "primary"}}}', '/box/color/alpha'),
  ('colour object without alpha', '{"box": {"color": {}}}', '/box/color'),
  (
    'colour object with an extra field',
    '{"box": {"color": {"alpha": ["primary", "opacityFaint"], "mix": 1}}}',
    '/box/color/mix',
  ),
  ('raw font size', '{"text": {"fontSize": 14}}', '/text/fontSize'),
  ('constant font size', '{"text": {"fontSize": {"const": "zero"}}}', '/text/fontSize'),
  ('size token as a font weight', '{"text": {"fontWeight": "fontSizeMd"}}', '/text/fontWeight'),
  ('raw font weight', '{"text": {"fontWeight": "w700"}}', '/text/fontWeight'),
  ('colour token as a font family', '{"text": {"fontFamily": "primary"}}', '/text/fontFamily'),
  ('font weight token as letter spacing', '{"text": {"letterSpacing": "weightBold"}}', '/text/letterSpacing'),
  ('font family token as line height', '{"text": {"height": "fontBody"}}', '/text/height'),
  ('size token as a decoration colour', '{"text": {"decorationColor": "tracking"}}', '/text/decorationColor'),
  ('colour token as an icon size', '{"icon": {"size": "primary"}}', '/icon/size'),
  ('size token as an icon colour', '{"icon": {"color": "iconSize"}}', '/icon/color'),
  (
    'size token as a shadow level',
    '{"box": {"boxShadow": [{"color": "primary", "level": "shadowMd"}, {"color": "primary", "level": "padding"}]}}',
    '/box/boxShadow/1/level',
  ),
  (
    'shadow with a size token as colour',
    '{"box": {"boxShadow": [{"color": "padding", "level": "shadowMd"}]}}',
    '/box/boxShadow/0/color',
  ),
  ('shadow without a level', '{"box": {"boxShadow": [{"color": "primary"}]}}', '/box/boxShadow/0'),
  ('shadow that is not an object', '{"box": {"boxShadow": ["shadowMd"]}}', '/box/boxShadow/0'),
  ('boxShadow that is not a list', '{"box": {"boxShadow": {}}}', '/box/boxShadow'),
  ('size token as a duration', '{"box": {"motion": {"duration": "padding"}}}', '/box/motion/duration'),
  ('raw duration', '{"box": {"motion": {"duration": 150}}}', '/box/motion/duration'),
  ('motion without a duration', '{"box": {"motion": {"curve": "linear"}}}', '/box/motion'),
  ('unknown curve', '{"box": {"motion": {"duration": "durationFast", "curve": "bounceIn"}}}', '/box/motion/curve'),
  (
    'colour token as a translation',
    '{"box": {"transform": {"translate": {"x": "primary"}}}}',
    '/box/transform/translate/x',
  ),
  (
    'constant translation',
    '{"box": {"transform": {"translate": {"y": {"const": "zero"}}}}}',
    '/box/transform/translate/y',
  ),
  ('transform without translate', '{"box": {"transform": {}}}', '/box/transform'),
  ('unknown transform', '{"box": {"transform": {"rotate": "lift"}}}', '/box/transform/rotate'),
  ('unknown translate axis', '{"box": {"transform": {"translate": {"z": "lift"}}}}', '/box/transform/translate/z'),
  ('insets mixing all with a side', '{"box": {"padding": {"all": "padding", "left": "gap"}}}', '/box/padding'),
  ('insets mixing all with symmetric', '{"box": {"margin": {"vertical": "gap", "all": "padding"}}}', '/box/margin'),
  (
    'insets mixing symmetric with a side',
    '{"box": {"padding": {"horizontal": "padding", "top": "gap"}}}',
    '/box/padding',
  ),
  ('unknown insets field', '{"box": {"padding": {"start": "gap"}}}', '/box/padding/start'),
  ('border none with a colour', '{"box": {"border": {"none": true, "color": "line"}}}', '/box/border'),
  ('border none false', '{"box": {"border": {"none": false}}}', '/box/border/none'),
  ('unknown border field', '{"box": {"border": {"style": "solid"}}}', '/box/border/style'),
  ('unknown border side field', '{"box": {"border": {"top": {"style": "dashed"}}}}', '/box/border/top/style'),
  ('colour token as a side width', '{"box": {"border": {"left": {"width": "primary"}}}}', '/box/border/left/width'),
  ('unknown constraints field', '{"box": {"constraints": {"width": "gap"}}}', '/box/constraints/width'),
  ('unknown style field', '{"boxx": {}}', '/boxx'),
  ('unknown box field', '{"box": {"gradient": "primary"}}', '/box/gradient'),
  ('unknown flex field', '{"flex": {"wrap": true}}', '/flex/wrap'),
  ('unknown text field', '{"text": {"fontFeatures": []}}', '/text/fontFeatures'),
  ('unknown icon field', '{"icon": {"weight": "fontSizeMd"}}', '/icon/weight'),
  ('unknown image field', '{"image": {"opacity": "opacityFaint"}}', '/image/opacity'),
  ('sub-style that is a string', '{"box": "surface"}', '/box'),
  ('sub-style that is a list', '{"text": []}', '/text'),
  ('unknown enum name', '{"box": {"alignment": "middle"}}', '/box/alignment'),
  ('enum given as a number', '{"flex": {"direction": 0}}', '/flex/direction'),
  ('maxLines as a string', '{"text": {"maxLines": "2"}}', '/text/maxLines'),
  ('maxLines of zero', '{"text": {"maxLines": 0}}', '/text/maxLines'),
  ('fractional maxLines', '{"text": {"maxLines": 1.5}}', '/text/maxLines'),
  ('softWrap as a string', '{"text": {"softWrap": "yes"}}', '/text/softWrap'),
  ('states that are a list', '{"states": ["hovered"]}', '/states'),
  ('capitalised state name', '{"states": {"Hovered": {}}}', '/states/Hovered'),
  ('state name with a dash', '{"states": {"is-open": {}}}', '/states/is-open'),
  ('state that is not an object', '{"states": {"hovered": "primary"}}', '/states/hovered'),
  ('nested states', '{"states": {"hovered": {"states": {"pressed": {}}}}}', '/states/hovered/states'),
  ('error inside a state', '{"states": {"pressed": {"box": {"color": "padding"}}}}', '/states/pressed/box/color'),
  ('field name with a slash', '{"a/b": 1}', '/a~1b'),
  ('field name with a tilde', '{"box": {"m~n": 1}}', '/box/m~0n'),
];

void main() {
  group('Style.fromJson', () {
    test('decodes every field in the schema', () {
      final decoded = _decode(_parse(_everyFieldText));
      expect(decoded.box, _everyFieldStyle.box);
      expect(decoded.flex, _everyFieldStyle.flex);
      expect(decoded.text, _everyFieldStyle.text);
      expect(decoded.icon, _everyFieldStyle.icon);
      expect(decoded.image, _everyFieldStyle.image);
      expect(decoded.states, _everyFieldStyle.states);
      expect(decoded, _everyFieldStyle);
    });

    test('decodes Dart map literals as well as decoded JSON', () {
      final style = _decode(const {
        'box': {'color': 'surface', 'boxShadow': <Object?>[]},
        'states': {
          'hovered': {
            'text': {'maxLines': 1},
          },
        },
      });
      expect(
        style,
        const Style(
          box: BoxStyle(color: _T.surface, boxShadow: []),
        ).on(StyleState.hovered, text: const StyledTextStyle(maxLines: 1)),
      );
    });

    test('accepts maps typed Map<dynamic, dynamic> when every key is a string', () {
      final json = <String, Object?>{
        'box': <dynamic, dynamic>{
          'color': <dynamic, dynamic>{
            'alpha': ['primary', 'opacityFaint'],
          },
        },
        'states': <dynamic, dynamic>{
          'hovered': <dynamic, dynamic>{
            'box': {'color': 'surface'},
          },
        },
      };
      expect(
        _decode(json),
        const Style(
          box: BoxStyle(color: AlphaOf(_T.primary, _T.opacityFaint)),
        ).on(StyleState.hovered, box: const BoxStyle(color: _T.surface)),
      );
      expect(
        () => _decode({
          'box': <Object, Object>{1: 'primary'},
        }),
        throwsA(
          isA<StyleJsonError>()
              .having((e) => e.path, 'path', '/box')
              .having((e) => e.message, 'message', contains('non-string key')),
        ),
      );
    });

    test('decodes every enum name to its Flutter value', () {
      void check<T>(String section, String field, Map<String, T> names, T? Function(Style) read) {
        for (final MapEntry(:key, :value) in names.entries) {
          final json = <String, Object?>{
            section: {field: key},
          };
          expect(read(_decode(json)), value, reason: '$section.$field: $key');
        }
      }

      check('box', 'alignment', const {
        'topLeft': Alignment.topLeft,
        'topCenter': Alignment.topCenter,
        'topRight': Alignment.topRight,
        'centerLeft': Alignment.centerLeft,
        'center': Alignment.center,
        'centerRight': Alignment.centerRight,
        'bottomLeft': Alignment.bottomLeft,
        'bottomCenter': Alignment.bottomCenter,
        'bottomRight': Alignment.bottomRight,
      }, (style) => style.box.alignment);
      check('box', 'clip', const {
        'none': Clip.none,
        'hardEdge': Clip.hardEdge,
        'antiAlias': Clip.antiAlias,
        'antiAliasWithSaveLayer': Clip.antiAliasWithSaveLayer,
      }, (style) => style.box.clip);
      check('box', 'shape', const {
        'rectangle': BoxShape.rectangle,
        'circle': BoxShape.circle,
      }, (style) => style.box.shape);
      check('flex', 'direction', const {
        'horizontal': Axis.horizontal,
        'vertical': Axis.vertical,
      }, (style) => style.flex.direction);
      check('flex', 'mainAxisAlignment', const {
        'start': MainAxisAlignment.start,
        'end': MainAxisAlignment.end,
        'center': MainAxisAlignment.center,
        'spaceBetween': MainAxisAlignment.spaceBetween,
        'spaceAround': MainAxisAlignment.spaceAround,
        'spaceEvenly': MainAxisAlignment.spaceEvenly,
      }, (style) => style.flex.mainAxisAlignment);
      check('flex', 'crossAxisAlignment', const {
        'start': CrossAxisAlignment.start,
        'end': CrossAxisAlignment.end,
        'center': CrossAxisAlignment.center,
        'stretch': CrossAxisAlignment.stretch,
        'baseline': CrossAxisAlignment.baseline,
      }, (style) => style.flex.crossAxisAlignment);
      check('flex', 'mainAxisSize', const {
        'min': MainAxisSize.min,
        'max': MainAxisSize.max,
      }, (style) => style.flex.mainAxisSize);
      check('text', 'textAlign', const {
        'left': TextAlign.left,
        'right': TextAlign.right,
        'center': TextAlign.center,
        'justify': TextAlign.justify,
        'start': TextAlign.start,
        'end': TextAlign.end,
      }, (style) => style.text.textAlign);
      check('text', 'overflow', const {
        'clip': TextOverflow.clip,
        'fade': TextOverflow.fade,
        'ellipsis': TextOverflow.ellipsis,
        'visible': TextOverflow.visible,
      }, (style) => style.text.overflow);
      check('text', 'fontStyle', const {
        'normal': FontStyle.normal,
        'italic': FontStyle.italic,
      }, (style) => style.text.fontStyle);
      check('text', 'decoration', const {
        'none': TextDecoration.none,
        'underline': TextDecoration.underline,
        'overline': TextDecoration.overline,
        'lineThrough': TextDecoration.lineThrough,
      }, (style) => style.text.decoration);
      check('image', 'fit', const {
        'fill': BoxFit.fill,
        'contain': BoxFit.contain,
        'cover': BoxFit.cover,
        'fitWidth': BoxFit.fitWidth,
        'fitHeight': BoxFit.fitHeight,
        'none': BoxFit.none,
        'scaleDown': BoxFit.scaleDown,
      }, (style) => style.image.fit);

      const curves = {
        'linear': Curves.linear,
        'easeIn': Curves.easeIn,
        'easeOut': Curves.easeOut,
        'easeInOut': Curves.easeInOut,
        'easeOutCubic': Curves.easeOutCubic,
        'easeInOutCubic': Curves.easeInOutCubic,
      };
      for (final MapEntry(:key, :value) in curves.entries) {
        final style = _decode({
          'box': {
            'motion': {'duration': 'durationFast', 'curve': key},
          },
        });
        expect(style.box.motion, Motion(_T.durationFast, value), reason: key);
      }
    });

    test('decodes an empty object to an empty style', () {
      expect(_decode(const {}), const Style());
    });

    test('decodes size constants', () {
      final style = _decode(_parse('{"box": {"width": {"const": "infinity"}, "height": {"const": "zero"}}}'));
      expect(style.box.width, StyleValue.infinity);
      expect(style.box.height, StyleValue.zero);
    });

    test('decodes the three insets forms', () {
      final style = _decode(
        _parse('''
        {
          "box": { "padding": { "all": "padding" }, "margin": { "vertical": "gap" } },
          "states": { "hovered": { "box": { "padding": { "left": "gap", "bottom": "paddingSm" } } } }
        }'''),
      );
      expect(style.box.padding, const StyledEdgeInsets.all(_T.padding));
      expect(style.box.margin, const StyledEdgeInsets.symmetric(vertical: _T.gap));
      expect(
        style.states[StyleState.hovered]!.box.padding,
        const StyledEdgeInsets.only(left: _T.gap, bottom: _T.paddingSm),
      );
    });

    test('decodes a uniform border to a StyledBorder equal to StyledBorder.all', () {
      final style = _decode(
        _parse('{"box": {"border": {"color": "line", "width": "strokeWidth", "radius": "cardRadius"}}}'),
      );
      expect(style.box.border, const StyledBorder.all(color: _T.line, width: _T.strokeWidth, radius: _T.cardRadius));
    });

    test('decodes none to StyledBorder.none, keeping a radius', () {
      expect(_decode(_parse('{"box": {"border": {"none": true}}}')).box.border, const StyledBorder.none());
      expect(
        _decode(_parse('{"box": {"border": {"none": true, "radius": "cardRadius"}}}')).box.border,
        const StyledBorder.none(radius: _T.cardRadius),
      );
    });

    test('decodes a motion without a curve with easeOutCubic', () {
      final style = _decode(_parse('{"box": {"motion": {"duration": "durationFast"}}}'));
      expect(style.box.motion, const Motion(_T.durationFast, Curves.easeOutCubic));
    });

    test('decodes an empty boxShadow list to an empty list and an absent one to null', () {
      expect(_decode(_parse('{"box": {"boxShadow": []}}')).box.boxShadow, isEmpty);
      expect(_decode(_parse('{"box": {"color": "surface"}}')).box.boxShadow, isNull);
    });

    test('decodes states as Style.on builds them, including app-defined states', () {
      final style = _decode(
        _parse('''
        {
          "states": {
            "pressed": { "box": { "transform": { "translate": { "y": "lift" } } } },
            "mobile": { "flex": { "direction": "vertical" } },
            "expanded": { "icon": { "size": "iconSize" } },
            "approved": {}
          }
        }'''),
      );
      final expected = const Style()
          .on(
            StyleState.pressed,
            box: const BoxStyle(transform: StyledTransform.translate(y: _T.lift)),
          )
          .on(StyledScreen.mobile.state, flex: const FlexStyle(direction: Axis.vertical))
          .on(const StyleState('expanded'), icon: const IconStyle(size: _T.iconSize))
          .on(const StyleState('approved'));
      expect(style, expected);
      expect(style.hasState(const StyleState('approved')), isTrue);
      expect(style.hasScreenStates, isTrue);
    });

    test('decodes the StyleButton.quiet kit preset', () {
      final style = Style.fromJson(_presetStyle(_quietPreset), _lookup);
      expect(style, _quietStyle);
      expect(jsonEncode(style.toJson()), jsonEncode(_presetStyle(_quietPreset)));
    });

    test('decodes the StyleCard.highlight kit preset', () {
      final style = Style.fromJson(_presetStyle(_highlightPreset), _lookup);
      expect(style, _highlightStyle);
      expect(style.box.boxShadow, isEmpty);
      expect(jsonEncode(style.toJson()), jsonEncode(_presetStyle(_highlightPreset)));
    });
  });

  group('Style.toJson', () {
    final styles = <String, Style>{
      'an empty style': const Style(),
      'every schema field': _everyFieldStyle,
      'StyleButton.quiet': _quietStyle,
      'StyleCard.highlight': _highlightStyle,
      'colour forms': const Style(
        box: BoxStyle(color: AlphaOf(_T.primary, _T.opacityFaint)),
        text: StyledTextStyle(color: _T.onSurfaceMuted, decorationColor: _T.accent),
        icon: IconStyle(color: AlphaOf(_T.accent, _T.opacityMedium)),
      ),
      'uniform border': const Style(
        box: BoxStyle(
          border: StyledBorder.all(color: _T.line, width: _T.strokeWidth, radius: _T.cardRadius),
        ),
      ),
      'partial border': const Style(
        box: BoxStyle(border: StyledBorder(color: _T.primary)),
      ),
      'border none': const Style(box: BoxStyle(border: StyledBorder.none())),
      'border none with radius': const Style(
        box: BoxStyle(border: StyledBorder.none(radius: _T.cardRadius)),
      ),
      'border sides': const Style(
        box: BoxStyle(
          border: StyledBorder.fromBorderSide(StyledBorderSide(color: _T.line, width: _T.strokeWidth)),
        ),
      ),
      'empty border': const Style(box: BoxStyle(border: StyledBorder())),
      'insets all': const Style(box: BoxStyle(padding: StyledEdgeInsets.all(_T.padding))),
      'insets symmetric': const Style(
        box: BoxStyle(
          padding: StyledEdgeInsets.symmetric(horizontal: _T.padding),
          margin: StyledEdgeInsets.symmetric(horizontal: _T.gap, vertical: StyleValue.zero),
        ),
      ),
      'insets only': const Style(
        box: BoxStyle(
          padding: StyledEdgeInsets.only(top: _T.gap),
          margin: StyledEdgeInsets.fromLTRB(_T.gap, _T.padding, _T.gap, _T.paddingSm),
        ),
      ),
      'insets zero': const Style(box: BoxStyle(padding: StyledEdgeInsets.zero)),
      'empty shadow list': const Style(box: BoxStyle(boxShadow: [])),
      'constraints': const Style(
        box: BoxStyle(constraints: StyledBoxConstraints.expand(height: _T.gap)),
        states: {
          StyleState.hovered: Style(
            box: BoxStyle(constraints: StyledBoxConstraints.tightFor(width: _T.gap)),
          ),
        },
      ),
      'transform with one axis': const Style(
        box: BoxStyle(transform: StyledTransform.translate(y: _T.lift)),
      ),
      'default motion': const Style(box: BoxStyle(motion: Motion())),
      for (final curve in [
        Curves.linear,
        Curves.easeIn,
        Curves.easeOut,
        Curves.easeInOut,
        Curves.easeOutCubic,
        Curves.easeInOutCubic,
      ])
        'motion with $curve': Style(box: BoxStyle(motion: Motion(_T.durationFast, curve))),
      'circle': const Style(
        box: BoxStyle(shape: BoxShape.circle, clip: Clip.hardEdge, alignment: Alignment.topRight),
      ),
      'flex': const Style(
        flex: FlexStyle(direction: Axis.vertical, spacing: StyleValue.zero, mainAxisSize: MainAxisSize.max),
      ),
      'text': const Style(
        text: StyledTextStyle(
          fontWeight: _T.weightBold,
          maxLines: 1,
          softWrap: true,
          decoration: TextDecoration.lineThrough,
        ),
      ),
      'image': const Style(
        image: ImageStyle(fit: BoxFit.scaleDown, height: _T.gap),
      ),
      'states of every kind': const Style(box: BoxStyle(color: _T.surface))
          .on(StyleState.hovered, box: const BoxStyle(color: _T.accentSubtle))
          .on(
            StyleState.focused,
            box: const BoxStyle(border: StyledBorder(color: _T.primary)),
          )
          .on(
            StyleState.pressed,
            box: const BoxStyle(transform: StyledTransform.translate(y: _T.lift)),
          )
          .on(StyleState.error, text: const StyledTextStyle(color: _T.accent))
          .on(StyleState.disabled, icon: const IconStyle(color: AlphaOf(_T.onSurfaceMuted, _T.opacityMedium)))
          .on(const StyleState('selected'), box: const BoxStyle(boxShadow: []))
          .on(StyledScreen.tablet.state, flex: const FlexStyle(direction: Axis.horizontal))
          .on(const StyleState('expanded'), image: const ImageStyle(fit: BoxFit.contain))
          .on(const StyleState('dragTarget2')),
    };

    for (final MapEntry(:key, value: style) in styles.entries) {
      test('round-trips $key', () {
        expect(Style.fromJson(style.toJson(), _lookup), style);
        expect(_decodeText(style.toJson()), style);
      });
    }

    test('emits keys in schema order', () {
      expect(jsonEncode(_everyFieldStyle.toJson()), jsonEncode(_parse(_everyFieldText)));
    });

    test('emits schema states in schema order, then other states alphabetically', () {
      final style = const Style()
          .on(const StyleState('zeta'), box: const BoxStyle(color: _T.primary))
          .on(StyledScreen.desktop.state, box: const BoxStyle(color: _T.primary))
          .on(const StyleState('alpha'), box: const BoxStyle(color: _T.primary))
          .on(StyleState.disabled, box: const BoxStyle(color: _T.primary))
          .on(StyleState.hovered, box: const BoxStyle(color: _T.primary));
      final states = style.toJson()['states']! as Map<String, Object?>;
      expect(states.keys.toList(), ['hovered', 'disabled', 'desktop', 'alpha', 'zeta']);
    });

    test('omits null fields and empty sub-styles', () {
      expect(const Style().toJson(), isEmpty);
      expect(
        const Style(
          box: BoxStyle(color: _T.primary),
          text: StyledTextStyle(),
          states: {},
        ).toJson(),
        {
          'box': {'color': 'primary'},
        },
      );
    });

    test('keeps an empty shadow list and an empty state override', () {
      expect(const Style(box: BoxStyle(boxShadow: [])).toJson(), {
        'box': {'boxShadow': <Object?>[]},
      });
      expect(const Style().on(StyleState.pressed).toJson(), {
        'states': {'pressed': <String, Object?>{}},
      });
    });

    test('encodes insets in their shortest form', () {
      Object? padding(StyledEdgeInsets insets) =>
          (Style(box: BoxStyle(padding: insets)).toJson()['box']! as Map<String, Object?>)['padding'];

      expect(padding(const StyledEdgeInsets.fromLTRB(_T.gap, _T.gap, _T.gap, _T.gap)), {'all': 'gap'});
      expect(padding(const StyledEdgeInsets.only(left: _T.gap, right: _T.gap)), {'horizontal': 'gap'});
      expect(padding(const StyledEdgeInsets.symmetric(horizontal: _T.gap, vertical: _T.padding)), {
        'horizontal': 'gap',
        'vertical': 'padding',
      });
      expect(padding(const StyledEdgeInsets.only(top: _T.gap, bottom: _T.padding)), {
        'top': 'gap',
        'bottom': 'padding',
      });
      expect(padding(StyledEdgeInsets.zero), isEmpty);
    });

    test('encodes StyledBorder.none and always names the curve', () {
      const style = Style(
        box: BoxStyle(
          border: StyledBorder.none(radius: _T.cardRadius),
          motion: Motion(_T.durationFast),
        ),
      );
      expect(
        jsonEncode(style.toJson()),
        '{"box":{"border":{"none":true,"radius":"cardRadius"},'
        '"motion":{"duration":"durationFast","curve":"linear"}}}',
      );
    });

    test('produces plain JSON', () {
      expect(jsonDecode(jsonEncode(_everyFieldStyle.toJson())), _parse(_everyFieldText));
    });
  });

  group('decode errors', () {
    for (final (name, text, path) in _decodeErrors) {
      test('$name fails at $path', () {
        expect(() => _decode(_parse(text)), _throwsAt(path));
      });
    }

    test('only a colour field calls an unknown #-string a raw colour', () {
      expect(
        () => _decode(_parse('{"box": {"color": "#FF0000"}}')),
        throwsA(isA<StyleJsonError>().having((e) => e.message, 'message', contains('Raw colour'))),
      );
      expect(
        () => _decode(_parse('{"box": {"width": "#10"}}')),
        throwsA(isA<StyleJsonError>().having((e) => e.message, 'message', 'Unknown token "#10".')),
      );
    });

    test('the message names the expected token type', () {
      expect(
        () => _decode(_parse('{"box": {"color": "padding"}}')),
        throwsA(
          isA<StyleJsonError>()
              .having((e) => e.message, 'message', contains('ThemeToken<Color>'))
              .having((e) => e.toString(), 'toString', startsWith('StyleJsonError at /box/color: ')),
        ),
      );
    });
  });

  group('encode errors', () {
    const data = DataValue(Color(0xFF00FF00));
    final cases = <(String, Style, String)>[
      ('DataValue colour', const Style(box: BoxStyle(color: data)), '/box/color'),
      ('DataValue size', const Style(box: BoxStyle(width: DataValue(10.0))), '/box/width'),
      (
        'DataValue in insets',
        const Style(box: BoxStyle(padding: StyledEdgeInsets.all(DataValue(4.0)))),
        '/box/padding/all',
      ),
      (
        'DataValue in a border side',
        const Style(
          box: BoxStyle(
            border: StyledBorder(left: StyledBorderSide(width: DataValue(2.0))),
          ),
        ),
        '/box/border/left/width',
      ),
      (
        'AlphaOf over a DataValue',
        const Style(box: BoxStyle(color: AlphaOf(data, _T.opacityFaint))),
        '/box/color/alpha/0',
      ),
      (
        'AlphaOf over an AlphaOf',
        const Style(text: StyledTextStyle(color: AlphaOf(AlphaOf(_T.primary, _T.opacityFaint), _T.opacityFaint))),
        '/text/color/alpha/0',
      ),
      (
        'DataValue shadow colour',
        const Style(box: BoxStyle(boxShadow: [StyledBoxShadow.level(data, _T.shadowMd)])),
        '/box/boxShadow/0/color',
      ),
      ('DataValue font size', const Style(text: StyledTextStyle(fontSize: DataValue(14.0))), '/text/fontSize'),
      ('constant font size', const Style(text: StyledTextStyle(fontSize: StyleValue.zero)), '/text/fontSize'),
      ('constant icon size', const Style(icon: IconStyle(size: StyleValue.infinity)), '/icon/size'),
      (
        'constant translation',
        const Style(
          box: BoxStyle(transform: StyledTransform.translate(x: StyleValue.zero)),
        ),
        '/box/transform/translate/x',
      ),
      (
        'DataValue duration',
        const Style(box: BoxStyle(motion: Motion(DataValue(Duration(milliseconds: 100))))),
        '/box/motion/duration',
      ),
      (
        'unnamed curve',
        const Style(box: BoxStyle(motion: Motion(_T.durationFast, Curves.bounceIn))),
        '/box/motion/curve',
      ),
      ('custom alignment', const Style(box: BoxStyle(alignment: Alignment(0.5, 0.5))), '/box/alignment'),
      ('directional alignment', const Style(box: BoxStyle(alignment: AlignmentDirectional.topStart)), '/box/alignment'),
      (
        'combined decoration',
        Style(
          text: StyledTextStyle(
            decoration: TextDecoration.combine([TextDecoration.underline, TextDecoration.overline]),
          ),
        ),
        '/text/decoration',
      ),
      ('maxLines of zero', const Style(text: StyledTextStyle(maxLines: 0)), '/text/maxLines'),
      (
        'border style',
        const Style(
          box: BoxStyle(
            border: StyledBorder.all(color: _T.line, width: _T.strokeWidth, style: BorderStyle.solid),
          ),
        ),
        '/box/border/style',
      ),
      (
        'border none with a colour',
        const Style(
          box: BoxStyle(
            border: StyledBorder(color: _T.line, width: StyleValue.zero, style: BorderStyle.none),
          ),
        ),
        '/box/border/style',
      ),
      (
        'StyledBorderSide.none',
        const Style(
          box: BoxStyle(border: StyledBorder(top: StyledBorderSide.none)),
        ),
        '/box/border/top/style',
      ),
      (
        'symmetric border, whose other sides are StyledBorderSide.none',
        const Style(
          box: BoxStyle(
            border: StyledBorder.symmetric(
              vertical: StyledBorderSide(color: _T.line, width: _T.strokeWidth),
            ),
          ),
        ),
        '/box/border/top/style',
      ),
      (
        'nested states',
        const Style().on(
          StyleState.hovered,
          style: const Style().on(StyleState.pressed, box: const BoxStyle(color: _T.primary)),
        ),
        '/states/hovered/states',
      ),
      (
        'capitalised state name',
        const Style().on(const StyleState('Selected'), box: const BoxStyle(color: _T.primary)),
        '/states/Selected',
      ),
      (
        'state name with a slash',
        const Style().on(const StyleState('a/b'), box: const BoxStyle(color: _T.primary)),
        '/states/a~1b',
      ),
      (
        'error inside a state',
        const Style().on(StyleState.hovered, box: const BoxStyle(color: data)),
        '/states/hovered/box/color',
      ),
      // Fields the schema does not cover.
      (
        'BoxStyle.gradient',
        const Style(
          box: BoxStyle(gradient: DataValue(LinearGradient(colors: [Color(0xFF000000), Color(0xFFFFFFFF)]))),
        ),
        '/box/gradient',
      ),
      (
        'BoxStyle.image',
        const Style(
          box: BoxStyle(image: DecorationImage(image: AssetImage('a.png'))),
        ),
        '/box/image',
      ),
      (
        'BoxStyle.backgroundBlendMode',
        const Style(box: BoxStyle(backgroundBlendMode: BlendMode.multiply)),
        '/box/backgroundBlendMode',
      ),
      (
        'BoxStyle.foregroundDecoration',
        const Style(box: BoxStyle(foregroundDecoration: DataValue(BoxDecoration()))),
        '/box/foregroundDecoration',
      ),
      (
        'BoxStyle.transformAlignment',
        const Style(box: BoxStyle(transformAlignment: Alignment.center)),
        '/box/transformAlignment',
      ),
      (
        'StyledTextStyle.backgroundColor',
        const Style(text: StyledTextStyle(backgroundColor: _T.primary)),
        '/text/backgroundColor',
      ),
      (
        'StyledTextStyle.fontFamilyFallback',
        const Style(text: StyledTextStyle(fontFamilyFallback: ['Roboto'])),
        '/text/fontFamilyFallback',
      ),
      ('StyledTextStyle.wordSpacing', const Style(text: StyledTextStyle(wordSpacing: _T.gap)), '/text/wordSpacing'),
      (
        'StyledTextStyle.textBaseline',
        const Style(text: StyledTextStyle(textBaseline: TextBaseline.alphabetic)),
        '/text/textBaseline',
      ),
      (
        'StyledTextStyle.leadingDistribution',
        const Style(text: StyledTextStyle(leadingDistribution: TextLeadingDistribution.even)),
        '/text/leadingDistribution',
      ),
      ('StyledTextStyle.locale', const Style(text: StyledTextStyle(locale: Locale('en'))), '/text/locale'),
      ('StyledTextStyle.foreground', Style(text: StyledTextStyle(foreground: Paint())), '/text/foreground'),
      ('StyledTextStyle.background', Style(text: StyledTextStyle(background: Paint())), '/text/background'),
      ('StyledTextStyle.shadows', const Style(text: StyledTextStyle(shadows: DataValue([]))), '/text/shadows'),
      (
        'StyledTextStyle.fontFeatures',
        const Style(text: StyledTextStyle(fontFeatures: [FontFeature.tabularFigures()])),
        '/text/fontFeatures',
      ),
      (
        'StyledTextStyle.fontVariations',
        const Style(text: StyledTextStyle(fontVariations: [FontVariation('wght', 400)])),
        '/text/fontVariations',
      ),
      (
        'StyledTextStyle.decorationStyle',
        const Style(text: StyledTextStyle(decorationStyle: TextDecorationStyle.dashed)),
        '/text/decorationStyle',
      ),
      (
        'StyledTextStyle.decorationThickness',
        const Style(text: StyledTextStyle(decorationThickness: _T.strokeWidth)),
        '/text/decorationThickness',
      ),
      (
        'StyledTextStyle.textDirection',
        const Style(text: StyledTextStyle(textDirection: TextDirection.rtl)),
        '/text/textDirection',
      ),
      (
        'StyledTextStyle.textScaler',
        const Style(text: StyledTextStyle(textScaler: TextScaler.noScaling)),
        '/text/textScaler',
      ),
      (
        'StyledTextStyle.textWidthBasis',
        const Style(text: StyledTextStyle(textWidthBasis: TextWidthBasis.longestLine)),
        '/text/textWidthBasis',
      ),
      (
        'StyledTextStyle.textHeightBehavior',
        const Style(text: StyledTextStyle(textHeightBehavior: TextHeightBehavior())),
        '/text/textHeightBehavior',
      ),
      (
        'StyledTextStyle.selectionColor',
        const Style(text: StyledTextStyle(selectionColor: _T.primary)),
        '/text/selectionColor',
      ),
      ('IconStyle.fill', const Style(icon: IconStyle(fill: _T.opacityFaint)), '/icon/fill'),
      ('IconStyle.weight', const Style(icon: IconStyle(weight: _T.gap)), '/icon/weight'),
      ('IconStyle.grade', const Style(icon: IconStyle(grade: _T.gap)), '/icon/grade'),
      ('IconStyle.opticalSize', const Style(icon: IconStyle(opticalSize: _T.iconSize)), '/icon/opticalSize'),
      ('IconStyle.shadows', const Style(icon: IconStyle(shadows: DataValue([]))), '/icon/shadows'),
      (
        'IconStyle.textDirection',
        const Style(icon: IconStyle(textDirection: TextDirection.ltr)),
        '/icon/textDirection',
      ),
      ('IconStyle.applyTextScaling', const Style(icon: IconStyle(applyTextScaling: true)), '/icon/applyTextScaling'),
      ('FlexStyle.wrap', const Style(flex: FlexStyle(wrap: true)), '/flex/wrap'),
      ('FlexStyle.runSpacing', const Style(flex: FlexStyle(runSpacing: _T.gap)), '/flex/runSpacing'),
      (
        'FlexStyle.wrapAlignment',
        const Style(flex: FlexStyle(wrapAlignment: WrapAlignment.center)),
        '/flex/wrapAlignment',
      ),
      (
        'FlexStyle.wrapCrossAxisAlignment',
        const Style(flex: FlexStyle(wrapCrossAxisAlignment: WrapCrossAlignment.center)),
        '/flex/wrapCrossAxisAlignment',
      ),
      ('FlexStyle.runAlignment', const Style(flex: FlexStyle(runAlignment: WrapAlignment.end)), '/flex/runAlignment'),
      (
        'FlexStyle.verticalDirection',
        const Style(flex: FlexStyle(verticalDirection: VerticalDirection.up)),
        '/flex/verticalDirection',
      ),
      (
        'FlexStyle.textDirection',
        const Style(flex: FlexStyle(textDirection: TextDirection.rtl)),
        '/flex/textDirection',
      ),
      (
        'FlexStyle.textBaseline',
        const Style(flex: FlexStyle(textBaseline: TextBaseline.ideographic)),
        '/flex/textBaseline',
      ),
      ('FlexStyle.clipBehavior', const Style(flex: FlexStyle(clipBehavior: Clip.hardEdge)), '/flex/clipBehavior'),
      ('ImageStyle.alignment', const Style(image: ImageStyle(alignment: Alignment.center)), '/image/alignment'),
      ('ImageStyle.color', const Style(image: ImageStyle(color: _T.primary)), '/image/color'),
      (
        'ImageStyle.colorBlendMode',
        const Style(image: ImageStyle(colorBlendMode: BlendMode.srcIn)),
        '/image/colorBlendMode',
      ),
      ('ImageStyle.repeat', const Style(image: ImageStyle(repeat: ImageRepeat.repeat)), '/image/repeat'),
      ('ImageStyle.centerSlice', const Style(image: ImageStyle(centerSlice: Rect.zero)), '/image/centerSlice'),
      (
        'ImageStyle.matchTextDirection',
        const Style(image: ImageStyle(matchTextDirection: true)),
        '/image/matchTextDirection',
      ),
      ('ImageStyle.gaplessPlayback', const Style(image: ImageStyle(gaplessPlayback: true)), '/image/gaplessPlayback'),
      ('ImageStyle.isAntiAlias', const Style(image: ImageStyle(isAntiAlias: true)), '/image/isAntiAlias'),
      (
        'ImageStyle.filterQuality',
        const Style(image: ImageStyle(filterQuality: FilterQuality.high)),
        '/image/filterQuality',
      ),
      ('ImageStyle.opacity', const Style(image: ImageStyle(opacity: _T.opacityFaint)), '/image/opacity'),
    ];

    for (final (name, style, path) in cases) {
      test('$name fails at $path', () {
        expect(style.toJson, _throwsAt(path));
      });
    }
  });

  group('merging decoded styles', () {
    test('merging over an empty style yields the decoded style', () {
      final decoded = Style.fromJson(_presetStyle(_quietPreset), _lookup);
      expect(const Style().merge(decoded), decoded);
      expect(const Style() + decoded, decoded);
    });

    test('a decoded state merges with the base state of the same name', () {
      final base = const Style(box: BoxStyle(color: _T.surface))
          .on(
            StyleState.hovered,
            box: const BoxStyle(border: StyledBorder(color: _T.line)),
            text: const StyledTextStyle(color: _T.onSurfaceMuted, fontWeight: _T.weightBold),
          )
          .on(StyleState.pressed, box: const BoxStyle(color: _T.accent));
      final decoded = Style.fromJson(_presetStyle(_quietPreset), _lookup);

      final merged = base + decoded;

      expect(
        merged.states[StyleState.hovered],
        const Style(
          box: BoxStyle(
            color: AlphaOf(_T.primary, _T.opacityFaint),
            border: StyledBorder(color: _T.line),
          ),
          text: StyledTextStyle(color: _T.primary, fontWeight: _T.weightBold),
          icon: IconStyle(color: _T.primary),
        ),
      );
      expect(merged.states[StyleState.pressed], base.states[StyleState.pressed]);
      expect(merged.resolveStates([StyleState.hovered]).box.color, const AlphaOf(_T.primary, _T.opacityFaint));
      expect(merged.resolveStates([StyleState.hovered]).text.color, _T.primary);
      expect(merged.resolveStates(const []).text.color, _T.onSurfaceMuted);
    });

    test('an empty boxShadow list removes the base shadow', () {
      const base = Style(
        box: BoxStyle(color: _T.surface, boxShadow: [StyledBoxShadow.level(_T.primary, _T.shadowMd)]),
      );
      final merged = base + Style.fromJson(_presetStyle(_highlightPreset), _lookup);
      expect(merged.box.boxShadow, isEmpty);
      expect(merged.box.decoration(const StyledTheme()).boxShadow, isEmpty);
      expect(merged.box.color, _T.accentSubtle);
    });

    test('an absent boxShadow keeps the base shadow', () {
      const base = Style(box: BoxStyle(boxShadow: [StyledBoxShadow.level(_T.primary, _T.shadowMd)]));
      final merged = base + _decode(_parse('{"box": {"color": "surface"}}'));
      expect(merged.box.boxShadow, base.box.boxShadow);
    });

    test('a decoded border merges field by field like StyledBorder.all', () {
      const base = Style(
        box: BoxStyle(
          border: StyledBorder.all(color: _T.line, width: _T.strokeWidth, radius: _T.cardRadius),
        ),
      );
      final merged = base + _decode(_parse('{"box": {"border": {"color": "primary"}}}'));
      expect(
        merged.box.border,
        const StyledBorder.all(color: _T.primary, width: _T.strokeWidth, radius: _T.cardRadius),
      );
    });
  });
}
