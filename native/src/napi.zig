//! Raw N-API bindings and thin wrappers.
//!
//! The N-API C headers are vendored under `vendor/node-api-headers/` and pulled
//! in here with `@cImport`. Everything the rest of the library needs from the C
//! API is re-exported through `c`, plus a few ergonomic wrappers so the comptime
//! machinery in `convert.zig` / `register.zig` doesn't have to spell out the raw
//! `napi_status` dance every time.

const std = @import("std");

/// The imported N-API C API. We pin `NAPI_VERSION` to 8 (Node >= 18) so the
/// headers expose exactly the surface we support.
pub const c = @cImport({
    @cDefine("NAPI_VERSION", "8");
    @cInclude("node_api.h");
});

// Convenience aliases for the handful of opaque handles we pass around.
pub const Env = c.napi_env;
pub const Value = c.napi_value;
pub const CallbackInfo = c.napi_callback_info;
pub const Callback = c.napi_callback;
pub const Status = c.napi_status;

/// A call into the N-API C API returned a non-`napi_ok` status.
pub const Error = error{NapiFailure};

/// Turn a `napi_status` into a Zig error. `napi_ok` is `0`.
pub fn check(status: Status) Error!void {
    if (status != c.napi_ok) return Error.NapiFailure;
}

/// Throw a JavaScript `Error` with the given message and return control to JS.
/// `msg` must be a null-terminated string. Used to surface Zig error unions.
pub fn throwError(env: Env, msg: [:0]const u8) void {
    _ = c.napi_throw_error(env, null, msg.ptr);
}

/// Read the arguments of the current call into `argv`, returning the actual
/// argument count reported by N-API.
pub fn getCallbackInfo(
    env: Env,
    info: CallbackInfo,
    argv: []Value,
) Error!usize {
    var argc: usize = argv.len;
    const argv_ptr: [*c]Value = if (argv.len == 0) null else argv.ptr;
    try check(c.napi_get_cb_info(env, info, &argc, argv_ptr, null, null));
    return argc;
}

/// Attach `value` to `object` under the (null-terminated) property `name`.
pub fn setNamedProperty(env: Env, object: Value, name: [:0]const u8, value: Value) Error!void {
    try check(c.napi_set_named_property(env, object, name.ptr, value));
}

/// Create a JS function backed by the native callback `cb`, named `name`.
pub fn createFunction(env: Env, name: [:0]const u8, cb: Callback) Error!Value {
    var result: Value = undefined;
    try check(c.napi_create_function(env, name.ptr, name.len, cb, null, &result));
    return result;
}

/// Create a JS UTF-8 string from a Zig slice.
pub fn createString(env: Env, s: []const u8) Error!Value {
    var result: Value = undefined;
    try check(c.napi_create_string_utf8(env, s.ptr, s.len, &result));
    return result;
}

/// The JS `undefined` value.
pub fn getUndefined(env: Env) Error!Value {
    var result: Value = undefined;
    try check(c.napi_get_undefined(env, &result));
    return result;
}

/// Create a JS `Error` object carrying `msg` (used to reject promises).
pub fn createError(env: Env, msg: []const u8) Error!Value {
    const message = try createString(env, msg);
    var result: Value = undefined;
    try check(c.napi_create_error(env, null, message, &result));
    return result;
}
