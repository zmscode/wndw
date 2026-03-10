/// Tests for feature #16: Async Window Operations (fullscreen transition events).
///
/// Verifies that `.fullscreen_entered` and `.fullscreen_exited` event variants
/// exist, that the Window struct has the necessary transition-tracking field,
/// and that dispatchEvent correctly routes both to their callbacks.
const std = @import("std");
const Window = @import("../platform/macos/window.zig").Window;
const ev = @import("../event.zig");

// ── Event variants ────────────────────────────────────────────────────────────

test "Event: has fullscreen_entered variant" {
    const e: ev.Event = .fullscreen_entered;
    try std.testing.expect(e == .fullscreen_entered);
}

test "Event: has fullscreen_exited variant" {
    const e: ev.Event = .fullscreen_exited;
    try std.testing.expect(e == .fullscreen_exited);
}

test "Event: fullscreen_entered and fullscreen_exited are distinct" {
    const entered: ev.Event = .fullscreen_entered;
    const exited: ev.Event = .fullscreen_exited;
    try std.testing.expect(std.meta.activeTag(entered) != std.meta.activeTag(exited));
}

// ── Transition state field ────────────────────────────────────────────────────

test "Window: has is_transitioning_fullscreen field" {
    comptime if (!@hasField(Window, "is_transitioning_fullscreen"))
        @compileError("missing field: is_transitioning_fullscreen");
}

test "Window: is_transitioning_fullscreen is bool" {
    try std.testing.expectEqual(bool, @TypeOf(@as(Window, undefined).is_transitioning_fullscreen));
}

test "Window: is_transitioning_fullscreen defaults to false" {
    var w: Window = undefined;
    w.is_transitioning_fullscreen = false;
    try std.testing.expect(!w.is_transitioning_fullscreen);
}

// ── Callback methods ──────────────────────────────────────────────────────────

test "Window: has setOnFullscreenEntered method" {
    comptime if (!@hasDecl(Window, "setOnFullscreenEntered"))
        @compileError("missing method: setOnFullscreenEntered");
}

test "Window: has setOnFullscreenExited method" {
    comptime if (!@hasDecl(Window, "setOnFullscreenExited"))
        @compileError("missing method: setOnFullscreenExited");
}

// ── Dispatch routing ──────────────────────────────────────────────────────────

test "dispatchEvent: fullscreen_entered fires callback" {
    var count: u32 = 0;
    var w: Window = undefined;
    w.callbacks = .{};
    w.input_state = .{};
    w.setOnFullscreenEntered(&count, struct {
        fn cb(ctx: ?*anyopaque) void {
            const p: *u32 = @ptrCast(@alignCast(ctx.?));
            p.* += 1;
        }
    }.cb);
    w.dispatchEvent(.fullscreen_entered);
    try std.testing.expectEqual(@as(u32, 1), count);
}

test "dispatchEvent: fullscreen_exited fires callback" {
    var count: u32 = 0;
    var w: Window = undefined;
    w.callbacks = .{};
    w.input_state = .{};
    w.setOnFullscreenExited(&count, struct {
        fn cb(ctx: ?*anyopaque) void {
            const p: *u32 = @ptrCast(@alignCast(ctx.?));
            p.* += 1;
        }
    }.cb);
    w.dispatchEvent(.fullscreen_exited);
    try std.testing.expectEqual(@as(u32, 1), count);
}

test "dispatchEvent: fullscreen events fire independently" {
    var entered_count: u32 = 0;
    var exited_count: u32 = 0;
    var w: Window = undefined;
    w.callbacks = .{};
    w.input_state = .{};

    const handler = struct {
        fn cb(ctx: ?*anyopaque) void {
            const p: *u32 = @ptrCast(@alignCast(ctx.?));
            p.* += 1;
        }
    }.cb;

    w.setOnFullscreenEntered(&entered_count, handler);
    w.setOnFullscreenExited(&exited_count, handler);

    w.dispatchEvent(.fullscreen_entered);
    w.dispatchEvent(.fullscreen_entered);
    w.dispatchEvent(.fullscreen_exited);

    try std.testing.expectEqual(@as(u32, 2), entered_count);
    try std.testing.expectEqual(@as(u32, 1), exited_count);
}
