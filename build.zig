const std = @import("std");

const RgfwOptions = struct {
    debug: bool,
    opengl: bool,
    native: bool,
    vulkan: bool,
    directx: bool,
    webgpu: bool,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const rgfw_options = RgfwOptions{
        .debug = b.option(bool, "rgfw_debug", "Enable RGFW debug logging") orelse false,
        .opengl = b.option(bool, "rgfw_opengl", "Enable RGFW OpenGL API helpers") orelse false,
        .native = b.option(bool, "rgfw_native", "Expose RGFW native backend structs in the bindings") orelse false,
        .vulkan = b.option(bool, "rgfw_vulkan", "Enable RGFW Vulkan API helpers (requires Vulkan SDK)") orelse false,
        .directx = b.option(bool, "rgfw_directx", "Enable RGFW DirectX API helpers (Windows only)") orelse false,
        .webgpu = b.option(bool, "rgfw_webgpu", "Enable RGFW WebGPU API helpers") orelse false,
    };

    const mod = b.addModule("wndw", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const write_files = b.addWriteFiles();
    const rgfw_impl = write_files.add("rgfw_impl.c",
        \\#define RGFW_IMPLEMENTATION
        \\#include "RGFW.h"
    );

    configureRgfw(b, mod, target, rgfw_options, rgfw_impl);

    const lib = b.addLibrary(.{
        .name = "wndw",
        .linkage = .static,
        .root_module = mod,
    });
    b.installArtifact(lib);

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}

fn configureRgfw(
    b: *std.Build,
    mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    options: RgfwOptions,
    implementation_file: std.Build.LazyPath,
) void {
    mod.addIncludePath(b.path("vendor/rgfw"));
    mod.addCSourceFile(.{
        .file = implementation_file,
        .flags = &.{"-std=c99"},
    });

    if (options.debug) {
        mod.addCMacro("RGFW_DEBUG", "1");
    }
    if (options.opengl) {
        mod.addCMacro("RGFW_OPENGL", "1");
    }
    if (options.native) {
        mod.addCMacro("RGFW_NATIVE", "1");
    }
    if (options.vulkan) {
        mod.addCMacro("RGFW_VULKAN", "1");
    }
    if (options.directx) {
        mod.addCMacro("RGFW_DIRECTX", "1");
    }
    if (options.webgpu) {
        mod.addCMacro("RGFW_WEBGPU", "1");
    }

    switch (target.result.os.tag) {
        .windows => {
            mod.linkSystemLibrary("gdi32", .{});
            mod.linkSystemLibrary("user32", .{});
            mod.linkSystemLibrary("shell32", .{});
            mod.linkSystemLibrary("advapi32", .{});
            if (options.opengl) {
                mod.linkSystemLibrary("opengl32", .{});
            }
            if (options.vulkan) {
                mod.linkSystemLibrary("vulkan-1", .{});
            }
            if (options.directx) {
                mod.linkSystemLibrary("dxgi", .{});
            }
        },
        .macos => {
            mod.linkFramework("Cocoa", .{});
            mod.linkFramework("CoreVideo", .{});
            mod.linkFramework("IOKit", .{});
            if (options.opengl) {
                mod.linkFramework("OpenGL", .{});
            }
            if (options.vulkan) {
                mod.linkSystemLibrary("vulkan", .{});
            }
        },
        .linux, .freebsd, .openbsd, .netbsd, .dragonfly, .illumos => {
            mod.linkSystemLibrary("X11", .{});
            mod.linkSystemLibrary("Xrandr", .{});
            mod.linkSystemLibrary("dl", .{});
            mod.linkSystemLibrary("pthread", .{});
            mod.linkSystemLibrary("m", .{});
            if (options.opengl) {
                mod.linkSystemLibrary("GL", .{});
            }
            if (options.vulkan) {
                mod.linkSystemLibrary("vulkan", .{});
            }
        },
        else => {},
    }
}
