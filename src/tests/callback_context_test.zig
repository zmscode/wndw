/// Tests for callbacks with user context pointer.
///
/// Verifies that callbacks receive the correct context pointer and that
/// different windows can have different contexts.
const std = @import("std");
const Window = @import("../platform/macos/window.zig").Window;
const ev = @import("../event.zig");

// ── Context pointer delivery ────────────────────────────────────────────────

const TestState = struct {
    key_count: u32 = 0,
    last_key: ev.Key = .unknown,
    resize_w: i32 = 0,
    resize_h: i32 = 0,
    focus_count: u32 = 0,
    appearance: ev.Appearance = .light,
};

fn ctxKeyCallback(ctx: ?*anyopaque, kp: ev.KeyEvent) void {
    const state: *TestState = @ptrCast(@alignCast(ctx.?));
    state.key_count += 1;
    state.last_key = kp.key;
}

fn ctxResizeCallback(ctx: ?*anyopaque, size: ev.Size) void {
    const state: *TestState = @ptrCast(@alignCast(ctx.?));
    state.resize_w = size.w;
    state.resize_h = size.h;
}

fn ctxVoidCallback(ctx: ?*anyopaque) void {
    const state: *TestState = @ptrCast(@alignCast(ctx.?));
    state.focus_count += 1;
}

fn ctxAppearanceCallback(ctx: ?*anyopaque, a: ev.Appearance) void {
    const state: *TestState = @ptrCast(@alignCast(ctx.?));
    state.appearance = a;
}

test "Callback with context: key press receives correct state" {
    var state = TestState{};

    var w: Window = undefined;
    w.callbacks = .{};
    w.input_state = .{};

    w.setOnKeyPress(&state, ctxKeyCallback);
    w.dispatchEvent(.{ .key_pressed = .{ .key = .escape } });

    try std.testing.expectEqual(@as(u32, 1), state.key_count);
    try std.testing.expect(state.last_key == .escape);
}

test "Callback with context: resize receives correct state" {
    var state = TestState{};

    var w: Window = undefined;
    w.callbacks = .{};
    w.input_state = .{};

    w.setOnResize(&state, ctxResizeCallback);
    w.dispatchEvent(.{ .resized = .{ .w = 1920, .h = 1080 } });

    try std.testing.expectEqual(@as(i32, 1920), state.resize_w);
    try std.testing.expectEqual(@as(i32, 1080), state.resize_h);
}

test "Callback with context: void callback receives context" {
    var state = TestState{};

    var w: Window = undefined;
    w.callbacks = .{};
    w.input_state = .{};

    w.setOnFocusGained(&state, ctxVoidCallback);
    w.dispatchEvent(.focus_gained);

    try std.testing.expectEqual(@as(u32, 1), state.focus_count);
}

test "Callback with context: null callback does not crash" {
    var w: Window = undefined;
    w.callbacks = .{};
    w.input_state = .{};

    // No callbacks set — dispatch should still work
    w.dispatchEvent(.{ .key_pressed = .{ .key = .a } });
    w.dispatchEvent(.focus_gained);
    w.dispatchEvent(.{ .resized = .{ .w = 100, .h = 100 } });
}

test "Callback with context: different windows get different contexts" {
    var state1 = TestState{};
    var state2 = TestState{};

    var w1: Window = undefined;
    w1.callbacks = .{};
    w1.input_state = .{};
    w1.setOnKeyPress(&state1, ctxKeyCallback);

    var w2: Window = undefined;
    w2.callbacks = .{};
    w2.input_state = .{};
    w2.setOnKeyPress(&state2, ctxKeyCallback);

    w1.dispatchEvent(.{ .key_pressed = .{ .key = .a } });
    w2.dispatchEvent(.{ .key_pressed = .{ .key = .b } });

    try std.testing.expectEqual(@as(u32, 1), state1.key_count);
    try std.testing.expect(state1.last_key == .a);
    try std.testing.expectEqual(@as(u32, 1), state2.key_count);
    try std.testing.expect(state2.last_key == .b);
}

test "Callback with context: null context is passed through" {
    var w: Window = undefined;
    w.callbacks = .{};
    w.input_state = .{};

    // Set callback with null context — the fn should receive null
    w.setOnKeyPress(null, struct {
        fn handler(ctx: ?*anyopaque, _: ev.KeyEvent) void {
            std.debug.assert(ctx == null);
        }
    }.handler);
    w.dispatchEvent(.{ .key_pressed = .{ .key = .a } });
}

test "Callback with context: appearance changed receives context" {
    var state = TestState{};

    var w: Window = undefined;
    w.callbacks = .{};
    w.input_state = .{};

    w.setOnAppearanceChanged(&state, ctxAppearanceCallback);
    w.dispatchEvent(.{ .appearance_changed = .dark });

    try std.testing.expectEqual(ev.Appearance.dark, state.appearance);
}

test "Callback with context: setting callback to null unregisters" {
    var state = TestState{};

    var w: Window = undefined;
    w.callbacks = .{};
    w.input_state = .{};

    w.setOnKeyPress(&state, ctxKeyCallback);
    w.dispatchEvent(.{ .key_pressed = .{ .key = .a } });
    try std.testing.expectEqual(@as(u32, 1), state.key_count);

    w.setOnKeyPress(null, null);
    w.dispatchEvent(.{ .key_pressed = .{ .key = .b } });
    // Count should not increase
    try std.testing.expectEqual(@as(u32, 1), state.key_count);
}
