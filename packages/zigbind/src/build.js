import { parseArgs } from "node:util";
import { spawnSync } from "node:child_process";
import {
  existsSync,
  readFileSync,
  writeFileSync,
  copyFileSync,
  readdirSync,
} from "node:fs";
import { join, basename, extname } from "node:path";
import process from "node:process";

const BUILD_HELP = `zigbind build — build the addon in the current directory

Usage:
  zigbind build [--release]

Options:
  --release   Optimize the build (-Doptimize=ReleaseFast)
  -h, --help  Show this help

Runs "zig build" in the current directory, then copies the resulting shared
library to ./<name>.node (renaming a plain .dylib/.so/.dll if needed).
`;

export async function runBuild(argv) {
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

  runZig(cwd, zigArgs);

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

/// Run `zig` with the given args, transparently repairing a missing/invalid
/// build.zig.zon fingerprint (Zig prints the correct value) and retrying once.
function runZig(cwd, args) {
  let res = spawnSync("zig", args, { cwd, encoding: "utf8" });

  if (res.error) {
    if (res.error.code === "ENOENT") {
      throw new Error("could not find `zig` on PATH (Zig 0.16.0 is required)");
    }
    throw res.error;
  }

  if (res.status !== 0) {
    const suggested = (res.stderr ?? "").match(
      /(?:suggested value|use this value): (0x[0-9a-fA-F]+)/,
    );
    if (suggested) {
      patchFingerprint(join(cwd, "build.zig.zon"), suggested[1]);
      res = spawnSync("zig", args, { cwd, encoding: "utf8" });
    }
  }

  process.stdout.write(res.stdout ?? "");
  process.stderr.write(res.stderr ?? "");
  if (res.status !== 0) {
    throw new Error("zig build failed");
  }
}

/// Insert or replace the `.fingerprint` field in a build.zig.zon.
function patchFingerprint(zonPath, value) {
  if (!existsSync(zonPath)) return;
  let src = readFileSync(zonPath, "utf8");
  if (/\.fingerprint\s*=\s*0x[0-9a-fA-F]+/.test(src)) {
    src = src.replace(/\.fingerprint\s*=\s*0x[0-9a-fA-F]+/, `.fingerprint = ${value}`);
  } else {
    // Insert right after the `.name = ...,` line.
    src = src.replace(/(\.name\s*=\s*[^\n]*,\n)/, `$1    .fingerprint = ${value},\n`);
  }
  writeFileSync(zonPath, src);
}

/// Find the built addon under zig-out. Prefers an already-named `.node`,
/// falling back to the first shared library it finds.
function findAddon(dir) {
  const nodes = [];
  const libs = [];
  const walk = (d) => {
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

/// The `<name>.node` filename to copy an addon to at the project root.
function addonName(addon) {
  if (extname(addon) === ".node") return basename(addon);
  // libfoo.dylib -> foo.node
  let name = basename(addon, extname(addon));
  if (name.startsWith("lib")) name = name.slice(3);
  return `${name}.node`;
}
