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

    // The wndw module — this is what consumers `@import("wndw")`.
    const mod = b.addModule("wndw", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ── Platform linking ──────────────────────────────────────────────────────
    // No C source files — the backend uses pure `extern fn` declarations.
    // Each platform branch links the necessary system frameworks/libraries.
    switch (target.result.os.tag) {
        .macos => {
            // Cocoa.framework bundles libobjc + AppKit + CoreGraphics +
            // CoreFoundation. That's everything we need for the ObjC runtime
            // calls in src/platform/macos/.
            //
            // addSystemFrameworkPath is linker-only — it does NOT add SDK
            // headers to any C compiler include path (there are no C files),
            // so the libDER/DERItem.h SDK bug cannot occur.
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

    // ── Demo runner ──────────────────────────────────────────────────────────
    // `zig build run` compiles and runs `demo.zig` by default.
    // `zig build run -- gl_demo` compiles and runs `gl_demo.zig`.
    // The demo file gets the wndw module as an import.
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
    // Two test targets:
    //   1. Module tests — tests embedded in the wndw module itself.
    //   2. Unit tests — the dedicated test suite in src/tests.zig, which
    //      imports all src/tests/*.zig files. These are kept in a separate
    //      module so they can use relative imports from src/ without escaping
    //      the module boundary.
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
}

/// Locate the macOS SDK without shelling out to `xcrun`.
/// Checks the `SDKROOT` environment variable first, then falls back to
/// the standard Xcode command-line tools path.
fn macOSSdkPath(b: *std.Build) ?[]const u8 {
    if (b.graph.environ_map.get("SDKROOT")) |p| return p;
    const default = "/Applications/Xcode.app/Contents/Developer/Platforms/" ++
        "MacOSX.platform/Developer/SDKs/MacOSX.sdk";
    return default;
}
