const std = @import("std");
const eq = @import("../event_queue.zig");
const ev = @import("../event.zig");
const EventQueue = eq.EventQueue;
const Key = ev.Key;
const MouseButton = ev.MouseButton;

test "empty queue returns null" {
    var q = EventQueue{};
    try std.testing.expect(q.pop() == null);
    try std.testing.expect(q.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), q.len());
}

test "push/pop FIFO order" {
    var q = EventQueue{};
    q.push(.{ .key_pressed = .{ .key = .a } });
    q.push(.{ .key_pressed = .{ .key = .b } });
    q.push(.{ .key_pressed = .{ .key = .c } });

    try std.testing.expectEqual(@as(usize, 3), q.len());
    try std.testing.expect(!q.isEmpty());

    const e1 = q.pop().?;
    try std.testing.expectEqual(Key.a, e1.key_pressed.key);

    const e2 = q.pop().?;
    try std.testing.expectEqual(Key.b, e2.key_pressed.key);

    const e3 = q.pop().?;
    try std.testing.expectEqual(Key.c, e3.key_pressed.key);

    try std.testing.expect(q.pop() == null);
    try std.testing.expect(q.isEmpty());
}

test "overflow drops newest event" {
    var q = EventQueue{};
    // Fill to capacity: QUEUE_CAP - 1 events (the buffer holds cap-1 items)
    var i: usize = 0;
    while (i < eq.QUEUE_CAP - 1) : (i += 1) {
        q.push(.{ .key_pressed = .{ .key = .a } });
    }
    try std.testing.expectEqual(eq.QUEUE_CAP - 1, q.len());

    // This push must be dropped — queue is full
    q.push(.{ .key_pressed = .{ .key = .b } });
    try std.testing.expectEqual(eq.QUEUE_CAP - 1, q.len());

    // All events should be .a, not .b
    i = 0;
    while (q.pop()) |event| : (i += 1) {
        try std.testing.expectEqual(Key.a, event.key_pressed.key);
    }
    try std.testing.expectEqual(eq.QUEUE_CAP - 1, i);
}

test "head/tail wrap-around" {
    var q = EventQueue{};
    // Advance head and tail to the middle of the buffer
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        q.push(.{ .key_pressed = .{ .key = .s } });
        _ = q.pop();
    }
    try std.testing.expect(q.isEmpty());

    // Fill again across the wrap boundary
    i = 0;
    while (i < eq.QUEUE_CAP - 1) : (i += 1) {
        q.push(.{ .key_pressed = .{ .key = .z } });
    }
    try std.testing.expectEqual(eq.QUEUE_CAP - 1, q.len());

    i = 0;
    while (q.pop()) |event| : (i += 1) {
        try std.testing.expectEqual(Key.z, event.key_pressed.key);
    }
    try std.testing.expectEqual(eq.QUEUE_CAP - 1, i);
}

test "mixed event types round-trip" {
    var q = EventQueue{};
    q.push(.{ .key_pressed = .{ .key = .escape } });
    q.push(.{ .mouse_pressed = .left });
    q.push(.{ .mouse_moved = .{ .x = 42, .y = 7 } });
    q.push(.{ .scroll = .{ .dx = 1.0, .dy = -2.5 } });
    q.push(.close_requested);

    const kp = q.pop().?;
    try std.testing.expect(kp == .key_pressed);
    try std.testing.expectEqual(Key.escape, kp.key_pressed.key);

    const mp = q.pop().?;
    try std.testing.expect(mp == .mouse_pressed);
    try std.testing.expectEqual(MouseButton.left, mp.mouse_pressed);

    const mm = q.pop().?;
    try std.testing.expect(mm == .mouse_moved);
    try std.testing.expectEqual(@as(i32, 42), mm.mouse_moved.x);
    try std.testing.expectEqual(@as(i32, 7), mm.mouse_moved.y);

    const sc = q.pop().?;
    try std.testing.expect(sc == .scroll);
    try std.testing.expectEqual(@as(f32, 1.0), sc.scroll.dx);
    try std.testing.expectEqual(@as(f32, -2.5), sc.scroll.dy);

    const cr = q.pop().?;
    try std.testing.expect(cr == .close_requested);

    try std.testing.expect(q.pop() == null);
}

test "len tracks push and pop correctly" {
    var q = EventQueue{};
    try std.testing.expectEqual(@as(usize, 0), q.len());

    q.push(.focus_gained);
    try std.testing.expectEqual(@as(usize, 1), q.len());

    q.push(.focus_lost);
    try std.testing.expectEqual(@as(usize, 2), q.len());

    _ = q.pop();
    try std.testing.expectEqual(@as(usize, 1), q.len());

    _ = q.pop();
    try std.testing.expectEqual(@as(usize, 0), q.len());
}
