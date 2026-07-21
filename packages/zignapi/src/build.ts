import { parseArgs } from "node:util";
import { existsSync, copyFileSync, readdirSync } from "node:fs";
import { join, basename, extname } from "node:path";
import process from "node:process";
import { runZig } from "./zig.js";

const BUILD_HELP = `zignapi build — build the addon in the current directory

Usage:
  zignapi build [--release]

Options:
  --release   Optimize the build (-Doptimize=ReleaseFast)
  -h, --help  Show this help

Runs "zig build" in the current directory, then copies the resulting shared
library to ./<name>.node (renaming a plain .dylib/.so/.dll if needed).
`;

export async function runBuild(argv: string[]): Promise<void> {
  const { values } = parseArgs({
    args: argv,
    options: {
      release: { type: "boolean", default: false },
      help: { type: "boolean", short: "h", default: false },
    },
  });

  if (values.help) {
    process.stdout.write(BUILD_HELP);
    return;
  }

  const cwd = process.cwd();
  if (!existsSync(join(cwd, "build.zig"))) {
    throw new Error("no build.zig found in the current directory");
  }

  const zigArgs = ["build"];
  if (values.release) zigArgs.push("-Doptimize=ReleaseFast");

  runZig(cwd, zigArgs, { repairZon: join(cwd, "build.zig.zon") });

  // Locate the freshly built addon and copy it to ./<name>.node.
  const addon = findAddon(join(cwd, "zig-out"));
  if (!addon) {
    throw new Error(
      "build succeeded but no addon (.node or shared library) was found under zig-out",
    );
  }

  const dest = join(cwd, addonName(addon));
  copyFileSync(addon, dest);
  process.stdout.write(`✔ built ${basename(dest)}\n`);
}

/**
 * Find the built addon under zig-out. Prefers an already-named `.node`,
 * falling back to the first shared library it finds.
 */
function findAddon(dir: string): string | null {
  const nodes: string[] = [];
  const libs: string[] = [];
  const walk = (d: string): void => {
    if (!existsSync(d)) return;
    for (const entry of readdirSync(d, { withFileTypes: true })) {
      const p = join(d, entry.name);
      if (entry.isDirectory()) {
        walk(p);
      } else if (entry.isFile()) {
        if (entry.name.endsWith(".node")) nodes.push(p);
        else if (/\.(dylib|so|dll)$/.test(entry.name)) libs.push(p);
      }
    }
  };
  walk(dir);
  return nodes[0] ?? libs[0] ?? null;
}

/** The `<name>.node` filename to copy an addon to at the project root. */
function addonName(addon: string): string {
  if (extname(addon) === ".node") return basename(addon);
  // libfoo.dylib -> foo.node
  let name = basename(addon, extname(addon));
  if (name.startsWith("lib")) name = name.slice(3);
  return `${name}.node`;
}
