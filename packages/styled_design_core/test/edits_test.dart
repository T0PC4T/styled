import 'dart:convert';
import 'dart:io';

import 'package:styled_design_core/io.dart';
import 'package:styled_design_core/styled_design_core.dart';
import 'package:test/test.dart';

final _kit = DesignWorkspace.load(Directory('test/fixtures/kit_workspace'));

void main() {
  final catalog = _kit.catalog!;
  final input = _kit.toInput();
  Map<String, Object?> tokens(DocumentEdit edit) => edit.json!['tokens']! as Map<String, Object?>;

  group('editScreen', () {
    test('applies the operations and gives the canonical text', () {
      const path = 'screens/admin/automations.json';
      final edit = editScreen(input, catalog, path, [
        {'op': 'setProp', 'node': 'newAutomation', 'prop': 'label', 'value': 'Add automation'},
      ]);
      expect(edit.ok, isTrue, reason: edit.message);
      expect(edit.message, startsWith('Wrote $path'));
      expect(edit.text, formatDocument(edit.json!, path: path));
      expect(edit.text, contains('"label": "Add automation"'));
    });

    test('refuses an operation that cannot apply, and an edit that adds an error', () {
      const path = 'screens/admin/dashboard.json';
      final unknown = editScreen(input, catalog, path, [
        {'op': 'remove', 'node': 'nope'},
      ]);
      expect(unknown.ok, isFalse);
      expect(unknown.diagnostics.map((d) => d.code), contains('E-node-unknown'));
      final error = editScreen(input, catalog, path, [
        {'op': 'setProp', 'node': 'automationsTile', 'prop': 'icon', 'value': 'no_such_icon'},
      ]);
      expect(error.ok, isFalse);
      expect(error.message, contains('adds 1 error'));
      expect(error.diagnostics.single.code, 'E-icon-unknown');
      expect(editScreen(input, catalog, 'screens/x.json', const []).message, contains('No screen'));
    });
  });

  group('setToken', () {
    test('overrides a library token in a mode, keeping the rest of the document', () {
      final edit = setToken(input, catalog, key: 'primary', mode: 'dark', value: '#123456');
      expect(edit.ok, isTrue, reason: edit.message);
      expect(tokens(edit).keys, ['cardRadius', 'accentSubtle', 'primary']);
      expect(tokens(edit)['primary'], {
        'values': {'dark': '#123456'},
      });
      expect(edit.message, 'Set primary to "#123456" in dark mode in tokens/tokens.json.');

      final again = setToken(input, catalog, key: 'cardRadius', value: 20);
      expect(tokens(again)['cardRadius'], {
        'values': {'light': 20},
      });
    });

    test('adds a new token with its type, light first', () {
      final noType = setToken(input, catalog, key: 'brandNew', value: '#FFFFFF');
      expect(noType.ok, isFalse);
      expect(noType.message, contains('give its type'));
      final dark = setToken(input, catalog, key: 'brandNew', value: '#FFFFFF', mode: 'dark', type: 'color');
      expect(dark.message, contains('light value first'));
      final ok = setToken(input, catalog, key: 'brandNew', value: '#FFFFFF', type: 'color', description: 'Brand.');
      expect(ok.ok, isTrue, reason: ok.message);
      expect(
        jsonEncode(tokens(ok)['brandNew']),
        '{"type":"color","description":"Brand.","values":{"light":"#FFFFFF"}}',
      );
      expect(ok.diagnostics.map((d) => d.code), ['W-token-unused']);
    });

    test('refuses a wrong value, a type on a library token, a changed type and an unknown mode', () {
      expect(setToken(input, catalog, key: 'primary', value: 'blue').message, contains('#RRGGBB'));
      expect(setToken(input, catalog, key: 'primary', value: '#000000', type: 'double').message, contains('no type'));
      expect(
        setToken(input, catalog, key: 'accentSubtle', value: 3, type: 'double').message,
        contains('cannot change'),
      );
      expect(setToken(input, catalog, key: 'primary', value: '#000000', mode: 'sepia').ok, isFalse);
      expect(setToken(input, catalog, key: 'Bad', value: 1).ok, isFalse);
    });
  });

  group('unsetToken', () {
    test('removes a mode or the whole entry', () {
      final dark = unsetToken(input, catalog, key: 'accentSubtle', mode: 'dark');
      expect(dark.ok, isTrue, reason: dark.message);
      expect((tokens(dark)['accentSubtle']! as Map)['values'], {'light': '#FFF7D6'});
      final whole = unsetToken(input, catalog, key: 'cardRadius');
      expect(tokens(whole).keys, ['accentSubtle']);
    });

    test('refuses removing a token in use, or the light value of a new token with other modes', () {
      final used = unsetToken(input, catalog, key: 'accentSubtle');
      expect(used.ok, isFalse);
      expect(used.diagnostics.map((d) => d.code), contains('E-token-unknown'));
      expect(unsetToken(input, catalog, key: 'accentSubtle', mode: 'light').message, contains('keeps its light'));
      expect(unsetToken(input, catalog, key: 'nope').ok, isFalse);
    });
  });

  group('presets', () {
    final quiet = {
      'format': 1,
      'id': 'StyleCard.calm',
      'extends': 'StyleCard.surface',
      'style': {
        'box': {'color': 'surfaceSubtle'},
      },
    };

    test('writePreset writes a new preset; one that adds an error is refused', () {
      final edit = writePreset(input, catalog, quiet);
      expect(edit.ok, isTrue, reason: edit.message);
      expect(edit.path, 'presets/StyleCard.calm.json');
      expect(edit.message, startsWith('Wrote presets/StyleCard.calm.json'));
      expect(edit.diagnostics.map((d) => d.code), ['W-preset-unused']);

      final raw = writePreset(input, catalog, {
        ...quiet,
        'style': {
          'box': {'color': '#FF0000'},
        },
      });
      expect(raw.ok, isFalse);
      expect(raw.diagnostics.map((d) => d.code), isNotEmpty);
      expect(writePreset(input, catalog, {'id': 'nope'}).ok, isFalse);
    });

    test('removePreset deletes an unused preset and refuses one in use', () {
      final withCalm = input.withFile('presets/StyleCard.calm.json', quiet);
      final removed = removePreset(withCalm, catalog, 'StyleCard.calm');
      expect(removed.ok, isTrue, reason: removed.message);
      expect(removed.deletes, isTrue);
      expect(removed.text, isNull);
      final used = removePreset(input, catalog, 'StyleCard.highlight');
      expect(used.ok, isFalse);
      expect(used.diagnostics.map((d) => d.code), contains('E-prop-kind'), reason: 'the dashboard still uses it');
    });
  });
}
