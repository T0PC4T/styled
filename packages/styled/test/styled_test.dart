import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:styled/styled.dart';

class _Colors {
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const blue = Color(0xFF2196F3);
  static const red = Color(0xFFF44336);
  static const green = Color(0xFF4CAF50);
  static const yellow = Color(0xFFFFEB3B);
  static const amber = Color(0xFFFFC107);
  static const grey = Color(0xFF9E9E9E);
  static const purple = Color(0xFF9C27B0);
  static const cyan = Color(0xFF00BCD4);
  static const orange = Color(0xFFFF9800);
}

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

class TestScaffold extends StatelessWidget {
  final Widget body;
  const TestScaffold({super.key, required this.body});
  @override
  Widget build(BuildContext context) => body;
}

void main() {
  group('Style & Token Architecture Tests', () {
    test('Style.on and resolveTokens apply states properly', () {
      final base =
          const Style(
                box: BoxStyle(
                  color: _Colors.white,
                  border: StyledBorder.all(
                    color: _Colors.black,
                    width: 1,
                    radius: 8,
                  ),
                ),
                text: StyledTextStyle(color: _Colors.black),
              )
              .on(StyledToken.hovered, box: const BoxStyle(color: _Colors.blue))
              .on(
                StyledToken.disabled,
                box: const BoxStyle(color: _Colors.grey),
              )
              .on(
                'custom_tag',
                text: const StyledTextStyle(color: _Colors.amber),
              );

      expect(base.box.color, _Colors.white);
      expect(base.text.color, _Colors.black);
      expect(base.box.border?.radius, 8.0);

      final hoveredStyle = base.resolveTokens([StyledToken.hovered]);
      expect(hoveredStyle.box.color, _Colors.blue);
      expect(hoveredStyle.text.color, _Colors.black);

      final customStyle = base.resolveTokens(['custom_tag']);
      expect(customStyle.box.color, _Colors.white);
      expect(customStyle.text.color, _Colors.amber);

      final compoundStyle = base.resolveTokens([
        StyledToken.hovered,
        'custom_tag',
      ]);
      expect(compoundStyle.box.color, _Colors.blue);
      expect(compoundStyle.text.color, _Colors.amber);
    });

    test('Style value equality works correctly', () {
      const style1 = Style(
        box: BoxStyle(color: _Colors.blue),
        text: StyledTextStyle(fontSize: 16),
      );
      const style2 = Style(
        box: BoxStyle(color: _Colors.blue),
        text: StyledTextStyle(fontSize: 16),
      );
      const style3 = Style(
        box: BoxStyle(color: _Colors.red),
        text: StyledTextStyle(fontSize: 16),
      );

      expect(style1, equals(style2));
      expect(style1.hashCode, equals(style2.hashCode));
      expect(style1, isNot(equals(style3)));
    });

    test(
      'BoxStyle equality and hashCode account for all decoration and container fields',
      () {
        final transform = Matrix4.rotationZ(0.5);
        final styleA = BoxStyle(
          color: _Colors.blue,
          boxShadow: const [BoxShadow(color: _Colors.black, blurRadius: 4)],
          transform: transform,
          transformAlignment: Alignment.center,
          curve: Curves.easeInOut,
          foregroundDecoration: const BoxDecoration(color: _Colors.red),
          backgroundBlendMode: BlendMode.colorBurn,
        );

        final styleB = BoxStyle(
          color: _Colors.blue,
          boxShadow: const [BoxShadow(color: _Colors.black, blurRadius: 4)],
          transform: transform,
          transformAlignment: Alignment.center,
          curve: Curves.easeInOut,
          foregroundDecoration: const BoxDecoration(color: _Colors.red),
          backgroundBlendMode: BlendMode.colorBurn,
        );

        final styleC = BoxStyle(
          color: _Colors.blue,
          boxShadow: const [BoxShadow(color: _Colors.white, blurRadius: 8)],
          transform: transform,
        );

        expect(styleA, equals(styleB));
        expect(styleA.hashCode, equals(styleB.hashCode));
        expect(styleA, isNot(equals(styleC)));
      },
    );

    test('BoxStyle.merge preserves animation properties', () {
      const animatedBox = BoxStyle(
        color: _Colors.blue,
        animates: true,
        animationDuration: Duration(milliseconds: 300),
        curve: Curves.bounceOut,
      );
      const overrideBox = BoxStyle(color: _Colors.red);

      final merged = animatedBox.merge(overrideBox);
      expect(merged.color, _Colors.red);
      expect(merged.animates, isTrue);
      expect(merged.animationDuration, const Duration(milliseconds: 300));
      expect(merged.curve, Curves.bounceOut);
    });

    test(
      'StyleResolver mergeText and mergeIcon apply properties correctly',
      () {
        const resolver = Style(box: BoxStyle(color: _Colors.white));
        final modified = resolver
            .mergeText(color: _Colors.green, fontSize: 20)
            .mergeIcon(color: _Colors.purple, size: 30);

        // Build context mock
        final contextMock = _MockBuildContext();
        final resolved = modified.resolve(contextMock);

        expect(resolved.text.color, _Colors.green);
        expect(resolved.text.fontSize, 20);
        expect(resolved.icon.color, _Colors.purple);
        expect(resolved.icon.size, 30);
      },
    );
  });

  group('Widget Rendering & Interactive Parameter Tests', () {
    testWidgets('StyledBox renders container with correct style', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          const StyledBox(
            style: Style(
              box: BoxStyle(width: 100, height: 100, color: _Colors.blue),
            ),
            child: Text('Box Child'),
          ),
        ),
      );

      expect(find.text('Box Child'), findsOneWidget);
      final inheritedStyle = tester.widget<InheritedStyle>(
        find.byType(InheritedStyle),
      );
      expect(inheritedStyle.style.box.color, _Colors.blue);
    });

    test(
      'FlexStyle copyWith, merge, equality and hashCode handle all properties',
      () {
        const flexA = FlexStyle(
          direction: Axis.horizontal,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          textDirection: TextDirection.rtl,
          verticalDirection: VerticalDirection.up,
          spacing: 12.0,
          runSpacing: 8.0,
          wrapAlignment: WrapAlignment.center,
          wrapCrossAxisAlignment: WrapCrossAlignment.center,
          runAlignment: WrapAlignment.end,
          clipBehavior: Clip.antiAlias,
        );

        final flexB = const FlexStyle().copyWith(
          direction: Axis.horizontal,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          textDirection: TextDirection.rtl,
          verticalDirection: VerticalDirection.up,
          spacing: 12.0,
          runSpacing: 8.0,
          wrapAlignment: WrapAlignment.center,
          wrapCrossAxisAlignment: WrapCrossAlignment.center,
          runAlignment: WrapAlignment.end,
          clipBehavior: Clip.antiAlias,
        );

        final flexC = flexA.copyWith(spacing: 16.0);

        expect(flexA, equals(flexB));
        expect(flexA.hashCode, equals(flexB.hashCode));
        expect(flexA, isNot(equals(flexC)));

        final merged = const FlexStyle(
          spacing: 10.0,
          clipBehavior: Clip.hardEdge,
        ).merge(const FlexStyle(spacing: 20.0));
        expect(merged.spacing, 20.0);
        expect(merged.clipBehavior, Clip.hardEdge);
      },
    );

    testWidgets(
      'StyledFlex renders native spacing and clipBehavior from Style',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            const StyledFlex(
              style: Style(
                flex: FlexStyle(
                  direction: Axis.horizontal,
                  spacing: 24,
                  clipBehavior: Clip.hardEdge,
                ),
              ),
              children: [Text('Child 1'), Text('Child 2')],
            ),
          ),
        );

        final flexFinder = find.byType(Flex);
        expect(flexFinder, findsOneWidget);
        final Flex flexWidget = tester.widget(flexFinder);
        expect(flexWidget.spacing, 24.0);
        expect(flexWidget.clipBehavior, Clip.hardEdge);
        expect(flexWidget.children.length, 2);
      },
    );

    testWidgets('StyledRow and StyledColumn render with spacing from Style', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          const Column(
            children: [
              StyledRow(
                style: Style(flex: FlexStyle(spacing: 16)),
                children: [Text('Row 1'), Text('Row 2')],
              ),
              StyledColumn(
                style: Style(flex: FlexStyle(spacing: 20)),
                children: [Text('Col 1'), Text('Col 2')],
              ),
            ],
          ),
        ),
      );

      expect(find.text('Row 1'), findsOneWidget);
      expect(find.text('Col 1'), findsOneWidget);
    });

    testWidgets('StyledWrap renders with Wrap properties from Style', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          const StyledWrap(
            style: Style(
              flex: FlexStyle(
                direction: Axis.horizontal,
                spacing: 12.0,
                runSpacing: 16.0,
                wrapAlignment: WrapAlignment.center,
                wrapCrossAxisAlignment: WrapCrossAlignment.end,
                runAlignment: WrapAlignment.spaceBetween,
                clipBehavior: Clip.antiAlias,
              ),
            ),
            children: [Text('Wrap 1'), Text('Wrap 2')],
          ),
        ),
      );

      final wrapFinder = find.byType(Wrap);
      expect(wrapFinder, findsOneWidget);
      final Wrap wrapWidget = tester.widget(wrapFinder);
      expect(wrapWidget.spacing, 12.0);
      expect(wrapWidget.runSpacing, 16.0);
      expect(wrapWidget.alignment, WrapAlignment.center);
      expect(wrapWidget.crossAxisAlignment, WrapCrossAlignment.end);
      expect(wrapWidget.runAlignment, WrapAlignment.spaceBetween);
      expect(wrapWidget.clipBehavior, Clip.antiAlias);
    });

    testWidgets(
      'StyledPressableRow, StyledPressableColumn, and StyledPressableWrap respond to interactions',
      (tester) async {
        bool rowTapped = false;
        bool colTapped = false;
        bool wrapTapped = false;

        await tester.pumpWidget(
          testApp(
            Column(
              children: [
                StyledPressableRow(
                  style: const Style(box: BoxStyle(color: _Colors.blue)),
                  onTap: () => rowTapped = true,
                  children: const [Text('Pressable Row Child')],
                ),
                StyledPressableColumn(
                  style: const Style(box: BoxStyle(color: _Colors.green)),
                  onTap: () => colTapped = true,
                  children: const [Text('Pressable Col Child')],
                ),
                StyledPressableWrap(
                  style: const Style(box: BoxStyle(color: _Colors.red)),
                  onTap: () => wrapTapped = true,
                  children: const [Text('Pressable Wrap Child')],
                ),
              ],
            ),
          ),
        );

        await tester.tap(find.text('Pressable Row Child'));
        expect(rowTapped, isTrue);

        await tester.tap(find.text('Pressable Col Child'));
        expect(colTapped, isTrue);

        await tester.tap(find.text('Pressable Wrap Child'));
        expect(wrapTapped, isTrue);
      },
    );

    testWidgets('StyledPressableBox handles focused and disabled overrides', (
      tester,
    ) async {
      final style = const Style(box: BoxStyle(color: _Colors.white))
          .on(StyledToken.focused, box: const BoxStyle(color: _Colors.blue))
          .on(StyledToken.disabled, box: const BoxStyle(color: _Colors.grey));

      // Test focused override
      await tester.pumpWidget(
        testApp(
          StyledPressableBox(
            style: style,
            focused: true,
            onTap: () {},
            child: const Text('Focused Button'),
          ),
        ),
      );
      var inheritedStyle = tester.widget<InheritedStyle>(
        find.byType(InheritedStyle).last,
      );
      expect(inheritedStyle.style.box.color, _Colors.blue);

      // Test explicit disabled: true override even with onTap non-null
      await tester.pumpWidget(
        testApp(
          StyledPressableBox(
            style: style,
            disabled: true,
            onTap: () {},
            child: const Text('Disabled Button'),
          ),
        ),
      );
      inheritedStyle = tester.widget<InheritedStyle>(
        find.byType(InheritedStyle).last,
      );
      expect(inheritedStyle.style.box.color, _Colors.grey);
    });

    testWidgets('StyledPressableBox fires full gestures and callbacks', (
      tester,
    ) async {
      bool tapped = false;
      bool doubleTapped = false;
      bool longPressed = false;
      bool secondaryTapped = false;
      bool? hoverState;
      bool? pressState;

      await tester.pumpWidget(
        testApp(
          StyledPressableBox(
            style: const Style(
              box: BoxStyle(width: 100, height: 100, color: _Colors.blue),
            ),
            onTap: () => tapped = true,
            onDoubleTap: () => doubleTapped = true,
            onLongPress: () => longPressed = true,
            onSecondaryTap: () => secondaryTapped = true,
            onHoverChange: (h) => hoverState = h,
            onPressedChange: (p) => pressState = p,
            child: const Text('Interact'),
          ),
        ),
      );

      final target = find.text('Interact');

      // Tap
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 350));
      expect(tapped, isTrue);

      // Double tap
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(doubleTapped, isTrue);

      // Long press
      await tester.longPress(target);
      await tester.pumpAndSettle();
      expect(longPressed, isTrue);

      // Secondary tap (right click)
      await tester.tap(target, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(secondaryTapped, isTrue);

      // Hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(target));
      await tester.pumpAndSettle();
      expect(hoverState, isTrue);

      await gesture.moveTo(const Offset(500, 500));
      await gesture.removePointer();
      await tester.pumpAndSettle();
      expect(hoverState, isFalse);

      // Press
      final pressGesture = await tester.startGesture(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 150));
      expect(pressState, isTrue);
      await pressGesture.up();
      await tester.pump(const Duration(milliseconds: 350));
      expect(pressState, isFalse);
    });

    testWidgets(
      'StyledPressableBox fires fine-grained onTapDown, onTapUp and onTapCancel',
      (tester) async {
        bool tapDown = false;
        bool tapUp = false;
        bool tapCancel = false;

        await tester.pumpWidget(
          testApp(
            StyledPressableBox(
              style: const Style(
                box: BoxStyle(width: 100, height: 100, color: _Colors.blue),
              ),
              onTapDown: (_) => tapDown = true,
              onTapUp: (_) => tapUp = true,
              onTapCancel: () => tapCancel = true,
              onTap: () {},
              child: const Text('Touch Target'),
            ),
          ),
        );

        final target = find.text('Touch Target');

        final gesture = await tester.startGesture(tester.getCenter(target));
        expect(tapDown, isTrue);
        await gesture.up();
        expect(tapUp, isTrue);
        expect(tapCancel, isFalse);
      },
    );

    testWidgets(
      'StyledBox renders container with transform and foregroundDecoration',
      (tester) async {
        final transform = Matrix4.rotationZ(0.2);
        await tester.pumpWidget(
          testApp(
            StyledBox(
              style: Style(
                box: BoxStyle(
                  width: 100,
                  height: 100,
                  color: _Colors.blue,
                  transform: transform,
                  transformAlignment: Alignment.center,
                  foregroundDecoration: const BoxDecoration(color: _Colors.red),
                ),
              ),
              child: const Text('Transformed Box'),
            ),
          ),
        );

        final containerFinder = find.byType(Container);
        expect(containerFinder, findsOneWidget);
        final Container container = tester.widget(containerFinder);
        expect(container.transform, transform);
        expect(container.transformAlignment, Alignment.center);
        expect(container.foregroundDecoration, isNotNull);
      },
    );

    test(
      'StyledTextStyle and IconStyle copyWith, merge, equality and hashCode handle all properties',
      () {
        const textA = StyledTextStyle(
          color: _Colors.blue,
          backgroundColor: _Colors.yellow,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
          letterSpacing: 1.5,
          wordSpacing: 2.0,
          height: 1.2,
          textBaseline: TextBaseline.alphabetic,
          shadows: [Shadow(color: _Colors.black, blurRadius: 2)],
          decoration: TextDecoration.underline,
          decorationColor: _Colors.red,
          decorationStyle: TextDecorationStyle.dashed,
          decorationThickness: 2.0,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          textDirection: TextDirection.ltr,
          maxLines: 3,
          selectionColor: _Colors.cyan,
        );

        final textB = const StyledTextStyle().copyWith(
          color: _Colors.blue,
          backgroundColor: _Colors.yellow,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
          letterSpacing: 1.5,
          wordSpacing: 2.0,
          height: 1.2,
          textBaseline: TextBaseline.alphabetic,
          shadows: const [Shadow(color: _Colors.black, blurRadius: 2)],
          decoration: TextDecoration.underline,
          decorationColor: _Colors.red,
          decorationStyle: TextDecorationStyle.dashed,
          decorationThickness: 2.0,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          textDirection: TextDirection.ltr,
          maxLines: 3,
          selectionColor: _Colors.cyan,
        );

        expect(textA, equals(textB));
        expect(textA.hashCode, equals(textB.hashCode));

        const iconA = IconStyle(
          color: _Colors.amber,
          size: 24,
          fill: 1.0,
          weight: 600,
          grade: 0.25,
          opticalSize: 24,
          shadows: [Shadow(color: _Colors.black, blurRadius: 4)],
          applyTextScaling: true,
        );

        final iconB = const IconStyle().copyWith(
          color: _Colors.amber,
          size: 24,
          fill: 1.0,
          weight: 600,
          grade: 0.25,
          opticalSize: 24,
          shadows: const [Shadow(color: _Colors.black, blurRadius: 4)],
          applyTextScaling: true,
        );

        expect(iconA, equals(iconB));
        expect(iconA.hashCode, equals(iconB.hashCode));
      },
    );

    testWidgets(
      'StyledText and StyledIcon render properties strictly from Style',
      (tester) async {
        await tester.pumpWidget(
          testApp(
            const Column(
              children: [
                StyledText(
                  'Sample Text',
                  style: Style(
                    text: StyledTextStyle(
                      fontSize: 12,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      backgroundColor: _Colors.yellow,
                    ),
                  ),
                ),
                StyledIcon(
                  IconData(0xe123, fontFamily: "TestIcons"),
                  style: Style(
                    icon: IconStyle(
                      size: 32,
                      color: _Colors.amber,
                      fill: 1.0,
                      weight: 700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        final textWidget = tester.widget<Text>(find.text('Sample Text'));
        expect(textWidget.maxLines, 2);
        expect(textWidget.overflow, TextOverflow.ellipsis);
        expect(textWidget.textAlign, TextAlign.center);
        expect(textWidget.style?.backgroundColor, _Colors.yellow);

        final iconWidget = tester.widget<Icon>(
          find.byIcon(const IconData(0xe123, fontFamily: "TestIcons")),
        );
        expect(iconWidget.size, 32.0);
        expect(iconWidget.color, _Colors.amber);
        expect(iconWidget.fill, 1.0);
        expect(iconWidget.weight, 700.0);
      },
    );

    testWidgets(
      'StyledSelectableText, StyledPressableText and StyledPressableIcon function correctly',
      (tester) async {
        bool textTapped = false;
        bool iconTapped = false;

        await tester.pumpWidget(
          testApp(
            Column(
              children: [
                const StyledSelectableText(
                  'Selectable Content',
                  style: Style(
                    text: StyledTextStyle(
                      fontSize: 14,
                      color: _Colors.black,
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
                StyledPressableText(
                  'Clickable Link',
                  style: const Style(
                    box: BoxStyle(padding: EdgeInsets.all(8)),
                    text: StyledTextStyle(
                      color: _Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  onTap: () => textTapped = true,
                ),
                StyledPressableIcon(
                  const IconData(0xe124, fontFamily: "TestIcons"),
                  style: const Style(
                    icon: IconStyle(color: _Colors.red, size: 28),
                  ),
                  onTap: () => iconTapped = true,
                ),
              ],
            ),
          ),
        );

        expect(find.text('Selectable Content'), findsOneWidget);

        await tester.tap(find.text('Clickable Link'));
        expect(textTapped, isTrue);

        await tester.tap(
          find.byIcon(const IconData(0xe124, fontFamily: "TestIcons")),
        );
        expect(iconTapped, isTrue);
      },
    );

    test(
      'ImageStyle copyWith, merge, equality and hashCode handle all properties',
      () {
        const imgA = ImageStyle(
          fit: BoxFit.cover,
          alignment: Alignment.topLeft,
          width: 120,
          height: 80,
          color: _Colors.red,
          colorBlendMode: BlendMode.srcOver,
          repeat: ImageRepeat.repeatX,
          centerSlice: Rect.fromLTWH(10, 10, 20, 20),
          matchTextDirection: true,
          gaplessPlayback: true,
          isAntiAlias: true,
          filterQuality: FilterQuality.high,
          opacity: 0.8,
          scale: 2.0,
          cacheWidth: 300,
          cacheHeight: 200,
          invertColors: true,
        );

        final imgB = const ImageStyle().copyWith(
          fit: BoxFit.cover,
          alignment: Alignment.topLeft,
          width: 120,
          height: 80,
          color: _Colors.red,
          colorBlendMode: BlendMode.srcOver,
          repeat: ImageRepeat.repeatX,
          centerSlice: const Rect.fromLTWH(10, 10, 20, 20),
          matchTextDirection: true,
          gaplessPlayback: true,
          isAntiAlias: true,
          filterQuality: FilterQuality.high,
          opacity: 0.8,
          scale: 2.0,
          cacheWidth: 300,
          cacheHeight: 200,
          invertColors: true,
        );

        final imgC = imgA.copyWith(width: 150);

        expect(imgA, equals(imgB));
        expect(imgA.hashCode, equals(imgB.hashCode));
        expect(imgA, isNot(equals(imgC)));

        final merged = const ImageStyle(
          width: 100,
          height: 100,
        ).merge(const ImageStyle(width: 200, fit: BoxFit.contain));
        expect(merged.width, 200.0);
        expect(merged.height, 100.0);
        expect(merged.fit, BoxFit.contain);
      },
    );

    testWidgets(
      'StyledImage and StyledPressableImage render properties strictly from Style',
      (tester) async {
        bool imgTapped = false;
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

        await tester.pumpWidget(
          testApp(
            Column(
              children: [
                StyledImage.memory(
                  testBytes,
                  style: const Style(
                    image: ImageStyle(
                      width: 64,
                      height: 64,
                      fit: BoxFit.contain,
                      repeat: ImageRepeat.noRepeat,
                      filterQuality: FilterQuality.medium,
                      opacity: 0.9,
                    ),
                  ),
                ),
                StyledPressableImage.memory(
                  testBytes,
                  style: const Style(image: ImageStyle(width: 48, height: 48)),
                  onTap: () => imgTapped = true,
                ),
              ],
            ),
          ),
        );

        final imageWidgets = tester.widgetList<Image>(find.byType(Image));
        expect(imageWidgets.length, 2);

        final firstImage = imageWidgets.first;
        expect(firstImage.width, 64.0);
        expect(firstImage.height, 64.0);
        expect(firstImage.fit, BoxFit.contain);
        expect(firstImage.repeat, ImageRepeat.noRepeat);
        expect(firstImage.filterQuality, FilterQuality.medium);

        await tester.tap(find.byType(StyledPressableImage));
        expect(imgTapped, isTrue);
      },
    );

    testWidgets(
      'StyledTextField integrates enabled: false and applies disabledToken',
      (tester) async {
        final inputStyle = const Style(
          box: BoxStyle(color: _Colors.white),
        ).on(StyledToken.disabled, box: const BoxStyle(color: _Colors.grey));

        await tester.pumpWidget(
          testApp(
            StyledTextField(
              style: inputStyle,
              enabled: false,
              hint: 'Enter text',
            ),
          ),
        );

        final inheritedFinder = find.byType(InheritedStyle);
        expect(inheritedFinder, findsWidgets);
        final InheritedStyle inherited = tester.widget(inheritedFinder.first);
        expect(inherited.style.box.color, _Colors.grey);
      },
    );

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
                box: BoxStyle(color: _Colors.white, padding: EdgeInsets.all(8)),
                text: StyledTextStyle(
                  fontSize: 16,
                  color: _Colors.black,
                  selectionColor: Color(0x553B82F6),
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
                box: BoxStyle(color: _Colors.white, padding: EdgeInsets.all(8)),
                text: StyledTextStyle(
                  fontSize: 16,
                  color: _Colors.black,
                  selectionColor: Color(0x553B82F6),
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
                text: StyledTextStyle(fontSize: 14, color: _Colors.black),
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
          testBrandAccent.key: _Colors.purple,
          testPrimary.key: _Colors.red,
        },
      );

      expect(theme.get(testSidebarWidth), 320.0);
      expect(theme(testBrandAccent), _Colors.purple);
      expect(theme.get(testPrimary), _Colors.red);
      expect(theme.get(testRadius), 8.0); // Unmodified fallback
    });

    test('StyledTheme.fromMap initializes values correctly', () {
      final theme = StyledTheme.fromMap({
        testPrimary.key: _Colors.amber,
        testRadius.key: 24.0,
        testSidebarWidth.key: 280.0,
      });

      expect(theme.get(testPrimary), _Colors.amber);
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
      final base = const StyledTheme().set(testPrimary, _Colors.green);
      final update = const StyledTheme().set(testRadius, 30.0);

      final merged = base.merge(update);
      expect(merged.get(testPrimary), _Colors.green);
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
          const StyledTheme().set(testPrimary, _Colors.orange),
        );
        await tester.pump();

        expect(observedPrimary, _Colors.orange);
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
        final customTheme = const StyledTheme().set(testPrimary, _Colors.amber);

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

        expect(retrievedTheme.get(testPrimary), _Colors.amber);
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
