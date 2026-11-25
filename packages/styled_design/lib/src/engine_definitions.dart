import 'package:flutter/widgets.dart';
import 'package:styled/styled.dart';
import 'package:styled_design_core/styled_design_core.dart';

import 'build_context.dart';
import 'registry.dart';

/// The definitions the engine ships, for widgets no library owns.
const List<DesignDefinition> engineDefinitions = [
  StyledTextDefinition(),
  StyledIconDefinition(),
  StyledImageDefinition(),
  StyledBoxDefinition(),
  ExpandedDefinition(),
  FlexibleDefinition(),
  DesignOutletDefinition(),
];

/// The engine's catalog entries, for a library's catalog.json.
List<DesignComponent> get engineComponents => [for (final d in engineDefinitions) d.spec];

final class StyledTextDefinition extends DesignDefinition {
  const StyledTextDefinition();

  @override
  DesignComponent get spec => const DesignComponent(
    type: 'StyledText',
    category: 'text',
    summary: 'A run of text. Pick its look with a text preset such as StyleText.body.',
    props: [
      DesignProp.string('text', required: true),
      DesignProp.style('style', families: ['StyleText']),
      DesignProp.string('semanticsLabel'),
    ],
  );

  @override
  Object build(DesignBuildContext ctx) => StyledText(
    ctx.string('text') ?? '',
    key: ctx.key,
    style: ctx.style('style'),
    semanticsLabel: ctx.string('semanticsLabel'),
  );
}

final class StyledIconDefinition extends DesignDefinition {
  const StyledIconDefinition();

  @override
  DesignComponent get spec => const DesignComponent(
    type: 'StyledIcon',
    category: 'text',
    summary: 'An icon from the icon catalogue, coloured and sized by its style or its parent.',
    props: [
      DesignProp.icon('icon', required: true),
      DesignProp.style('style', families: ['StyleIconToken']),
      DesignProp.string('semanticLabel'),
    ],
  );

  @override
  Object build(DesignBuildContext ctx) => switch (ctx.icon('icon')) {
    final icon? => StyledIcon(icon, key: ctx.key, style: ctx.style('style'), semanticLabel: ctx.string('semanticLabel')),
    null => SizedBox.shrink(key: ctx.key),
  };
}

final class StyledImageDefinition extends DesignDefinition {
  const StyledImageDefinition();

  @override
  DesignComponent get spec => const DesignComponent(
    type: 'StyledImage',
    category: 'media',
    summary: 'An image from the host app, resolved from a reference.',
    props: [
      DesignProp('image', PropKind.image, required: true),
      DesignProp.style('style', families: []),
      DesignProp.string('semanticLabel'),
    ],
  );

  @override
  Object build(DesignBuildContext ctx) => switch (ctx.image('image')) {
    final image? => StyledImage(image, key: ctx.key, style: ctx.style('style'), semanticLabel: ctx.string('semanticLabel')),
    null => SizedBox.shrink(key: ctx.key),
  };
}

final class StyledBoxDefinition extends DesignDefinition {
  const StyledBoxDefinition();

  @override
  DesignComponent get spec => const DesignComponent(
    type: 'StyledBox',
    category: 'layout',
    summary: 'A box drawn by a preset. Prefer a library component when one fits.',
    props: [DesignProp.style('style', families: [])],
    slots: [DesignSlot('child'), DesignSlot('children', many: true)],
  );

  @override
  Object build(DesignBuildContext ctx) => StyledBox(
    key: ctx.key,
    style: ctx.style('style') ?? const Style(),
    child: ctx.child('child'),
    children: ctx.childrenOrNull('children'),
  );
}

final class ExpandedDefinition extends DesignDefinition {
  const ExpandedDefinition();

  @override
  DesignComponent get spec => const DesignComponent(
    type: 'Expanded',
    category: 'layout',
    summary: 'Fills the remaining space of its row or column. Must be a direct child of one.',
    props: [DesignProp.integer('flex', defaultValue: 1)],
    slots: [DesignSlot('child', required: true)],
  );

  @override
  Object build(DesignBuildContext ctx) =>
      Expanded(key: ctx.key, flex: ctx.integer('flex') ?? 1, child: ctx.child('child') ?? const SizedBox.shrink());
}

final class FlexibleDefinition extends DesignDefinition {
  const FlexibleDefinition();

  @override
  DesignComponent get spec => const DesignComponent(
    type: 'Flexible',
    category: 'layout',
    summary: 'Takes up to its share of its row or column. Must be a direct child of one.',
    props: [
      DesignProp.integer('flex', defaultValue: 1),
      DesignProp.choice('fit', values: ['loose', 'tight'], defaultValue: 'loose'),
    ],
    slots: [DesignSlot('child', required: true)],
  );

  @override
  Object build(DesignBuildContext ctx) => Flexible(
    key: ctx.key,
    flex: ctx.integer('flex') ?? 1,
    fit: ctx.choice('fit', FlexFit.values) ?? FlexFit.loose,
    child: ctx.child('child') ?? const SizedBox.shrink(),
  );
}

/// Supplies the page a frame's [DesignOutlet] draws, and the `page` root a
/// frame's expressions read (`page.id`, `page.title`).
class DesignOutletScope extends InheritedWidget {
  final Widget page;
  final String? pageId;
  final String? pageTitle;

  const DesignOutletScope({super.key, required this.page, this.pageId, this.pageTitle, required super.child});

  static DesignOutletScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<DesignOutletScope>();

  static Widget? pageOf(BuildContext context) => of(context)?.page;

  @override
  bool updateShouldNotify(DesignOutletScope oldWidget) =>
      page != oldWidget.page || pageId != oldWidget.pageId || pageTitle != oldWidget.pageTitle;
}

final class DesignOutletDefinition extends DesignDefinition {
  const DesignOutletDefinition();

  @override
  DesignComponent get spec => const DesignComponent(
    type: 'DesignOutlet',
    category: 'layout',
    summary: "Where a frame draws the page it frames. Only in a frame screen's tree.",
    rules: [DesignRule('rootOf', types: ['frame'], code: 'E-outlet-outside-frame')],
  );

  @override
  Object build(DesignBuildContext ctx) => Builder(
    key: ctx.key,
    builder: (context) => DesignOutletScope.pageOf(context) ?? const SizedBox.shrink(),
  );
}

/// Drawn for a node of a type the registry does not know: a labelled
/// placeholder in the studio, nothing in the app.
class DesignPlaceholder extends StatelessWidget {
  final String label;
  const DesignPlaceholder(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(border: Border.all(color: const Color(0xFF9AA5B1)), color: const Color(0x11000000)),
    child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF52606D))),
  );
}

/// Drawn in place of a node that failed to build, in the studio and in debug
/// builds: an outline, the node id and the message.
class DesignErrorBox extends StatelessWidget {
  final String nodeId;
  final String message;
  const DesignErrorBox({super.key, required this.nodeId, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD64545), width: 2), color: const Color(0x14D64545)),
    child: Text('#$nodeId: $message', style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
  );
}
