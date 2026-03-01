/// wndw — pure Zig windowing library.
///
/// Public API. Dispatches to the platform backend at comptime.
/// Adding a new platform = one new file + one switch branch here.

const builtin = @import("builtin");

const platform = switch (builtin.os.tag) {
    .macos   => @import("platform/macos/window.zig"),
    // .windows => @import("platform/windows/window.zig"),
    // .linux   => @import("platform/linux/x11.zig"),
    else     => @compileError("wndw: platform not yet supported"),
};

// ── Re-exports ────────────────────────────────────────────────────────────────

pub const Window      = platform.Window;
pub const Event       = platform.Event;
pub const Key         = platform.Key;
pub const MouseButton  = @import("event.zig").MouseButton;
pub const Cursor       = @import("event.zig").Cursor;
pub const Modifiers    = @import("event.zig").Modifiers;
pub const KeyEvent     = @import("event.zig").KeyEvent;
pub const Position     = @import("event.zig").Position;
pub const Size         = @import("event.zig").Size;
pub const ScrollDelta  = @import("event.zig").ScrollDelta;
pub const Options      = platform.Options;

// ── Top-level API ─────────────────────────────────────────────────────────────

/// Open a new window. Returns a pointer to heap-allocated Window state.
/// Call `win.close()` when done.
///
/// Example:
///   var win = try wndw.init("hello", 800, 600, .{ .centred = true });
///   defer win.close();
pub fn init(title: [:0]const u8, w: i32, h: i32, opts: Options) !*Window {
    return platform.init(title, w, h, opts);
}
