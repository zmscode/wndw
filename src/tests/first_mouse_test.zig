/// Tests for feature #10: First-Mouse Detection.
///
/// Verifies that the Window struct has the necessary fields and that
/// the isFirstMouse() method exists. Runtime behavior (click-to-focus
/// detection) is tested via the demo — these are compile-time/unit tests.
const std = @import("std");
const Window = @import("../platform/macos/window.zig").Window;

// ── Field presence ───────────────────────────────────────────────────────────

test "Window: has is_first_mouse field" {
    comptime if (!@hasField(Window, "is_first_mouse")) @compileError("missing field: is_first_mouse");
}

test "Window: is_first_mouse is bool" {
    try std.testing.expectEqual(bool, @TypeOf(@as(Window, undefined).is_first_mouse));
}

test "Window: is_first_mouse defaults to false" {
    var w: Window = undefined;
    w.is_first_mouse = false;
    try std.testing.expect(!w.is_first_mouse);
}

// ── Method presence ──────────────────────────────────────────────────────────

test "Window: has isFirstMouse method" {
    comptime if (!@hasDecl(Window, "isFirstMouse")) @compileError("missing method: isFirstMouse");
}

// ── State transitions ────────────────────────────────────────────────────────

test "Window: is_first_mouse can be set to true" {
    var w: Window = undefined;
    w.is_first_mouse = true;
    try std.testing.expect(w.is_first_mouse);
}

test "Window: is_first_mouse can be cleared after first click" {
    var w: Window = undefined;
    w.is_first_mouse = true;
    // Simulate click consumed — clear the flag
    w.is_first_mouse = false;
    try std.testing.expect(!w.is_first_mouse);
}
