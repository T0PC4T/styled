import 'package:meta/meta.dart';

import 'screen.dart';

/// One link between screens: an action under a node's event, or a page's
/// frame.
@immutable
final class FlowEdge {
  final String from;

  /// The node whose event holds the action; null for a frame link.
  final String? node;
  final String? event;

  /// push, replaceAll or replace (navigate), openModal, back, backTo, or frame.
  final String kind;
  final String to;

  /// JSON pointer of the action in [from]'s file; null for a frame link.
  final String? pointer;

  const FlowEdge({required this.from, required this.kind, required this.to, this.node, this.event, this.pointer});

  Map<String, Object?> toJson() => {'from': from, 'node': ?node, 'event': ?event, 'kind': kind, 'to': to};

  @override
  String toString() => '${node == null ? from : '$from#$node.$event'} → $to ($kind)';
}

/// The flow map: which event on which node leads to which screen.
@immutable
final class FlowMap {
  /// Screen id → kind, for every screen in the map.
  final Map<String, ScreenKind> screens;
  final List<FlowEdge> edges;

  const FlowMap(this.screens, this.edges);

  Map<String, Object?> toJson() => {
    'screens': {for (final MapEntry(:key, :value) in screens.entries) key: value.name},
    'edges': [for (final e in edges) e.toJson()],
  };

  /// One line per edge.
  String toText() => edges.isEmpty ? 'No links.\n' : '${edges.join('\n')}\n';

  /// A Mermaid flowchart: pages as boxes, modals rounded, frames as
  /// subroutines; frame links dotted.
  String toMermaid() {
    String id(String screen) => screen.replaceAll('.', '_');
    final b = StringBuffer('flowchart LR\n');
    for (final MapEntry(key: screen, value: kind) in screens.entries) {
      b.writeln(switch (kind) {
        ScreenKind.page => '  ${id(screen)}["$screen"]',
        ScreenKind.modal => '  ${id(screen)}("$screen")',
        ScreenKind.frame => '  ${id(screen)}[["$screen"]]',
      });
    }
    for (final e in edges) {
      if (e.kind == 'frame') {
        b.writeln('  ${id(e.from)} -.->|frame| ${id(e.to)}');
      } else {
        b.writeln('  ${id(e.from)} -->|"${e.node}.${e.event}: ${e.kind}"| ${id(e.to)}');
      }
    }
    return b.toString();
  }
}

/// The flow map of [screens], derived from their actions and frames. Screens
/// in id order; within a screen, nodes depth first, events and actions in
/// document order (nested `then` lists included).
FlowMap buildFlow(Iterable<ScreenDoc> screens) {
  final sorted = screens.toList()..sort((a, b) => a.id.compareTo(b.id));
  final edges = <FlowEdge>[];
  for (final screen in sorted) {
    if (screen.frame case final frame? when frame.isNotEmpty) {
      edges.add(FlowEdge(from: screen.id, kind: 'frame', to: frame));
    }
    for (final node in screen.nodes) {
      for (final MapEntry(key: event, value: actions) in node.on.entries) {
        for (final action in flattenActions(actions)) {
          final (kind, to) = switch (action) {
            NavigateAction(:final mode, :final to) => (mode.name, to),
            OpenModalAction(:final screen) => ('openModal', screen),
            BackAction(:final fallback) => ('back', fallback),
            BackToAction(:final to) => ('backTo', to),
            _ => (null, null),
          };
          if (kind == null || to == null || to.isEmpty) continue;
          edges.add(
            FlowEdge(from: screen.id, node: node.id, event: event, kind: kind, to: to, pointer: action.pointer),
          );
        }
      }
    }
  }
  return FlowMap({for (final s in sorted) s.id: s.kind}, edges);
}
