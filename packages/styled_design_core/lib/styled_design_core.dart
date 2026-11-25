/// Pure Dart core of the styled design engine: the catalog model, screen,
/// token and preset documents, the expression language and diagnostics.
///
/// Free of `dart:io` and Flutter, so the Flutter runtime (web included), the
/// generator and the command line tool all share it. File access lives in
/// `package:styled_design_core/io.dart`.
library;

export 'src/annotations.dart';
export 'src/bundle.dart';
export 'src/bundle_builder.dart';
export 'src/catalog.dart';
export 'src/catalog_help.dart';
export 'src/codes.dart';
export 'src/contract.dart';
export 'src/describe.dart';
export 'src/diagnostics.dart';
export 'src/documents.dart';
export 'src/expressions.dart';
export 'src/flow.dart';
export 'src/fmt.dart';
export 'src/formatters.dart';
export 'src/json_util.dart' show comparePointers, deepCopyJson, jsonAt, sortDiagnostics, titleFromId;
export 'src/merge_patch.dart';
export 'src/patch.dart';
export 'src/safe_parse.dart';
export 'src/screen.dart';
export 'src/token_values.dart';
export 'src/validator.dart'
    show
        diagnosticsFail,
        isRoutePrefix,
        parseScreens,
        propKindText,
        slotAccepts,
        slotAcceptsText,
        styleStates,
        validateWorkspace;
export 'src/workspace_input.dart';
