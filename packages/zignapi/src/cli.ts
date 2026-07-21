#!/usr/bin/env node
import process from "node:process";
import { runNew } from "./new.js";
import { runBuild } from "./build.js";

const HELP = `zignapi — write native Node.js addons in Zig

Usage:
  zignapi new <name>          Scaffold a new addon project into ./<name>
  zignapi build [--release]   Build the addon in the current directory
  zignapi --help              Show this help

Run "zignapi <command> --help" for command-specific options.
`;

async function main(): Promise<void> {
  const [command, ...rest] = process.argv.slice(2);
  switch (command) {
    case "new":
      return runNew(rest);
    case "build":
      return runBuild(rest);
    case "-h":
    case "--help":
    case undefined:
      process.stdout.write(HELP);
      return;
    default:
      process.stderr.write(`zignapi: unknown command '${command}'\n\n${HELP}`);
      process.exitCode = 1;
  }
}

main().catch((err: unknown) => {
  const message = err instanceof Error ? err.message : String(err);
  process.stderr.write(`zignapi: ${message}\n`);
  process.exitCode = 1;
});
