/// TDD tests for Window state fields and new methods.
///
/// Pure comptime/field-access tests — no ObjC calls made, no Cocoa linkage needed.
/// Tests that exercise methods which call into ObjC (setTitle, resize, …) are
/// limited to compile-time existence checks via @hasDecl.
const std = @import("std");
const Window = @import("../platform/macos/window.zig").Window;

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
