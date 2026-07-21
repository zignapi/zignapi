# __NAME__

A native Node.js addon written in [Zig](https://ziglang.org/) with
[zigbind](https://github.com/) — requires **Zig 0.16.0** and **Node >= 18**.

```sh
zigbind build      # compiles src/main.zig into __NAME__.node (and zig-out/lib/)
node --test        # runs test.js
```

Edit `src/main.zig` to add functions, then list them in the `zigbind.register`
call at the bottom of that file.

> This project's `build.zig.zon` resolves the `zigbind` Zig module via
> `.path = "../native"`. It expects to live alongside the zigbind `native/`
> sources (i.e. scaffolded inside the zigbind monorepo). Adjust that path if you
> move the project elsewhere.
