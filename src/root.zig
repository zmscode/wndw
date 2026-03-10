/// wndw — a pure Zig windowing library.
///
/// This is the public API entry point. All user-facing types are re-exported
/// here so consumers only need `@import("wndw")`. Platform selection happens
/// at comptime via a single switch — adding a new OS means writing one backend
/// file and adding one branch below.
///
/// Architecture overview:
///
///   src/root.zig          ← you are here (public API surface)
///   src/event.zig         ← platform-agnostic event types (Key, Event, etc.)
///   src/event_queue.zig   ← lock-free circular buffer for event delivery
///   src/platform/macos/   ← macOS backend (ObjC runtime, no C files)
///
/// Usage:
///   const wndw = @import("wndw");
///   var win = try wndw.init("hello", 800, 600, .{ .centred = true });
///   defer win.close();
///   while (!win.shouldClose()) {
///       while (win.poll()) |ev| { ... }
///   }
const builtin = @import("builtin");
const event = @import("event.zig");

/// Comptime platform dispatch. Each backend module must export:
///   - `Window` struct with poll/close/shouldClose + all window methods
///   - `Options` struct for window creation hints
///   - `GLHints` struct for OpenGL context configuration
///   - `init(title, w, h, opts) !*Window` constructor
///   - `Renderer` struct for native rendering (used by the UI framework)
const platform = switch (builtin.os.tag) {
    .macos => @import("platform/macos/window.zig"),
    // .windows => @import("platform/windows/window.zig"),
    // .linux   => @import("platform/linux/x11.zig"),
    else => @compileError("wndw: platform not yet supported"),
};

const platform_renderer = switch (builtin.os.tag) {
    .macos => @import("platform/macos/renderer.zig"),
    else => @compileError("wndw: platform renderer not yet supported"),
};

// ── Re-exports ────────────────────────────────────────────────────────────────
// Flatten platform + event types into a single namespace so consumers
// can write `wndw.Key`, `wndw.Event`, etc. without reaching into internals.

pub const Window = platform.Window;
pub const Event = platform.Event;
pub const Key = platform.Key;
pub const MouseButton = event.MouseButton;
pub const Cursor = event.Cursor;
pub const Modifiers = event.Modifiers;
pub const KeyEvent = event.KeyEvent;
pub const Position = event.Position;
pub const Size = event.Size;
pub const ScrollDelta = event.ScrollDelta;
pub const TextInput = event.TextInput;
pub const Appearance = event.Appearance;
pub const Options = platform.Options;
pub const GLHints = platform.GLHints;
pub const Monitor = platform.Monitor;
/// OpenGL function pointer type compatible with zgl's `binding.FunctionPointer`.
pub const FnPtr = Window.FnPtr;
/// Native renderer for drawing UI framework draw commands via platform APIs.
pub const Renderer = platform_renderer.Renderer;

// ── Top-level API ─────────────────────────────────────────────────────────────

/// Create and show a new window. Returns a heap-allocated Window whose
/// lifetime is managed by the caller (call `win.close()` to destroy it).
///
/// The window is immediately visible and receives keyboard focus. On macOS,
/// this also bootstraps the NSApplication singleton on first call.
///
/// Example:
/// ```zig
///   var win = try wndw.init("hello", 800, 600, .{ .centred = true });
///   defer win.close();
/// ```
pub fn init(title: [:0]const u8, w: i32, h: i32, opts: Options) !*Window {
    return platform.init(title, w, h, opts);
}
