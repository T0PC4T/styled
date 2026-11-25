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
2. `design new screen <id> --from list|detail|formModal|dashboard` starts from a template.
3. Edit the JSON file, or send `design patch <screen> --ops '<json>'`.
4. `design validate --json` reports every problem at once. Each diagnostic names the node,
   says what is wrong, and gives a `hint` or the `allowed` values. Fix and re-run.
5. `design describe <screen> --fixture <name>` prints the tree as it resolves against a
   fixture. `design screenshot <screen>` returns a picture when a studio tab is open.
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

Paths start at `data` (from the app), `state` (this screen), `params` and `query` (the
URL), `event` (inside an action), or a variable a `repeat` or template slot introduces,
such as `row` inside a table column's `cell`.

## Linking screens

A link is an action under a node's event.

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
