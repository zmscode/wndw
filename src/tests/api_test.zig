/// Compile-time API surface tests.
///
/// These tests do not open windows or touch the OS; they verify that the
/// shared types (Key, MouseButton, Event) have all expected members and that
/// payload field types are correct.  They run on any platform.
const std = @import("std");
const ev = @import("../event.zig");
const Key = ev.Key;
const MouseButton = ev.MouseButton;
const Event = ev.Event;

// ── Key ───────────────────────────────────────────────────────────────────────

test "Key: all 26 letters" {
    const letters = [26]Key{
        .a, .b, .c, .d, .e, .f, .g, .h, .i, .j, .k, .l, .m,
        .n, .o, .p, .q, .r, .s, .t, .u, .v, .w, .x, .y, .z,
    };
    try std.testing.expectEqual(@as(usize, 26), letters.len);
    // Verify they are all distinct
    for (letters, 0..) |k, i| {
        for (letters, 0..) |k2, j| {
            if (i != j) try std.testing.expect(k != k2);
        }
    }
}

test "Key: digits 0-9" {
    _ = Key.@"0";
    _ = Key.@"1";
    _ = Key.@"2";
    _ = Key.@"3";
    _ = Key.@"4";
    _ = Key.@"5";
    _ = Key.@"6";
    _ = Key.@"7";
    _ = Key.@"8";
    _ = Key.@"9";
}

test "Key: function keys f1–f20" {
    _ = Key.f1;
    _ = Key.f2;
    _ = Key.f3;
    _ = Key.f4;
    _ = Key.f5;
    _ = Key.f6;
    _ = Key.f7;
    _ = Key.f8;
    _ = Key.f9;
    _ = Key.f10;
    _ = Key.f11;
    _ = Key.f12;
    _ = Key.f13;
    _ = Key.f14;
    _ = Key.f15;
    _ = Key.f16;
    _ = Key.f17;
    _ = Key.f18;
    _ = Key.f19;
    _ = Key.f20;
}

test "Key: navigation" {
    _ = Key.left;
    _ = Key.right;
    _ = Key.up;
    _ = Key.down;
    _ = Key.home;
    _ = Key.end;
    _ = Key.page_up;
    _ = Key.page_down;
}

test "Key: editing" {
    _ = Key.enter;
    _ = Key.escape;
    _ = Key.backspace;
    _ = Key.delete;
    _ = Key.tab;
    _ = Key.space;
    _ = Key.insert;
}

test "Key: modifiers" {
    _ = Key.left_shift;
    _ = Key.right_shift;
    _ = Key.left_ctrl;
    _ = Key.right_ctrl;
    _ = Key.left_alt;
    _ = Key.right_alt;
    _ = Key.left_super;
    _ = Key.right_super;
    _ = Key.caps_lock;
    _ = Key.num_lock;
    _ = Key.scroll_lock;
}

test "Key: punctuation" {
    _ = Key.minus;
    _ = Key.equal;
    _ = Key.left_bracket;
    _ = Key.right_bracket;
    _ = Key.backslash;
    _ = Key.semicolon;
    _ = Key.apostrophe;
    _ = Key.grave;
    _ = Key.comma;
    _ = Key.period;
    _ = Key.slash;
}

test "Key: numpad" {
    _ = Key.kp_0;
    _ = Key.kp_9;
    _ = Key.kp_decimal;
    _ = Key.kp_divide;
    _ = Key.kp_multiply;
    _ = Key.kp_subtract;
    _ = Key.kp_add;
    _ = Key.kp_enter;
    _ = Key.kp_equal;
}

test "Key: unknown sentinel" {
    _ = Key.unknown;
    // unknown should differ from all letter keys
    try std.testing.expect(Key.unknown != Key.a);
    try std.testing.expect(Key.unknown != Key.z);
}

// ── MouseButton ───────────────────────────────────────────────────────────────

test "MouseButton: all five buttons distinct" {
    const buttons = [5]MouseButton{ .left, .right, .middle, .x1, .x2 };
    for (buttons, 0..) |b, i| {
        for (buttons, 0..) |b2, j| {
            if (i != j) try std.testing.expect(b != b2);
        }
    }
}

// ── Event ─────────────────────────────────────────────────────────────────────

test "Event: all 11 tags constructible" {
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
    };
    try std.testing.expectEqual(@as(usize, 11), events.len);
}

test "Event: key payload is Key" {
    const e = Event{ .key_pressed = .escape };
    const k: Key = e.key_pressed;
    try std.testing.expectEqual(Key.escape, k);
}

test "Event: mouse payload is MouseButton" {
    const e = Event{ .mouse_pressed = .right };
    const b: MouseButton = e.mouse_pressed;
    try std.testing.expectEqual(MouseButton.right, b);
}

test "Event: mouse_moved payload fields are i32" {
    const e = Event{ .mouse_moved = .{ .x = -5, .y = 100 } };
    const x: i32 = e.mouse_moved.x;
    const y: i32 = e.mouse_moved.y;
    try std.testing.expectEqual(@as(i32, -5), x);
    try std.testing.expectEqual(@as(i32, 100), y);
}

test "Event: scroll payload fields are f32" {
    const e = Event{ .scroll = .{ .dx = 0.5, .dy = -1.5 } };
    const dx: f32 = e.scroll.dx;
    const dy: f32 = e.scroll.dy;
    try std.testing.expectEqual(@as(f32, 0.5), dx);
    try std.testing.expectEqual(@as(f32, -1.5), dy);
}

test "Event: resized payload fields are i32" {
    const e = Event{ .resized = .{ .w = 1920, .h = 1080 } };
    try std.testing.expectEqual(@as(i32, 1920), e.resized.w);
    try std.testing.expectEqual(@as(i32, 1080), e.resized.h);
}

test "Event: active tag check" {
    const e = Event{ .key_pressed = .tab };
    try std.testing.expect(e == .key_pressed);

    const e2 = Event.close_requested;
    try std.testing.expect(e2 == .close_requested);
}
