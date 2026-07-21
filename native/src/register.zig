//! Module registration: turn a struct of `name = fn` pairs into the
//! `napi_register_module_v1` entry point Node looks up when it loads a `.node`.
//!
//! Usage from an addon's root source file:
//!
//! ```zig
//! const zignapi = @import("zignapi");
//! pub fn add(a: i32, b: i32) i32 { return a + b; }
//! comptime { zignapi.register(.{ .add = add }); }
//! ```

const std = @import("std");
const napi = @import("napi.zig");
const convert = @import("convert.zig");
const typedefs = @import("typedefs.zig");
const asyncwork = @import("async.zig");
const c = napi.c;

/// Export `napi_register_module_v1` for the given set of functions.
///
/// `defs` must be an anonymous struct literal whose field names become the JS
/// property names and whose field values are the Zig functions to expose.
/// Must be called from a `comptime {}` block at container scope so the `@export`
/// runs while building the module.
pub fn register(comptime defs: anytype) void {
    const Defs = @TypeOf(defs);
    switch (@typeInfo(Defs)) {
        .@"struct" => {},
        else => @compileError("zignapi.register expects a struct literal, e.g. .{ .add = add }"),
    }

    // TypeScript declarations for this module, generated at comptime and
    // embedded so `zignapi build` can emit `index.d.ts` / `index.js`.
    const dts = typedefs.declarations(defs);

    const Registrar = struct {
        fn entry(env: napi.Env, exports: napi.Value) callconv(.c) napi.Value {
            inline for (@typeInfo(Defs).@"struct".fields) |field| {
                registerField(env, exports, field.name, @field(defs, field.name)) catch {
                    napi.throwError(env, "zignapi: failed to register '" ++ field.name ++ "'");
                    return null;
                };
            }
            // Best-effort: attach the type declarations. Failure here must not
            // break a working module, so ignore errors.
            if (napi.createString(env, dts)) |v| {
                napi.setNamedProperty(env, exports, "__zignapi_dts__", v) catch {};
            } else |_| {}
            return exports;
        }
    };

    @export(&Registrar.entry, .{ .name = "napi_register_module_v1", .linkage = .strong });
}

/// Bind a single field onto `exports` under `name`. The field is either a plain
/// function (registered synchronously) or an `asyncFn(...)` marker (registered
/// as an async, promise-returning function).
fn registerField(
    env: napi.Env,
    exports: napi.Value,
    comptime name: [:0]const u8,
    comptime field_val: anytype,
) !void {
    const fn_value = try napi.createFunction(env, name, callbackFor(field_val));
    try napi.setNamedProperty(env, exports, name, fn_value);
}

fn callbackFor(comptime field_val: anytype) napi.Callback {
    const FieldT = @TypeOf(field_val);
    if (comptime asyncwork.isAsyncMarker(FieldT)) {
        return asyncwork.AsyncWrap(FieldT.func).callback;
    }
    return Wrap(field_val).callback;
}

/// Build the `napi_callback` trampoline for a specific Zig function.
///
/// Each distinct `func` produces its own type (and therefore its own callback),
/// which is how we smuggle the target function into the fixed C callback
/// signature without any runtime closure/state.
fn Wrap(comptime func: anytype) type {
    const fn_info = @typeInfo(@TypeOf(func)).@"fn";

    return struct {
        fn callback(env: napi.Env, info: napi.CallbackInfo) callconv(.c) napi.Value {
            // Collect the JS arguments (one slot per Zig parameter).
            var argv: [fn_info.params.len]napi.Value = undefined;
            _ = napi.getCallbackInfo(env, info, &argv) catch {
                napi.throwError(env, "zignapi: failed to read arguments");
                return null;
            };

            // String arguments are copied out of V8 into this arena, which is
            // freed once the call (and any return-value conversion) is done.
            var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
            defer arena.deinit();
            const allocator = arena.allocator();

            // Convert each argument from JS into its Zig type. `napi.Env` and
            // `napi.Value` parameters are passed through raw and don't consume a
            // JS argument (like napi-rs's `Env`), so track the JS index separately.
            var args: std.meta.ArgsTuple(@TypeOf(func)) = undefined;
            comptime var js_arg: usize = 0;
            inline for (fn_info.params, 0..) |param, i| {
                const P = param.type.?;
                if (P == napi.Env) {
                    args[i] = env;
                } else if (P == napi.Value) {
                    args[i] = argv[js_arg];
                    js_arg += 1;
                } else {
                    args[i] = convert.fromJs(P, env, argv[js_arg], allocator) catch {
                        napi.throwError(env, "zignapi: failed to convert argument");
                        return null;
                    };
                    js_arg += 1;
                }
            }

            const result = @call(.auto, func, args);
            return finish(env, fn_info.return_type.?, result);
        }

        /// Convert the Zig return value to JS, turning `!T` error unions into
        /// thrown JS exceptions and `void` into `undefined`.
        fn finish(env: napi.Env, comptime RetType: type, result: RetType) napi.Value {
            switch (@typeInfo(RetType)) {
                .error_union => |eu| {
                    const payload = result catch |err| {
                        napi.throwError(env, @errorName(err));
                        return null;
                    };
                    return toJs(env, eu.payload, payload);
                },
                .void => return null,
                else => return toJs(env, RetType, result),
            }
        }

        fn toJs(env: napi.Env, comptime T: type, value: T) napi.Value {
            return convert.toJs(T, env, value) catch {
                napi.throwError(env, "zignapi: failed to convert return value");
                return null;
            };
        }
    };
}
