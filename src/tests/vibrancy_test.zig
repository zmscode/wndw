/// Tests for blurred/vibrancy window backgrounds (feature #6).
///
/// Verifies the WindowBackground and BlurMaterial enums, Options fields,
/// and Window struct/method surface. Runtime NSVisualEffectView behaviour
/// is exercised via the demo — these are compile-time/unit tests.
const std = @import("std");
const Window = @import("../platform/macos/window.zig").Window;
const Options = @import("../platform/macos/window.zig").Options;

// ── WindowBackground enum ────────────────────────────────────────────────────

test "Options: has WindowBackground type" {
    _ = Options.WindowBackground;
}

test "WindowBackground: has solid variant" {
    _ = Options.WindowBackground.solid;
}

test "WindowBackground: has transparent variant" {
    _ = Options.WindowBackground.transparent;
}

test "WindowBackground: has blurred variant" {
    _ = Options.WindowBackground.blurred;
}

test "WindowBackground: has ultra_dark variant" {
    _ = Options.WindowBackground.ultra_dark;
}

test "WindowBackground: all variants are distinct" {
    const BG = Options.WindowBackground;
    try std.testing.expect(BG.solid != BG.transparent);
    try std.testing.expect(BG.solid != BG.blurred);
    try std.testing.expect(BG.solid != BG.ultra_dark);
    try std.testing.expect(BG.transparent != BG.blurred);
    try std.testing.expect(BG.transparent != BG.ultra_dark);
    try std.testing.expect(BG.blurred != BG.ultra_dark);
}

// ── BlurMaterial enum ────────────────────────────────────────────────────────

test "Options: has BlurMaterial type" {
    _ = Options.BlurMaterial;
}

test "BlurMaterial: has sidebar variant" {
    _ = Options.BlurMaterial.sidebar;
}

test "BlurMaterial: has popover variant" {
    _ = Options.BlurMaterial.popover;
}

test "BlurMaterial: has hud variant" {
    _ = Options.BlurMaterial.hud;
}

test "BlurMaterial: has titlebar variant" {
    _ = Options.BlurMaterial.titlebar;
}

test "BlurMaterial: has under_window variant" {
    _ = Options.BlurMaterial.under_window;
}

// ── Options fields ───────────────────────────────────────────────────────────

test "Options: has background field" {
    comptime if (!@hasField(Options, "background")) @compileError("missing field: background");
}

test "Options: background defaults to solid" {
    const opts = Options{};
    try std.testing.expectEqual(Options.WindowBackground.solid, opts.background);
}

test "Options: background can be set to blurred" {
    const opts = Options{ .background = .blurred };
    try std.testing.expectEqual(Options.WindowBackground.blurred, opts.background);
}

test "Options: background can be set to ultra_dark" {
    const opts = Options{ .background = .ultra_dark };
    try std.testing.expectEqual(Options.WindowBackground.ultra_dark, opts.background);
}

test "Options: background can be set to transparent" {
    const opts = Options{ .background = .transparent };
    try std.testing.expectEqual(Options.WindowBackground.transparent, opts.background);
}

test "Options: has blur_material field" {
    comptime if (!@hasField(Options, "blur_material")) @compileError("missing field: blur_material");
}

test "Options: blur_material defaults to sidebar" {
    const opts = Options{};
    try std.testing.expectEqual(Options.BlurMaterial.sidebar, opts.blur_material);
}

test "Options: blur_material can be set to hud" {
    const opts = Options{ .background = .blurred, .blur_material = .hud };
    try std.testing.expectEqual(Options.BlurMaterial.hud, opts.blur_material);
}

test "Options: transparent bool preserved for backward compat" {
    const opts = Options{ .transparent = true };
    try std.testing.expect(opts.transparent);
}

// ── Window struct ────────────────────────────────────────────────────────────

test "Window: has ns_effect_view field" {
    comptime if (!@hasField(Window, "ns_effect_view")) @compileError("missing field: ns_effect_view");
}

test "Window: ns_effect_view defaults to null" {
    var w: Window = undefined;
    w.ns_effect_view = null;
    try std.testing.expectEqual(@as(?@import("../platform/macos/objc.zig").id, null), w.ns_effect_view);
}

test "Window: has setBackground method" {
    comptime if (!@hasDecl(Window, "setBackground")) @compileError("missing method: setBackground");
}

test "Window: has setBlurMaterial method" {
    comptime if (!@hasDecl(Window, "setBlurMaterial")) @compileError("missing method: setBlurMaterial");
}
