/// Build configuration for the wndw windowing library.
///
/// Produces a static library (`libwndw.a`) and provides:
///   - `zig build`          — build the library
///   - `zig build test`     — run all unit tests
///   - `zig build run`      — run the default demo (`demo.zig`)
///   - `zig build run -- X` — run a named demo (`X.zig`)
///
/// Platform linking is handled per-OS. Currently only macOS is implemented;
/// adding a new platform means adding a branch to the switch below.
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ── Shared render types ──────────────────────────────────────────────────
    // QuadCmd, ClipCmd — the leaf of the dependency tree. Imported by both
    // the wndw module (platform renderer) and the ui module (draw list).
    const render_types_mod = b.createModule(.{
        .root_source_file = b.path("src/ui/render/types.zig"),
        .target = target,
        .optimize = optimize,
    });

    // The wndw module — this is what consumers `@import("wndw")`.
    const mod = b.addModule("wndw", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.addImport("render_types", render_types_mod);

    // ── Platform linking ──────────────────────────────────────────────────────
    // No C source files — the backend uses pure `extern fn` declarations.
    // Each platform branch links the necessary system frameworks/libraries.
    switch (target.result.os.tag) {
        .macos => {
            if (b.sysroot == null) {
                if (macOSSdkPath(b)) |sdk| {
                    mod.addSystemFrameworkPath(.{ .cwd_relative = b.fmt("{s}/System/Library/Frameworks", .{sdk}) });
                    mod.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/usr/lib", .{sdk}) });
                }
            }
            mod.linkFramework("Cocoa", .{});
            mod.linkFramework("Carbon", .{});
            mod.linkFramework("CoreVideo", .{});
            mod.linkFramework("CoreText", .{});
        },
        else => {},
    }

    // ── UI module ─────────────────────────────────────────────────────────────
    // Platform-agnostic element tree, style, layout, and draw commands.
    // Imports the Renderer type from the wndw module (which dispatches to
    // the platform-specific implementation at comptime).
    const ui_mod = b.addModule("ui", .{
        .root_source_file = b.path("src/ui/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    ui_mod.addImport("wndw", mod);
    ui_mod.addImport("render_types", render_types_mod);

    // ── Library artifact ──────────────────────────────────────────────────────
    const lib = b.addLibrary(.{
        .name = "wndw",
        .linkage = .static,
        .root_module = mod,
    });
    b.installArtifact(lib);

    // ── Demo runner ──────────────────────────────────────────────────────────
    const raw_name: []const u8 = if (b.args) |args|
        if (args.len > 0) args[0] else "demo"
    else
        "demo";

    for (raw_name) |c| {
        if (c == '/' or c == '\\') @panic("demo name must not contain path separators");
    }
    if (std.mem.indexOf(u8, raw_name, "..") != null) @panic("demo name must not contain '..'");
    const demo_name = raw_name;

    const demo_mod = b.createModule(.{
        .root_source_file = b.path(b.fmt("{s}.zig", .{demo_name})),
        .target = target,
        .optimize = optimize,
    });
    demo_mod.addImport("wndw", mod);
    demo_mod.addImport("ui", ui_mod);

    const demo_exe = b.addExecutable(.{
        .name = demo_name,
        .root_module = demo_mod,
    });

    const run_cmd = b.addRunArtifact(demo_exe);
    if (b.args) |args| {
        if (args.len > 1) run_cmd.addArgs(args[1..]);
    }

    const run_step = b.step("run", "Run a demo (e.g. `zig build run -- demo`)");
    run_step.dependOn(&run_cmd.step);

    // ── Tests ─────────────────────────────────────────────────────────────────
    const mod_tests = b.addTest(.{ .root_module = mod });
    const run_tests = b.addRunArtifact(mod_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    const unit_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const unit_tests = b.addTest(.{ .root_module = unit_test_mod });
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);

    // UI tests — imports the ui module (which pulls in wndw + render_types).
    const ui_test_mod = b.createModule(.{
        .root_source_file = b.path("src/ui/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    ui_test_mod.addImport("wndw", mod);
    ui_test_mod.addImport("render_types", render_types_mod);
    const ui_tests = b.addTest(.{ .root_module = ui_test_mod });
    test_step.dependOn(&b.addRunArtifact(ui_tests).step);
}

/// Locate the macOS SDK without shelling out to `xcrun`.
fn macOSSdkPath(b: *std.Build) ?[]const u8 {
    if (b.graph.environ_map.get("SDKROOT")) |p| return p;
    const default = "/Applications/Xcode.app/Contents/Developer/Platforms/" ++
        "MacOSX.platform/Developer/SDKs/MacOSX.sdk";
    return default;
}
