# zigbind (CLI)

Scaffold and build native Node.js addons written in Zig. Written in TypeScript,
compiled to ESM with **zero runtime dependencies**, no `node-gyp`. Requires
**Zig 0.16.0** on `PATH` and **Node >= 18**.

## Commands

```sh
zigbind new <name>          # scaffold ./<name> from the built-in template
zigbind build [--release]   # run `zig build` in the cwd, emit ./<name>.node
```

- `new` copies the template tree (substituting the project name) and pins the
  `zigbind` Zig dependency with `zig fetch --save`.
- `build` runs `zig build` (adding `-Doptimize=ReleaseFast` with `--release`),
  then copies the produced shared library to `./<name>.node`. If `build.zig.zon`
  is missing a fingerprint, it fills in the value Zig suggests and retries.

## Development

The source is TypeScript under `src/` and compiles to `dist/` with `tsc`.
TypeScript is a **workspace-root** devDependency (not installed in this package),
so build through the workspace:

```sh
pnpm install                 # the root `prepare` script compiles the CLI
pnpm --filter zigbind build  # or rebuild explicitly (runs tsc)
```

The `bin` points at the compiled `dist/cli.js`; the published package ships
`dist/`, `templates/`, and a bundled copy of the Zig `native/` sources.
