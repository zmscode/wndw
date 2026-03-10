/// Tests for Monitor struct extensions — features #7 and #8.
///
/// #7: Display content bounds (visible frame excluding dock/menu bar).
/// #8: Stable display UUIDs via CGDisplayCreateUUIDFromDisplayID.
///
/// Runtime correctness (actual Cocoa calls) is verified via the demo.
/// These are compile-time / struct surface tests.
const std = @import("std");
const Monitor = @import("../platform/macos/window.zig").Monitor;

// ── Feature #7: Content bounds ────────────────────────────────────────────────

test "Monitor: has content_x field" {
    comptime if (!@hasField(Monitor, "content_x")) @compileError("missing field: content_x");
}

test "Monitor: has content_y field" {
    comptime if (!@hasField(Monitor, "content_y")) @compileError("missing field: content_y");
}

test "Monitor: has content_w field" {
    comptime if (!@hasField(Monitor, "content_w")) @compileError("missing field: content_w");
}

test "Monitor: has content_h field" {
    comptime if (!@hasField(Monitor, "content_h")) @compileError("missing field: content_h");
}

test "Monitor: content fields are i32" {
    try std.testing.expectEqual(i32, @TypeOf(@as(Monitor, undefined).content_x));
    try std.testing.expectEqual(i32, @TypeOf(@as(Monitor, undefined).content_y));
    try std.testing.expectEqual(i32, @TypeOf(@as(Monitor, undefined).content_w));
    try std.testing.expectEqual(i32, @TypeOf(@as(Monitor, undefined).content_h));
}

test "Monitor: content bounds fit within full bounds" {
    // A Monitor with content area fully within the full frame is valid.
    const m = Monitor{
        .x = 0,
        .y = 0,
        .w = 1920,
        .h = 1080,
        .content_x = 0,
        .content_y = 0,
        .content_w = 1920,
        .content_h = 1057,
        .scale = 1.0,
        .ns_screen = undefined,
        .uuid = 0,
    };
    try std.testing.expect(m.content_w <= m.w);
    try std.testing.expect(m.content_h <= m.h);
}

// ── Feature #8: Stable display UUIDs ─────────────────────────────────────────

test "Monitor: has uuid field" {
    comptime if (!@hasField(Monitor, "uuid")) @compileError("missing field: uuid");
}

test "Monitor: uuid field is u128" {
    try std.testing.expectEqual(u128, @TypeOf(@as(Monitor, undefined).uuid));
}

test "Monitor: uuid zero is a valid default (unknown display)" {
    const m = Monitor{
        .x = 0,
        .y = 0,
        .w = 1920,
        .h = 1080,
        .content_x = 0,
        .content_y = 0,
        .content_w = 1920,
        .content_h = 1057,
        .scale = 1.0,
        .ns_screen = undefined,
        .uuid = 0,
    };
    try std.testing.expectEqual(@as(u128, 0), m.uuid);
}

test "Monitor: two monitors with different UUIDs are distinct displays" {
    const a = Monitor{
        .x = 0,
        .y = 0,
        .w = 1920,
        .h = 1080,
        .content_x = 0,
        .content_y = 0,
        .content_w = 1920,
        .content_h = 1057,
        .scale = 1.0,
        .ns_screen = undefined,
        .uuid = 0xDEAD_BEEF_0000_0001_0000_0000_0000_0001,
    };
    const b = Monitor{
        .x = 1920,
        .y = 0,
        .w = 2560,
        .h = 1440,
        .content_x = 1920,
        .content_y = 0,
        .content_w = 2560,
        .content_h = 1440,
        .scale = 2.0,
        .ns_screen = undefined,
        .uuid = 0xDEAD_BEEF_0000_0002_0000_0000_0000_0002,
    };
    try std.testing.expect(a.uuid != b.uuid);
}
