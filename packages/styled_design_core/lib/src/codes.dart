/// Every diagnostic code the engine reports, with one line saying what it
/// means. Codes are stable: agents and AGENTS.md rely on them. `E-` codes are
/// errors, `W-` codes warnings. Library rules add their own codes (see the
/// catalog's `rules`).
const Map<String, String> diagnosticCodes = {
  // Structure.
  'E-json': 'A file is not valid JSON, or not a JSON object.',
  'E-schema': 'A document does not match its schema: an unknown or missing field, a wrong type or pattern.',
  'E-id-path': "A screen's id differs from the path its file spells, or a preset's file name from its id.",
  'E-duplicate-id': 'Two nodes in one screen share an id.',
  // Tokens.
  'E-token-unknown': 'A token key that neither the catalog nor tokens.json defines.',
  'E-token-type': 'A token value does not fit its type, or `type` is given on a library token.',
  'E-token-light': 'A new token has no `light` value.',
  'W-token-unused': 'A new token that no preset or screen uses.',
  // Presets and styles.
  'E-preset-family': 'A preset id names a family the catalog does not have.',
  'E-preset-extends': 'A preset extends an unknown variant, a variant of another family, or forms a cycle.',
  'E-preset-variant': 'A designer preset reuses the id of a built-in variant.',
  'E-style-field': 'A style has a field the Style JSON does not know.',
  'E-style-raw': 'A style holds a raw number or hex colour where a token key is required.',
  'E-style-token-type': 'A style field names a token of the wrong type.',
  'E-style-value': 'A style value is not one of the allowed values, or its fields do not combine.',
  'W-preset-unused': 'A designer preset that nothing references.',
  // Components (checked against catalog.json).
  'E-component-unknown': 'A node type the catalog does not list.',
  'E-ctor-unknown': 'A named constructor the component does not have.',
  'E-prop-unknown': 'A prop the component does not have.',
  'E-prop-required': 'A required prop is missing.',
  'E-prop-kind': 'A prop value of the wrong kind: wrong JSON type, unknown choice, preset variant or token type.',
  'E-icon-unknown': 'An icon name the catalog does not list.',
  'E-style-family': 'A style prop names a preset of a family the prop does not accept.',
  'E-prop-bind': 'An expression in a prop that must be a literal.',
  'E-slot-unknown': 'A slot the component does not have.',
  'E-slot-required': 'A required slot is missing or empty.',
  'E-slot-accepts':
      'A node the slot does not accept: a value in a widget slot, a widget in a value slot, or a wrong value type.',
  'W-slot-single': 'A single-child slot holds several nodes without `when`; only the first is drawn.',
  'E-event-unknown': 'An event the component does not have.',
  // Expressions.
  'E-bind-root': 'A path starts at a root that is not in scope there.',
  'E-bind-path': 'A path that does not resolve: not in the default fixture, or not declared in state, params or query.',
  'E-formatter-unknown': 'A `{{path|formatter}}` names a formatter the catalog does not list.',
  // Flow.
  'E-screen-unknown': 'An action, frame or start names a screen that does not exist.',
  'E-param-missing': 'A link to a page does not supply a `:param` of its route.',
  'E-modal-target': 'A link targets the wrong kind of screen, or closeModal runs outside a modal.',
  'E-emit-undeclared': "An emit is not declared in the screen's `emits`, or its payload keys differ.",
  'W-unreachable': 'No navigate, openModal or frame link leads to the screen from the start screen.',
  // Routing lints.
  'W-push-no-back': 'A page opened with a push has no `back` action.',
  'W-frame-nav-mode': 'A navigate in a frame does not use mode replaceAll.',
  'W-query-undeclared': "setQuery sets a key the screen's `query` does not declare.",
  'W-backto-not-ancestor': "backTo targets a page whose route is not a prefix of this page's route.",
  // Events.
  'W-unbound-primary': "A node's primary event (such as a button's tap) has no action and the node is not disabled.",
  // Patch and link.
  'E-node-unknown': 'A patch or link names a node id the screen does not have.',
  'E-patch-op': 'A patch operation is malformed or cannot apply.',
};

/// The default sentence for a library rule's diagnostic, by rule kind.
const Map<String, String> ruleKinds = {
  'notInside': 'The component must not sit inside one of the listed types.',
  'onlyInside': 'The component must sit inside one of the listed types.',
  'pageRoot': "A page's root is one of the listed types, with the listed props.",
  'modalRoot': "A modal's root is one of the listed types.",
  'frameRoot': "A frame's root is one of the listed types.",
  'singleScroll': 'Below a scrolling page root, another scroll view must set the listed props.',
  'lastColumnProps': "Inside a table's last column, the component sets the listed props.",
  'rootOf': 'The component may appear only in screens of the listed kinds.',
};
