# zigbind

Write native Node.js addons in [Zig](https://ziglang.org/) — the Zig equivalent of
[napi-rs](https://napi.rs/) for Rust.

You write plain Zig functions, register them with one comptime call, and `zigbind`
produces a `.node` addon that Node can `require()` directly. No `node-gyp`, no C glue.

```zig
const zigbind = @import("zigbind");

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

comptime {
    zigbind.register(.{ .add = add });
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
zigbind/
├── native/                 # the Zig library (a Zig package, NOT an npm package)
│   ├── src/                # zigbind.zig, napi.zig, convert.zig, async.zig, register.zig
│   └── vendor/             # vendored N-API headers (node-api-headers)
├── packages/zigbind/       # the `zigbind` CLI (npm package): `new` + `build`
└── playground/             # example addon exercising the whole pipeline
```

## Try it

```sh
pnpm install
pnpm --filter playground build   # compiles the addon via the zigbind CLI
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
