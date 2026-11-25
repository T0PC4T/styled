import 'package:meta/meta_meta.dart';

import 'catalog.dart';

/// Marks a widget, or with [Designable.value] a value class, as something a
/// design document may place. The design generator reads its constructors and
/// writes its definition and catalog entry.
@Target({TargetKind.classType})
final class Designable {
  /// layout, primitives, cards, inputs, tables, navigation, ...
  final String category;

  /// One line an agent reads when choosing a component.
  final String summary;

  /// The event the widget exists for, such as a button's `tap`.
  final String? primaryEvent;

  /// A hand-written `DesignDefinition` class to use instead of a generated one,
  /// for widgets too irregular to derive.
  final Type? definition;

  /// Placement lints, such as `DesignRule.notInside(['OnboardingCard'], code: 'W-table-in-card')`.
  final List<DesignRule> rules;

  final bool isValue;

  const Designable({
    this.category = 'other',
    this.summary = '',
    this.primaryEvent,
    this.definition,
    this.rules = const [],
  }) : isValue = false;

  /// A value class that a slot of another component holds, such as a menu item.
  const Designable.value({this.category = 'other', this.summary = '', this.primaryEvent, this.definition})
    : rules = const [],
      isValue = true;
}

/// Marks an exported widget that designers may not place, with the reason.
@Target({TargetKind.classType})
final class NotDesignable {
  final String reason;
  const NotDesignable(this.reason);
}

/// On a builder parameter: the slot is a template built once per item, and
/// the build adds the variable [as] (`row`, `items`).
@Target({TargetKind.parameter, TargetKind.field})
final class DesignTemplate {
  final String as;

  /// The slot name, when it differs from the parameter without `Builder`.
  final String? name;
  const DesignTemplate({required this.as, this.name});
}

/// On a function parameter that reads a value from a row, such as `idOf`:
/// it becomes a path prop called [name].
@Target({TargetKind.parameter, TargetKind.field})
final class DesignPath {
  final String name;
  const DesignPath(this.name);
}

/// On a style parameter: the preset families a design document may pass, such as
/// `@DesignFamilies([StyleCard, StyleCardSection])`.
///
/// The generator takes a style parameter's families from this annotation, else from the parameter's
/// type, else from its default; a style parameter with none fails the build. [DesignFamilies.any] is for a
/// style that truly takes a preset of any family.
@Target({TargetKind.parameter, TargetKind.field})
final class DesignFamilies {
  /// The accepted preset families.
  final List<Type> families;

  /// Whether a preset of any family is accepted.
  final bool any;

  const DesignFamilies(this.families) : any = false;

  /// Any family: the catalog lists no families, and the validator accepts any preset.
  const DesignFamilies.any() : families = const [], any = true;
}

/// On a parameter designers do not set.
@Target({TargetKind.parameter, TargetKind.field})
final class DesignIgnore {
  const DesignIgnore();
}

/// On a widget parameter that is its owner's anchor, such as a popup menu's
/// button: the owner handles its taps, so documents need not link them.
@Target({TargetKind.parameter, TargetKind.field})
final class DesignAnchor {
  const DesignAnchor();
}
