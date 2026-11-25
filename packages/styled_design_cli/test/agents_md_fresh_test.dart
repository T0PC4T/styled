import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:styled_design_cli/styled_design_cli.dart';
import 'package:styled_design_core/io.dart';
import 'package:test/test.dart';

/// The kit workspace's AGENTS.md is what `design init` writes today. When the
/// guide changes, run with UPDATE_AGENTS_MD=1 to rewrite it.
void main() {
  test('the kit workspace guide is fresh', () {
    const dir = '../styled_design_core/test/fixtures/kit_workspace';
    final ws = DesignWorkspace.load(Directory(dir));
    final expected = agentsMd(name: ws.manifest!.name, catalog: ws.catalog);
    final file = File(p.join(dir, 'AGENTS.md'));
    if (Platform.environment['UPDATE_AGENTS_MD'] == '1') file.writeAsStringSync(expected);
    expect(file.readAsStringSync(), expected, reason: 'Run with UPDATE_AGENTS_MD=1 to rewrite it.');
  });
}
