// Runs automatically before `npm pack` / `npm publish` (and their pnpm
// equivalents). Copies the zigbind Zig sources (the monorepo's `native/`) into
// this package so the published tarball is self-contained and the CLI can
// `zig fetch --save` them from `<pkg>/native`. In the workspace checkout the
// CLI falls back to `../../native`, so this copy is only needed for publishing
// and is gitignored.
import { cpSync, existsSync, rmSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const pkgRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const src = join(pkgRoot, "..", "..", "native");
const dest = join(pkgRoot, "native");

// The compiled CLI must exist — typescript lives at the workspace root, so
// publish through pnpm or the release workflow (which build first), not bare
// `npm publish` from this directory.
if (!existsSync(join(pkgRoot, "dist", "cli.js"))) {
  console.error("prepack: dist/ is missing — run `pnpm --filter zigbind build` first");
  process.exit(1);
}

if (!existsSync(join(src, "build.zig.zon"))) {
  console.error(`prepack: cannot find zigbind sources at ${src}`);
  process.exit(1);
}

rmSync(dest, { recursive: true, force: true });
cpSync(src, dest, {
  recursive: true,
  filter: (p) => !/(\/|^)(zig-out|\.zig-cache)(\/|$)/.test(p),
});
console.log(`prepack: bundled native/ -> ${dest}`);
