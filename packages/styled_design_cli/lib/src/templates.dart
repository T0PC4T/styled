/// Built-in screen templates for `design new screen <id> --from <name>`.
///
/// Each is a screen document with three placeholders: `__ID__`, `__ROUTE__`
/// and `__TITLE__`. Filled in, each validates with no errors against the kit
/// catalog; it links to no other screen, so a new screen is only unreachable
/// (`W-unreachable`) until something links to it.
library;

import 'dart:convert';

/// Template name → (one-line summary, JSON text).
const screenTemplates = <String, (String, String)>{
  'list': ('A list page: title, toolbar, CrudView with table, grid and empty state, pagination.', _list),
  'detail': ('A detail page for one item: header with save and delete, an editing card.', _detail),
  'formModal': ('A modal with a form: ModalScaffold, one text input, submit and close.', _formModal),
  'dashboard': ('An overview page: title and a grid of KPI cards.', _dashboard),
  'frame': ('A frame that previews pages inside a sidebar shell, with one DesignOutlet.', _frame),
};

/// The route a page template gets for [id]: admin.users → /admin/users.
String routeForId(String id) => '/${id.split('.').join('/')}';

/// [template] (JSON text with placeholders) filled in for screen [id]. A
/// template's `__ROUTE__` is the route [id] spells; a detail page appends
/// `/:id` itself.
Map<String, Object?> fillTemplate(String template, {required String id, required String title}) {
  final text = template
      .replaceAll('__ID__', id)
      .replaceAll('__ROUTE__', routeForId(id))
      .replaceAll('__TITLE__', jsonEncode(title).substring(1, jsonEncode(title).length - 1));
  return (jsonDecode(text) as Map).cast<String, Object?>();
}

const _list = r'''
{
  "format": 1,
  "id": "__ID__",
  "kind": "page",
  "title": "__TITLE__",
  "route": "__ROUTE__",
  "fixtures": {
    "default": {
      "items": [
        { "id": "item_1", "name": "First item", "enabled": true },
        { "id": "item_2", "name": "Second item", "enabled": true },
        { "id": "item_3", "name": "Third item", "enabled": false }
      ],
      "isLoading": false,
      "error": null,
      "viewMode": "table",
      "sort": { "key": "name", "ascending": true },
      "paging": { "page": 1, "pageCount": 1, "pageSize": 25, "total": 3 }
    },
    "empty": { "items": [], "paging": { "total": 0 } },
    "loading": { "items": [], "isLoading": true },
    "failed": { "error": "Items could not be loaded. Try again." }
  },
  "emits": {
    "createItem": { "description": "The New button was pressed. Replace with openModal or navigate when that screen exists." },
    "openItem": { "description": "An item was chosen. Replace with navigate when its page exists.", "payload": { "id": "string" } },
    "search": { "description": "Search text changed (already debounced by the input).", "payload": { "value": "string" } },
    "setViewMode": { "description": "Card or table view was chosen.", "payload": { "mode": "string" } },
    "toggleSort": { "description": "A sortable column header was pressed.", "payload": { "key": "string" } },
    "previousPage": { "description": "Go to the previous page of results." },
    "nextPage": { "description": "Go to the next page of results." },
    "setPageSize": { "description": "Rows per page changed.", "payload": { "size": "number" } }
  },
  "root": {
    "id": "page",
    "type": "StyledListView",
    "props": { "style": "StyleContentList.normal" },
    "children": [
      {
        "id": "title",
        "type": "OnboardingPageTitle",
        "props": { "title": "__TITLE__", "subtitle": "Say in one line what this list holds" },
        "slots": {
          "actions": [
            {
              "id": "newItem",
              "type": "OnboardingButton.primary",
              "props": { "label": "New", "icon": "plus", "collapseTextOnMobile": true },
              "on": { "tap": [{ "do": "emit", "name": "createItem" }] }
            }
          ]
        }
      },
      {
        "id": "toolbar",
        "type": "CrudToolbar",
        "props": { "searchHint": "Search by name..." },
        "slots": {
          "actions": [
            {
              "id": "viewMode",
              "type": "ViewModeSwitcher",
              "props": { "currentMode": { "$bind": "data.viewMode" } },
              "on": { "modeChanged": [{ "do": "emit", "name": "setViewMode", "payload": { "mode": { "$bind": "event.value" } } }] }
            }
          ]
        },
        "on": { "searchChanged": [{ "do": "emit", "name": "search", "payload": { "value": { "$bind": "event.value" } } }] }
      },
      {
        "id": "errorBanner",
        "type": "OnboardingCalloutBanner.error",
        "when": { "$not": { "$empty": { "$bind": "data.error" } } },
        "props": { "message": { "$bind": "data.error" } }
      },
      {
        "id": "list",
        "type": "CrudView",
        "props": {
          "items": { "$bind": "data.items" },
          "isLoading": { "$bind": "data.isLoading" },
          "viewMode": { "$bind": "data.viewMode" }
        },
        "slots": {
          "empty": [
            {
              "id": "emptyState",
              "type": "OnboardingEmptyState",
              "props": { "icon": "inbox", "title": "Nothing here yet", "subtitle": "Say what appears here and how to add the first one." }
            }
          ],
          "table": [
            {
              "id": "table",
              "type": "OnboardingDataTable",
              "note": "Placed directly in the table slot. Never wrap a table in OnboardingCard.",
              "props": {
                "rows": { "$bind": "items" },
                "idPath": "id",
                "sortKey": { "$bind": "data.sort.key" },
                "sortAscending": { "$bind": "data.sort.ascending" }
              },
              "slots": {
                "columns": [
                  {
                    "id": "colName",
                    "type": "OnboardingTableColumn",
                    "props": { "label": "Name", "flex": 5, "sortKey": "name" },
                    "slots": {
                      "cell": [{ "id": "nameCell", "type": "StyledText", "props": { "text": { "$bind": "row.name" }, "style": "StyleText.cellTitle" } }]
                    }
                  },
                  {
                    "id": "colStatus",
                    "type": "OnboardingTableColumn",
                    "props": { "label": "Status", "flex": 2 },
                    "slots": {
                      "cell": [
                        { "id": "rowEnabled", "type": "OnboardingStatusBadge.success", "when": { "$bind": "row.enabled" }, "props": { "label": "Enabled", "dot": true } },
                        { "id": "rowDisabled", "type": "OnboardingStatusBadge.neutral", "props": { "label": "Disabled" } }
                      ]
                    }
                  },
                  {
                    "id": "colActions",
                    "type": "OnboardingTableColumn",
                    "props": { "label": "", "width": "tableActionColumnWidth", "alignment": "centerRight" },
                    "slots": {
                      "cell": [
                        {
                          "id": "rowOpen",
                          "type": "OnboardingIconButton",
                          "props": { "icon": "pencil", "tooltip": "Open", "tooltipPosition": "left" },
                          "on": { "tap": [{ "do": "emit", "name": "openItem", "payload": { "id": { "$bind": "row.id" } } }] }
                        }
                      ]
                    }
                  }
                ]
              },
              "on": {
                "rowTap": [{ "do": "emit", "name": "openItem", "payload": { "id": { "$bind": "event.row.id" } } }],
                "sort": [{ "do": "emit", "name": "toggleSort", "payload": { "key": { "$bind": "event.value" } } }]
              }
            }
          ],
          "grid": [
            {
              "id": "grid",
              "type": "OnboardingGrid",
              "children": [
                {
                  "id": "card",
                  "type": "OnboardingCard",
                  "repeat": { "over": { "$bind": "items" }, "as": "item", "key": { "$bind": "item.id" } },
                  "on": { "tap": [{ "do": "emit", "name": "openItem", "payload": { "id": { "$bind": "item.id" } } }] },
                  "children": [
                    {
                      "id": "cardMenu",
                      "type": "OnboardingCardMenu",
                      "props": { "title": { "$bind": "item.name" } },
                      "slots": {
                        "titleBadge": [
                          { "id": "cardEnabled", "type": "OnboardingStatusBadge.success", "when": { "$bind": "item.enabled" }, "props": { "label": "Enabled", "dot": true } },
                          { "id": "cardDisabled", "type": "OnboardingStatusBadge.neutral", "props": { "label": "Disabled" } }
                        ],
                        "items": [
                          {
                            "id": "cardOpen",
                            "type": "OnboardingPopupMenuItem",
                            "props": { "label": "Open", "icon": "pencil" },
                            "on": { "tap": [{ "do": "emit", "name": "openItem", "payload": { "id": { "$bind": "item.id" } } }] }
                          }
                        ]
                      }
                    },
                    { "id": "cardId", "type": "StyledText", "props": { "text": { "$bind": "item.id" }, "style": "StyleText.bodySubtle" } }
                  ]
                }
              ]
            }
          ]
        }
      },
      {
        "id": "pagination",
        "type": "OnboardingPaginationBar",
        "when": { "$gt": [{ "$bind": "data.paging.total" }, { "$bind": "data.paging.pageSize" }] },
        "props": {
          "page": { "$bind": "data.paging.page" },
          "pageCount": { "$bind": "data.paging.pageCount" },
          "pageSize": { "$bind": "data.paging.pageSize" },
          "totalItems": { "$bind": "data.paging.total" }
        },
        "on": {
          "previous": [{ "do": "emit", "name": "previousPage" }],
          "next": [{ "do": "emit", "name": "nextPage" }],
          "pageSizeChanged": [{ "do": "emit", "name": "setPageSize", "payload": { "size": { "$bind": "event.value" } } }]
        }
      }
    ]
  }
}
''';

const _detail = r'''
{
  "format": 1,
  "id": "__ID__",
  "kind": "page",
  "title": "__TITLE__",
  "route": "__ROUTE__/:id",
  "params": { "id": { "sample": "item_1", "description": "The id of the item shown." } },
  "state": {
    "name": { "$bind": "data.item.name" },
    "enabled": { "$bind": "data.item.enabled" }
  },
  "fixtures": {
    "default": {
      "item": { "id": "item_1", "name": "First item", "enabled": true, "updatedAt": "2026-11-24T09:00:00Z" },
      "isSaving": false,
      "errors": { "name": null }
    },
    "saving": { "isSaving": true },
    "invalid": { "errors": { "name": "Give it a name." } }
  },
  "emits": {
    "saveItem": {
      "description": "Save name and enabled. Return false to stay on the page (validation failed).",
      "payload": { "id": "string", "name": "string", "enabled": "bool" },
      "returns": "bool"
    },
    "deleteItem": { "description": "Delete the item. Return false if it could not be deleted.", "payload": { "id": "string" }, "returns": "bool" }
  },
  "root": {
    "id": "page",
    "type": "StyledListView",
    "props": { "style": "StyleContentList.normal" },
    "children": [
      {
        "id": "header",
        "type": "OnboardingPageHeader",
        "note": "Once the list page exists, add \"on\": {\"back\": [{\"do\": \"back\", \"fallback\": \"<list screen>\"}]} here and after save and delete.",
        "props": {
          "title": { "$bind": "state.name" },
          "subtitle": { "$text": "Updated {{data.item.updatedAt|dateTime}}" },
          "backLabel": "Back"
        },
        "slots": {
          "badge": [
            { "id": "enabledBadge", "type": "OnboardingStatusBadge.success", "when": { "$bind": "state.enabled" }, "props": { "label": "Enabled", "dot": true } },
            { "id": "disabledBadge", "type": "OnboardingStatusBadge.neutral", "props": { "label": "Disabled" } }
          ],
          "actions": [
            {
              "id": "delete",
              "type": "OnboardingButton",
              "props": { "label": "Delete", "icon": "trash", "style": "StyleButton.ghost", "collapseTextOnMobile": true },
              "on": {
                "tap": [
                  {
                    "do": "confirm",
                    "title": "Delete this item?",
                    "message": { "$text": "{{state.name}} cannot be restored." },
                    "confirmLabel": "Delete",
                    "destructive": true,
                    "then": [
                      { "do": "emit", "name": "deleteItem", "payload": { "id": { "$bind": "params.id" } } },
                      { "do": "toast", "message": "Deleted" }
                    ]
                  }
                ]
              }
            },
            {
              "id": "save",
              "type": "OnboardingButton.primary",
              "props": { "label": "Save", "icon": "circle_check", "loading": { "$bind": "data.isSaving" } },
              "on": {
                "tap": [
                  {
                    "do": "emit",
                    "name": "saveItem",
                    "payload": { "id": { "$bind": "params.id" }, "name": { "$bind": "state.name" }, "enabled": { "$bind": "state.enabled" } }
                  },
                  { "do": "toast", "message": "Saved" }
                ]
              }
            }
          ]
        }
      },
      {
        "id": "details",
        "type": "OnboardingCard",
        "children": [
          {
            "id": "nameInput",
            "type": "OnboardingTextInput",
            "props": {
              "label": "Name",
              "isRequired": true,
              "initialValue": { "$bind": "data.item.name" },
              "error": { "$bind": "data.errors.name" }
            },
            "on": { "changed": [{ "do": "setState", "set": { "name": { "$bind": "event.value" } } }] }
          },
          {
            "id": "enabledSwitch",
            "type": "OnboardingSwitchInput",
            "props": { "label": "Enabled", "subtitle": "Say what enabling it does.", "value": { "$bind": "state.enabled" } },
            "on": { "changed": [{ "do": "setState", "set": { "enabled": { "$bind": "event.value" } } }] }
          }
        ]
      }
    ]
  }
}
''';

const _formModal = r'''
{
  "format": 1,
  "id": "__ID__",
  "kind": "modal",
  "title": "__TITLE__",
  "state": { "name": "" },
  "fixtures": {
    "default": { "isSubmitting": false, "errors": { "name": null } },
    "submitting": { "isSubmitting": true },
    "invalid": { "errors": { "name": "Give it a name." } }
  },
  "emits": {
    "submit": {
      "description": "Create it. Return the new id, or false to keep the modal open.",
      "payload": { "name": "string" },
      "returns": "any",
      "sample": "item_1"
    }
  },
  "root": {
    "id": "modal",
    "type": "ModalScaffold",
    "props": {
      "title": "__TITLE__",
      "subtitle": "Say in one line what happens next.",
      "size": "sm",
      "submitLabel": "Create",
      "isSubmitting": { "$bind": "data.isSubmitting" }
    },
    "children": [
      {
        "id": "nameInput",
        "type": "OnboardingTextInput",
        "props": { "label": "Name", "hint": "A short name", "isRequired": true, "autofocus": true, "error": { "$bind": "data.errors.name" } },
        "on": { "changed": [{ "do": "setState", "set": { "name": { "$bind": "event.value" } } }] }
      }
    ],
    "on": {
      "submit": [
        { "do": "emit", "name": "submit", "payload": { "name": { "$bind": "state.name" } } },
        { "do": "closeModal", "result": { "$bind": "event.result" } }
      ]
    }
  }
}
''';

const _dashboard = r'''
{
  "format": 1,
  "id": "__ID__",
  "kind": "page",
  "title": "__TITLE__",
  "route": "__ROUTE__",
  "fixtures": {
    "default": { "counts": { "total": 12, "open": 3, "overdue": 1 } },
    "empty": { "counts": { "total": 0, "open": 0, "overdue": 0 } }
  },
  "root": {
    "id": "page",
    "type": "StyledListView",
    "props": { "style": "StyleContentList.normal" },
    "children": [
      { "id": "title", "type": "OnboardingPageTitle", "props": { "title": "__TITLE__", "subtitle": "Say in one line what this overview shows" } },
      {
        "id": "tiles",
        "type": "OnboardingGrid",
        "props": { "minItemWidth": "gridMinItemWidth", "spacing": "padding" },
        "children": [
          { "id": "totalTile", "type": "OnboardingKpiCard", "props": { "label": "Total", "value": { "$text": "{{data.counts.total|number}}" }, "icon": "layout_dashboard" } },
          { "id": "openTile", "type": "OnboardingKpiCard", "props": { "label": "Open", "value": { "$text": "{{data.counts.open|number}}" }, "icon": "bolt" } },
          { "id": "overdueTile", "type": "OnboardingKpiCard", "props": { "label": "Overdue", "value": { "$text": "{{data.counts.overdue|number}}" }, "icon": "circle_check" } }
        ]
      },
      {
        "id": "overdueNotice",
        "type": "OnboardingCalloutBanner.warning",
        "when": { "$gt": [{ "$bind": "data.counts.overdue" }, 0] },
        "props": { "message": { "$text": "{{data.counts.overdue}} overdue. Say what to do about them." } }
      }
    ]
  }
}
''';

const _frame = r'''
{
  "format": 1,
  "id": "__ID__",
  "kind": "frame",
  "title": "__TITLE__",
  "description": "Preview-only stand-in for the app's shell. Sidebar buttons change section, so they navigate with mode replaceAll.",
  "root": {
    "id": "shell",
    "type": "OnboardingSidebarShell",
    "slots": {
      "sidebar": [
        {
          "id": "sidebar",
          "type": "OnboardingSidebar",
          "slots": {
            "header": [{ "id": "brand", "type": "OnboardingSidebarHeader", "props": { "title": "App name", "subtitle": "Organisation" } }]
          },
          "children": [
            {
              "id": "mainSection",
              "type": "OnboardingSidebarSection",
              "props": { "title": "Manage" },
              "children": [
                {
                  "id": "navHome",
                  "type": "OnboardingSidebarButton",
                  "note": "Point it at a page: design link __ID__#navHome.tap --to <page>, then remove disabled. Mark it selected with {\"$eq\": [{\"$bind\": \"page.id\"}, \"<page>\"]}.",
                  "props": { "label": "Home", "icon": "layout_dashboard", "disabled": true }
                }
              ]
            }
          ]
        }
      ],
      "child": [{ "id": "outlet", "type": "DesignOutlet" }]
    }
  }
}
''';
