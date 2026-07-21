//! Build-only compile check (never shipped to consumers, not imported by
//! `zignapi.zig`). Building this as an *object* forces the whole comptime
//! pipeline — `register` → the per-function callback trampolines → `convert`
//! for every supported type, including an error union — to be analyzed, so
//! `zig build` in `native/` fails loudly on any API or type mistake. The
//! N-API symbols it references stay undefined in the object file; they are
//! resolved when a real addon links, exactly as in production.

const zignapi = @import("zignapi.zig");
const napi = zignapi.napi;

// Reference the concrete (non-generic) wrappers so they are compiled too.
comptime {
    _ = napi.check;
    _ = napi.throwError;
    _ = napi.getCallbackInfo;
    _ = napi.setNamedProperty;
    _ = napi.createFunction;
    _ = napi.createString;
    _ = napi.getUndefined;
    _ = napi.createError;
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}
fn negate(x: bool) bool {
    return !x;
}
fn scale(x: f64) f64 {
    return x * 2.0;
}
fn echo(s: []const u8) []const u8 {
    return s;
}
fn checked(x: i32) !i32 {
    return if (x < 0) error.MustBeNonNegative else x;
}

// Async: runs on the thread pool, returns a Promise.
fn heavy(a: i32, b: i32) i32 {
    return a * b;
}
fn heavyChecked(x: i32) !i32 {
    return if (x < 0) error.MustBeNonNegative else x;
}

// Raw passthrough: `napi.Env` / `napi.Value` params + a threadsafe function.
fn onEvent(env: napi.Env, callback: napi.Value) void {
    const tsfn = zignapi.ThreadsafeFunction(i32).create(env, callback) catch return;
    tsfn.call(1) catch {};
    tsfn.release();
}

comptime {
    zignapi.register(.{
        .add = add,
        .negate = negate,
        .scale = scale,
        .echo = echo,
        .checked = checked,
        .heavy = zignapi.asyncFn(heavy),
        .heavyChecked = zignapi.asyncFn(heavyChecked),
        .onEvent = onEvent,
    });
}
