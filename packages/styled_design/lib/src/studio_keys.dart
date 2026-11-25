import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The key of a widget drawn for a template slot's node in the studio
/// (`DesignScope.studio`): one per item, so the studio can find each
/// instance of the node, such as a table cell, by hit testing.
///
/// Outside the studio a template node has no key of its own, as before.
@immutable
final class DesignNodeKey extends LocalKey {
  final String nodeId;

  /// Tells this instance from the node's other instances.
  final int instance;

  const DesignNodeKey(this.nodeId, this.instance);

  @override
  bool operator ==(Object other) => other is DesignNodeKey && other.nodeId == nodeId && other.instance == instance;

  @override
  int get hashCode => Object.hash(nodeId, instance);

  @override
  String toString() => '[DesignNodeKey $nodeId#$instance]';
}

/// The node id a widget key names, or null: the `ValueKey<String>` every
/// node gets (`saveButton`, or `row#auto_welcome` for a repeated node), or a
/// [DesignNodeKey]. Library widgets may use string keys of their own, so
/// check the id against the screen's nodes.
String? designNodeIdOf(Key? key) => switch (key) {
  DesignNodeKey(:final nodeId) => nodeId,
  ValueKey<String>(:final value) => value.split('#').first,
  _ => null,
};

/// Numbers the instances of one template slot's build: the same item object
/// keeps its number, so a rebuild keeps its key.
final class TemplateInstances {
  final _byItem = Map<Object?, int>.identity();
  var _next = 0;

  int of(Object? item) {
    // Equal texts or numbers may be one object: number those per call.
    if (item == null || item is String || item is num || item is bool) return _next++;
    return _byItem.putIfAbsent(item, () => _next++);
  }
}
