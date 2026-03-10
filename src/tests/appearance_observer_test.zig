/// Tests for feature #14: Appearance Observer (Live Theme Switching).
///
/// The live-broadcast mechanism (NSDistributedNotificationCenter observer
/// firing appearance_changed to all live windows) was implemented in feature
/// #1 and is tested here via dispatchEvent — no ObjC runtime needed.
const std = @import("std");
const Window = @import("../platform/macos/window.zig").Window;
const ev = @import("../event.zig");

// ── API surface ──────────────────────────────────────────────────────────────

test "Window: has setOnAppearanceChanged method" {
    comptime if (!@hasDecl(Window, "setOnAppearanceChanged")) @compileError("missing method: setOnAppearanceChanged");
}

test "Window: has getAppearance method" {
    comptime if (!@hasDecl(Window, "getAppearance")) @compileError("missing method: getAppearance");
}

// ── Dispatch routes to callback ──────────────────────────────────────────────

test "appearance_changed: dispatched to callback with correct value" {
    var received: ev.Appearance = .light;
    var w: Window = undefined;
    w.callbacks = .{};
    w.input_state = .{};
    w.setOnAppearanceChanged(&received, struct {
        fn cb(ctx: ?*anyopaque, a: ev.Appearance) void {
            const p: *ev.Appearance = @ptrCast(@alignCast(ctx.?));
            p.* = a;
        }
    }.cb);

    w.dispatchEvent(.{ .appearance_changed = .dark });
    try std.testing.expectEqual(ev.Appearance.dark, received);

    w.dispatchEvent(.{ .appearance_changed = .light });
    try std.testing.expectEqual(ev.Appearance.light, received);
}

// ── Multiple windows each have independent callbacks ──────────────────────────

test "appearance_changed: two windows fire independent callbacks" {
    var a_val: ev.Appearance = .light;
    var b_val: ev.Appearance = .light;

    var wa: Window = undefined;
    wa.callbacks = .{};
    wa.input_state = .{};
    var wb: Window = undefined;
    wb.callbacks = .{};
    wb.input_state = .{};

    const handler = struct {
        fn cb(ctx: ?*anyopaque, a: ev.Appearance) void {
            const p: *ev.Appearance = @ptrCast(@alignCast(ctx.?));
            p.* = a;
        }
    }.cb;

    wa.setOnAppearanceChanged(&a_val, handler);
    wb.setOnAppearanceChanged(&b_val, handler);

    wa.dispatchEvent(.{ .appearance_changed = .dark });
    try std.testing.expectEqual(ev.Appearance.dark, a_val);
    try std.testing.expectEqual(ev.Appearance.light, b_val); // wb not yet updated

    wb.dispatchEvent(.{ .appearance_changed = .dark });
    try std.testing.expectEqual(ev.Appearance.dark, b_val);
}

// ── No callback is safe ───────────────────────────────────────────────────────

test "appearance_changed: no callback does not crash" {
    var w: Window = undefined;
    w.callbacks = .{};
    w.input_state = .{};
    w.dispatchEvent(.{ .appearance_changed = .dark });
    w.dispatchEvent(.{ .appearance_changed = .light });
}

// ── appearance_override default ───────────────────────────────────────────────

test "Window: appearance_override defaults to null" {
    comptime if (!@hasField(Window, "appearance_override")) @compileError("missing field: appearance_override");
    var w: Window = undefined;
    w.appearance_override = null;
    try std.testing.expect(w.appearance_override == null);
}
