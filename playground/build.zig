const std = @import("std");

/// Builds the example addon into `zig-out/lib/addon.node`.
///
/// The addon is a dynamic library that imports the `zigbind` module (resolved
/// from `../native` via `build.zig.zon`). N-API symbols are intentionally left
/// undefined at link time and resolved by Node when it loads the addon.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigbind = b.dependency("zigbind", .{}).module("zigbind");

    const addon = b.addLibrary(.{
        .name = "addon",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "zigbind", .module = zigbind },
            },
        }),
    });

    // Let N-API symbols stay undefined; Node resolves them at load time. This
    // is the portable equivalent of macOS `-undefined dynamic_lookup`.
    addon.linker_allow_shlib_undefined = true;

    // Install the dynamic library renamed to `addon.node` under zig-out/lib.
    const install = b.addInstallFileWithDir(addon.getEmittedBin(), .lib, "addon.node");
    b.getInstallStep().dependOn(&install.step);
}
