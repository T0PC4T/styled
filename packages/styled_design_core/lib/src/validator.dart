/// The validator: checks a workspace's documents against the catalog and
/// explains every problem it finds, in one run.
library;

import 'catalog.dart';
import 'diagnostics.dart';
import 'documents.dart';
import 'expressions.dart';
import 'flow.dart';
import 'formatters.dart';
import 'json_util.dart';
import 'safe_parse.dart';
import 'screen.dart';
import 'token_values.dart';
import 'workspace_input.dart';

part 'validate_documents.dart';
part 'validate_screen.dart';
part 'validate_style.dart';

/// Checks every document of [input] against [catalog] and returns every
/// problem found, sorted by file, then JSON pointer.
///
/// [strict] does not change what is reported; it is the flag a caller passes
/// on to [diagnosticsFail], where warnings then count as failures.
List<Diagnostic> validateWorkspace(WorkspaceInput input, Catalog catalog, {bool strict = false}) {
  final v = _Validator(input, catalog)..run();
  return sortDiagnostics(v.out);
}

/// Whether [diagnostics] fail a run: any error, or with [strict] any
/// diagnostic at all.
bool diagnosticsFail(Iterable<Diagnostic> diagnostics, {bool strict = false}) =>
    diagnostics.any((d) => d.isError || strict);

/// The screens of [input] that parse well enough to use, by id. Screens whose
/// structure is broken are left out; [validateWorkspace] reports why.
Map<String, ScreenDoc> parseScreens(WorkspaceInput input) {
  final screens = <String, ScreenDoc>{};
  for (final MapEntry(key: path, value: json) in input.screenFiles.entries) {
    final (doc, _) = parseScreenSafely(json, file: path, partial: true);
    if (doc != null && doc.id.isNotEmpty) screens.putIfAbsent(doc.id, () => doc);
  }
  return screens;
}

/// A designer preset as the validator reads it.
final class _Preset {
  final String path;
  final String id;
  final String family;
  final String? extendsId;
  const _Preset(this.path, this.id, this.family, this.extendsId);
}

/// A parsed screen and where it came from.
final class _Screen {
  final String path;
  final ScreenDoc doc;

  /// Pointers the parser already reported as E-schema.
  final Set<String> broken;
  const _Screen(this.path, this.doc, this.broken);
}

final class _Validator {
  final WorkspaceInput input;
  final Catalog catalog;
  final out = <Diagnostic>[];

  /// Every token key (library and new) → its type.
  final tokens = <String, String>{};

  /// New tokens of tokens.json → nothing; to find the unused ones.
  final newTokens = <String>[];

  /// Every token key → its light value (overrides applied), for hints.
  final lightValues = <String, Object?>{};
  final usedTokens = <String>{};

  final presets = <String, _Preset>{};
  final usedPresets = <String>{};

  final screens = <String, _Screen>{};
  WorkspaceManifest? manifest;

  _Validator(this.input, this.catalog);

  void report(
    String code,
    String message, {
    required String? file,
    required String? pointer,
    String? node,
    String? hint,
    List<String>? allowed,
  }) => out.add(Diagnostic.of(code, message, file: file, pointer: pointer, node: node, hint: hint, allowed: allowed));

  Iterable<String> get formatterNames =>
      catalog.formatters.isNotEmpty ? catalog.formatters : DesignFormatters.standard.names;

  /// The component for a node type, or null.
  DesignComponent? component(String componentType) => catalog.components[componentType];

  /// Token keys of [type], or every key when [type] is null.
  Iterable<String> tokensOfType(String? type) =>
      type == null ? tokens.keys : tokens.entries.where((e) => e.value == type).map((e) => e.key);

  void run() {
    out.addAll(input.loadProblems);
    checkManifest();
    checkTokens();
    collectPresets();
    collectScreens();
    for (final preset in presets.values) {
      checkPreset(preset);
    }
    for (final screen in screens.values) {
      _ScreenCheck(this, screen).run();
    }
    checkWorkspaceFlow();
    checkUnused();
  }

  // ---------------------------------------------------------------- screens

  void collectScreens() {
    for (final MapEntry(key: path, value: json) in input.screenFiles.entries) {
      final (doc, problems) = parseScreenSafely(json, file: path, partial: true);
      out.addAll(withNodes(json, path, problems));
      final broken = {
        for (final d in problems)
          if (d.isError && d.pointer != null) d.pointer!,
      };
      final expected = WorkspaceInput.screenIdForPath(path);
      final id = json['id'];
      if (id is String && isScreenId(id) && id != expected) {
        report(
          'E-id-path',
          "Screen '$id' is in $path, which spells '$expected'.",
          file: path,
          pointer: '/id',
          hint: "Move the file to ${WorkspaceInput.pathForScreenId(id)}, or set id to '$expected'.",
        );
      }
      if (doc == null || doc.id.isEmpty) continue;
      if (screens.containsKey(doc.id)) continue; // Reported as E-id-path above.
      screens[doc.id] = _Screen(path, doc, broken);
      checkDuplicateIds(path, doc);
    }
  }

  /// [problems] with `node` filled in for those inside a node: the deepest
  /// node whose pointer holds the problem's pointer.
  List<Diagnostic> withNodes(Map<String, Object?> json, String path, List<Diagnostic> problems) {
    final screenId = json['id'] is String ? json['id']! as String : WorkspaceInput.screenIdForPath(path);
    final ids = <String, String>{};
    void visit(Object? node, String pointer) {
      if (node is! Map<String, Object?>) return;
      if (node['id'] case final String id) ids[pointer] = id;
      if (node['children'] case final List<Object?> children) {
        for (var i = 0; i < children.length; i++) {
          visit(children[i], '$pointer/children/$i');
        }
      }
      if (node['slots'] case final Map<String, Object?> slots) {
        for (final MapEntry(:key, :value) in slots.entries) {
          if (value is! List<Object?>) continue;
          for (var i = 0; i < value.length; i++) {
            visit(value[i], '$pointer/slots/${pointerSegment(key)}/$i');
          }
        }
      }
    }

    visit(json['root'], '/root');
    return [
      for (final d in problems)
        if (d.node != null || d.pointer == null || !d.pointer!.startsWith('/root'))
          d
        else
          switch ((ids.keys.where((k) => d.pointer == k || d.pointer!.startsWith('$k/')).toList()
                ..sort((a, b) => b.length.compareTo(a.length)))
              .firstOrNull) {
            final at? => d.copyWith(node: '$screenId#${ids[at]}'),
            null => d,
          },
    ];
  }

  void checkDuplicateIds(String path, ScreenDoc doc) {
    final first = <String, String>{};
    final all = doc.nodes.map((n) => n.id).toSet();
    for (final node in doc.nodes) {
      final seen = first[node.id];
      if (seen == null) {
        first[node.id] = node.pointer;
        continue;
      }
      var n = 2;
      while (all.contains('${node.id}$n')) {
        n++;
      }
      report(
        'E-duplicate-id',
        "Node id '${node.id}' is used twice in ${doc.id}; the first is at $seen.",
        file: path,
        pointer: '${node.pointer}/id',
        node: '${doc.id}#${node.id}',
        hint: "Give this node its own id, such as '${node.id}$n'.",
      );
    }
  }

  // -------------------------------------------------------------- workspace

  void checkWorkspaceFlow() {
    // A page's frame.
    for (final s in screens.values) {
      final frame = s.doc.frame;
      if (frame == null || frame.isEmpty || s.broken.contains('/frame')) continue;
      final target = screens[frame]?.doc;
      if (target == null) {
        report(
          'E-screen-unknown',
          "Page ${s.doc.id} names frame '$frame', which does not exist.",
          file: s.path,
          pointer: '/frame',
          hint:
              didYouMean(frame, screens.values.where((x) => x.doc.kind == ScreenKind.frame).map((x) => x.doc.id)) ??
              'Create it with design new screen $frame --from frame, or remove frame.',
        );
      } else if (target.kind != ScreenKind.frame) {
        report(
          'E-modal-target',
          "Page ${s.doc.id} names $frame as its frame, but that is a ${target.kind.name}.",
          file: s.path,
          pointer: '/frame',
          hint: 'A frame is a screen of kind frame with one DesignOutlet.',
        );
      }
    }

    // Frames hold exactly one outlet.
    for (final s in screens.values.where((s) => s.doc.kind == ScreenKind.frame)) {
      final outlets = s.doc.nodes.where((n) => n.componentType == 'DesignOutlet').toList();
      if (outlets.length != 1) {
        report(
          'E-schema',
          outlets.isEmpty
              ? 'Frame ${s.doc.id} has no DesignOutlet, so its pages have nowhere to draw.'
              : 'Frame ${s.doc.id} has ${outlets.length} DesignOutlet nodes; a frame draws its page in exactly one.',
          file: s.path,
          pointer: outlets.length > 1 ? outlets[1].pointer : '/root',
          node: outlets.length > 1 ? '${s.doc.id}#${outlets[1].id}' : null,
          hint: 'Put one {"id": "outlet", "type": "DesignOutlet"} where the page goes.',
        );
      }
    }

    // The start screen.
    final start = manifest?.start ?? '';
    final startOk = start.isNotEmpty && screens.containsKey(start);
    if (start.isNotEmpty && isScreenId(start) && !startOk) {
      report(
        'E-screen-unknown',
        "The start screen '$start' does not exist.",
        file: 'design.json',
        pointer: '/start',
        hint: didYouMean(start, screens.keys) ?? 'Set start to the page the prototype opens on.',
        allowed: shortList(screens.values.where((s) => s.doc.kind == ScreenKind.page).map((s) => s.doc.id)),
      );
    } else if (startOk && screens[start]!.doc.kind != ScreenKind.page) {
      report(
        'E-modal-target',
        "The start screen '$start' is a ${screens[start]!.doc.kind.name}; the prototype opens on a page.",
        file: 'design.json',
        pointer: '/start',
        allowed: shortList(screens.values.where((s) => s.doc.kind == ScreenKind.page).map((s) => s.doc.id)),
      );
    }

    final flow = buildFlow(screens.values.map((s) => s.doc));

    // Reachability from start.
    if (startOk) {
      final reached = <String>{start};
      final queue = [start];
      while (queue.isNotEmpty) {
        final from = queue.removeLast();
        for (final edge in flow.edges) {
          if (edge.from != from || edge.kind == 'back' || edge.kind == 'backTo') continue;
          if (reached.add(edge.to)) queue.add(edge.to);
        }
      }
      for (final s in screens.values) {
        if (s.doc.kind == ScreenKind.frame || reached.contains(s.doc.id)) continue;
        report(
          'W-unreachable',
          'Nothing leads to ${s.doc.id} from the start screen $start.',
          file: s.path,
          pointer: '',
          hint: s.doc.kind == ScreenKind.modal
              ? 'Open it with an openModal action on a reachable screen.'
              : 'Link to it: design link <screen>#<node>.<event> --to ${s.doc.id}',
        );
      }
    }

    // A page opened with a push needs a way back.
    final pushedFrom = <String, FlowEdge>{};
    for (final edge in flow.edges) {
      if (edge.kind == 'push') pushedFrom.putIfAbsent(edge.to, () => edge);
    }
    for (final MapEntry(key: id, value: edge) in pushedFrom.entries) {
      final target = screens[id];
      if (target == null || target.doc.kind != ScreenKind.page) continue;
      final hasBack = target.doc.nodes.any(
        (n) => n.on.values.any((a) => flattenActions(a).any((x) => x is BackAction)),
      );
      if (hasBack) continue;
      report(
        'W-push-no-back',
        '$id is opened with a push (from ${edge.from}#${edge.node}.${edge.event}) but has no back action.',
        file: target.path,
        pointer: '/root',
        node: '$id#${target.doc.root.id}',
        hint:
            'Add a back control, such as OnboardingPageHeader with on.back: [{"do": "back", "fallback": "${edge.from}"}].',
      );
    }
  }

  void checkUnused() {
    for (final key in newTokens) {
      if (usedTokens.contains(key)) continue;
      report(
        'W-token-unused',
        "New token '$key' is not used by any preset or screen.",
        file: WorkspaceInput.tokensPath,
        pointer: '/tokens/${pointerSegment(key)}',
        hint: 'Use it in a preset style, or remove it.',
      );
    }
    for (final preset in presets.values) {
      if (usedPresets.contains(preset.id)) continue;
      report(
        'W-preset-unused',
        "Designer preset '${preset.id}' is not used by any screen or preset.",
        file: preset.path,
        pointer: '/id',
        hint: 'Reference it from a style prop, such as "style": "${preset.id}", or remove the file.',
      );
    }
  }
}
