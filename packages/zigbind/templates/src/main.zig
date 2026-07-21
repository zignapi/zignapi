const zigbind = @import("zigbind");

/// Exposed to JS as `addon.add(a, b)`.
pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

/// Exposed to JS as `addon.greet(name)`.
pub fn greet(name: []const u8) []const u8 {
    _ = name;
    return "hello from Zig";
}

// Emits `napi_register_module_v1`. Each field becomes a property on the addon's
// `exports`. Add your own Zig functions here.
comptime {
    zigbind.register(.{
        .add = add,
        .greet = greet,
    });
}
