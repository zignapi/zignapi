const std = @import("std");

/// Build script for the `zignapi` Zig library.
///
/// This is a Zig package, not an npm package. Its main product is the Zig
/// module named "zignapi" (exposed via `b.addModule`), which addons import to
/// register their functions with Node. Building here also runs two local
/// checks so `zig build` in this directory validates the library on its own:
///
///   - a compile check (`src/_check.zig` built as an object) that exercises the
///     full comptime pipeline for every supported type, and
///   - `zig build test`, the pure-comptime unit tests in `src/convert.zig`.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const headers = b.path("vendor/node-api-headers");

    // The module consumers import as `@import("zignapi")`. It links libc (for
    // the C allocator used to marshal string arguments, and to make the N-API
    // headers available to `@cImport`). Target/optimize are left unset here so
    // each consumer picks them; the include path travels with the module.
    const mod = b.addModule("zignapi", .{
        .root_source_file = b.path("src/zignapi.zig"),
        .link_libc = true,
    });
    mod.addIncludePath(headers);

    // Standalone compile check. Built as an object, so the still-undefined
    // N-API symbols are fine (they resolve when a real addon links). Failing
    // to compile any of the conversion/registration code fails `zig build`.
    const check_mod = b.createModule(.{
        .root_source_file = b.path("src/_check.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    check_mod.addIncludePath(headers);
    const check_obj = b.addObject(.{
        .name = "zignapi-check",
        .root_module = check_mod,
    });
    b.getInstallStep().dependOn(&check_obj.step);

    // Unit tests: only the pure-comptime conversions (no N-API runtime calls),
    // so the test binary links without Node present.
    const tests_mod = b.createModule(.{
        .root_source_file = b.path("src/convert.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    tests_mod.addIncludePath(headers);
    const unit_tests = b.addTest(.{ .root_module = tests_mod });
    const run_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run zignapi unit tests");
    test_step.dependOn(&run_tests.step);
}
