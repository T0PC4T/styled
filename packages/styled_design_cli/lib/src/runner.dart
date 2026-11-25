import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'commands_create.dart';
import 'commands_edit.dart';
import 'commands_read.dart';
import 'context.dart';

/// Exit codes: 0 ok; 1 problems found or the command failed; 64 usage error.
abstract final class ExitCodes {
  static const ok = 0;
  static const failed = 1;
  static const usage = 64;
}

/// Runs the `design` command line with [args] and returns its exit code.
///
/// Output goes to [out] and [err] (stdout and stderr by default); [cwd] is
/// the directory relative paths start from (the process's by default), and
/// [now] the clock `design request` dates entries with.
Future<int> runDesign(
  List<String> args, {
  StringSink? out,
  StringSink? err,
  String? cwd,
  DateTime Function()? now,
}) async {
  final ctx = CliContext(
    cwd: cwd ?? Directory.current.path,
    out: out ?? stdout,
    err: err ?? stderr,
    now: now ?? DateTime.now,
  );
  final runner = designRunner(ctx);
  try {
    return await runner.run(args) ?? ExitCodes.ok;
  } on UsageException catch (e) {
    ctx.err
      ..writeln(e.message)
      ..writeln()
      ..writeln(e.usage);
    return ExitCodes.usage;
  } on CliFailure catch (e) {
    ctx.err.writeln(e.message);
    return e.exitCode;
  } on FileSystemException catch (e) {
    ctx.err.writeln('${e.message}${e.path == null ? '' : ': ${e.path}'}. Check the path and permissions, then retry.');
    return ExitCodes.failed;
  } on Object catch (e, stack) {
    // A bug in the tool, not in the workspace: say so, briefly, and fail.
    ctx.err
      ..writeln('design failed unexpectedly: $e')
      ..writeln(stack.toString().split('\n').take(5).join('\n'))
      ..writeln('Run design validate to find the document that causes it, and report this.');
    return ExitCodes.failed;
  }
}

/// The `design` command runner, with every command.
CommandRunner<int> designRunner(CliContext ctx) {
  final runner = _Runner(ctx);
  runner.argParser.addOption(
    'workspace',
    abbr: 'w',
    help: 'The workspace folder (default: the current directory).',
    valueHelp: 'dir',
  );
  for (final command in [
    InitCommand(ctx),
    CatalogCommand(ctx),
    NewCommand(ctx),
    ValidateCommand(ctx),
    DescribeCommand(ctx),
    PatchCommand(ctx),
    LinkCommand(ctx),
    FlowCommand(ctx),
    ContractCommand(ctx),
    FmtCommand(ctx),
    RequestCommand(ctx),
    ExportCommand(ctx),
  ]) {
    runner.addCommand(command);
  }
  return runner;
}

final class _Runner extends CommandRunner<int> {
  final CliContext ctx;
  _Runner(this.ctx)
    : super('design', 'Build and check design workspaces: JSON screens drawn from the catalog of a Flutter library.');

  @override
  void printUsage() => ctx.out.writeln(usage);

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults.command == null && !(topLevelResults['help'] as bool)) {
      if (topLevelResults.rest.isNotEmpty) {
        throw UsageException('Unknown command "${topLevelResults.rest.first}".', usage);
      }
      printUsage();
      return ExitCodes.ok;
    }
    return super.runCommand(topLevelResults);
  }
}
