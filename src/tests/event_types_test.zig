/// Tests for event types added beyond the original 11.
const std = @import("std");
const ev = @import("../event.zig");
const eq = @import("../event_queue.zig");
const Event = ev.Event;
const Modifiers = ev.Modifiers;

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
    q.push(.minimized);
    q.push(.restored);
    const e1 = q.pop().?;
    const e2 = q.pop().?;
    try std.testing.expect(e1 == .minimized);
    try std.testing.expect(e2 == .restored);
    try std.testing.expect(q.pop() == null);
}

test "Event: key_pressed with mods round-trips through EventQueue" {
    var q = eq.EventQueue{};
    q.push(.{ .key_pressed = .{ .key = .a, .mods = .{ .ctrl = true } } });
    const e = q.pop().?;
    switch (e) {
        .key_pressed => |kp| {
            try std.testing.expect(kp.key == .a);
            try std.testing.expect(kp.mods.ctrl);
            try std.testing.expect(!kp.mods.shift);
        },
        else => return error.TestUnexpectedResult,
    }
}

test "Event: mouse_entered tag exists" {
    const e = Event.mouse_entered;
    try std.testing.expect(e == .mouse_entered);
}

test "Event: mouse_left tag exists" {
    const e = Event.mouse_left;
    try std.testing.expect(e == .mouse_left);
}

test "Event: maximized tag exists" {
    const e = Event.maximized;
    try std.testing.expect(e == .maximized);
}

test "Event: refresh_requested tag exists" {
    const e = Event.refresh_requested;
    try std.testing.expect(e == .refresh_requested);
}

test "Event: scale_changed tag exists with f32 payload" {
    const e: Event = .{ .scale_changed = 2.0 };
    switch (e) {
        .scale_changed => |s| try std.testing.expectEqual(@as(f32, 2.0), s),
        else => return error.TestUnexpectedResult,
    }
}

test "Event: new tags round-trip through EventQueue" {
    var q = eq.EventQueue{};
    q.push(.mouse_entered);
    q.push(.mouse_left);
    q.push(.maximized);
    q.push(.refresh_requested);
    q.push(.{ .scale_changed = 1.5 });
    try std.testing.expect(q.pop().? == .mouse_entered);
    try std.testing.expect(q.pop().? == .mouse_left);
    try std.testing.expect(q.pop().? == .maximized);
    try std.testing.expect(q.pop().? == .refresh_requested);
    const sc = q.pop().?;
    switch (sc) {
        .scale_changed => |s| try std.testing.expectEqual(@as(f32, 1.5), s),
        else => return error.TestUnexpectedResult,
    }
}

test "Event: file_drop_started tag exists" {
    try std.testing.expect(Event.file_drop_started == .file_drop_started);
}

test "Event: file_dropped tag exists with count" {
    const e: Event = .{ .file_dropped = 3 };
    switch (e) {
        .file_dropped => |n| try std.testing.expectEqual(@as(u32, 3), n),
        else => return error.TestUnexpectedResult,
    }
}

test "Event: file_drop_left tag exists" {
    try std.testing.expect(Event.file_drop_left == .file_drop_left);
}

test "Event: all 21 tags constructible" {
    const no_mods = Modifiers{};
    const events = [_]Event{
        .{ .key_pressed = .{ .key = .a, .mods = no_mods } },
        .{ .key_released = .{ .key = .a, .mods = no_mods } },
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
        .mouse_entered,
        .mouse_left,
        .maximized,
        .refresh_requested,
        .{ .scale_changed = 1.0 },
        .file_drop_started,
        .{ .file_dropped = 1 },
        .file_drop_left,
    };
    try std.testing.expectEqual(@as(usize, 21), events.len);
}

// ── Modifiers ───────────────────────────────────────────────────────────────

test "Modifiers struct exists with expected fields" {
    comptime {
        if (!@hasField(Modifiers, "shift")) @compileError("missing: shift");
        if (!@hasField(Modifiers, "ctrl")) @compileError("missing: ctrl");
        if (!@hasField(Modifiers, "alt")) @compileError("missing: alt");
        if (!@hasField(Modifiers, "super")) @compileError("missing: super");
        if (!@hasField(Modifiers, "caps_lock")) @compileError("missing: caps_lock");
    }
}

test "Modifiers defaults to all false" {
    const m = Modifiers{};
    try std.testing.expect(!m.shift);
    try std.testing.expect(!m.ctrl);
    try std.testing.expect(!m.alt);
    try std.testing.expect(!m.super);
    try std.testing.expect(!m.caps_lock);
}

test "key_pressed payload has .key and .mods fields" {
    const e: Event = .{ .key_pressed = .{ .key = .a, .mods = .{ .shift = true } } };
    switch (e) {
        .key_pressed => |kp| {
            try std.testing.expect(kp.key == .a);
            try std.testing.expect(kp.mods.shift);
            try std.testing.expect(!kp.mods.ctrl);
        },
        else => return error.TestUnexpectedResult,
    }
}

test "key_released payload has .key and .mods fields" {
    const e: Event = .{ .key_released = .{ .key = .escape, .mods = .{ .super = true } } };
    switch (e) {
        .key_released => |kr| {
            try std.testing.expect(kr.key == .escape);
            try std.testing.expect(kr.mods.super);
        },
        else => return error.TestUnexpectedResult,
    }
}
