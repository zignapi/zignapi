# __NAME__

A native Node.js addon written in [Zig](https://ziglang.org/) with
[zigbind](https://github.com/) — requires **Zig 0.16.0** and **Node >= 18**.

```sh
zignapi build      # compiles src/main.zig into __NAME__.node (and zig-out/lib/)
node --test        # runs test.js
```

Edit `src/main.zig` to add functions, then list them in the `zigbind.register`
call at the bottom of that file.

## The zigbind dependency

`zignapi new` added the `zigbind` Zig module to `build.zig.zon` with
`zig fetch --save`, which pins it by content hash:

```zig
.dependencies = .{
    .zigbind = .{ .url = "…", .hash = "zigbind-…" },
},
```

The `url` points at the zigbind sources on the machine where you scaffolded.
The content is cached globally by hash, so builds don't need that path again.
To share this project across machines/CI, re-point `url` at a hosted tarball
of the zigbind `native/` sources (the `hash` stays the same) with:

```sh
zig fetch --save=zigbind https://…/zigbind-native.tar.gz
```
