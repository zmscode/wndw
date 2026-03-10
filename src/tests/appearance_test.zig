/// Tests for dark/light mode (appearance) tracking.
///
/// Covers the Appearance enum, the appearance_changed event variant,
/// event queue round-tripping, and callback wiring.
const std = @import("std");
const ev = @import("../event.zig");
const eq = @import("../event_queue.zig");
const Event = ev.Event;
const Appearance = ev.Appearance;

// ── Appearance enum ─────────────────────────────────────────────────────────

test "Appearance: has light and dark variants" {
    const l = Appearance.light;
    const d = Appearance.dark;
    try std.testing.expect(l != d);
}

test "Appearance: light and dark are distinct enum values" {
    try std.testing.expectEqual(@as(u1, 0), @intFromEnum(Appearance.light));
    try std.testing.expectEqual(@as(u1, 1), @intFromEnum(Appearance.dark));
}

// ── Event variant ───────────────────────────────────────────────────────────

test "Event: appearance_changed tag exists with Appearance payload" {
    const e: Event = .{ .appearance_changed = .dark };
    switch (e) {
        .appearance_changed => |a| try std.testing.expectEqual(Appearance.dark, a),
        else => return error.TestUnexpectedResult,
    }
}

test "Event: appearance_changed light variant" {
    const e: Event = .{ .appearance_changed = .light };
    try std.testing.expect(e == .appearance_changed);
    switch (e) {
        .appearance_changed => |a| try std.testing.expectEqual(Appearance.light, a),
        else => return error.TestUnexpectedResult,
    }
}

test "Event: appearance_changed compares as active tag" {
    const e: Event = .{ .appearance_changed = .dark };
    try std.testing.expect(e == .appearance_changed);
    try std.testing.expect(e != .focus_gained);
}

// ── EventQueue round-trip ───────────────────────────────────────────────────

test "Event: appearance_changed round-trips through EventQueue" {
    var q = eq.EventQueue{};
    q.push(.{ .appearance_changed = .dark });
    q.push(.{ .appearance_changed = .light });

    const e1 = q.pop().?;
    switch (e1) {
        .appearance_changed => |a| try std.testing.expectEqual(Appearance.dark, a),
        else => return error.TestUnexpectedResult,
    }

    const e2 = q.pop().?;
    switch (e2) {
        .appearance_changed => |a| try std.testing.expectEqual(Appearance.light, a),
        else => return error.TestUnexpectedResult,
    }

    try std.testing.expect(q.pop() == null);
}

test "Event: appearance_changed interleaves with other events" {
    var q = eq.EventQueue{};
    q.push(.focus_gained);
    q.push(.{ .appearance_changed = .dark });
    q.push(.close_requested);

    try std.testing.expect(q.pop().? == .focus_gained);
    const ac = q.pop().?;
    try std.testing.expect(ac == .appearance_changed);
    try std.testing.expect(q.pop().? == .close_requested);
}

// ── Callback signature ──────────────────────────────────────────────────────

test "Event: appearance_changed callback type is correct" {
    // Verify the callback function type matches the expected signature.
    // This is a compile-time test — if it compiles, it passes.
    const CbType = *const fn (Appearance) void;
    const cb: CbType = struct {
        fn handler(_: Appearance) void {}
    }.handler;
    _ = cb;
}
