import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import process from "node:process";

const PKG_ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");

/// Locate the zigbind Zig sources (the `native/` directory) that ship with this
/// CLI. Works both from the published npm package (bundled at `<pkg>/native`)
/// and from the monorepo checkout (`packages/zigbind` -> `../../native`).
export function resolveZigbindSources() {
  const candidates = [
    join(PKG_ROOT, "native"), // bundled inside the published package
    join(PKG_ROOT, "..", "..", "native"), // monorepo layout
  ];
  for (const dir of candidates) {
    if (existsSync(join(dir, "build.zig.zon"))) return dir;
  }
  throw new Error(
    "could not locate the zigbind Zig sources (native/) shipped with the CLI",
  );
}

/// Run `zig` with the given args in `cwd`. If the run fails because
/// `build.zig.zon` is missing/has an invalid fingerprint and `repairZon` is
/// given, patch in the value Zig suggests and retry once. On success, forwards
/// zig's output; on failure, forwards it and throws.
export function runZig(cwd, args, { repairZon } = {}) {
  let res = spawnSync("zig", args, { cwd, encoding: "utf8" });

  if (res.error) {
    if (res.error.code === "ENOENT") {
      throw new Error("could not find `zig` on PATH (Zig 0.16.0 is required)");
    }
    throw res.error;
  }

  if (res.status !== 0 && repairZon) {
    const suggested = (res.stderr ?? "").match(
      /(?:suggested value|use this value): (0x[0-9a-fA-F]+)/,
    );
    if (suggested) {
      patchFingerprint(repairZon, suggested[1]);
      res = spawnSync("zig", args, { cwd, encoding: "utf8" });
    }
  }

  process.stdout.write(res.stdout ?? "");
  process.stderr.write(res.stderr ?? "");
  if (res.status !== 0) {
    throw new Error(`zig ${args[0] ?? ""} failed`);
  }
  return res;
}

/// Insert or replace the `.fingerprint` field in a build.zig.zon.
export function patchFingerprint(zonPath, value) {
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
