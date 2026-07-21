const std = @import("std");
const zignapi = @import("zignapi");
const napi = zignapi.napi;

/// Sync — exposed to JS as `addon.add(a, b)`.
pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

/// Async — runs on libuv's thread pool and resolves a `Promise<number>`.
fn multiplySlow(a: i32, b: i32) i32 {
    return a * b;
}

/// Async that can reject: a Zig error becomes a rejected promise.
fn failing(x: i32) !i32 {
    return if (x < 0) error.MustBeNonNegative else x;
}

/// Threadsafe: call the JS `callback` with 1..n from a spawned worker thread.
/// `env` is passed through raw and isn't a JS argument.
fn countTo(env: napi.Env, n: i32, callback: napi.Value) void {
    const tsfn = zignapi.ThreadsafeFunction(i32).create(env, callback) catch return;
    const worker = std.Thread.spawn(.{}, countWorker, .{ tsfn, n }) catch {
        tsfn.release();
        return;
    };
    worker.detach();
}

fn countWorker(tsfn: zignapi.ThreadsafeFunction(i32), n: i32) void {
    var i: i32 = 1;
    while (i <= n) : (i += 1) tsfn.call(i) catch {};
    tsfn.release();
}

comptime {
    zignapi.register(.{
        .add = add,
        .multiplySlow = zignapi.asyncFn(multiplySlow),
        .failing = zignapi.asyncFn(failing),
        .countTo = countTo,
    });
}
