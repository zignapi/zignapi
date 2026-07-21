// Produce the release asset for the zigbind Zig package: a tarball whose ROOT
// is the `native/` package (so `build.zig.zon` sits at the tarball root, which
// is what `zig fetch` expects — a single wrapping directory would NOT work).
//
// Output: dist/zigbind-<version>.tar.gz, where <version> is read from
// native/build.zig.zon. This is what CI uploads to the GitHub release and what
// `zigbind new` fetches from.
//
// Usage: node scripts/pack-native.mjs
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, rmSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const nativeDir = join(repoRoot, "native");
const distDir = join(repoRoot, "dist");

const zon = readFileSync(join(nativeDir, "build.zig.zon"), "utf8");
const version = zon.match(/\.version\s*=\s*"([^"]+)"/)?.[1];
if (!version) {
  console.error("pack-native: could not read .version from native/build.zig.zon");
  process.exit(1);
}

// These must match `.paths` in native/build.zig.zon.
const members = ["build.zig", "build.zig.zon", "src", "vendor"];
for (const m of members) {
  if (!existsSync(join(nativeDir, m))) {
    console.error(`pack-native: missing native/${m}`);
    process.exit(1);
  }
}

mkdirSync(distDir, { recursive: true });
const out = join(distDir, `zigbind-${version}.tar.gz`);
rmSync(out, { force: true });

const res = spawnSync(
  "tar",
  ["-czf", out, "--exclude", ".DS_Store", "-C", nativeDir, ...members],
  { stdio: "inherit", env: { ...process.env, COPYFILE_DISABLE: "1" } },
);
if (res.status !== 0) {
  console.error("pack-native: tar failed");
  process.exit(res.status ?? 1);
}
console.log(`pack-native: wrote ${out}`);
