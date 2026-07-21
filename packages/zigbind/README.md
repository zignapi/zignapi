# zigbind (CLI)

Scaffold and build native Node.js addons written in Zig. Pure JavaScript (ESM),
no external dependencies, no `node-gyp`. Requires **Zig 0.16.0** on `PATH` and
**Node >= 18**.

## Commands

```sh
zigbind new <name>          # scaffold ./<name> from the built-in template
zigbind build [--release]   # run `zig build` in the cwd, emit ./<name>.node
```

- `new` copies the template tree, substituting the project name into file
  contents and names.
- `build` runs `zig build` (adding `-Doptimize=ReleaseFast` with `--release`),
  then copies the produced shared library to `./<name>.node`. If `build.zig.zon`
  is missing a fingerprint, it fills in the value Zig suggests and retries.
