const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("wndw", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ── Platform linking ──────────────────────────────────────────────────────
    // No C source files — pure extern fn declarations only.
    // Adding a new platform = one new branch here.
    switch (target.result.os.tag) {
        .macos => {
            // Cocoa bundles libobjc; linking it is sufficient for the ObjC
            // runtime + AppKit symbols used in src/platform/macos/.
            // addSystemFrameworkPath is linker-only — it does NOT add the SDK
            // path to any C compiler include path (there are no C files here),
            // so the libDER/DERItem.h error that affected the RGFW build cannot
            // occur.
            if (b.sysroot == null) {
                if (macOSSdkPath(b)) |sdk| {
                    mod.addSystemFrameworkPath(.{ .cwd_relative = b.fmt("{s}/System/Library/Frameworks", .{sdk}) });
                    mod.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/usr/lib", .{sdk}) });
                }
            }
            mod.linkFramework("Cocoa", .{});
        },
        // .windows => { mod.linkSystemLibrary("user32", .{}); ... },
        // .linux   => { mod.linkSystemLibrary("X11", .{}); ... },
        else => {},
    }

    // ── Library artifact ──────────────────────────────────────────────────────
    const lib = b.addLibrary(.{
        .name = "wndw",
        .linkage = .static,
        .root_module = mod,
    });
    b.installArtifact(lib);

    // ── Demo runner: `zig build run -- <name>` ────────────────────────────────
    // Defaults to "demo" if no argument is provided.
    const demo_name = if (b.args) |args|
        if (args.len > 0) args[0] else "demo"
    else
        "demo";

    const demo_mod = b.createModule(.{
        .root_source_file = b.path(b.fmt("{s}.zig", .{demo_name})),
        .target = target,
        .optimize = optimize,
    });
    demo_mod.addImport("wndw", mod);

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

    // Unit tests — rooted at src/tests.zig so all src/tests/*.zig files share
    // the src/ module root and can import siblings via relative "../" paths.
    const unit_test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const unit_tests = b.addTest(.{ .root_module = unit_test_mod });
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);
}

/// Returns the macOS SDK root without relying on xcrun.
/// Checks SDKROOT env var first, then falls back to the standard Xcode path.
fn macOSSdkPath(b: *std.Build) ?[]const u8 {
    if (b.graph.environ_map.get("SDKROOT")) |p| return p;
    const default = "/Applications/Xcode.app/Contents/Developer/Platforms/" ++
        "MacOSX.platform/Developer/SDKs/MacOSX.sdk";
    return default;
}
