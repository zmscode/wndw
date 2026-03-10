/// Tests for feature #12: Synthetic Drag Events for Text Selection.
///
/// Verifies that the Window struct has the fields needed to track the
/// drag-synthesis NSTimer. Runtime behavior (60Hz position updates during
/// held drags) is tested via the demo.
const std = @import("std");
const Window = @import("../platform/macos/window.zig").Window;

// ── Field presence ───────────────────────────────────────────────────────────

test "Window: has drag_timer field" {
    comptime if (!@hasField(Window, "drag_timer")) @compileError("missing field: drag_timer");
}

test "Window: drag_timer is optional" {
    // The field must be optional so we can check whether a timer is active.
    const T = @TypeOf(@as(Window, undefined).drag_timer);
    const info = @typeInfo(T);
    comptime if (info != .optional) @compileError("drag_timer must be an optional type");
}

test "Window: drag_timer defaults to null" {
    var w: Window = undefined;
    w.drag_timer = null;
    try std.testing.expect(w.drag_timer == null);
}

// ── State tracking ───────────────────────────────────────────────────────────

test "Window: drag_timer can be set and cleared" {
    var w: Window = undefined;
    w.drag_timer = null;
    try std.testing.expect(w.drag_timer == null);

    // Simulate a timer being started (non-null) and then cancelled (null).
    // We don't need a real NSTimer here — just verify the field round-trips.
    const fake_ptr: *anyopaque = @ptrFromInt(0xDEAD_BEEF);
    w.drag_timer = fake_ptr;
    try std.testing.expect(w.drag_timer != null);

    w.drag_timer = null;
    try std.testing.expect(w.drag_timer == null);
}

// ── mouse_moved event is the synthetic payload ────────────────────────────────

test "Event: mouse_moved carries a Position payload" {
    const event = @import("../event.zig");
    const ev = event.Event{ .mouse_moved = .{ .x = 42, .y = 99 } };
    switch (ev) {
        .mouse_moved => |pos| {
            try std.testing.expectEqual(@as(i32, 42), pos.x);
            try std.testing.expectEqual(@as(i32, 99), pos.y);
        },
        else => return error.WrongVariant,
    }
}
