/// The `design` command line tool: works on a design workspace folder.
library;

export 'src/agents_md.dart' show agentsMd;
export 'src/context.dart' show CliFailure, diagnosticLine, summaryLine;
export 'src/mcp.dart' show DesignMcpServer, DesignRun, McpTool, designTools;
export 'src/runner.dart' show ExitCodes, designRunner, runDesign;
export 'src/templates.dart' show fillTemplate, routeForId, screenTemplates;
