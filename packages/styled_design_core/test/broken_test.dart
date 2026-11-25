import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:styled_design_core/io.dart';
import 'package:styled_design_core/styled_design_core.dart';
import 'package:test/test.dart';

/// The broken-document folder: test/fixtures/broken holds a small catalog, a
/// base workspace that validates clean, and one folder per diagnostic code.
/// Each case folder overlays files on the base and lists in expected.json the
/// diagnostics the validator must report.
const _root = 'test/fixtures/broken';

/// Codes only patch and link report; covered by operations_test.dart and the CLI tests.
const _patchOnly = {'E-node-unknown', 'E-patch-op'};

Catalog _catalog() =>
    Catalog.fromJson(jsonDecode(File('$_root/catalog.json').readAsStringSync()) as Map<String, Object?>);

WorkspaceInput _input(String caseDir) {
  final base = DesignWorkspace.load(Directory('$_root/base'));
  final overlay = DesignWorkspace.load(Directory(caseDir));
  return WorkspaceInput({...base.files, ...overlay.files}, loadProblems: overlay.loadProblems);
}

List<Directory> _cases() =>
    Directory(_root).listSync().whereType<Directory>().where((d) => p.basename(d.path) != 'base').toList()
      ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  final catalog = _catalog();

  test('the base workspace validates with no diagnostics', () {
    final found = validateWorkspace(DesignWorkspace.load(Directory('$_root/base')).toInput(), catalog);
    expect(found, isEmpty, reason: found.join('\n'));
  });

  test('every diagnostic code has a broken case', () {
    final covered = {
      for (final dir in _cases())
        for (final d in (_expected(dir)['diagnostics']! as List).cast<Map<String, Object?>>()) d['code'],
    };
    final ruleCodes = {
      for (final r in [...catalog.rules, for (final c in catalog.components.values) ...c.rules]) r.code,
    };
    final required = {...diagnosticCodes.keys.where((c) => !_patchOnly.contains(c)), ...ruleCodes};
    expect(required.difference(covered), isEmpty, reason: 'codes without a case');
    for (final dir in _cases()) {
      expect(required, contains(p.basename(dir.path)), reason: 'a case folder is named after its code');
    }
  });

  for (final dir in _cases()) {
    final name = p.basename(dir.path);
    test('broken case $name', () {
      final spec = _expected(dir);
      final expected = (spec['diagnostics']! as List).cast<Map<String, Object?>>();
      final tolerate = {...(spec['tolerate'] as List? ?? const []).cast<String>()};
      final found = validateWorkspace(_input(dir.path), catalog);
      final report = found.map((d) => '  $d [${d.node}]').join('\n');

      for (final e in expected) {
        final match = found.where((d) => d.code == e['code'] && d.file == e['file'] && d.pointer == e['pointer']);
        expect(match, isNotEmpty, reason: 'expected ${jsonEncode(e)}\nreported:\n$report');
        final d = match.first;
        if (e['node'] != null) expect(d.node, e['node'], reason: 'node of ${jsonEncode(e)}');
        if (e['hint'] case final String hint) {
          expect(d.hint, contains(hint), reason: 'hint of ${jsonEncode(e)}');
        }
        if (e['allowed'] == true) expect(d.allowed, isNotNull, reason: 'allowed of ${jsonEncode(e)}');
        expect(d.message, isNotEmpty);
        expect(d.isError, d.code.startsWith('E-'));
      }

      final expectedCodes = expected.map((e) => e['code']).toSet();
      for (final d in found) {
        final listed = expected.any((e) => e['code'] == d.code && e['file'] == d.file && e['pointer'] == d.pointer);
        final ok =
            listed || tolerate.contains(d.code) || (d.code == 'W-unreachable' && !expectedCodes.contains(d.code));
        expect(ok, isTrue, reason: 'unexpected ${d.code} at ${d.file} ${d.pointer}: ${d.message}\nreported:\n$report');
      }

      // Every diagnostic names its file and pointer, and a node when it is in one.
      for (final d in found) {
        expect(d.file, isNotNull, reason: '$d');
        expect(d.pointer, isNotNull, reason: '$d');
        if (d.pointer!.startsWith('/root') && d.file!.startsWith('screens/') && d.code != 'W-push-no-back') {
          expect(d.node, isNotNull, reason: 'a diagnostic inside a node names it: $d');
        }
      }
    });
  }

  test('diagnostics come sorted by file, then pointer', () {
    final found = validateWorkspace(_input('$_root/E-prop-kind'), catalog);
    final sorted = [...found]
      ..sort((a, b) {
        final f = a.file!.compareTo(b.file!);
        return f != 0 ? f : comparePointers(a.pointer, b.pointer);
      });
    expect(found.map((d) => '${d.file}${d.pointer}'), sorted.map((d) => '${d.file}${d.pointer}'));
  });
}

Map<String, Object?> _expected(Directory dir) =>
    jsonDecode(File(p.join(dir.path, 'expected.json')).readAsStringSync()) as Map<String, Object?>;
