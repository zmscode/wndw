/// Tests for zgl-compatible OpenGL loader integration.
///
/// Verifies that `Window.FnPtr` and `Window.glGetProcAddress` have the
/// exact types that zgl's `loadExtensions()` expects, so users can write:
///
///   try gl.loadExtensions(&win, wndw.Window.glGetProcAddress);
///
const std = @import("std");
const root = @import("../root.zig");
const Window = root.Window;

// ── FnPtr type ───────────────────────────────────────────────────────────────

test "Window exports FnPtr type" {
    comptime {
        if (!@hasDecl(Window, "FnPtr")) @compileError("missing: FnPtr");
    }
}

test "FnPtr alignment matches zgl expectation" {
    const expected_align = @alignOf(fn (u32) callconv(.c) u32);
    const actual_align = @typeInfo(Window.FnPtr).pointer.alignment;
    try std.testing.expectEqual(expected_align, actual_align);
}

test "FnPtr is pointer to const anyopaque" {
    const info = @typeInfo(Window.FnPtr).pointer;
    try std.testing.expect(info.is_const);
    try std.testing.expect(info.child == anyopaque);
}

// ── glGetProcAddress ─────────────────────────────────────────────────────────

test "Window has glGetProcAddress" {
    comptime {
        if (!@hasDecl(Window, "glGetProcAddress")) @compileError("missing: glGetProcAddress");
    }
}

test "glGetProcAddress signature is zgl-compatible" {
    // zgl expects: fn(@TypeOf(load_ctx), [:0]const u8) ?FunctionPointer
    // With load_ctx = *Window, that becomes:
    const Expected = fn (*Window, [:0]const u8) ?Window.FnPtr;
    const actual: Expected = Window.glGetProcAddress;
    _ = actual;
}

test "glGetProcAddress returns an optional" {
    // Verify the return type is optional (nullable), matching zgl's expectation.
    // Runtime testing of the actual CFBundle lookup requires Cocoa.framework
    // to be linked, which the unit test module doesn't do.
    const RetType = @typeInfo(@TypeOf(Window.glGetProcAddress)).@"fn".return_type.?;
    try std.testing.expect(@typeInfo(RetType) == .optional);
}
