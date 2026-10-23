import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:styled/styled.dart';

class _Colors {
  static const white = ThemeToken<Color>('test.white', Color(0xFFFFFFFF));
  static const black = ThemeToken<Color>('test.black', Color(0xFF000000));
  static const blue = ThemeToken<Color>('test.blue', Color(0xFF2196F3));
  static const red = ThemeToken<Color>('test.red', Color(0xFFF44336));
  static const green = ThemeToken<Color>('test.green', Color(0xFF4CAF50));

  static const amber = ThemeToken<Color>('test.amber', Color(0xFFFFC107));
  static const grey = ThemeToken<Color>('test.grey', Color(0xFF9E9E9E));
  static const purple = ThemeToken<Color>('test.purple', Color(0xFF9C27B0));
  static const cyan = ThemeToken<Color>('test.cyan', Color(0xFF00BCD4));
  static const orange = ThemeToken<Color>('test.orange', Color(0xFFFF9800));
}

const _selected = StyleState('selected');

Widget testApp([dynamic home, WidgetBuilder? builder, StyledTheme? theme]) {
  final Widget? effectiveHome = home is Widget ? home : null;
  return StyledThemeControllerProvider(
    controller: StyledThemeController(theme ?? const StyledTheme()),
    child: WidgetsApp(
      color: const Color(0xFF0000FF),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) =>
              effectiveHome ??
              (builder != null ? builder(context) : const SizedBox()),
        ),
      ),
      textStyle: const TextStyle(color: Color(0xFFFFFFFF)),
      localizationsDelegates: const [DefaultWidgetsLocalizations.delegate],
    ),
  );
}

/// The style the innermost box publishes to its descendants.
Style _innermostStyle(WidgetTester tester) =>
    tester.widget<InheritedStyle>(find.byType(InheritedStyle).last).style;

void main() {
  group('Style', () {
    test('on and resolveStates apply overrides; later states win', () {
      final base = const Style(
        box: BoxStyle(
          color: _Colors.white,
          border: StyledBorder.all(color: _Colors.black, width: DataValue(1.0), radius: DataValue(8.0)),
        ),
        text: StyledTextStyle(color: _Colors.black),
      )
          .on(StyleState.hovered, box: const BoxStyle(color: _Colors.blue))
          .on(StyleState.disabled, box: const BoxStyle(color: _Colors.grey))
          .on(_selected, text: const StyledTextStyle(color: _Colors.amber));

      expect(base.box.color, _Colors.white);
      expect(base.box.border?.radius, const DataValue(8.0));

      final hovered = base.resolveStates([StyleState.hovered]);
      expect(hovered.box.color, _Colors.blue);
      expect(hovered.text.color, _Colors.black);
      expect(hovered.states, isEmpty);

      final compound = base.resolveStates([_selected, StyleState.hovered]);
      expect(compound.box.color, _Colors.blue);
      expect(compound.text.color, _Colors.amber);

      expect(base.resolveStates([StyleState.hovered, StyleState.disabled]).box.color, _Colors.grey);
    });

    test('on merges into an existing override for the same state', () {
      final style = const Style()
          .on(StyleState.hovered, box: const BoxStyle(color: _Colors.blue))
          .on(StyleState.hovered, text: const StyledTextStyle(color: _Colors.red));
      final hovered = style.resolveStates([StyleState.hovered]);
      expect(hovered.box.color, _Colors.blue);
      expect(hovered.text.color, _Colors.red);
    });

    test('merge and + combine sub-styles and states without casts', () {
      const a = Style(box: BoxStyle(color: _Colors.white, padding: StyledEdgeInsets.all(DataValue(4.0))));
      final b = const Style(box: BoxStyle(color: _Colors.red)).on(StyleState.pressed, box: const BoxStyle(color: _Colors.green));
      final Style merged = a + b;
      expect(merged.box.color, _Colors.red);
      expect(merged.box.padding, const StyledEdgeInsets.all(DataValue(4.0)));
      expect(merged.hasState(StyleState.pressed), isTrue);
      expect(a.merge(null), same(a));
    });

    test('equal styles with states have equal hash codes', () {
      Style build() => const Style(box: BoxStyle(color: _Colors.blue))
          .on(StyleState.hovered, box: const BoxStyle(color: _Colors.red))
          .on(_selected, text: const StyledTextStyle(fontSize: DataValue(14.0)));
      expect(build(), equals(build()));
      expect(build().hashCode, equals(build().hashCode));
      expect(build(), isNot(equals(const Style(box: BoxStyle(color: _Colors.blue)))));
    });

    test('BoxStyle equality covers decoration, transform and motion', () {
      const level = ThemeToken<ShadowLevel>('test.level', ShadowLevel(opacity: 0.5, blurRadius: 4));
      BoxStyle build({ThemeToken<Color> shadow = _Colors.black}) => BoxStyle(
            color: _Colors.blue,
            boxShadow: [StyledBoxShadow.level(shadow, level)],
            transform: const StyledTransform.translate(y: DataValue(-2.0)),
            transformAlignment: Alignment.center,
            motion: const Motion(DataValue(Duration(milliseconds: 200)), Curves.easeInOut),
            foregroundDecoration: const DataValue(BoxDecoration(color: Color(0x11FF0000))),
            backgroundBlendMode: BlendMode.colorBurn,
          );
      expect(build(), equals(build()));
      expect(build().hashCode, equals(build().hashCode));
      expect(build(), isNot(equals(build(shadow: _Colors.white))));
    });

    test('BoxStyle.merge keeps motion and merges borders field by field', () {
      const base = BoxStyle(
        color: _Colors.blue,
        motion: Motion(DataValue(Duration(milliseconds: 300)), Curves.bounceOut),
        border: StyledBorder.all(color: _Colors.grey, width: DataValue(1.0), radius: DataValue(8.0)),
      );
      final merged = base.merge(const BoxStyle(color: _Colors.red, border: StyledBorder(color: _Colors.blue)));
      expect(merged.color, _Colors.red);
      expect(merged.motion, const Motion(DataValue(Duration(milliseconds: 300)), Curves.bounceOut));
      expect(merged.border, const StyledBorder(color: _Colors.blue, width: DataValue(1.0), radius: DataValue(8.0)));
      const theme = StyledTheme();
      expect(merged.decoration(theme).borderRadius, BorderRadius.circular(8));
      expect((merged.decoration(theme).border! as Border).top.color, _Colors.blue.defaultValue);
    });

    test('StyledBorder draws a uniform side only when colour and width are known', () {
      const theme = StyledTheme();
      expect(const StyledBorder.all(radius: DataValue(8.0)).boxBorder(theme), isNull);
      expect(const StyledBorder.all(color: _Colors.red).boxBorder(theme), isNull);
      final sides = const StyledBorder(color: _Colors.red, width: DataValue(2.0), bottom: StyledBorderSide(color: _Colors.blue))
          .boxBorder(theme)! as Border;
      expect(sides.top.color, _Colors.red.defaultValue);
      expect(sides.bottom.color, _Colors.blue.defaultValue);
    });

    test('StyleResolver.map and merge defer until resolve', () {
      final resolver = const Style(box: BoxStyle(color: _Colors.white))
          .map((s) => s.add(text: const StyledTextStyle(color: _Colors.green)))
          .merge(const Style(icon: IconStyle(size: DataValue(30.0))));
      final resolved = resolver.resolve(_MockBuildContext());
      expect(resolved.box.color, _Colors.white);
      expect(resolved.text.color, _Colors.green);
      expect(resolved.icon.size, const DataValue(30.0));
    });

    test('sub-style merge, equality and hashCode', () {
      const flexA = FlexStyle(direction: Axis.horizontal, spacing: DataValue(12.0), wrap: true, runSpacing: DataValue(8.0));
      expect(flexA, equals(const FlexStyle(direction: Axis.horizontal, spacing: DataValue(12.0), wrap: true, runSpacing: DataValue(8.0))));
      expect(flexA.hashCode, equals(const FlexStyle(direction: Axis.horizontal, spacing: DataValue(12.0), wrap: true, runSpacing: DataValue(8.0)).hashCode));
      final merged = const FlexStyle(spacing: DataValue(10.0), clipBehavior: Clip.hardEdge).merge(const FlexStyle(spacing: DataValue(20.0)));
      expect(merged.spacing, const DataValue(20.0));
      expect(merged.clipBehavior, Clip.hardEdge);

      const textA = StyledTextStyle(color: _Colors.blue, fontSize: DataValue(16.0), shadows: DataValue([Shadow(color: Color(0xFF000000), blurRadius: 2)]), maxLines: 3);
      final textB = const StyledTextStyle(color: _Colors.red).merge(textA);
      expect(textB, equals(textA));
      expect(textB.hashCode, equals(textA.hashCode));

      const iconA = IconStyle(color: _Colors.amber, size: DataValue(24.0), shadows: DataValue([Shadow(color: Color(0xFF000000), blurRadius: 4)]));
      expect(const IconStyle(size: DataValue(12.0)).merge(iconA), equals(iconA));

      final img = const ImageStyle(width: DataValue(100.0), height: DataValue(100.0)).merge(const ImageStyle(width: DataValue(200.0), fit: BoxFit.contain));
      expect(img.width, const DataValue(200.0));
      expect(img.height, const DataValue(100.0));
      expect(img.fit, BoxFit.contain);
    });
  });

  group('Style values', () {
    const opacity = ThemeToken<double>('test.opacity', 0.25);
    const gap = ThemeToken<double>('test.gap', 8);
    const level = ThemeToken<ShadowLevel>('test.level', ShadowLevel(opacity: 0.5, blurRadius: 10, dy: 2));
    const size = ThemeToken<double>('test.size', 40);
    const lift = ThemeToken<double>('test.lift', -2);
    const stroke = ThemeToken<double>('test.stroke', 1);
    const textSize = ThemeToken<double>('test.textSize', 14);

    test('tokens resolve against the theme and fall back to their defaults', () {
      expect(_Colors.blue.resolve(const StyledTheme()), _Colors.blue.defaultValue);
      final theme = const StyledTheme().set(_Colors.blue, _Colors.red.defaultValue);
      expect(_Colors.blue.resolve(theme), _Colors.red.defaultValue);
    });

    test('AlphaOf takes its opacity from a token', () {
      const value = AlphaOf(_Colors.blue, opacity);
      expect(value.resolve(const StyledTheme()), _Colors.blue.defaultValue.withValues(alpha: 0.25));
      expect(value.resolve(const StyledTheme().set(opacity, 0.5)).a, closeTo(0.5, 0.001));
      expect(const AlphaOf(DataValue(Color(0xFF00FF00)), opacity), const AlphaOf(DataValue(Color(0xFF00FF00)), opacity));
    });

    test('DataValue.of wraps non-null values only', () {
      expect(DataValue.of<Color>(null), isNull);
      expect(DataValue.of(const Color(0xFF123456))?.value, const Color(0xFF123456));
    });

    test('layout constants resolve to themselves', () {
      expect(StyleValue.infinity.resolve(const StyledTheme()), double.infinity);
      expect(StyleValue.zero.resolve(const StyledTheme()), 0);
    });

    test('wrappers resolve to Flutter types', () {
      final theme = const StyledTheme().set(gap, 12).set(size, 300).set(lift, -4).set(stroke, 2);
      expect(const StyledEdgeInsets.symmetric(horizontal: gap).resolve(theme), const EdgeInsets.symmetric(horizontal: 12));
      expect(const StyledEdgeInsets.only(top: gap, left: StyleValue.zero).resolve(theme), const EdgeInsets.only(top: 12));
      expect(const StyledBoxConstraints(maxWidth: size).resolve(theme), const BoxConstraints(maxWidth: 300));
      expect(const StyledTransform.translate(y: lift).resolve(theme), Matrix4.translationValues(0, -4, 0));
      expect(
        const StyledBoxShadow.level(_Colors.blue, level).resolve(theme),
        BoxShadow(color: _Colors.blue.defaultValue.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 2)),
      );
      expect(const StyledBorderSide(color: _Colors.red, width: stroke).resolve(theme), BorderSide(color: _Colors.red.defaultValue, width: 2));
    });

    test('wrappers offer the core Flutter constructors', () {
      final theme = const StyledTheme().set(gap, 12).set(size, 300).set(stroke, 2);
      expect(const StyledBoxConstraints.expand().resolve(theme), const BoxConstraints.expand());
      expect(const StyledBoxConstraints.expand(height: size).resolve(theme), const BoxConstraints.expand(height: 300));
      expect(const StyledBoxConstraints.tightFor(width: size).resolve(theme), const BoxConstraints.tightFor(width: 300));
      expect(
        const StyledEdgeInsets.fromLTRB(gap, StyleValue.zero, gap, gap).resolve(theme),
        const EdgeInsets.fromLTRB(12, 0, 12, 12),
      );

      const side = StyledBorderSide(color: _Colors.red, width: stroke);
      final all = const StyledBorder.fromBorderSide(side).boxBorder(theme)! as Border;
      expect(all.left, BorderSide(color: _Colors.red.defaultValue, width: 2));
      expect(all.bottom, BorderSide(color: _Colors.red.defaultValue, width: 2));

      final symmetric = const StyledBorder.symmetric(horizontal: side).boxBorder(theme)! as Border;
      expect(symmetric.top.width, 2);
      expect(symmetric.left.style, BorderStyle.none);
    });

    test('wrappers work with dot shorthand', () {
      const style = BoxStyle(
        padding: .symmetric(horizontal: gap),
        border: .all(color: _Colors.red, width: stroke, radius: gap),
        transform: .translate(y: lift),
        constraints: .tightFor(width: size),
        width: .infinity,
      );
      expect(style.padding, const StyledEdgeInsets.symmetric(horizontal: gap));
      expect(style.width, StyleValue.infinity);
    });

    test('ThemedStyle produces Flutter types', () {
      const style = Style(text: StyledTextStyle(color: _Colors.green, fontSize: textSize));
      final bound = style.bind(const StyledTheme().set(textSize, 18));
      expect(bound.textStyle.color, _Colors.green.defaultValue);
      expect(bound.textStyle.fontSize, 18);
    });

    testWidgets('changing the theme re-resolves every token in place', (tester) async {
      final controller = StyledThemeController();
      await tester.pumpWidget(StyledThemeControllerProvider(
        controller: controller,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: StyledBox(style: Style(box: BoxStyle(color: _Colors.blue, padding: StyledEdgeInsets.all(gap))), child: SizedBox()),
        ),
      ));
      Container container() => tester.widget<Container>(find.byType(Container));
      expect((container().decoration! as BoxDecoration).color, _Colors.blue.defaultValue);
      expect(container().padding, const EdgeInsets.all(8));

      controller.updateTheme(const StyledTheme().set(_Colors.blue, _Colors.orange.defaultValue).set(gap, 20));
      await tester.pump();
      expect((container().decoration! as BoxDecoration).color, _Colors.orange.defaultValue);
      expect(container().padding, const EdgeInsets.all(20));
    });
  });

  group('StyledBox', () {
    testWidgets('renders a container and publishes its style', (tester) async {
      await tester.pumpWidget(testApp(
        const StyledBox(
          style: Style(box: BoxStyle(width: DataValue(100.0), height: DataValue(100.0), color: _Colors.blue)),
          child: Text('Box Child'),
        ),
      ));
      expect(find.text('Box Child'), findsOneWidget);
      expect(_innermostStyle(tester).box.color, _Colors.blue);
    });

    testWidgets('lays out children as a Flex from style.flex', (tester) async {
      await tester.pumpWidget(testApp(
        const StyledBox(
          style: Style(flex: FlexStyle(direction: Axis.horizontal, spacing: DataValue(24.0), clipBehavior: Clip.hardEdge)),
          children: [Text('Child 1'), Text('Child 2')],
        ),
      ));
      final flex = tester.widget<Flex>(find.byType(Flex));
      expect(flex.direction, Axis.horizontal);
      expect(flex.spacing, 24.0);
      expect(flex.clipBehavior, Clip.hardEdge);
      expect(flex.children.length, 2);
    });

    testWidgets('lays out children as a Wrap when flex.wrap is true', (tester) async {
      await tester.pumpWidget(testApp(
        const StyledBox(
          style: Style(
            flex: FlexStyle(
              wrap: true,
              spacing: DataValue(12.0),
              runSpacing: DataValue(16.0),
              wrapAlignment: WrapAlignment.center,
              wrapCrossAxisAlignment: WrapCrossAlignment.end,
              runAlignment: WrapAlignment.spaceBetween,
            ),
          ),
          children: [Text('Wrap 1'), Text('Wrap 2')],
        ),
      ));
      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.spacing, 12.0);
      expect(wrap.runSpacing, 16.0);
      expect(wrap.alignment, WrapAlignment.center);
      expect(wrap.crossAxisAlignment, WrapCrossAlignment.end);
      expect(wrap.runAlignment, WrapAlignment.spaceBetween);
    });

    testWidgets('StyledRow and StyledColumn force their direction', (tester) async {
      await tester.pumpWidget(testApp(
        const Column(
          children: [
            StyledRow(style: Style(flex: FlexStyle(spacing: DataValue(16.0))), children: [Text('Row 1')]),
            StyledColumn(style: Style(flex: FlexStyle(direction: Axis.horizontal)), children: [Text('Col 1')]),
          ],
        ),
      ));
      final flexes = tester.widgetList<Flex>(find.byType(Flex)).toList();
      expect(flexes[0].direction, Axis.horizontal);
      expect(flexes[0].spacing, 16.0);
      expect(flexes[1].direction, Axis.vertical);
    });

    testWidgets('animates when style.box.motion is set, without widget flags', (tester) async {
      await tester.pumpWidget(testApp(
        const StyledBox(
          style: Style(box: BoxStyle(color: _Colors.blue, motion: Motion(DataValue(Duration(milliseconds: 250))))),
          child: SizedBox(),
        ),
      ));
      final animated = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      expect(animated.duration, const Duration(milliseconds: 250));

      await tester.pumpWidget(testApp(const StyledBox(style: Style(box: BoxStyle(color: _Colors.blue)), child: SizedBox())));
      expect(find.byType(AnimatedContainer), findsNothing);
    });

    testWidgets('renders transform and foregroundDecoration', (tester) async {
      await tester.pumpWidget(testApp(
        const StyledBox(
          style: Style(
            box: BoxStyle(
              width: DataValue(100.0),
              height: DataValue(100.0),
              transform: StyledTransform.translate(x: DataValue(4.0), y: DataValue(-2.0)),
              transformAlignment: Alignment.center,
              foregroundDecoration: DataValue(BoxDecoration(color: Color(0x11FF0000))),
            ),
          ),
          child: Text('Transformed Box'),
        ),
      ));
      final container = tester.widget<Container>(find.byType(Container));
      expect(container.transform, Matrix4.translationValues(4, -2, 0));
      expect(container.transformAlignment, Alignment.center);
      expect(container.foregroundDecoration, isNotNull);
    });

    testWidgets('activates application states passed in states', (tester) async {
      final style = const Style(box: BoxStyle(color: _Colors.white)).on(_selected, box: const BoxStyle(color: _Colors.purple));
      await tester.pumpWidget(testApp(StyledBox(style: style, states: const [_selected], child: const SizedBox())));
      expect(_innermostStyle(tester).box.color, _Colors.purple);
    });

    testWidgets('activates the current screen tier as a state', (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final style = const Style(box: BoxStyle(color: _Colors.white))
          .on(StyledScreen.mobile.state, box: const BoxStyle(color: _Colors.orange))
          .on(StyledScreen.desktop.state, box: const BoxStyle(color: _Colors.cyan));
      await tester.pumpWidget(testApp(StyledBox(style: style, child: const SizedBox())));
      expect(_innermostStyle(tester).box.color, _Colors.orange);
    });

    testWidgets('screen breakpoints come from theme tokens', (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late StyledScreen screen;
      await tester.pumpWidget(testApp(
        null,
        (context) {
          screen = context.screen;
          return const SizedBox();
        },
        const StyledTheme().set(StyledBreakpoints.mobile, 400),
      ));
      expect(screen, StyledScreen.tablet);
    });

    testWidgets('text and icon properties cascade to StyledText and StyledIcon', (tester) async {
      await tester.pumpWidget(testApp(
        const StyledBox(
          style: Style(text: StyledTextStyle(color: _Colors.red, fontSize: DataValue(18.0)), icon: IconStyle(size: DataValue(22.0))),
          children: [
            StyledText('Inherited'),
            StyledText('Own', style: Style(text: StyledTextStyle(fontSize: DataValue(10.0)))),
            StyledIcon(IconData(0xe123, fontFamily: 'TestIcons')),
          ],
        ),
      ));
      expect(tester.widget<Text>(find.text('Inherited')).style?.color, _Colors.red.defaultValue);
      final own = tester.widget<Text>(find.text('Own'));
      expect(own.style?.color, _Colors.red.defaultValue);
      expect(own.style?.fontSize, 10);
      expect(tester.widget<Icon>(find.byType(Icon)).size, 22);
    });
  });

  group('Interactive StyledBox', () {
    testWidgets('handles focused and disabled overrides', (tester) async {
      final style = const Style(box: BoxStyle(color: _Colors.white))
          .on(StyleState.focused, box: const BoxStyle(color: _Colors.blue))
          .on(StyleState.disabled, box: const BoxStyle(color: _Colors.grey));

      await tester.pumpWidget(testApp(StyledBox(
        style: style,
        interaction: Interaction(focused: true, onTap: () {}),
        child: const Text('Focused Button'),
      )));
      expect(_innermostStyle(tester).box.color, _Colors.blue);

      await tester.pumpWidget(testApp(StyledBox(
        style: style,
        interaction: Interaction(enabled: false, onTap: () {}),
        child: const Text('Disabled Button'),
      )));
      expect(_innermostStyle(tester).box.color, _Colors.grey);
    });

    testWidgets('a box without handlers is not visually disabled', (tester) async {
      final style = const Style(box: BoxStyle(color: _Colors.white)).on(StyleState.disabled, box: const BoxStyle(color: _Colors.grey));
      await tester.pumpWidget(testApp(StyledBox(style: style, interaction: const Interaction(), child: const Text('Passive'))));
      expect(_innermostStyle(tester).box.color, _Colors.white);
    });

    testWidgets('pressed wins over hovered while both are active', (tester) async {
      final style = const Style(
        box: BoxStyle(width: DataValue(100.0), height: DataValue(100.0), color: _Colors.white),
      )
          .on(StyleState.pressed, box: const BoxStyle(color: _Colors.green))
          .on(StyleState.hovered, box: const BoxStyle(color: _Colors.blue));

      await tester.pumpWidget(testApp(StyledBox(style: style, interaction: Interaction(onTap: () {}), child: const Text('Target'))));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Target')));
      await tester.pump();
      expect(_innermostStyle(tester).box.color, _Colors.blue);

      await mouse.down(tester.getCenter(find.text('Target')));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_innermostStyle(tester).box.color, _Colors.green);

      await mouse.up();
      await tester.pump(const Duration(milliseconds: 350));
      expect(_innermostStyle(tester).box.color, _Colors.blue);
      await mouse.removePointer();
    });

    testWidgets('fires full gestures and callbacks', (tester) async {
      var tapped = false;
      var doubleTapped = false;
      var longPressed = false;
      var secondaryTapped = false;
      bool? hoverState;
      bool? pressState;

      await tester.pumpWidget(testApp(StyledBox(
        style: const Style(box: BoxStyle(width: DataValue(100.0), height: DataValue(100.0), color: _Colors.blue)),
        interaction: Interaction(
          onTap: () => tapped = true,
          onDoubleTap: () => doubleTapped = true,
          onLongPress: () => longPressed = true,
          onSecondaryTap: () => secondaryTapped = true,
          onHoverChange: (h) => hoverState = h,
          onPressedChange: (p) => pressState = p,
        ),
        child: const Text('Interact'),
      )));

      final target = find.text('Interact');
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 350));
      expect(tapped, isTrue);

      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(doubleTapped, isTrue);

      await tester.longPress(target);
      await tester.pumpAndSettle();
      expect(longPressed, isTrue);

      await tester.tap(target, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(secondaryTapped, isTrue);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(target));
      await tester.pumpAndSettle();
      expect(hoverState, isTrue);
      await gesture.moveTo(const Offset(500, 500));
      await gesture.removePointer();
      await tester.pumpAndSettle();
      expect(hoverState, isFalse);

      final press = await tester.startGesture(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 150));
      expect(pressState, isTrue);
      await press.up();
      await tester.pump(const Duration(milliseconds: 350));
      expect(pressState, isFalse);
    });

    testWidgets('fires onTapDown, onTapUp and onTapCancel', (tester) async {
      var tapDown = false;
      var tapUp = false;
      var tapCancel = false;

      await tester.pumpWidget(testApp(StyledBox(
        style: const Style(box: BoxStyle(width: DataValue(100.0), height: DataValue(100.0))),
        interaction: Interaction(
          onTapDown: (_) => tapDown = true,
          onTapUp: (_) => tapUp = true,
          onTapCancel: () => tapCancel = true,
          onTap: () {},
        ),
        child: const Text('Touch Target'),
      )));

      final gesture = await tester.startGesture(tester.getCenter(find.text('Touch Target')));
      expect(tapDown, isTrue);
      await gesture.up();
      expect(tapUp, isTrue);
      expect(tapCancel, isFalse);
    });

    testWidgets('interactive rows, columns and wraps respond to taps', (tester) async {
      var rowTapped = false;
      var colTapped = false;
      var wrapTapped = false;
      await tester.pumpWidget(testApp(Column(
        children: [
          StyledRow(interaction: Interaction(onTap: () => rowTapped = true), children: const [Text('Row Child')]),
          StyledColumn(interaction: Interaction(onTap: () => colTapped = true), children: const [Text('Col Child')]),
          StyledBox(
            style: const Style(flex: FlexStyle(wrap: true)),
            interaction: Interaction(onTap: () => wrapTapped = true),
            children: const [Text('Wrap Child')],
          ),
        ],
      )));
      await tester.tap(find.text('Row Child'));
      await tester.tap(find.text('Col Child'));
      await tester.tap(find.text('Wrap Child'));
      expect([rowTapped, colTapped, wrapTapped], everyElement(isTrue));
    });

    testWidgets('a tappable image is a StyledImage inside an interactive box', (tester) async {
      var tapped = false;
        final testBytes = Uint8List.fromList([
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
          0x00,
          0x00,
          0x00,
          0x0D,
          0x49,
          0x48,
          0x44,
          0x52,
          0x00,
          0x00,
          0x00,
          0x01,
          0x00,
          0x00,
          0x00,
          0x01,
          0x08,
          0x06,
          0x00,
          0x00,
          0x00,
          0x1F,
          0x15,
          0xC4,
          0x89,
          0x00,
          0x00,
          0x00,
          0x0A,
          0x49,
          0x44,
          0x41,
          0x54,
          0x78,
          0x9C,
          0x63,
          0x00,
          0x01,
          0x00,
          0x00,
          0x05,
          0x00,
          0x01,
          0x0D,
          0x0A,
          0x2D,
          0xB4,
          0x00,
          0x00,
          0x00,
          0x00,
          0x49,
          0x45,
          0x4E,
          0x44,
          0xAE,
          0x42,
          0x60,
          0x82,
        ]);
      await tester.pumpWidget(testApp(Column(
        children: [
          StyledImage.memory(
            testBytes,
            style: const Style(
              image: ImageStyle(width: DataValue(64.0), height: DataValue(64.0), fit: BoxFit.contain, filterQuality: FilterQuality.medium, opacity: DataValue(0.9)),
            ),
          ),
          StyledBox(
            style: const Style(image: ImageStyle(width: DataValue(48.0), height: DataValue(48.0))),
            interaction: Interaction(onTap: () => tapped = true),
            child: StyledImage.memory(testBytes),
          ),
        ],
      )));

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images.length, 2);
      expect(images.first.width, 64.0);
      expect(images.first.fit, BoxFit.contain);
      expect(images.first.filterQuality, FilterQuality.medium);
      expect(images.last.width, 48.0);

      await tester.tap(find.byType(Image).last);
      expect(tapped, isTrue);
    });
  });

  group('StyledTextField', () {
    testWidgets('enabled: false activates the disabled state', (tester) async {
      final inputStyle = const Style(box: BoxStyle(color: _Colors.white)).on(StyleState.disabled, box: const BoxStyle(color: _Colors.grey));
      await tester.pumpWidget(testApp(StyledTextField(style: inputStyle, enabled: false, hint: 'Enter text')));
      final inherited = tester.widget<InheritedStyle>(find.byType(InheritedStyle).first);
      expect(inherited.style.box.color, _Colors.grey);
    });

    testWidgets('error message uses the error state text by default', (tester) async {
      final inputStyle = const Style(box: BoxStyle(color: _Colors.white))
          .on(StyleState.error, text: const StyledTextStyle(color: _Colors.red, fontSize: DataValue(11.0)));
      await tester.pumpWidget(testApp(StyledTextField(style: inputStyle, label: 'Email', error: 'Required')));
      final error = tester.widget<Text>(find.text('Required'));
      expect(error.style?.color, _Colors.red.defaultValue);
      expect(error.style?.fontSize, 11);
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('cursor colour follows text colour rather than a built-in brand colour', (tester) async {
      await tester.pumpWidget(testApp(const StyledTextField(style: Style(text: StyledTextStyle(color: _Colors.purple)))));
      expect(tester.widget<EditableText>(find.byType(EditableText)).cursorColor, _Colors.purple.defaultValue);
    });

    testWidgets(
      'StyledTextField handles text selection, typing, and backspace deletion',
      (tester) async {
        final controller = TextEditingController(
          text: 'Antigravity Text Engine',
        );
        String changed = '';

        await tester.pumpWidget(
          testApp(
            StyledTextField(
              style: const Style(
                box: BoxStyle(color: _Colors.white, padding: StyledEdgeInsets.all(DataValue(8.0))),
                text: StyledTextStyle(
                  fontSize: DataValue(16.0),
                  color: _Colors.black,
                  selectionColor: DataValue(Color(0x553B82F6)),
                ),
              ),
              controller: controller,
              onChanged: (val) => changed = val,
            ),
          ),
        );

        expect(find.text('Antigravity Text Engine'), findsOneWidget);

        // 1. Focus input
        await tester.tap(find.byType(EditableText));
        await tester.pumpAndSettle();

        // 2. Select text range
        controller.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 11,
        );
        await tester.pumpAndSettle();
        expect(controller.selection.textInside(controller.text), 'Antigravity');

        // 3. Delete selection via backspace key simulation
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pumpAndSettle();

        expect(controller.text, ' Text Engine');
        expect(changed, ' Text Engine');
      },
    );

    testWidgets(
      'StyledTextField allows pressing Shift and arrow keys to highlight multiple characters',
      (tester) async {
        final controller = TextEditingController(
          text: 'Antigravity Text Engine',
        );

        await tester.pumpWidget(
          testApp(
            StyledTextField(
              style: const Style(
                box: BoxStyle(color: _Colors.white, padding: StyledEdgeInsets.all(DataValue(8.0))),
                text: StyledTextStyle(
                  fontSize: DataValue(16.0),
                  color: _Colors.black,
                  selectionColor: DataValue(Color(0x553B82F6)),
                ),
              ),
              controller: controller,
            ),
          ),
        );

        // Focus input and position cursor at offset 0
        await tester.tap(find.byType(EditableText));
        await tester.pumpAndSettle();
        controller.selection = const TextSelection.collapsed(offset: 0);
        await tester.pumpAndSettle();

        // 1. Press Shift + Right Arrow 4 times (selects 'Anti')
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();

        // Verify that the selection is active and covers 4 characters ('Anti')
        expect(controller.selection.baseOffset, 0);
        expect(controller.selection.extentOffset, 4);
        expect(controller.selection.textInside(controller.text), 'Anti');
        expect(controller.selection.isCollapsed, isFalse);

        // 2. Extend selection further with Shift + Right Arrow to cover 'Antigravity' (7 more characters)
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        for (int i = 0; i < 7; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();

        expect(controller.selection.baseOffset, 0);
        expect(controller.selection.extentOffset, 11);
        expect(controller.selection.textInside(controller.text), 'Antigravity');

        // 3. Shrink selection backwards with Shift + Left Arrow
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();

        expect(controller.selection.baseOffset, 0);
        expect(controller.selection.extentOffset, 10);
        expect(controller.selection.textInside(controller.text), 'Antigravit');

        // 4. Press Backspace to delete the highlighted characters
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pumpAndSettle();

        expect(controller.text, 'y Text Engine');
        expect(controller.selection.baseOffset, 0);
      },
    );

    testWidgets(
      'StyledTextField enforces maxLines: 1 and TextOverflow.ellipsis on hint text',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            const StyledTextField(
              style: Style(
                box: BoxStyle(color: _Colors.white),
                text: StyledTextStyle(fontSize: DataValue(14.0), color: _Colors.black),
              ),
              hint: 'Search companies by name, slug, or ID...',
            ),
          ),
        );

        final hintTextFinder = find.text(
          'Search companies by name, slug, or ID...',
        );
        expect(hintTextFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(hintTextFinder);
        expect(textWidget.maxLines, 1);
        expect(textWidget.overflow, TextOverflow.ellipsis);
      },
    );
  });


  group('StyledTheme & ThemeToken Architecture Tests', () {
    const testPrimary = ThemeToken<Color>('testPrimary', Color(0xFF1E3A8A));
    const testSidebarWidth = ThemeToken<double>('testSidebarWidth', 250.0);
    const testBrandAccent = ThemeToken<Color>(
      'testBrandAccent',
      Color(0xFF10B981),
    );
    const testRadius = ThemeToken<double>('testRadius', 8.0);

    test('ThemeToken falls back to defaultValue when unset', () {
      const theme = StyledTheme();
      expect(theme.get(testPrimary), const Color(0xFF1E3A8A));
      expect(theme.get(testSidebarWidth), 250.0);
      expect(theme(testBrandAccent), const Color(0xFF10B981));
      expect(theme.get(testRadius), 8.0);
    });

    test('ThemeToken retrieves custom override value with type safety', () {
      final theme = const StyledTheme().copyWith(
        overrides: {
          testSidebarWidth.key: 320.0,
          testBrandAccent.key: _Colors.purple.defaultValue,
          testPrimary.key: _Colors.red.defaultValue,
        },
      );

      expect(theme.get(testSidebarWidth), 320.0);
      expect(theme(testBrandAccent), _Colors.purple.defaultValue);
      expect(theme.get(testPrimary), _Colors.red.defaultValue);
      expect(theme.get(testRadius), 8.0); // Unmodified fallback
    });

    test('StyledTheme.fromMap initializes values correctly', () {
      final theme = StyledTheme.fromMap({
        testPrimary.key: _Colors.amber.defaultValue,
        testRadius.key: 24.0,
        testSidebarWidth.key: 280.0,
      });

      expect(theme.get(testPrimary), _Colors.amber.defaultValue);
      expect(theme.get(testRadius), 24.0);
      expect(theme.get(testSidebarWidth), 280.0);
    });

    test(
      'StyledTheme JSON serialization and deserialization works seamlessly',
      () {
        const testWeight = ThemeToken<FontWeight>(
          'testWeight',
          FontWeight.w400,
        );
        const testHeader = ThemeToken<String>('customHeader', '');
        const testSubtle = ThemeToken<Color>('testSubtle', Color(0xFF000000));

        final theme = const StyledTheme().copyWith(
          overrides: {
            testPrimary.key: const Color(0xFF123456),
            testSubtle.key: const Color(0x6678350F),
            testWeight.key: FontWeight.w700,
            testRadius.key: 12.0,
            testHeader.key: 'My Header',
          },
          metadata: {'version': '2.0'},
        );

        final json = theme.toJson();
        expect(json['testPrimary'], '#123456');
        expect(json['testSubtle'], '#6678350F');
        expect(json['testWeight'], 'w700');
        expect(json['testRadius'], 12.0);
        expect(json['customHeader'], 'My Header');
        expect(json['metadata'], {'version': '2.0'});

        final restored = StyledTheme.fromJson(json);
        expect(restored.get(testPrimary), const Color(0xFF123456));
        expect(restored.get(testSubtle), const Color(0x6678350F));
        expect(restored.get(testWeight), FontWeight.w700);
        expect(restored.get(testRadius), 12.0);
        expect(restored.get(testHeader), 'My Header');
        expect(restored.metadata['version'], '2.0');
      },
    );

    test('StyledTheme merge combines values', () {
      final base = const StyledTheme().set(testPrimary, _Colors.green.defaultValue);
      final update = const StyledTheme().set(testRadius, 30.0);

      final merged = base.merge(update);
      expect(merged.get(testPrimary), _Colors.green.defaultValue);
      expect(merged.get(testRadius), 30.0);
    });

    testWidgets(
      'ThemeController and StyledThemeProvider notify listeners on update',
      (tester) async {
        final controller = StyledThemeController();
        late Color observedPrimary;

        await tester.pumpWidget(
          StyledThemeControllerProvider(
            controller: controller,
            child: Builder(
              builder: (context) {
                observedPrimary = context.theme.get(testPrimary);
                return Container();
              },
            ),
          ),
        );

        expect(observedPrimary, const Color(0xFF1E3A8A));

        controller.updateTheme(
          const StyledTheme().set(testPrimary, _Colors.orange.defaultValue),
        );
        await tester.pump();

        expect(observedPrimary, _Colors.orange.defaultValue);
      },
    );

    testWidgets(
      'StyledThemeProvider.of and context.theme provide access to controller and theme',
      (tester) async {
        final controller = StyledThemeController();
        late StyledThemeController? retrievedController;
        late StyledTheme retrievedTheme;

        await tester.pumpWidget(
          StyledThemeControllerProvider(
            controller: controller,
            child: Builder(
              builder: (context) {
                retrievedController = StyledThemeControllerProvider.of(context);
                retrievedTheme = context.theme;
                return Container();
              },
            ),
          ),
        );

        expect(retrievedController, same(controller));
        expect(retrievedTheme.get(testPrimary), const Color(0xFF1E3A8A));
      },
    );

    testWidgets('context.theme throws FlutterError when unmounted', (
      tester,
    ) async {
      FlutterError? caughtError;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            try {
              context.theme;
            } on FlutterError catch (e) {
              caughtError = e;
            }
            return const SizedBox();
          },
        ),
      );
      expect(caughtError, isNotNull);
      expect(
        caughtError!.message,
        contains(
          'context.theme called with a context that does not contain a StyledThemeProvider',
        ),
      );
    });

    testWidgets(
      'StyledThemeProvider.test isolates theme without global state',
      (tester) async {
        late StyledTheme retrievedTheme;
        final customTheme = const StyledTheme().set(testPrimary, _Colors.amber.defaultValue);

        await tester.pumpWidget(
          StyledThemeControllerProvider.test(
            theme: customTheme,
            child: Builder(
              builder: (context) {
                retrievedTheme = context.theme;
                return const SizedBox();
              },
            ),
          ),
        );

        expect(retrievedTheme.get(testPrimary), _Colors.amber.defaultValue);
      },
    );
  });

  group('StyledScreen & StyledScreenContextExtension Tests', () {
    test('StyledScreen comparison operators work accurately', () {
      expect(StyledScreen.mobile < StyledScreen.tablet, isTrue);
      expect(StyledScreen.tablet < StyledScreen.desktop, isTrue);
      expect(StyledScreen.desktop > StyledScreen.mobile, isTrue);
      expect(StyledScreen.tablet >= StyledScreen.mobile, isTrue);
      expect(StyledScreen.mobile <= StyledScreen.mobile, isTrue);
      expect(StyledScreen.mobile.isMobile, isTrue);
      expect(StyledScreen.tablet.isTablet, isTrue);
      expect(StyledScreen.desktop.isDesktop, isTrue);
    });

    testWidgets(
      'StyledScreenContextExtension resolves mobile screen correctly',
      (tester) async {
        tester.view.physicalSize = const Size(500, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        late StyledScreen screen;
        late Size size;
        late bool isMobile;
        late bool isTablet;
        late bool isDesktop;

        await tester.pumpWidget(
          testApp(null, (context) {
            screen = context.screen;
            size = context.screenSize;
            isMobile = context.isMobile;
            isTablet = context.isTablet;
            isDesktop = context.isDesktop;
            return Container();
          }),
        );

        expect(screen, StyledScreen.mobile);
        expect(size.width, 500);
        expect(isMobile, isTrue);
        expect(isTablet, isFalse);
        expect(isDesktop, isFalse);
      },
    );

    testWidgets(
      'StyledScreenContextExtension resolves tablet screen correctly',
      (tester) async {
        tester.view.physicalSize = const Size(900, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        late StyledScreen screen;
        late bool isMobile;
        late bool isTablet;
        late bool isDesktop;

        await tester.pumpWidget(
          testApp(null, (context) {
            screen = context.screen;
            isMobile = context.isMobile;
            isTablet = context.isTablet;
            isDesktop = context.isDesktop;
            return Container();
          }),
        );

        expect(screen, StyledScreen.tablet);
        expect(isMobile, isFalse);
        expect(isTablet, isTrue);
        expect(isDesktop, isFalse);
      },
    );

    testWidgets(
      'StyledScreenContextExtension resolves desktop screen correctly',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        late StyledScreen screen;
        late bool isMobile;
        late bool isTablet;
        late bool isDesktop;

        await tester.pumpWidget(
          testApp(null, (context) {
            screen = context.screen;
            isMobile = context.isMobile;
            isTablet = context.isTablet;
            isDesktop = context.isDesktop;
            return Container();
          }),
        );

        expect(screen, StyledScreen.desktop);
        expect(isMobile, isFalse);
        expect(isTablet, isFalse);
        expect(isDesktop, isTrue);
      },
    );
  });
}

class _MockBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
