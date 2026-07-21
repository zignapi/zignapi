//! zignapi — write native Node.js addons in Zig.
//!
//! This is the public entry point of the Zig module consumers import with
//! `@import("zignapi")`. It re-exports the pieces an addon author needs:
//!
//!   - `register` : expose Zig functions to JS and emit `napi_register_module_v1`.
//!   - `napi`     : the raw N-API bindings and thin wrappers, for escape hatches.
//!   - `convert`  : the comptime Zig <-> JS value conversions.
//!   - `c`        : the imported N-API C API (`@cImport`), for advanced use.

const std = @import("std");

pub const napi = @import("napi.zig");
pub const convert = @import("convert.zig");
pub const typedefs = @import("typedefs.zig");
pub const async_ = @import("async.zig");

/// Register Zig functions as a Node addon. See `register.zig`.
pub const register = @import("register.zig").register;

/// The raw imported N-API C API (`napi_*` functions and types).
pub const c = napi.c;

test {
    // Pull every submodule into the test build so their comptime checks and
    // unit tests run with `zig build test`.
    std.testing.refAllDecls(@This());
    _ = napi;
    _ = convert;
    _ = async_;
    _ = @import("register.zig");
}
