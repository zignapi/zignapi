//! Comptime generation of TypeScript declarations for the registered functions.
//!
//! The mapping reuses `convert.classify`, so the `.d.ts` and the runtime
//! conversions can never drift apart. `register.zig` embeds the produced string
//! in the addon (as the `__zignapi_dts__` export); `zignapi build` reads it back
//! and writes `index.d.ts` / `index.js`.

const std = @import("std");
const convert = @import("convert.zig");

/// The TypeScript type string for a Zig type. Error unions map to their payload
/// (Zig errors surface as thrown JS exceptions, which don't appear in the type);
/// `void` maps to `void`.
pub fn tsType(comptime T: type) []const u8 {
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
/// Parameter names aren't available from `@typeInfo`, so they're `arg0`, `arg1`, …
pub fn declarations(comptime defs: anytype) []const u8 {
    comptime var out: []const u8 = "";
    inline for (@typeInfo(@TypeOf(defs)).@"struct".fields) |field| {
        const fn_info = @typeInfo(@TypeOf(@field(defs, field.name))).@"fn";
        comptime var params: []const u8 = "";
        inline for (fn_info.params, 0..) |param, i| {
            const sep = if (i == 0) "" else ", ";
            params = params ++ sep ++ std.fmt.comptimePrint(
                "arg{d}: {s}",
                .{ i, tsType(param.type.?) },
            );
        }
        out = out ++ "export function " ++ field.name ++ "(" ++ params ++
            "): " ++ tsType(fn_info.return_type.?) ++ ";\n";
    }
    return out;
}

test "declarations render one export per function" {
    const S = struct {
        fn add(a: i32, b: i32) i32 {
            return a + b;
        }
        fn greet(name: []const u8) []const u8 {
            return name;
        }
        fn toggle(x: bool) bool {
            return !x;
        }
        fn checked(x: i32) !i32 {
            return x;
        }
    };
    const dts = comptime declarations(.{
        .add = S.add,
        .greet = S.greet,
        .toggle = S.toggle,
        .checked = S.checked,
    });
    try std.testing.expectEqualStrings(
        \\export function add(arg0: number, arg1: number): number;
        \\export function greet(arg0: string): string;
        \\export function toggle(arg0: boolean): boolean;
        \\export function checked(arg0: number): number;
        \\
    , dts);
}
