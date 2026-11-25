import 'dart:io';

import 'package:styled_design_cli/styled_design_cli.dart';

Future<void> main(List<String> args) async {
  final code = await runDesign(args);
  await stdout.flush();
  await stderr.flush();
  exit(code);
}
