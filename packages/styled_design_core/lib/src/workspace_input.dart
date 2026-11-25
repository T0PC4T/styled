import 'package:meta/meta.dart';

import 'diagnostics.dart';
import 'documents.dart';

/// An IO-free view of a design workspace: every design document by its
/// workspace-relative path (forward slashes), plus the files that could not
/// be read. `DesignWorkspace.toInput()` (io.dart) builds one from a folder;
/// tests and the studio build one in memory.
@immutable
final class WorkspaceInput {
  /// Workspace-relative path → decoded JSON object: `design.json`,
  /// `tokens/tokens.json`, `presets/<id>.json`, `screens/<a>/<b>.json`.
  /// `catalog.json` is ignored by the validator.
  final Map<String, Map<String, Object?>> files;

  /// Problems met while reading the files, such as `E-json`.
  final List<Diagnostic> loadProblems;

  const WorkspaceInput(this.files, {this.loadProblems = const []});

  Map<String, Object?>? get manifestJson => files['design.json'];

  WorkspaceManifest? get manifest => switch (manifestJson) {
    final m? => WorkspaceManifest.fromJson(m),
    null => null,
  };

  Map<String, Object?>? get tokensJson => files[tokensPath];

  /// presets/*.json, by path, sorted.
  Map<String, Map<String, Object?>> get presetFiles => _under('presets/');

  /// screens/**/*.json, by path, sorted.
  Map<String, Map<String, Object?>> get screenFiles => _under('screens/');

  Map<String, Map<String, Object?>> _under(String prefix) {
    final paths = files.keys.where((k) => k.startsWith(prefix) && k.endsWith('.json')).toList()..sort();
    return {for (final path in paths) path: files[path]!};
  }

  /// This input with [path] replaced by [json] (or removed when null).
  WorkspaceInput withFile(String path, Map<String, Object?>? json) {
    final next = {...files};
    if (json == null) {
      next.remove(path);
    } else {
      next[path] = json;
    }
    return WorkspaceInput(
      next,
      loadProblems: [
        for (final d in loadProblems)
          if (d.file != path) d,
      ],
    );
  }

  static const tokensPath = 'tokens/tokens.json';

  /// The screen id a path spells: screens/admin/automations.json → admin.automations.
  static String screenIdForPath(String path) {
    var rest = path.startsWith('screens/') ? path.substring('screens/'.length) : path;
    if (rest.endsWith('.json')) rest = rest.substring(0, rest.length - '.json'.length);
    return rest.split('/').join('.');
  }

  /// The path a screen id spells: admin.automations → screens/admin/automations.json.
  static String pathForScreenId(String id) => 'screens/${id.split('.').join('/')}.json';

  /// The path of a designer preset: StyleCard.highlight → presets/StyleCard.highlight.json.
  static String pathForPresetId(String id) => 'presets/$id.json';
}
