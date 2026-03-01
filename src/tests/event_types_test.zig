/// Tests for event types added beyond the original 11.
const std = @import("std");
const ev = @import("../event.zig");
const eq = @import("../event_queue.zig");
const Event = ev.Event;

test "Event: minimized tag exists and compares" {
    const e = Event.minimized;
    try std.testing.expect(e == .minimized);
}

test "Event: restored tag exists and compares" {
    const e = Event.restored;
    try std.testing.expect(e == .restored);
}

test "Event: minimized != restored" {
    try std.testing.expect(Event.minimized != Event.restored);
}

test "Event: minimized round-trips through EventQueue" {
    var q = eq.EventQueue{};
    q.push(Event.minimized);
    q.push(Event.restored);
    const e1 = q.pop().?;
    const e2 = q.pop().?;
    try std.testing.expect(e1 == .minimized);
    try std.testing.expect(e2 == .restored);
    try std.testing.expect(q.pop() == null);
}

test "Event: all 13 tags constructible" {
    const events = [_]Event{
        .{ .key_pressed = .a },
        .{ .key_released = .a },
        .{ .mouse_pressed = .left },
        .{ .mouse_released = .left },
        .{ .mouse_moved = .{ .x = 0, .y = 0 } },
        .{ .scroll = .{ .dx = 0, .dy = 0 } },
        .{ .resized = .{ .w = 0, .h = 0 } },
        .{ .moved = .{ .x = 0, .y = 0 } },
        .focus_gained,
        .focus_lost,
        .close_requested,
        .minimized,
        .restored,
    };
    try std.testing.expectEqual(@as(usize, 13), events.len);
}
