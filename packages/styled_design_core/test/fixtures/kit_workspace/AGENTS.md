# Working in this design workspace

This folder holds the design of the Onboarding360 app as JSON documents. The app and the
design studio draw these documents with the same renderer, so what you write here is what
ships. A designer reviews your work in the studio and makes small edits there; a developer
supplies the data and handles the events each screen declares.

You build screens out of components that already exist in the app's Flutter library. You
cannot create a component, and you never write Dart.

## The loop

1. `design catalog <words>` finds components, presets, tokens and icons.
   `design catalog OnboardingDataTable` prints one component in full, with an example node.
2. `design new screen <id> --from list|detail|formModal|dashboard|frame` starts from a template.
3. Edit the JSON file, or send `design patch <screen> --ops '<json>'`.
4. `design validate --json` reports every problem at once. Each diagnostic names the file,
   the JSON pointer and the node, says what is wrong, and gives a `hint` or the `allowed`
   values. Fix and re-run.
5. `design describe <screen> --fixture <name>` prints the tree as it resolves against a
   fixture: which nodes show, what each prop reads, where each event leads.
6. `design flow` prints which event on which node leads to which screen.

You are finished when `design validate --strict` exits 0.

## Rules, and why

- **Use only what the catalog lists.** A name the catalog does not know cannot be drawn.
  When you need a component, prop, token or icon that is missing, run
  `design request "<what and why>"` and build the closest thing with what exists.
- **Every design value is a token key.** Spacing, colour, radius and size props take a key
  such as `"paddingSm"`, never a number or a hex colour. That is what keeps light mode, dark
  mode and tenant themes working.
- **Write the `default` fixture before the tree.** It is the data contract the developer
  implements, and the validator checks every `data.` path against it. Then add `empty`,
  `loading` and `failed` fixtures for any screen that loads data, as merge patches over
  `default`, so the designer can review those states.
- **Keep node ids.** Links, patches and the designer's edits address nodes by id. Give a new
  node a short lower-camel id that says what it is (`saveButton`, not `button3`).
- **One screen per file**, at the path its id spells: `admin.automations` lives in
  `screens/admin/automations.json`.
- **Put nothing computed in a screen.** Expressions read paths and compare values. A total,
  a formatted name or a filtered list arrives ready-made in `data`; add the field to the
  fixture and the developer will supply it.

## Naming

JSON names are the Dart names.

| Dart | JSON |
| --- | --- |
| `OnboardingButton.primary(...)` | `"type": "OnboardingButton.primary"` |
| a parameter: `label:` | a prop: `"label"` |
| `onTap`, `onRowTap`, `onChanged` | events `tap`, `rowTap`, `changed` under `"on"` |
| a `Widget` parameter: `leading:` | a slot: `"slots": { "leading": [ ... ] }` |
| `children:` | `"children": [ ... ]` |
| `TablerIcons.circle_check` | `"icon": "circle_check"` |
| `const StyleText.cellTitle()` | `"style": "StyleText.cellTitle"` |
| `OnboardingTokens.paddingSm` | `"spacing": "paddingSm"` |

## Page skeleton

A page's root is one `StyledListView` with `StyleContentList.normal`. It is the only
vertical scroll and it supplies the page padding, so nothing inside adds either.

```json
{
  "id": "page",
  "type": "StyledListView",
  "props": { "style": "StyleContentList.normal" },
  "children": [
    { "id": "title", "type": "OnboardingPageTitle", "props": { "title": "..." } }
  ]
}
```

- A table goes straight into the page or a `CrudView` slot. It has its own card chrome, so
  wrapping it in `OnboardingCard` doubles the border.
- A modal's root is `ModalScaffold`.
- A slot is always a list. A single-child slot draws the first node whose `when` passes, so
  write the conditional node first and the fallback after it.

## Values and expressions

A prop holds a literal or one expression. An expression is an object with one `$` key.

| Expression | Result |
| --- | --- |
| `{ "$bind": "data.paging.total" }` | the value at the path |
| `{ "$text": "{{state.name}} was saved" }` | text; `{{path|dateTime}}` formats |
| `{ "$not": x }`, `{ "$and": [..] }`, `{ "$or": [..] }` | logic |
| `{ "$eq": [a, b] }`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte`, `$in`, `$empty` | tests |
| `{ "$if": [cond, then, else] }`, `{ "$match": [x, { "case": v }, default] }` | choices |

Formatters after the bar in a `$text` hole:

| Formatter | Takes | Gives |
| --- | --- | --- |
| `date` | ISO 8601 text (`2026-11-24T09:05:00Z`) | `24 Nov 2026` |
| `dateTime` | ISO 8601 text | `24 Nov 2026, 09:05` |
| `number` | a number | `1,234.5` |
| `percent` | a fraction | `0.25` → `25%` |
| `currency` | a number of pounds | `£1,234.50` |
| `count` | a list, an object or a number | how many: `3` |
| `upper`, `lower` | text | the same text in upper or lower case |
| `initials` | a name | `Ada Lovelace` → `AL` |

A date in a fixture is ISO 8601 text; say so in the field's name or a `note`, since the
data contract only records it as text.

Paths start at `data` (from the app), `state` (this screen), `params` and `query` (the
URL), `event` (inside an action), `page` (in a frame: `page.id` is the screen showing in it), or a variable a `repeat` or template
slot introduces, such as `row` inside a table column's `cell`.

## Linking screens

A link is an action under a node's event. `design link <screen>#<node>.<event> --to <screen>`
writes one for you on a node that exists. To add a new way in, such as a sidebar button in
the frame or a tile on a dashboard, insert the node with `design patch` and give it the
`navigate` action (`replaceAll` from a sidebar). A new page joins the workspace's frame when
there is one (`design new screen` sets `"frame"`; pass `--frame` when there are several).

```json
"on": { "rowTap": [{ "do": "navigate", "to": "admin.automationEditor", "params": { "id": { "$bind": "event.row.id" } } }] }
```

| The user is... | Action |
| --- | --- |
| opening a detail or editor they will come back from | `navigate` (mode `push`, the default) |
| changing section from the sidebar | `navigate` with `"mode": "replaceAll"` |
| pressing Back | `back` with a `fallback` screen |
| using a breadcrumb | `backTo` |
| changing a tab or filter on the same page | `setQuery` |
| opening a dialog | `openModal`, and `closeModal` inside it |
| asking the app to do something | `emit`, with a name declared in the screen's `emits` |

Actions run in order. An `emit` whose handler returns `false` stops the list, so
`[emit save, toast, back]` stays on the page when the save is rejected.

Give every button a handler. A button with no action is disabled in the app, and
`design export` refuses it.

## Commands

Run them in the workspace, or pass `--workspace <dir>`. Exit code 0 is success, 1 means
problems were found or the command failed, 64 means the command was called wrongly.

| Command | Does |
| --- | --- |
| `design catalog [words] [--kind component\|token\|preset\|icon\|formatter] [--json]` | search the catalog; an exact component name prints it in full |
| `design new screen <id> --from <template>` | a new screen from list, detail, formModal, dashboard or frame |
| `design new preset <Family.variant> --extends <Family.base>` | a new preset variant |
| `design new token <key> --type <type> --light <value>` | a new token |
| `design validate [paths...] [--json] [--strict]` | every problem, in one run |
| `design describe <screen> [--fixture <name>]` | the resolved tree as text |
| `design patch <screen> --ops '<json list>'` | structural edits by node id; refused if they add an error |
| `design link <screen>#<node>.<event> --to <screen> [--mode push\|replaceAll\|replace] [--param k=v]` | add a navigate action |
| `design flow [--json\|--mermaid]` | the links between screens |
| `design contract <screen>` | the data, params and events the app must supply |
| `design fmt [--check]` | rewrite every document in canonical form |
| `design request "<need>"` | note something the catalog lacks, in requests.md |
| `design export [--out <path>]` | the bundle the app ships; strict: any error or warning refuses it |
| `design token set <key> --value <v> [--mode light\|dark] [--type <type>]` | set a token value; `--type` adds a new token |
| `design token unset <key> [--mode <mode>]` | remove a token's value in a mode, or the whole token |
| `design preset write <Family.variant> --json '<preset>'` | write a designer preset; refused if it adds an error |
| `design preset remove <Family.variant>` | delete a designer preset nothing uses |
| `design serve [--port 4400] [--studio <dir>]` | serve the studio; every save shows in its open tabs |
| `design screenshot <screen> [--fixture <name>] [--mode light\|dark] [--size 1440x900] [--out <file.png>]` | a PNG of the screen, drawn by the studio tab |
| `design focus <screen>[#<node>]` | show the screen in the studio tab and point at the node |

## The studio

The designer reviews your screens in the studio. `design serve` serves it on
`http://127.0.0.1:4400` (pass `--studio <dir>` or set `DESIGN_STUDIO_DIR` to the studio's
built web files) and pushes every file you save to the open tab within a second. A file
that does not parse keeps its last good version on screen under a banner, so fix the
diagnostic and save again. In Play mode every link, modal and emit works with fixture data.

In Inspect mode the designer selects nodes and edits them, and edits tokens and presets.
Each edit goes to `design serve` as the operations of the matching command (`design patch`,
`design token set`, `design preset write`) and is refused when it would add an error, so a
file the designer changed reads exactly as if you had run the command. Read the file again
before you edit it after the designer has worked on it.

With a studio tab open, check your work visually: `design screenshot admin.automations
--fixture empty --mode dark --size 390x844` writes a PNG of what the designer will see, and
`design focus admin.automations#saveButton` shows the designer the node you mean. Both
fail with a message saying what to start when no server or no studio tab is there.

Patch operations: `insert {parent, slot, index?, node}`, `remove {node}`,
`move {node, parent, slot, index?}`, `setProp {node, prop, value}` (null removes),
`setEvent {node, event, actions}` (null removes), `setWhen {node, when}`,
`wrap {node, with: {id, type, props?}, slot}`. Each is an object with `"op"`. A slot is
named as `catalog <Component>` lists it; a list of children is the slot `children`:

```json
[{ "op": "insert", "parent": "manage", "slot": "children", "index": 1,
   "node": { "id": "navUsers", "type": "OnboardingSidebarButton", "props": { "label": "Users" } } }]
```

## Diagnostic codes

Codes starting `E-` are errors, `W-` warnings.

| Code | Meaning |
| --- | --- |
| `E-json` | A file is not valid JSON, or not a JSON object. |
| `E-schema` | A document does not match its schema: an unknown or missing field, a wrong type or pattern. |
| `E-id-path` | A screen's id differs from the path its file spells, or a preset's file name from its id. |
| `E-duplicate-id` | Two nodes in one screen share an id. |
| `E-token-unknown` | A token key that neither the catalog nor tokens.json defines. |
| `E-token-type` | A token value does not fit its type, or `type` is given on a library token. |
| `E-token-light` | A new token has no `light` value. |
| `W-token-unused` | A new token that no preset or screen uses. |
| `E-preset-family` | A preset id names a family the catalog does not have. |
| `E-preset-extends` | A preset extends an unknown variant, a variant of another family, or forms a cycle. |
| `E-preset-variant` | A designer preset reuses the id of a built-in variant. |
| `E-style-field` | A style has a field the Style JSON does not know. |
| `E-style-raw` | A style holds a raw number or hex colour where a token key is required. |
| `E-style-token-type` | A style field names a token of the wrong type. |
| `E-style-value` | A style value is not one of the allowed values, or its fields do not combine. |
| `W-preset-unused` | A designer preset that nothing references. |
| `E-component-unknown` | A node type the catalog does not list. |
| `E-ctor-unknown` | A named constructor the component does not have. |
| `E-prop-unknown` | A prop the component does not have. |
| `E-prop-required` | A required prop is missing. |
| `E-prop-kind` | A prop value of the wrong kind: wrong JSON type, unknown choice, preset variant or token type. |
| `E-icon-unknown` | An icon name the catalog does not list. |
| `E-style-family` | A style prop names a preset of a family the prop does not accept. |
| `E-prop-bind` | An expression in a prop that must be a literal. |
| `E-slot-unknown` | A slot the component does not have. |
| `E-slot-required` | A required slot is missing or empty. |
| `E-slot-accepts` | A node the slot does not accept: a value in a widget slot, a widget in a value slot, or a wrong value type. |
| `W-slot-single` | A single-child slot holds several nodes without `when`; only the first is drawn. |
| `E-event-unknown` | An event the component does not have. |
| `E-bind-root` | A path starts at a root that is not in scope there. |
| `E-bind-path` | A path that does not resolve: not in the default fixture, or not declared in state, params or query. |
| `E-formatter-unknown` | A `{{path\|formatter}}` names a formatter the catalog does not list. |
| `E-screen-unknown` | An action, frame or start names a screen that does not exist. |
| `E-param-missing` | A link to a page does not supply a `:param` of its route. |
| `E-modal-target` | A link targets the wrong kind of screen, or closeModal runs outside a modal. |
| `E-emit-undeclared` | An emit is not declared in the screen's `emits`, or its payload keys differ. |
| `W-unreachable` | No navigate, openModal or frame link leads to the screen from the start screen. |
| `W-push-no-back` | A page opened with a push has no `back` action. |
| `W-frame-nav-mode` | A navigate in a frame does not use mode replaceAll. |
| `W-query-undeclared` | setQuery sets a key the screen's `query` does not declare. |
| `W-backto-not-ancestor` | backTo targets a page whose route is not a prefix of this page's route. |
| `W-unbound-primary` | A node's primary event (such as a button's tap) has no action and the node is not disabled. |
| `E-node-unknown` | A patch or link names a node id the screen does not have. |
| `E-patch-op` | A patch operation is malformed or cannot apply. |

The library adds these, from its placement rules:

| Code | Meaning |
| --- | --- |
| `W-page-root` | A page's root is a StyledListView with StyleContentList.normal (README 3.2). |
| `W-nested-scroll` | A StyledListView inside a page must use StyleContentList.flush: the page root is the only scroll (README 3.2). |
| `E-modal-root` | A modal's root is a ModalScaffold (README 4.1). |
| `E-outlet-outside-frame` | DesignOutlet: The component may appear only in screens of the listed kinds. (frame) |
| `W-table-in-card` | OnboardingDataTable: The component must not sit inside one of the listed types. (OnboardingCard) |
| `W-tooltip-rightmost` | An icon button in the last column of a table opens its tooltip to the left (tooltipPosition: left). |
