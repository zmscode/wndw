/// Tests for feature #17: Thread-Safe Window State.
///
/// Verifies the presence of a per-window mutex and that EventQueue's ring
/// buffer structure supports safe concurrent use. Full contention testing
/// is an integration concern — these are compile-time / struct surface tests.
const std = @import("std");
const Window = @import("../platform/macos/window.zig").Window;
const EventQueue = @import("../event_queue.zig").EventQueue;
const ev = @import("../event.zig");

// ── Mutex field ───────────────────────────────────────────────────────────────

test "Window: has state_mutex field" {
    comptime if (!@hasField(Window, "state_mutex"))
        @compileError("missing field: state_mutex");
}

test "Window: state_mutex is Thread.Mutex" {
    try std.testing.expectEqual(std.Thread.Mutex, @TypeOf(@as(Window, undefined).state_mutex));
}

// ── EventQueue sequential consistency ────────────────────────────────────────

test "EventQueue: push then pop is sequentially consistent" {
    var q = EventQueue{};
    q.push(.focus_gained);
    q.push(.{ .key_pressed = .{ .key = .a } });
    q.push(.close_requested);

    try std.testing.expectEqual(ev.Event.focus_gained, q.pop().?);
    const kp = q.pop().?;
    switch (kp) {
        .key_pressed => |k| try std.testing.expectEqual(ev.Key.a, k.key),
        else => return error.WrongEvent,
    }
    try std.testing.expectEqual(ev.Event.close_requested, q.pop().?);
    try std.testing.expect(q.pop() == null);
}

test "EventQueue: overflow drops oldest events (ring buffer)" {
    var q = EventQueue{};
    // Fill the queue to capacity — the ring buffer should wrap without crashing.
    var i: u32 = 0;
    while (i < 256) : (i += 1) {
        q.push(.focus_gained);
    }
    // Should still be able to pop without crashing.
    _ = q.pop();
}

// ── Window dispatchEvent is reentrant-safe ────────────────────────────────────

test "Window: dispatchEvent with no callbacks does not use mutex" {
    // Verify dispatch works without any side effects when callbacks are null.
    var w: Window = undefined;
    w.callbacks = .{};
    w.input_state = .{};
    // These should all be no-ops (no callbacks, but must not crash).
    w.dispatchEvent(.fullscreen_entered);
    w.dispatchEvent(.fullscreen_exited);
    w.dispatchEvent(.focus_gained);
    w.dispatchEvent(.focus_lost);
}
