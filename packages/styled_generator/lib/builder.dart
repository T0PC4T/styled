import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/styled_preset_generator.dart';
import 'src/styled_tokens_generator.dart';

/// Builder factory for package:styled code generation.
///
/// Generates `.styled.g.dart` part files for [@StyledPreset] and [@StyledTokens].
Builder styledBuilder(BuilderOptions options) => PartBuilder(
      [
        const StyledPresetGenerator(),
        const StyledTokensGenerator(),
      ],
      '.styled.g.dart',
      header: '// GENERATED CODE - DO NOT MODIFY BY HAND\n\n'
          '// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member, unused_local_variable\n',
    );
