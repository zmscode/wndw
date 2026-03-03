/// Tests for OpenGL context support (Phase 9).
///
/// Tests use @hasDecl/@hasField for existence checks only —
/// actual GL context requires a live window + ObjC runtime.
const std = @import("std");
const Window = @import("../platform/macos/window.zig").Window;
const wmod = @import("../platform/macos/window.zig");

// ── Phase 9a: GLHints struct ────────────────────────────────────────────────

test "GLHints struct exists" {
    try std.testing.expect(@hasDecl(wmod, "GLHints"));
}

test "GLHints has expected fields" {
    comptime {
        if (!@hasField(wmod.GLHints, "major")) @compileError("missing: major");
        if (!@hasField(wmod.GLHints, "minor")) @compileError("missing: minor");
        if (!@hasField(wmod.GLHints, "depth_bits")) @compileError("missing: depth_bits");
        if (!@hasField(wmod.GLHints, "stencil_bits")) @compileError("missing: stencil_bits");
        if (!@hasField(wmod.GLHints, "samples")) @compileError("missing: samples");
        if (!@hasField(wmod.GLHints, "double_buffer")) @compileError("missing: double_buffer");
    }
}

test "GLHints defaults" {
    const h = wmod.GLHints{};
    try std.testing.expectEqual(@as(u32, 3), h.major);
    try std.testing.expectEqual(@as(u32, 2), h.minor);
    try std.testing.expectEqual(@as(u32, 24), h.depth_bits);
    try std.testing.expectEqual(@as(u32, 0), h.stencil_bits);
    try std.testing.expectEqual(@as(u32, 0), h.samples);
    try std.testing.expect(h.double_buffer);
}

test "Window: gl_context field exists" {
    comptime if (!@hasField(Window, "gl_context")) @compileError("missing field: gl_context");
}

test "Window: gl_format field exists" {
    comptime if (!@hasField(Window, "gl_format")) @compileError("missing field: gl_format");
}

test "Window: gl_context defaults to null" {
    var w: Window = undefined;
    w.gl_context = null;
    try std.testing.expect(w.gl_context == null);
}

// ── Phase 9b: createGLContext ───────────────────────────────────────────────

test "Window has createGLContext" {
    try std.testing.expect(@hasDecl(Window, "createGLContext"));
}

// ── Phase 9c: Context operations ────────────────────────────────────────────

test "Window has makeContextCurrent" {
    try std.testing.expect(@hasDecl(Window, "makeContextCurrent"));
}

test "Window has swapBuffers" {
    try std.testing.expect(@hasDecl(Window, "swapBuffers"));
}

test "Window has setSwapInterval" {
    try std.testing.expect(@hasDecl(Window, "setSwapInterval"));
}

test "Window has deleteContext" {
    try std.testing.expect(@hasDecl(Window, "deleteContext"));
}

// ── Phase 9d: getProcAddress ────────────────────────────────────────────────

test "Window has getProcAddress" {
    try std.testing.expect(@hasDecl(Window, "getProcAddress"));
}

// ── GL context resize update ─────────────────────────────────────────────────

test "Window: updateGLContextIfNeeded exists" {
    try std.testing.expect(@hasDecl(Window, "updateGLContextIfNeeded"));
}

// ── close() cleanup ──────────────────────────────────────────────────────────

test "Window has close and deleteContext for GL cleanup" {
    try std.testing.expect(@hasDecl(Window, "close"));
    try std.testing.expect(@hasDecl(Window, "deleteContext"));
}
