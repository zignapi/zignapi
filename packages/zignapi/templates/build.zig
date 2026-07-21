const std = @import("std");

/// Builds the addon into `zig-out/lib/__NAME__.node`.
///
/// The addon is a dynamic library importing the `zignapi` module. N-API symbols
/// are left undefined at link time and resolved by Node when it loads the addon.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zignapi = b.dependency("zignapi", .{}).module("zignapi");

    const addon = b.addLibrary(.{
        .name = "__NAME__",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "zignapi", .module = zignapi },
            },
        }),
    });

    // Portable equivalent of macOS `-undefined dynamic_lookup`: let N-API
    // symbols stay undefined so Node resolves them when it loads the addon.
    addon.linker_allow_shlib_undefined = true;

    const install = b.addInstallFileWithDir(addon.getEmittedBin(), .lib, "__NAME__.node");
    b.getInstallStep().dependOn(&install.step);
}
