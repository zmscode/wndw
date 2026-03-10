/// Tests for feature #9: Ctrl+Click → Right-Click Synthesis.
const std = @import("std");
const window = @import("../platform/macos/window.zig");
const event = @import("../event.zig");

test "ctrl_synthesize: ctrl+left produces right" {
    const result = window.ctrl_synthesize(.left, true);
    try std.testing.expectEqual(event.MouseButton.right, result);
}

test "ctrl_synthesize: ctrl+right stays right" {
    const result = window.ctrl_synthesize(.right, true);
    try std.testing.expectEqual(event.MouseButton.right, result);
}

test "ctrl_synthesize: no ctrl+left stays left" {
    const result = window.ctrl_synthesize(.left, false);
    try std.testing.expectEqual(event.MouseButton.left, result);
}

test "ctrl_synthesize: no ctrl+middle stays middle" {
    const result = window.ctrl_synthesize(.middle, false);
    try std.testing.expectEqual(event.MouseButton.middle, result);
}

test "ctrl_synthesize: ctrl+middle stays middle (only left is synthesized)" {
    const result = window.ctrl_synthesize(.middle, true);
    try std.testing.expectEqual(event.MouseButton.middle, result);
}
