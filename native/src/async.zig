//! Async support — stub.
//!
//! TODO: wrap `napi_create_async_work` / `napi_queue_async_work` so that Zig
//! functions returning something awaitable (or explicitly marked async) run on
//! libuv's thread pool and resolve a JS `Promise` via `napi_create_promise` /
//! `napi_resolve_deferred`. Nothing here is wired into `register.zig` yet;
//! today every exported function runs synchronously on the JS thread.

const std = @import("std");

comptime {
    // Keep this file referenced so it participates in compilation checks even
    // while it is only a placeholder.
    std.debug.assert(true);
}
