# zignapi

Write native Node.js addons in [Zig](https://ziglang.org/) — the Zig equivalent of
[napi-rs](https://napi.rs/) for Rust.

You write plain Zig functions, register them with one comptime call, and `zignapi`
produces a `.node` addon that Node can `require()` directly. No `node-gyp`, no C glue.

```zig
const zignapi = @import("zignapi");

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

comptime {
    zignapi.register(.{ .add = add });
}
```

```js
const addon = require("./zig-out/lib/addon.node");
console.log(addon.add(2, 3)); // 5
```

## Requirements

- **Zig 0.16.0** exactly. The build scripts and the comptime reflection in
  `native/src` rely on 0.16.0 APIs (`b.addLibrary`, the `root_module`/`createModule`
  module graph, lowercase `@typeInfo` tags such as `.@"fn"` / `.@"struct"`, and the
  `union(enum)` `CallingConvention`). Other Zig versions will not compile.
- **Node.js >= 18**, targeting **N-API version 8**.
- **pnpm** for the workspace.

## Layout

```
zignapi/
├── native/                 # the Zig library (a Zig package, NOT an npm package)
│   ├── src/                # zignapi.zig, napi.zig, convert.zig, async.zig, register.zig
│   └── vendor/             # vendored N-API headers (node-api-headers)
├── packages/zignapi/       # the CLI (npm package `zignapi`, command `zignapi`)
└── playground/             # example addon exercising the whole pipeline
```

## Try it

```sh
pnpm install
pnpm --filter playground build   # compiles the addon via the zignapi CLI
pnpm --filter playground test    # node --test, checks add(2, 3) === 5
```

## How it works

- `native/src/napi.zig` `@cImport`s the vendored N-API headers and exposes thin
  wrappers over the raw C API.
- `native/src/convert.zig` uses `@typeInfo` at comptime to convert between Zig and
  JS values (`i32`, `f64`, `bool`, `[]const u8`). Zig error unions (`!T`) are thrown
  as JS exceptions via `napi_throw_error`.
- `native/src/register.zig` generates the `napi_register_module_v1` entry point Node
  looks up when it loads the `.node` file.
- The addon is built as a dynamic library and installed as `<name>.node`. N-API
  symbols are left undefined at link time (`-fallow-shlib-undefined`, the portable
  equivalent of macOS `-undefined dynamic_lookup`) and resolved by Node at load.

Async support (`native/src/async.zig`) is a stub for now — see the TODO there.

## Scaffolding a project (`zignapi new`)

The CLI is published to npm as **`zignapi`** and installs the `zignapi` command:

```sh
npm install -g zignapi
zignapi new my-addon
```

`zignapi new <name>` creates a project and wires the `zignapi` Zig module into
its `build.zig.zon` with `zig fetch --save`, pinning it by content hash. By
default it fetches the **hosted release tarball**
(`https://github.com/zignapi/zignapi/releases/download/v<version>/zignapi-<version>.tar.gz`),
so a scaffolded project is portable across machines and CI. If that URL is
unreachable — or you pass `--local` — it falls back to the Zig sources bundled
with the CLI (or `../../native` in this checkout). Override the URL with
`ZIGNAPI_RELEASE_URL` (handy for a mirror or a local `file://` tarball).

The `playground/` deliberately keeps a plain `.path = "../native"` dependency
instead: it's the in-repo dev harness, so it should track edits to `native/`
live without a re-fetch.

## Releasing

The Zig library is distributed as a GitHub **release asset** — a tarball whose
root is the `native/` package (so `build.zig.zon` sits at the tarball root,
which is what `zig fetch` requires).

1. Bump `.version` in `native/build.zig.zon` **and** `packages/zignapi/package.json`
   to the same value.
2. Tag and push: `git tag v0.1.0 && git push --tags`.
3. `.github/workflows/release.yml` builds `dist/zignapi-<version>.tar.gz`
   (`node scripts/pack-native.mjs`) and uploads it to the release.
4. Publish the CLI to npm (the `Publish CLI to npm` workflow, or `npm publish`
   from `packages/zignapi` — `prepack` bundles `native/` as the offline fallback).

> A published release asset is immutable: never re-upload it for the same tag,
> or the pinned `hash` in downstream projects will stop matching.
