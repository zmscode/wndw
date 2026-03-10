/// Tests for keyboard layout awareness (character field on KeyEvent).
///
/// Verifies that KeyEvent carries an optional Unicode codepoint resolved
/// from the keyboard layout, and that it round-trips through the event queue.
const std = @import("std");
const ev = @import("../event.zig");
const eq = @import("../event_queue.zig");
const Event = ev.Event;
const KeyEvent = ev.KeyEvent;

// ── KeyEvent character field ────────────────────────────────────────────────

test "KeyEvent: has character field defaulting to null" {
    const ke = KeyEvent{ .key = .a };
    try std.testing.expectEqual(@as(?u21, null), ke.character);
}

test "KeyEvent: character field can hold a codepoint" {
    const ke = KeyEvent{ .key = .a, .character = 'a' };
    try std.testing.expectEqual(@as(?u21, 'a'), ke.character);
}

test "KeyEvent: character field can hold non-ASCII" {
    // ü = U+00FC
    const ke = KeyEvent{ .key = .u, .character = 0x00FC };
    try std.testing.expectEqual(@as(?u21, 0x00FC), ke.character);
}

test "KeyEvent: character field can hold CJK codepoint" {
    // 你 = U+4F60
    const ke = KeyEvent{ .key = .unknown, .character = 0x4F60 };
    try std.testing.expectEqual(@as(?u21, 0x4F60), ke.character);
}

test "KeyEvent: modifier keys have null character" {
    const ke = KeyEvent{ .key = .left_shift, .mods = .{ .shift = true } };
    try std.testing.expectEqual(@as(?u21, null), ke.character);
}

// ── Event round-trip with character ─────────────────────────────────────────

test "Event: key_pressed with character round-trips through EventQueue" {
    var q = eq.EventQueue{};
    q.push(.{ .key_pressed = .{ .key = .a, .character = 'a' } });
    q.push(.{ .key_pressed = .{ .key = .a, .character = 'A', .mods = .{ .shift = true } } });

    const e1 = q.pop().?;
    switch (e1) {
        .key_pressed => |kp| {
            try std.testing.expectEqual(ev.Key.a, kp.key);
            try std.testing.expectEqual(@as(?u21, 'a'), kp.character);
        },
        else => return error.TestUnexpectedResult,
    }

    const e2 = q.pop().?;
    switch (e2) {
        .key_pressed => |kp| {
            try std.testing.expectEqual(ev.Key.a, kp.key);
            try std.testing.expectEqual(@as(?u21, 'A'), kp.character);
            try std.testing.expect(kp.mods.shift);
        },
        else => return error.TestUnexpectedResult,
    }
}

test "Event: key_released with character round-trips" {
    var q = eq.EventQueue{};
    q.push(.{ .key_released = .{ .key = .semicolon, .character = ';' } });
    const e = q.pop().?;
    switch (e) {
        .key_released => |kr| {
            try std.testing.expectEqual(ev.Key.semicolon, kr.key);
            try std.testing.expectEqual(@as(?u21, ';'), kr.character);
        },
        else => return error.TestUnexpectedResult,
    }
}

test "Event: key_pressed null character (e.g. function key) round-trips" {
    var q = eq.EventQueue{};
    q.push(.{ .key_pressed = .{ .key = .f1 } });
    const e = q.pop().?;
    switch (e) {
        .key_pressed => |kp| {
            try std.testing.expectEqual(ev.Key.f1, kp.key);
            try std.testing.expectEqual(@as(?u21, null), kp.character);
        },
        else => return error.TestUnexpectedResult,
    }
}
