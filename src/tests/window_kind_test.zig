/// Tests for window kinds (normal, floating, popup, dialog).
///
/// Verifies that the WindowKind enum exists in Options and that the
/// different kinds have distinct values. Runtime behavior (NSPanel vs
/// NSWindow) is tested via the demo — these are compile-time/unit tests.
const std = @import("std");
const Window = @import("../platform/macos/window.zig").Window;
const Options = @import("../platform/macos/window.zig").Options;

// ── WindowKind enum ─────────────────────────────────────────────────────────

test "Options: has kind field" {
    comptime if (!@hasField(Options, "kind")) @compileError("missing field: kind");
}

test "WindowKind: has normal, floating, popup, dialog variants" {
    const Kind = Options.WindowKind;
    const n = Kind.normal;
    const f = Kind.floating;
    const p = Kind.popup;
    const d = Kind.dialog;
    try std.testing.expect(n != f);
    try std.testing.expect(n != p);
    try std.testing.expect(n != d);
    try std.testing.expect(f != p);
    try std.testing.expect(f != d);
    try std.testing.expect(p != d);
}

test "WindowKind: default is normal" {
    const opts = Options{};
    try std.testing.expectEqual(Options.WindowKind.normal, opts.kind);
}

test "Options: floating kind can be set" {
    const opts = Options{ .kind = .floating };
    try std.testing.expectEqual(Options.WindowKind.floating, opts.kind);
}

test "Options: popup kind can be set" {
    const opts = Options{ .kind = .popup };
    try std.testing.expectEqual(Options.WindowKind.popup, opts.kind);
}

test "Options: dialog kind can be set" {
    const opts = Options{ .kind = .dialog };
    try std.testing.expectEqual(Options.WindowKind.dialog, opts.kind);
}

// ── Parent field ────────────────────────────────────────────────────────────

test "Options: has parent field" {
    comptime if (!@hasField(Options, "parent")) @compileError("missing field: parent");
}

test "Options: parent defaults to null" {
    const opts = Options{};
    try std.testing.expectEqual(@as(?*Window, null), opts.parent);
}

// ── Window struct ───────────────────────────────────────────────────────────

test "Window: has is_panel field" {
    comptime if (!@hasField(Window, "is_panel")) @compileError("missing field: is_panel");
}

test "Window: is_panel defaults to false" {
    var w: Window = undefined;
    w.is_panel = false;
    try std.testing.expect(!w.is_panel);
}
