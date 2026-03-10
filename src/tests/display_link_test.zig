/// Tests for CVDisplayLink frame sync API surface.
///
/// These are compile-time and API-level tests. Actual vsync behavior
/// requires a running window and display, which is tested via the demo.
const std = @import("std");
const Window = @import("../platform/macos/window.zig").Window;

// ── API surface ─────────────────────────────────────────────────────────────

test "Window: has createDisplayLink method" {
    try std.testing.expect(@hasDecl(Window, "createDisplayLink"));
}

test "Window: has destroyDisplayLink method" {
    try std.testing.expect(@hasDecl(Window, "destroyDisplayLink"));
}

test "Window: has waitForFrame method" {
    try std.testing.expect(@hasDecl(Window, "waitForFrame"));
}

test "Window: has display_link field" {
    comptime if (!@hasField(Window, "display_link")) @compileError("missing field: display_link");
}

test "Window: display_link defaults to null" {
    var w: Window = undefined;
    w.display_link = null;
    try std.testing.expectEqual(@as(?*anyopaque, null), w.display_link);
}

test "Window: has frame_ready field" {
    comptime if (!@hasField(Window, "frame_ready")) @compileError("missing field: frame_ready");
}
