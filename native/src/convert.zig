//! Comptime conversions between Zig values and JavaScript values.
//!
//! Every function is generic over the Zig type and dispatches on `@typeInfo`
//! at comptime, so a wrapper compiled for `fn (i32, i32) i32` only ever emits
//! the `int32` code paths. Supported types: `i32`/`u32`/`i64`/... (any int),
//! `f16`/`f32`/`f64` (any float), `bool`, and `[]const u8` (UTF-8 strings).

const std = @import("std");
const napi = @import("napi.zig");
const c = napi.c;

/// The JS-representable category a Zig type maps onto. Kept as a plain enum
/// (rather than `@compileError` inline) so the classification is unit-testable
/// at comptime without touching the N-API runtime.
pub const Kind = enum { int, float, bool, string, unsupported };

/// Classify a Zig type. `.unsupported` means there is no JS mapping for it.
pub fn classify(comptime T: type) Kind {
    return switch (@typeInfo(T)) {
        .int => .int,
        .float => .float,
        .bool => .bool,
        .pointer => |p| if (p.size == .slice and p.child == u8 and p.is_const)
            .string
        else
            .unsupported,
        else => .unsupported,
    };
}

/// Compile-time guard that fails with a readable message for unsupported types.
fn assertSupported(comptime T: type) void {
    if (classify(T) == .unsupported) {
        @compileError("zignapi: unsupported type '" ++ @typeName(T) ++
            "' (supported: integers, floats, bool, []const u8)");
    }
}

/// Read a JavaScript `value` into a Zig value of type `T`.
///
/// `allocator` is only used for `[]const u8` results (the bytes are copied out
/// of V8). Callers own the returned slice's lifetime through that allocator.
pub fn fromJs(comptime T: type, env: napi.Env, value: napi.Value, allocator: std.mem.Allocator) !T {
    comptime assertSupported(T);
    return switch (comptime classify(T)) {
        .int => blk: {
            const info = @typeInfo(T).int;
            if (info.signedness == .unsigned and info.bits <= 32) {
                var out: u32 = undefined;
                try napi.check(c.napi_get_value_uint32(env, value, &out));
                break :blk @intCast(out);
            } else if (info.signedness == .signed and info.bits <= 32) {
                var out: i32 = undefined;
                try napi.check(c.napi_get_value_int32(env, value, &out));
                break :blk @intCast(out);
            } else {
                var out: i64 = undefined;
                try napi.check(c.napi_get_value_int64(env, value, &out));
                break :blk @intCast(out);
            }
        },
        .float => blk: {
            var out: f64 = undefined;
            try napi.check(c.napi_get_value_double(env, value, &out));
            break :blk @floatCast(out);
        },
        .bool => blk: {
            var out: bool = undefined;
            try napi.check(c.napi_get_value_bool(env, value, &out));
            break :blk out;
        },
        .string => blk: {
            // First call with a null buffer to learn the byte length, then copy.
            var len: usize = 0;
            try napi.check(c.napi_get_value_string_utf8(env, value, null, 0, &len));
            const buf = try allocator.alloc(u8, len + 1);
            var written: usize = 0;
            try napi.check(c.napi_get_value_string_utf8(env, value, buf.ptr, buf.len, &written));
            break :blk buf[0..written];
        },
        .unsupported => unreachable,
    };
}

/// Create a JavaScript value from a Zig value of type `T`.
pub fn toJs(comptime T: type, env: napi.Env, value: T) !napi.Value {
    comptime assertSupported(T);
    var result: napi.Value = undefined;
    switch (comptime classify(T)) {
        .int => {
            const info = @typeInfo(T).int;
            if (info.signedness == .unsigned and info.bits <= 32) {
                try napi.check(c.napi_create_uint32(env, @intCast(value), &result));
            } else if (info.signedness == .signed and info.bits <= 32) {
                try napi.check(c.napi_create_int32(env, @intCast(value), &result));
            } else {
                try napi.check(c.napi_create_int64(env, @intCast(value), &result));
            }
        },
        .float => try napi.check(c.napi_create_double(env, @floatCast(value), &result)),
        .bool => try napi.check(c.napi_get_boolean(env, value, &result)),
        .string => try napi.check(c.napi_create_string_utf8(env, value.ptr, value.len, &result)),
        .unsupported => unreachable,
    }
    return result;
}

test "classify maps Zig types to JS kinds" {
    const expectEqual = std.testing.expectEqual;
    try expectEqual(Kind.int, classify(i32));
    try expectEqual(Kind.int, classify(u64));
    try expectEqual(Kind.float, classify(f64));
    try expectEqual(Kind.float, classify(f32));
    try expectEqual(Kind.bool, classify(bool));
    try expectEqual(Kind.string, classify([]const u8));
    // A mutable slice is intentionally *not* treated as a JS string.
    try expectEqual(Kind.unsupported, classify([]u8));
    try expectEqual(Kind.unsupported, classify(struct { x: i32 }));
}
