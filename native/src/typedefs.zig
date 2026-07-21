//! Comptime generation of TypeScript declarations for the registered functions.
//!
//! The mapping reuses `convert.classify`, so the `.d.ts` and the runtime
//! conversions can never drift apart. `register.zig` embeds the produced string
//! in the addon (as the `__zignapi_dts__` export); `zignapi build` reads it back
//! and writes `index.d.ts` / `index.js`.

const std = @import("std");
const napi = @import("napi.zig");
const convert = @import("convert.zig");
const asyncwork = @import("async.zig");

/// The TypeScript type string for a Zig type. `napi.Value` (a raw JS handle,
/// e.g. a callback) maps to `any`; error unions map to their payload (Zig
/// errors surface as thrown JS exceptions); `void` maps to `void`.
pub fn tsType(comptime T: type) []const u8 {
    if (T == napi.Value) return "any";
    return switch (@typeInfo(T)) {
        .void => "void",
        .error_union => |eu| tsType(eu.payload),
        else => switch (convert.classify(T)) {
            .int, .float => "number",
            .bool => "boolean",
            .string => "string",
            .unsupported => @compileError(
                "zignapi: no TypeScript mapping for '" ++ @typeName(T) ++ "'",
            ),
        },
    };
}

/// Build the `.d.ts` body: one `export function` line per registered function.
/// `napi.Env` parameters are skipped (they aren't JS arguments); `asyncFn`
/// functions return `Promise<T>`. Parameter names are `arg0`, `arg1`, …
pub fn declarations(comptime defs: anytype) []const u8 {
    comptime var out: []const u8 = "";
    inline for (@typeInfo(@TypeOf(defs)).@"struct".fields) |field| {
        const field_val = @field(defs, field.name);
        const is_async = asyncwork.isAsyncMarker(@TypeOf(field_val));
        const func = if (is_async) @TypeOf(field_val).func else field_val;
        const fn_info = @typeInfo(@TypeOf(func)).@"fn";

        comptime var params: []const u8 = "";
        comptime var js_i: usize = 0;
        inline for (fn_info.params) |param| {
            const P = param.type.?;
            if (P == napi.Env) continue; // not a JS argument
            const sep = if (js_i == 0) "" else ", ";
            params = params ++ sep ++ std.fmt.comptimePrint("arg{d}: {s}", .{ js_i, tsType(P) });
            js_i += 1;
        }

        const ret = tsType(fn_info.return_type.?);
        const ret_str = if (is_async) "Promise<" ++ ret ++ ">" else ret;
        out = out ++ "export function " ++ field.name ++ "(" ++ params ++ "): " ++ ret_str ++ ";\n";
    }
    return out;
}

test "declarations render sync, async and passthrough signatures" {
    const S = struct {
        fn add(a: i32, b: i32) i32 {
            return a + b;
        }
        fn greet(name: []const u8) []const u8 {
            return name;
        }
        fn heavy(a: i32, b: i32) i32 {
            return a * b;
        }
        fn onEvent(env: napi.Env, cb: napi.Value) void {
            _ = env;
            _ = cb;
        }
    };
    const dts = comptime declarations(.{
        .add = S.add,
        .greet = S.greet,
        .heavy = asyncwork.asyncFn(S.heavy),
        .onEvent = S.onEvent,
    });
    try std.testing.expectEqualStrings(
        \\export function add(arg0: number, arg1: number): number;
        \\export function greet(arg0: string): string;
        \\export function heavy(arg0: number, arg1: number): Promise<number>;
        \\export function onEvent(arg0: any): void;
        \\
    , dts);
}
