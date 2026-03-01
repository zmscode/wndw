/// Tests for event callbacks (Phase 11).
///
/// Callback function pointers stored on Window. Each setter stores a fn ptr
/// that fires during dispatchEvent() (called by poll()). Tests use
/// dispatchEvent() directly to avoid pulling in ObjC linker symbols.
const std = @import("std");
const Window = @import("../platform/macos/window.zig").Window;
const ev = @import("../event.zig");

// ── Existence checks ────────────────────────────────────────────────────────

test "Window has setOnKeyPress" {
    try std.testing.expect(@hasDecl(Window, "setOnKeyPress"));
}

test "Window has setOnKeyRelease" {
    try std.testing.expect(@hasDecl(Window, "setOnKeyRelease"));
}

test "Window has setOnMousePress" {
    try std.testing.expect(@hasDecl(Window, "setOnMousePress"));
}

test "Window has setOnMouseRelease" {
    try std.testing.expect(@hasDecl(Window, "setOnMouseRelease"));
}

test "Window has setOnMouseMove" {
    try std.testing.expect(@hasDecl(Window, "setOnMouseMove"));
}

test "Window has setOnScroll" {
    try std.testing.expect(@hasDecl(Window, "setOnScroll"));
}

test "Window has setOnResize" {
    try std.testing.expect(@hasDecl(Window, "setOnResize"));
}

test "Window has setOnMove" {
    try std.testing.expect(@hasDecl(Window, "setOnMove"));
}

test "Window has setOnFocusGained" {
    try std.testing.expect(@hasDecl(Window, "setOnFocusGained"));
}

test "Window has setOnFocusLost" {
    try std.testing.expect(@hasDecl(Window, "setOnFocusLost"));
}

test "Window has setOnCloseRequested" {
    try std.testing.expect(@hasDecl(Window, "setOnCloseRequested"));
}

test "Window has dispatchEvent" {
    try std.testing.expect(@hasDecl(Window, "dispatchEvent"));
}

// ── Callback field ──────────────────────────────────────────────────────────

test "Window: callbacks field exists" {
    comptime if (!@hasField(Window, "callbacks")) @compileError("missing field: callbacks");
}

// ── Callback invocation (pure logic via dispatchEvent) ──────────────────────

var test_key_count: u32 = 0;
var test_last_key: ev.Key = .unknown;

fn testKeyCallback(kp: ev.KeyEvent) void {
    test_key_count += 1;
    test_last_key = kp.key;
}

test "Callback: setOnKeyPress fires on dispatchEvent" {
    test_key_count = 0;
    test_last_key = .unknown;

    var w: Window = undefined;
    w.callbacks = .{};
    w.input_state = .{};

    w.setOnKeyPress(testKeyCallback);
    w.dispatchEvent(.{ .key_pressed = .{ .key = .escape } });

    try std.testing.expectEqual(@as(u32, 1), test_key_count);
    try std.testing.expect(test_last_key == .escape);
}

var test_mouse_btn: ev.MouseButton = .left;
var test_mouse_count: u32 = 0;

fn testMouseCallback(btn: ev.MouseButton) void {
    test_mouse_count += 1;
    test_mouse_btn = btn;
}

test "Callback: setOnMousePress fires on dispatchEvent" {
    test_mouse_count = 0;

    var w: Window = undefined;
    w.callbacks = .{};
    w.input_state = .{};

    w.setOnMousePress(testMouseCallback);
    w.dispatchEvent(.{ .mouse_pressed = .right });

    try std.testing.expectEqual(@as(u32, 1), test_mouse_count);
    try std.testing.expect(test_mouse_btn == .right);
}

var test_resize_w: i32 = 0;
var test_resize_h: i32 = 0;

fn testResizeCallback(size: ev.Size) void {
    test_resize_w = size.w;
    test_resize_h = size.h;
}

test "Callback: setOnResize fires on dispatchEvent" {
    test_resize_w = 0;
    test_resize_h = 0;

    var w: Window = undefined;
    w.callbacks = .{};
    w.input_state = .{};

    w.setOnResize(testResizeCallback);
    w.dispatchEvent(.{ .resized = .{ .w = 1024, .h = 768 } });

    try std.testing.expectEqual(@as(i32, 1024), test_resize_w);
    try std.testing.expectEqual(@as(i32, 768), test_resize_h);
}

var test_void_count: u32 = 0;

fn testVoidCallback() void {
    test_void_count += 1;
}

test "Callback: setOnFocusGained fires on dispatchEvent" {
    test_void_count = 0;

    var w: Window = undefined;
    w.callbacks = .{};
    w.input_state = .{};

    w.setOnFocusGained(testVoidCallback);
    w.dispatchEvent(.focus_gained);

    try std.testing.expectEqual(@as(u32, 1), test_void_count);
}

test "Callback: null callback does not crash" {
    var w: Window = undefined;
    w.callbacks = .{};
    w.input_state = .{};

    // No callbacks set — dispatchEvent should still work
    w.dispatchEvent(.{ .key_pressed = .{ .key = .a } });
}
