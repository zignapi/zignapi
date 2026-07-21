const zignapi = @import("zignapi");

/// Exposed to JS as `addon.add(a, b)`.
pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

// Emits `napi_register_module_v1`, the entry point Node calls when it loads the
// `.node` file. Each field becomes a property on the addon's `exports`.
comptime {
    zignapi.register(.{
        .add = add,
    });
}
