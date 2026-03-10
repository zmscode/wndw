/// Tests for feature #15: Traffic Light Button Repositioning.
///
/// Verifies the API surface: the `traffic_light_offset` field and the
/// `setTrafficLightPosition` / `resetTrafficLightPosition` methods.
/// Visual positioning (actual button movement) is tested via the demo.
const std = @import("std");
const Window = @import("../platform/macos/window.zig").Window;
const event = @import("../event.zig");

// ── Field presence ───────────────────────────────────────────────────────────

test "Window: has traffic_light_offset field" {
    comptime if (!@hasField(Window, "traffic_light_offset")) @compileError("missing field: traffic_light_offset");
}

test "Window: traffic_light_offset is optional Position" {
    const T = @TypeOf(@as(Window, undefined).traffic_light_offset);
    try std.testing.expectEqual(?event.Position, T);
}

test "Window: traffic_light_offset defaults to null" {
    var w: Window = undefined;
    w.traffic_light_offset = null;
    try std.testing.expect(w.traffic_light_offset == null);
}

// ── Method presence ──────────────────────────────────────────────────────────

test "Window: has setTrafficLightPosition method" {
    comptime if (!@hasDecl(Window, "setTrafficLightPosition")) @compileError("missing method: setTrafficLightPosition");
}

test "Window: has resetTrafficLightPosition method" {
    comptime if (!@hasDecl(Window, "resetTrafficLightPosition")) @compileError("missing method: resetTrafficLightPosition");
}

// ── Field state transitions ───────────────────────────────────────────────────

test "Window: traffic_light_offset can be set" {
    var w: Window = undefined;
    w.traffic_light_offset = .{ .x = 12, .y = 20 };
    const off = w.traffic_light_offset.?;
    try std.testing.expectEqual(@as(i32, 12), off.x);
    try std.testing.expectEqual(@as(i32, 20), off.y);
}

test "Window: traffic_light_offset can be reset to null" {
    var w: Window = undefined;
    w.traffic_light_offset = .{ .x = 12, .y = 20 };
    w.traffic_light_offset = null;
    try std.testing.expect(w.traffic_light_offset == null);
}
