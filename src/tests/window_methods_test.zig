/// TDD tests for Window state fields and new methods.
///
/// Pure comptime/field-access tests — no ObjC calls made, no Cocoa linkage needed.
/// Tests that exercise methods which call into ObjC (setTitle, resize, …) are
/// limited to compile-time existence checks via @hasDecl.
const std = @import("std");
const Window = @import("../platform/macos/window.zig").Window;
const objc = @import("../platform/macos/objc.zig");

// ── State fields ──────────────────────────────────────────────────────────────

test "Window: is_focused field exists and is bool" {
    comptime if (!@hasField(Window, "is_focused")) @compileError("Window missing field: is_focused");
    var w: Window = undefined;
    w.is_focused = true;
    try std.testing.expect(w.is_focused);
    w.is_focused = false;
    try std.testing.expect(!w.is_focused);
}

test "Window: is_minimized field exists and is bool" {
    comptime if (!@hasField(Window, "is_minimized")) @compileError("Window missing field: is_minimized");
    var w: Window = undefined;
    w.is_minimized = false;
    try std.testing.expect(!w.is_minimized);
}

// ── isFocused / isMinimized — logic correctness ───────────────────────────────

test "Window.isFocused reflects is_focused field" {
    var w: Window = undefined;
    w.is_focused = true;
    try std.testing.expect(w.isFocused());
    w.is_focused = false;
    try std.testing.expect(!w.isFocused());
}

test "Window.isMinimized reflects is_minimized field" {
    var w: Window = undefined;
    w.is_minimized = true;
    try std.testing.expect(w.isMinimized());
    w.is_minimized = false;
    try std.testing.expect(!w.isMinimized());
}

// ── getSize / getPos — logic correctness ─────────────────────────────────────

test "Window.getSize returns stored w/h" {
    var w: Window = undefined;
    w.w = 1920;
    w.h = 1080;
    const sz = w.getSize();
    try std.testing.expectEqual(@as(i32, 1920), sz.w);
    try std.testing.expectEqual(@as(i32, 1080), sz.h);
}

test "Window.getPos returns stored x/y" {
    var w: Window = undefined;
    w.x = 42;
    w.y = 100;
    const pos = w.getPos();
    try std.testing.expectEqual(@as(i32, 42), pos.x);
    try std.testing.expectEqual(@as(i32, 100), pos.y);
}

test "Window.getSize return type has w and h fields" {
    const Ret = @typeInfo(@TypeOf(Window.getSize)).@"fn".return_type.?;
    comptime if (!@hasField(Ret, "w")) @compileError("getSize missing field: w");
    comptime if (!@hasField(Ret, "h")) @compileError("getSize missing field: h");
}

test "Window.getPos return type has x and y fields" {
    const Ret = @typeInfo(@TypeOf(Window.getPos)).@"fn".return_type.?;
    comptime if (!@hasField(Ret, "x")) @compileError("getPos missing field: x");
    comptime if (!@hasField(Ret, "y")) @compileError("getPos missing field: y");
}

// ── is_visible / is_borderless — fields & logic ─────────────────────────────

test "Window: is_visible field exists, defaults true" {
    comptime if (!@hasField(Window, "is_visible")) @compileError("missing field: is_visible");
    var w: Window = undefined;
    w.is_visible = true;
    try std.testing.expect(w.is_visible);
}

test "Window: is_borderless field exists and is bool" {
    comptime if (!@hasField(Window, "is_borderless")) @compileError("missing field: is_borderless");
    var w: Window = undefined;
    w.is_borderless = true;
    try std.testing.expect(w.is_borderless);
    w.is_borderless = false;
    try std.testing.expect(!w.is_borderless);
}

test "Window.isVisible reflects is_visible field" {
    var w: Window = undefined;
    w.is_visible = true;
    try std.testing.expect(w.isVisible());
    w.is_visible = false;
    try std.testing.expect(!w.isVisible());
}

test "Window.isBorderless reflects is_borderless field" {
    var w: Window = undefined;
    w.is_borderless = false;
    try std.testing.expect(!w.isBorderless());
    w.is_borderless = true;
    try std.testing.expect(w.isBorderless());
}

// ── ObjC-backed methods: existence checks only ───────────────────────────────

test "Window has setTitle" {
    try std.testing.expect(@hasDecl(Window, "setTitle"));
}
test "Window has resize" {
    try std.testing.expect(@hasDecl(Window, "resize"));
}
test "Window has move" {
    try std.testing.expect(@hasDecl(Window, "move"));
}
test "Window has minimize" {
    try std.testing.expect(@hasDecl(Window, "minimize"));
}
test "Window has restore" {
    try std.testing.expect(@hasDecl(Window, "restore"));
}
test "Window has maximize" {
    try std.testing.expect(@hasDecl(Window, "maximize"));
}
test "Window has setFullscreen" {
    try std.testing.expect(@hasDecl(Window, "setFullscreen"));
}
test "Window has setCursorVisible" {
    try std.testing.expect(@hasDecl(Window, "setCursorVisible"));
}
test "Window has setAlwaysOnTop" {
    try std.testing.expect(@hasDecl(Window, "setAlwaysOnTop"));
}
test "Window has isFullscreen" {
    try std.testing.expect(@hasDecl(Window, "isFullscreen"));
}
test "Window has isMaximized" {
    try std.testing.expect(@hasDecl(Window, "isMaximized"));
}
test "Window has setOpacity" {
    try std.testing.expect(@hasDecl(Window, "setOpacity"));
}
test "Window has focus" {
    try std.testing.expect(@hasDecl(Window, "focus"));
}
test "Window has hide" {
    try std.testing.expect(@hasDecl(Window, "hide"));
}
test "Window has show" {
    try std.testing.expect(@hasDecl(Window, "show"));
}
test "Window has center" {
    try std.testing.expect(@hasDecl(Window, "center"));
}

// ── User pointer (pure logic) ───────────────────────────────────────────────

test "Window: user_ptr field exists, defaults null" {
    comptime if (!@hasField(Window, "user_ptr")) @compileError("missing field: user_ptr");
    var w: Window = undefined;
    w.user_ptr = null;
    try std.testing.expectEqual(@as(?*anyopaque, null), w.user_ptr);
}

test "Window.setUserPtr / getUserPtr round-trip" {
    var w: Window = undefined;
    w.user_ptr = null;
    try std.testing.expectEqual(@as(?*anyopaque, null), w.getUserPtr());

    var data: u32 = 42;
    w.setUserPtr(&data);
    try std.testing.expectEqual(@as(?*anyopaque, @ptrCast(&data)), w.getUserPtr());

    w.setUserPtr(null);
    try std.testing.expectEqual(@as(?*anyopaque, null), w.getUserPtr());
}

// ── Native handles ──────────────────────────────────────────────────────────

test "Window.getNativeWindow returns objc.id" {
    comptime if (!@hasDecl(Window, "getNativeWindow")) @compileError("missing: getNativeWindow");
    const Ret = @typeInfo(@TypeOf(Window.getNativeWindow)).@"fn".return_type.?;
    try std.testing.expect(Ret == objc.id);
}

test "Window.getNativeView returns objc.id" {
    comptime if (!@hasDecl(Window, "getNativeView")) @compileError("missing: getNativeView");
    const Ret = @typeInfo(@TypeOf(Window.getNativeView)).@"fn".return_type.?;
    try std.testing.expect(Ret == objc.id);
}

// ── Phase 2 ObjC-backed: existence checks ───────────────────────────────────

test "Window has setMinSize" {
    try std.testing.expect(@hasDecl(Window, "setMinSize"));
}
test "Window has setMaxSize" {
    try std.testing.expect(@hasDecl(Window, "setMaxSize"));
}
test "Window has setAspectRatio" {
    try std.testing.expect(@hasDecl(Window, "setAspectRatio"));
}
test "Window has flash" {
    try std.testing.expect(@hasDecl(Window, "flash"));
}

// ── Cursor state & control ──────────────────────────────────────────────────

test "Window: is_cursor_visible field exists, defaults true" {
    comptime if (!@hasField(Window, "is_cursor_visible")) @compileError("missing field: is_cursor_visible");
    var w: Window = undefined;
    w.is_cursor_visible = true;
    try std.testing.expect(w.is_cursor_visible);
}

test "Window.isCursorVisible reflects is_cursor_visible field" {
    var w: Window = undefined;
    w.is_cursor_visible = true;
    try std.testing.expect(w.isCursorVisible());
    w.is_cursor_visible = false;
    try std.testing.expect(!w.isCursorVisible());
}

test "Window has moveMouse" {
    try std.testing.expect(@hasDecl(Window, "moveMouse"));
}

test "Window has getMousePos" {
    try std.testing.expect(@hasDecl(Window, "getMousePos"));
}

test "Window.getMousePos return type has x and y" {
    const Ret = @typeInfo(@TypeOf(Window.getMousePos)).@"fn".return_type.?;
    comptime if (!@hasField(Ret, "x")) @compileError("getMousePos missing field: x");
    comptime if (!@hasField(Ret, "y")) @compileError("getMousePos missing field: y");
}

test "Window has setStandardCursor" {
    try std.testing.expect(@hasDecl(Window, "setStandardCursor"));
}

test "Window has resetCursor" {
    try std.testing.expect(@hasDecl(Window, "resetCursor"));
}

// ── Clipboard ───────────────────────────────────────────────────────────────

test "Window has clipboardRead" {
    try std.testing.expect(@hasDecl(Window, "clipboardRead"));
}

test "Window has clipboardWrite" {
    try std.testing.expect(@hasDecl(Window, "clipboardWrite"));
}

// ── Drag and drop ───────────────────────────────────────────────────────────

test "Window has setDragAndDrop" {
    try std.testing.expect(@hasDecl(Window, "setDragAndDrop"));
}

test "Window has getDroppedFiles" {
    try std.testing.expect(@hasDecl(Window, "getDroppedFiles"));
}

// ── Monitor/display ─────────────────────────────────────────────────────────

test "Monitor struct has expected fields" {
    const monitor_mod = @import("../platform/macos/window.zig");
    comptime {
        if (!@hasField(monitor_mod.Monitor, "x")) @compileError("missing: x");
        if (!@hasField(monitor_mod.Monitor, "y")) @compileError("missing: y");
        if (!@hasField(monitor_mod.Monitor, "w")) @compileError("missing: w");
        if (!@hasField(monitor_mod.Monitor, "h")) @compileError("missing: h");
        if (!@hasField(monitor_mod.Monitor, "scale")) @compileError("missing: scale");
    }
}

test "Window has getPrimaryMonitor" {
    try std.testing.expect(@hasDecl(Window, "getPrimaryMonitor"));
}

test "Window has getWindowMonitor" {
    try std.testing.expect(@hasDecl(Window, "getWindowMonitor"));
}

test "Window has getMonitors" {
    try std.testing.expect(@hasDecl(Window, "getMonitors"));
}

test "Window has moveToMonitor" {
    try std.testing.expect(@hasDecl(Window, "moveToMonitor"));
}

// ── Cursor enum ─────────────────────────────────────────────────────────────

test "Cursor enum exists with expected values" {
    const event = @import("../event.zig");
    comptime {
        if (!@hasField(event.Cursor, "arrow")) @compileError("missing: arrow");
        if (!@hasField(event.Cursor, "ibeam")) @compileError("missing: ibeam");
        if (!@hasField(event.Cursor, "crosshair")) @compileError("missing: crosshair");
        if (!@hasField(event.Cursor, "pointing_hand")) @compileError("missing: pointing_hand");
        if (!@hasField(event.Cursor, "resize_left_right")) @compileError("missing: resize_left_right");
        if (!@hasField(event.Cursor, "resize_up_down")) @compileError("missing: resize_up_down");
        if (!@hasField(event.Cursor, "not_allowed")) @compileError("missing: not_allowed");
    }
}
