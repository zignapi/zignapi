#!/usr/bin/env node
import process from "node:process";
import { runNew } from "../src/new.js";
import { runBuild } from "../src/build.js";

const HELP = `zigbind — write native Node.js addons in Zig

Usage:
  zigbind new <name>          Scaffold a new addon project into ./<name>
  zigbind build [--release]   Build the addon in the current directory
  zigbind --help              Show this help

Run "zigbind <command> --help" for command-specific options.
`;

async function main() {
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
      process.stderr.write(`zigbind: unknown command '${command}'\n\n${HELP}`);
      process.exitCode = 1;
  }
}

main().catch((err) => {
  process.stderr.write(`zigbind: ${err.message}\n`);
  process.exitCode = 1;
});
