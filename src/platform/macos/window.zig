/// macOS window backend — pure ObjC runtime, no C headers needed.
///
/// This file implements the entire macOS windowing stack using only
/// `extern fn` declarations against libobjc and CoreGraphics. Linking
/// `-framework Cocoa` (done in build.zig) pulls in everything we need:
/// libobjc, AppKit, CoreGraphics, and CoreFoundation.
///
/// Key design patterns:
///   - All Cocoa API calls go through `objc.msgSend()`, which casts
///     `objc_msgSend` to the correct function pointer type per-call.
///   - For selectors that take or return structs (NSRect, NSPoint, etc.)
///     we cast `objc_msgSend` to a manually-typed fn pointer. On arm64
///     this is always correct — `objc_msgSend_stret` is x86-only.
///   - The global `g` struct caches the NSApplication instance, ObjC
///     class objects, and the run loop mode string. It's initialised
///     once on the first `init()` call.
///   - Window delegate and custom NSView subclass are registered at
///     runtime via `objc_allocateClassPair` / `class_addMethod`.
const std = @import("std");
const objc = @import("objc.zig");
const cocoa = @import("cocoa.zig");
const event = @import("../../event.zig");

pub const Event = event.Event;
pub const Key = event.Key;

// ── CoreFoundation externs (for getProcAddress via CFBundle) ────────────────
/// These are used exclusively by `getProcAddress()` to load OpenGL function
/// pointers at runtime. CFBundle is more reliable than dlsym for this purpose
/// (matches the approach used by RGFW, GLFW, and other windowing libraries).
extern fn CFBundleGetBundleWithIdentifier(bundleID: *anyopaque) ?*anyopaque;
extern fn CFStringCreateWithCString(alloc: ?*anyopaque, cStr: [*:0]const u8, encoding: u32) ?*anyopaque;
extern fn CFBundleGetFunctionPointerForName(bundle: *anyopaque, name: *anyopaque) ?*anyopaque;
extern fn CFRelease(cf: *anyopaque) void;

/// CoreFoundation string encoding constant for ASCII.
const kCFStringEncodingASCII: u32 = 0x0600;

// ── Carbon / UCKeyTranslate externs (for keyboard layout character resolution) ──

/// Opaque type for keyboard layout data (UCKeyboardLayout*).
const UCKeyboardLayout = anyopaque;

/// Translate a virtual keycode + modifier state into a Unicode string
/// using the current keyboard layout.
extern fn UCKeyTranslate(
    keyLayoutPtr: *const UCKeyboardLayout,
    virtualKeyCode: u16,
    keyAction: u16,
    modifierKeyState: u32,
    keyboardType: u32,
    keyTranslateOptions: u32,
    deadKeyState: *u32,
    maxStringLength: usize,
    actualStringLength: *usize,
    unicodeString: [*]u16,
) i32;

/// Get the current keyboard input source.
extern fn TISCopyCurrentKeyboardLayoutInputSource() ?*anyopaque;
/// Get a property from an input source (returns CFData for "UCKeyboardLayout").
extern fn TISGetInputSourceProperty(inputSource: *anyopaque, propertyKey: *anyopaque) ?*anyopaque;
/// Get a pointer to the bytes inside a CFData object.
extern fn CFDataGetBytePtr(data: *anyopaque) *const UCKeyboardLayout;
/// The property key constant for the Unicode keyboard layout data.
extern var kTISPropertyUnicodeKeyLayoutData: *anyopaque;

/// kUCKeyActionDown
const kUCKeyActionDown: u16 = 0;
/// kUCKeyTranslateNoDeadKeysBit
const kUCKeyTranslateNoDeadKeysMask: u32 = 1;

/// Get the physical keyboard type via IOKit (LMGetKbdType equivalent).
extern fn LMGetKbdType() u8;

// ── CoreVideo / CVDisplayLink externs ────────────────────────────────────────

/// CVDisplayLink opaque type.
const CVDisplayLinkRef = *anyopaque;

/// Callback signature for CVDisplayLink output.
const CVDisplayLinkOutputCallback = *const fn (
    displayLink: CVDisplayLinkRef,
    inNow: *const anyopaque,
    inOutputTime: *const anyopaque,
    flagsIn: u64,
    flagsOut: *u64,
    userInfo: ?*anyopaque,
) callconv(.c) i32;

extern fn CVDisplayLinkCreateWithActiveCGDisplays(linkOut: *?CVDisplayLinkRef) i32;
extern fn CVDisplayLinkSetOutputCallback(link: CVDisplayLinkRef, callback: CVDisplayLinkOutputCallback, userInfo: ?*anyopaque) i32;
extern fn CVDisplayLinkStart(link: CVDisplayLinkRef) i32;
extern fn CVDisplayLinkStop(link: CVDisplayLinkRef) i32;
extern fn CVDisplayLinkRelease(link: CVDisplayLinkRef) void;

// ── Foundation global string constants ──────────────────────────────────────
/// The actual `NSDefaultRunLoopMode` constant from Foundation. Using this
/// instead of creating a string with `ns_string("kCFRunLoopDefaultMode")`
/// ensures pointer-identity with the real run loop mode constant.
extern var NSDefaultRunLoopMode: objc.id;

// ── Options ───────────────────────────────────────────────────────────────────

/// Window creation options passed to `wndw.init()`.
/// All fields default to `false` for a standard titled window.
pub const Options = struct {
    /// Window background style — controls transparency and vibrancy.
    pub const WindowBackground = enum {
        /// Solid opaque background (default).
        solid,
        /// Transparent — clear the background to clear color yourself.
        transparent,
        /// Frosted-glass vibrancy via NSVisualEffectView. The specific look
        /// is controlled by `blur_material`.
        blurred,
        /// Dark HUD-style vibrancy (NSVisualEffectMaterialHUDWindow).
        ultra_dark,
    };

    /// NSVisualEffectView material, used when `background == .blurred`.
    pub const BlurMaterial = enum {
        sidebar,      // NSVisualEffectMaterialSidebar = 7
        popover,      // NSVisualEffectMaterialPopover = 6
        hud,          // NSVisualEffectMaterialHUDWindow = 23
        titlebar,     // NSVisualEffectMaterialTitlebar = 3
        under_window, // NSVisualEffectMaterialUnderWindowBackground = 21
    };

    /// Window kind — controls the underlying Cocoa class and focus behavior.
    pub const WindowKind = enum {
        /// Standard NSWindow — appears in window list, can become key and main.
        normal,
        /// NSPanel with floating window level — stays above normal windows,
        /// does not activate the app when clicked (palette/tool window).
        floating,
        /// NSPanel that does not become key — for tooltips, autocomplete
        /// popups, and other transient UI that shouldn't steal focus.
        popup,
        /// NSPanel presented as a sheet attached to `parent`. Slides down
        /// from the parent's title bar and blocks interaction with it until
        /// dismissed. Requires `parent` to be set.
        dialog,
    };

    /// Centre the window on the primary display.
    centred: bool = false,
    /// Deprecated: use `background = .transparent` instead.
    transparent: bool = false,
    /// Remove the title bar and window chrome entirely. Note: borderless
    /// windows need special handling for minimize/maximize — see the
    /// `minimize()` and `maximize()` methods.
    borderless: bool = false,
    /// Allow the user to resize the window by dragging its edges.
    resizable: bool = false,
    /// Use an inset (transparent) titlebar where content extends behind
    /// the title bar area. The traffic-light buttons remain visible but
    /// the bar itself is transparent, similar to Safari or Finder.
    inset_titlebar: bool = false,
    /// Window background: solid, transparent, blurred, or ultra_dark.
    background: WindowBackground = .solid,
    /// NSVisualEffectView material used when `background == .blurred`.
    blur_material: BlurMaterial = .sidebar,
    /// Window kind — normal (default), floating palette, popup, or dialog.
    kind: WindowKind = .normal,
    /// Parent window for `.dialog` kind (sheet attachment). Ignored for
    /// other kinds. Must be non-null when `kind == .dialog`.
    parent: ?*Window = null,
};

// ── Global app state (initialised once) ───────────────────────────────────────

/// Singleton state for the macOS application. Initialised on the first
/// call to `init()` and never torn down (matches NSApplication's own
/// lifetime). Contains cached ObjC class objects so we don't re-register
/// them on every window creation.
const MAX_LIVE_WINDOWS = 16;

const Global = struct {
    /// The `[NSApplication sharedApplication]` singleton.
    app: objc.id = undefined,
    /// Runtime-created "WndwAppDelegate" class.
    app_delegate_cls: objc.Class = undefined,
    /// Instance of WndwAppDelegate, set as the app's delegate.
    app_delegate: objc.id = undefined,
    /// Runtime-created "WndwWindowDelegate" class (handles resize/move/focus
    /// notifications from AppKit).
    win_delegate_cls: objc.Class = undefined,
    /// Runtime-created "WndwView" NSView subclass (handles mouse tracking,
    /// drag-and-drop, and display scale changes).
    view_cls: objc.Class = undefined,
    /// Retained `NSDefaultRunLoopMode` string, cached to avoid repeated
    /// ObjC string creation on every event drain.
    run_loop_mode: objc.id = undefined,
    initialised: bool = false,
    /// All live windows — used to broadcast app-wide events (e.g. appearance changes).
    live_windows: [MAX_LIVE_WINDOWS]?*Window = .{null} ** MAX_LIVE_WINDOWS,
    /// Last known appearance — used to detect changes and avoid duplicate events.
    last_appearance: event.Appearance = .light,
};
var g: Global = .{};

// ── Event queue ───────────────────────────────────────────────────────────────

const EventQueue = @import("../../event_queue.zig").EventQueue;

// ── Monitor ───────────────────────────────────────────────────────────────────

/// Display/monitor info. Populated from `NSScreen` properties.
pub const Monitor = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    /// Backing scale factor (1.0 = standard, 2.0 = Retina).
    scale: f32,
    /// The underlying NSScreen object (for passing to `moveToMonitor`).
    ns_screen: objc.id,
};

/// Hard limit on monitor enumeration to avoid dynamic allocation.
const MAX_MONITORS = 16;

/// Extract a `Monitor` struct from an NSScreen object by querying
/// its `frame` (geometry) and `backingScaleFactor` (DPI scale).
fn monitor_from_screen(screen: objc.id) Monitor {
    const FnRect = fn (objc.id, objc.SEL) callconv(.c) objc.NSRect;
    const fn_rect: *const FnRect = @ptrCast(&objc.objc_msgSend);
    const frame = fn_rect(screen, objc.sel_registerName("frame"));
    const FnScale = fn (objc.id, objc.SEL) callconv(.c) objc.CGFloat;
    const fn_scale: *const FnScale = @ptrCast(&objc.objc_msgSend);
    const scale: f32 = @floatCast(fn_scale(screen, objc.sel_registerName("backingScaleFactor")));
    return .{
        .x = @intFromFloat(frame.origin.x),
        .y = @intFromFloat(frame.origin.y),
        .w = @intFromFloat(frame.size.width),
        .h = @intFromFloat(frame.size.height),
        .scale = scale,
        .ns_screen = screen,
    };
}

// ── GLHints ──────────────────────────────────────────────────────────────────

/// OpenGL context creation hints. Passed to `Window.createGLContext()`.
///
/// Defaults produce a 3.2 Core profile with 24-bit depth and double buffering,
/// which is the most common configuration for modern OpenGL on macOS.
///
/// Apple deprecated NSOpenGL in favour of Metal (macOS 10.14+), but the
/// OpenGL path still works on macOS 14+ and is the standard cross-platform GL route.
pub const GLHints = struct {
    /// OpenGL major version (3 or 4). Selects the NSOpenGL profile:
    ///   major >= 4 → NSOpenGLProfileVersion4_1Core
    ///   major >= 3 → NSOpenGLProfileVersion3_2Core
    ///   else       → NSOpenGLProfileVersionLegacy
    major: u32 = 3,
    /// OpenGL minor version (informational on macOS — the profile enum
    /// determines the actual version).
    minor: u32 = 2,
    /// Depth buffer bits (0 to disable depth testing).
    depth_bits: u32 = 24,
    /// Stencil buffer bits (0 to disable).
    stencil_bits: u32 = 0,
    /// MSAA sample count (0 to disable multisampling).
    samples: u32 = 0,
    /// Enable double buffering (almost always true).
    double_buffer: bool = true,
    /// Request an sRGB-capable framebuffer.
    srgb: bool = false,
    /// Make the GL surface transparent (for compositing with the desktop).
    transparent: bool = false,
};

// ── Window ────────────────────────────────────────────────────────────────────

/// The main window handle. Heap-allocated by `init()`, destroyed by `close()`.
///
/// Holds the underlying NSWindow/NSView objects, the event queue, input
/// state bitsets, optional callbacks, and OpenGL context (if created).
///
/// Methods fall into three categories:
///   1. Pure state queries (isFocused, getSize, isKeyDown) — no ObjC calls.
///   2. ObjC-backed mutations (setTitle, resize, minimize) — send messages
///      to the NSWindow/NSView.
///   3. OpenGL operations (createGLContext, swapBuffers, getProcAddress).
pub const Window = struct {
    /// The underlying `NSWindow` object.
    ns_window: objc.id,
    /// The content view (`WndwView`, our custom NSView subclass).
    ns_view: objc.id,
    /// The window delegate (`WndwWindowDelegate` instance) — receives
    /// resize/move/focus/close notifications from AppKit.
    ns_delegate: objc.id,
    /// Cached window dimensions (updated by delegate callbacks).
    w: i32,
    h: i32,
    /// Cached window position (updated by delegate callbacks).
    x: i32,
    y: i32,
    /// Internal event ring buffer. Filled by `drain_ns_events()`, consumed
    /// by `poll()`.
    queue: EventQueue = .{},
    /// Set to `true` when the user requests closing (via close button,
    /// Cmd+W, or `win.quit()`). Checked by `shouldClose()`.
    should_close: bool = false,
    /// Previous modifier flags — used by `FlagsChanged` handling to detect
    /// which modifier key was pressed or released (AppKit only tells us
    /// the new flag state, not which key triggered the change).
    prev_flags: usize = 0,
    /// Tracked window state — updated by delegate callbacks.
    is_focused: bool = false,
    is_minimized: bool = false,
    is_visible: bool = true,
    is_borderless: bool = false,
    /// Whether this window was created as an NSPanel (floating/popup/dialog).
    is_panel: bool = false,
    /// Opaque user pointer for associating application data with a window.
    user_ptr: ?*anyopaque = null,
    /// Cursor visibility state (tracked locally since NSCursor hide/unhide
    /// is a global counter, not per-window).
    is_cursor_visible: bool = true,
    /// Per-window appearance override (null = follow system).
    appearance_override: ?event.Appearance = null,
    /// NSVisualEffectView used for blurred/vibrancy backgrounds (null if unused).
    ns_effect_view: ?objc.id = null,
    /// Saved style mask for borderless minimize: restored in the
    /// `windowDidMiniaturize:` delegate after the animation finishes.
    saved_style_mask: ?usize = null,
    /// Drag-and-drop state: number of dropped files and their paths.
    /// Paths point into ObjC-managed memory and are valid until the next
    /// drag operation.
    drop_count: u32 = 0,
    drop_paths: [MAX_DROP_FILES][*:0]const u8 = undefined,
    /// Retained NSString objects backing `drop_paths`. Released on next drop or close().
    drop_strings: [MAX_DROP_FILES]?objc.id = .{null} ** MAX_DROP_FILES,
    /// Per-frame key and mouse button state for `isKeyDown`/`isKeyPressed` etc.
    input_state: InputState = .{},
    /// Optional event callbacks — fire during `dispatchEvent()`.
    callbacks: Callbacks = .{},
    /// Static buffer for text_input event payloads. Overwritten each time
    /// `insertText:` fires; valid until the next `poll()` cycle.
    text_buf: [64]u8 = undefined,
    text_len: usize = 0,
    /// NSOpenGLContext and NSOpenGLPixelFormat (null until `createGLContext` is called).
    gl_context: ?objc.id = null,
    gl_format: ?objc.id = null,
    /// CVDisplayLink handle (null until `createDisplayLink` is called).
    display_link: ?*anyopaque = null,
    /// Atomic flag set by the CVDisplayLink callback on vsync, cleared by `waitForFrame`.
    frame_ready: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    /// OpenGL function pointer type with the alignment that zgl expects.
    /// Matches `zgl.binding.FunctionPointer` so `glGetProcAddress` can be
    /// passed directly to `zgl.loadExtensions()`.
    pub const FnPtr = *align(@alignOf(fn (u32) callconv(.c) u32)) const anyopaque;

    const MAX_DROP_FILES = 64;

    // ── Callbacks ─────────────────────────────────────────────────────────────

    /// Optional function pointers that fire during `dispatchEvent()` (which
    /// is called by `poll()` for each dequeued event). Set them with the
    /// corresponding `setOn*` methods. Set to `null` to unregister.
    ///
    /// Callbacks fire synchronously — they execute inline during `poll()`,
    /// so keep them fast to avoid stalling the event loop.
    /// A callback slot holding a function pointer and an opaque user context.
    /// The context pointer is passed as the first argument to the callback.
    fn Cb(comptime Arg: type) type {
        return struct {
            func: ?*const fn (?*anyopaque, Arg) void = null,
            ctx: ?*anyopaque = null,

            pub inline fn call(self: @This(), arg: Arg) void {
                if (self.func) |f| f(self.ctx, arg);
            }
        };
    }

    /// Callback slot for events with no payload.
    const CbVoid = struct {
        func: ?*const fn (?*anyopaque) void = null,
        ctx: ?*anyopaque = null,

        pub inline fn call(self: CbVoid) void {
            if (self.func) |f| f(self.ctx);
        }
    };

    pub const Callbacks = struct {
        on_key_press: Cb(event.KeyEvent) = .{},
        on_key_release: Cb(event.KeyEvent) = .{},
        on_mouse_press: Cb(event.MouseButton) = .{},
        on_mouse_release: Cb(event.MouseButton) = .{},
        on_mouse_move: Cb(event.Position) = .{},
        on_scroll: Cb(event.ScrollDelta) = .{},
        on_resize: Cb(event.Size) = .{},
        on_move: Cb(event.Position) = .{},
        on_focus_gained: CbVoid = .{},
        on_focus_lost: CbVoid = .{},
        on_close_requested: CbVoid = .{},
        on_minimized: CbVoid = .{},
        on_restored: CbVoid = .{},
        on_maximized: CbVoid = .{},
        on_mouse_entered: CbVoid = .{},
        on_mouse_left: CbVoid = .{},
        on_refresh_requested: CbVoid = .{},
        on_scale_changed: Cb(f32) = .{},
        on_file_drop_started: CbVoid = .{},
        on_file_dropped: Cb(u32) = .{},
        on_file_drop_left: CbVoid = .{},
        on_text_input: Cb(event.TextInput) = .{},
        on_appearance_changed: Cb(event.Appearance) = .{},
    };

    pub fn setOnKeyPress(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque, event.KeyEvent) void) void {
        win.callbacks.on_key_press = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnKeyRelease(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque, event.KeyEvent) void) void {
        win.callbacks.on_key_release = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnMousePress(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque, event.MouseButton) void) void {
        win.callbacks.on_mouse_press = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnMouseRelease(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque, event.MouseButton) void) void {
        win.callbacks.on_mouse_release = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnMouseMove(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque, event.Position) void) void {
        win.callbacks.on_mouse_move = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnScroll(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque, event.ScrollDelta) void) void {
        win.callbacks.on_scroll = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnResize(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque, event.Size) void) void {
        win.callbacks.on_resize = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnMove(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque, event.Position) void) void {
        win.callbacks.on_move = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnFocusGained(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque) void) void {
        win.callbacks.on_focus_gained = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnFocusLost(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque) void) void {
        win.callbacks.on_focus_lost = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnCloseRequested(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque) void) void {
        win.callbacks.on_close_requested = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnMinimized(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque) void) void {
        win.callbacks.on_minimized = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnRestored(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque) void) void {
        win.callbacks.on_restored = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnMaximized(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque) void) void {
        win.callbacks.on_maximized = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnMouseEntered(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque) void) void {
        win.callbacks.on_mouse_entered = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnMouseLeft(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque) void) void {
        win.callbacks.on_mouse_left = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnRefreshRequested(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque) void) void {
        win.callbacks.on_refresh_requested = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnScaleChanged(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque, f32) void) void {
        win.callbacks.on_scale_changed = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnFileDropStarted(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque) void) void {
        win.callbacks.on_file_drop_started = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnFileDropped(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque, u32) void) void {
        win.callbacks.on_file_dropped = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnFileDropLeft(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque) void) void {
        win.callbacks.on_file_drop_left = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnTextInput(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque, event.TextInput) void) void {
        win.callbacks.on_text_input = .{ .func = cb, .ctx = ctx };
    }

    pub fn setOnAppearanceChanged(win: *Window, ctx: ?*anyopaque, cb: ?*const fn (?*anyopaque, event.Appearance) void) void {
        win.callbacks.on_appearance_changed = .{ .func = cb, .ctx = ctx };
    }

    // ── InputState ────────────────────────────────────────────────────────────

    /// Bitset-based key and mouse button state tracking.
    ///
    /// Maintains two frames of state (`current` and `prev`) to support
    /// edge-detection queries:
    ///   - `isKeyDown(k)` — key is held right now
    ///   - `isKeyPressed(k)` — key went down this frame (was up last frame)
    ///   - `isKeyReleased(k)` — key went up this frame (was down last frame)
    ///
    /// `nextFrame()` copies current → prev and is called once per `poll()`
    /// drain cycle (when the Zig-side queue is empty and we're about to
    /// drain fresh OS events).
    pub const InputState = struct {
        /// 3 × u64 = 192 bits, enough for all Key enum variants.
        const KEY_WORDS = 3;
        /// 5 mouse buttons fit in a u8.
        const MOUSE_BITS = 5;

        comptime {
            const key_count = @typeInfo(event.Key).@"enum".fields.len;
            if (KEY_WORDS * 64 < key_count)
                @compileError("KEY_WORDS * 64 must be >= number of Key variants");
            if (MOUSE_BITS < @typeInfo(event.MouseButton).@"enum".fields.len)
                @compileError("MOUSE_BITS must be >= number of MouseButton variants");
        }

        key_current: [KEY_WORDS]u64 = .{ 0, 0, 0 },
        key_prev: [KEY_WORDS]u64 = .{ 0, 0, 0 },
        mouse_current: u8 = 0,
        mouse_prev: u8 = 0,

        /// Compute the word index and bit mask for a given key.
        fn keyBit(key: event.Key) struct { word: usize, mask: u64 } {
            const idx: usize = @intFromEnum(key);
            return .{ .word = idx / 64, .mask = @as(u64, 1) << @intCast(idx % 64) };
        }

        /// Compute the bit mask for a given mouse button.
        fn mouseBit(btn: event.MouseButton) u8 {
            return @as(u8, 1) << @intCast(@intFromEnum(btn));
        }

        /// Mark a key as pressed in the current frame.
        pub fn handleKeyPress(self: *InputState, key: event.Key) void {
            const b = keyBit(key);
            self.key_current[b.word] |= b.mask;
        }

        /// Mark a key as released in the current frame.
        pub fn handleKeyRelease(self: *InputState, key: event.Key) void {
            const b = keyBit(key);
            self.key_current[b.word] &= ~b.mask;
        }

        /// Mark a mouse button as pressed in the current frame.
        pub fn handleMousePress(self: *InputState, btn: event.MouseButton) void {
            self.mouse_current |= mouseBit(btn);
        }

        /// Mark a mouse button as released in the current frame.
        pub fn handleMouseRelease(self: *InputState, btn: event.MouseButton) void {
            self.mouse_current &= ~mouseBit(btn);
        }

        /// Advance to the next frame: copy current state into previous.
        /// Called once at the start of each `poll()` drain cycle.
        pub fn nextFrame(self: *InputState) void {
            self.key_prev = self.key_current;
            self.mouse_prev = self.mouse_current;
        }

        /// Returns `true` if the key is currently held down.
        pub fn isKeyDown(self: *const InputState, key: event.Key) bool {
            const b = keyBit(key);
            return (self.key_current[b.word] & b.mask) != 0;
        }

        /// Returns `true` if the key was just pressed this frame
        /// (down now, was up last frame).
        pub fn isKeyPressed(self: *const InputState, key: event.Key) bool {
            const b = keyBit(key);
            return (self.key_current[b.word] & b.mask) != 0 and (self.key_prev[b.word] & b.mask) == 0;
        }

        /// Returns `true` if the key was just released this frame
        /// (up now, was down last frame).
        pub fn isKeyReleased(self: *const InputState, key: event.Key) bool {
            const b = keyBit(key);
            return (self.key_current[b.word] & b.mask) == 0 and (self.key_prev[b.word] & b.mask) != 0;
        }

        /// Returns `true` if the mouse button is currently held down.
        pub fn isMouseBtnDown(self: *const InputState, btn: event.MouseButton) bool {
            return (self.mouse_current & mouseBit(btn)) != 0;
        }

        /// Returns `true` if the mouse button was just pressed this frame.
        pub fn isMouseBtnPressed(self: *const InputState, btn: event.MouseButton) bool {
            return (self.mouse_current & mouseBit(btn)) != 0 and (self.mouse_prev & mouseBit(btn)) == 0;
        }

        /// Returns `true` if the mouse button was just released this frame.
        pub fn isMouseBtnReleased(self: *const InputState, btn: event.MouseButton) bool {
            return (self.mouse_current & mouseBit(btn)) == 0 and (self.mouse_prev & mouseBit(btn)) != 0;
        }
    };

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    /// Destroy the window and free its memory. Nils the delegate first to
    /// prevent stale callbacks from firing after the Window struct is freed.
    pub fn close(win: *Window) void {
        unregister_live_window(win);
        win.destroyDisplayLink();
        win.deleteContext();
        win.releaseDropStrings();
        objc.msgSend(void, win.ns_window, "setDelegate:", .{@as(?objc.id, null)});
        // Zero the delegate's back-pointer and release it to prevent late
        // AppKit notifications from accessing freed Window memory.
        _ = objc.object_setInstanceVariable(win.ns_delegate, "wndw_win", null);
        objc.msgSend(void, win.ns_delegate, "release", .{});
        objc.msgSend(void, win.ns_window, "orderOut:", .{@as(?objc.id, null)});
        objc.msgSend(void, win.ns_window, "close", .{});
        std.heap.c_allocator.destroy(win);
    }

    /// Returns `true` once `quit()` has been called or the close button was clicked.
    pub fn shouldClose(win: *Window) bool {
        return win.should_close;
    }

    /// Signal that the window should close. The next `shouldClose()` call
    /// will return `true`. Does not immediately destroy the window.
    pub fn quit(win: *Window) void {
        win.should_close = true;
    }

    /// Return the next queued event, or `null` if none remain.
    ///
    /// When the internal Zig-side queue is empty, this drains pending OS
    /// events from the NSApplication run loop into the queue. Each dequeued
    /// event is passed through `dispatchEvent()` which updates input state
    /// bitsets and fires any registered callbacks.
    ///
    /// Typical usage:
    /// ```zig
    /// while (win.poll()) |ev| {
    ///     switch (ev) { ... }
    /// }
    /// ```
    pub fn poll(win: *Window) ?Event {
        if (win.queue.isEmpty()) {
            win.input_state.nextFrame();
            drain_ns_events(win);
        }
        const ev = win.queue.pop() orelse return null;
        win.dispatchEvent(ev);
        return ev;
    }

    /// Update input state and fire callbacks for an event.
    ///
    /// Called by `poll()` for each dequeued event. Exposed publicly so tests
    /// can exercise the callback/input-state logic without needing the ObjC
    /// runtime (which would pull in linker symbols unavailable in test builds).
    pub fn dispatchEvent(win: *Window, ev: Event) void {
        switch (ev) {
            .key_pressed => |kp| {
                win.input_state.handleKeyPress(kp.key);
                win.callbacks.on_key_press.call(kp);
            },
            .key_released => |kr| {
                win.input_state.handleKeyRelease(kr.key);
                win.callbacks.on_key_release.call(kr);
            },
            .mouse_pressed => |btn| {
                win.input_state.handleMousePress(btn);
                win.callbacks.on_mouse_press.call(btn);
            },
            .mouse_released => |btn| {
                win.input_state.handleMouseRelease(btn);
                win.callbacks.on_mouse_release.call(btn);
            },
            .mouse_moved => |pos| win.callbacks.on_mouse_move.call(pos),
            .scroll => |s| win.callbacks.on_scroll.call(s),
            .resized => |r| win.callbacks.on_resize.call(r),
            .moved => |p| win.callbacks.on_move.call(p),
            .focus_gained => win.callbacks.on_focus_gained.call(),
            .focus_lost => win.callbacks.on_focus_lost.call(),
            .close_requested => win.callbacks.on_close_requested.call(),
            .minimized => win.callbacks.on_minimized.call(),
            .restored => win.callbacks.on_restored.call(),
            .maximized => win.callbacks.on_maximized.call(),
            .mouse_entered => win.callbacks.on_mouse_entered.call(),
            .mouse_left => win.callbacks.on_mouse_left.call(),
            .refresh_requested => win.callbacks.on_refresh_requested.call(),
            .scale_changed => |s| win.callbacks.on_scale_changed.call(s),
            .file_drop_started => win.callbacks.on_file_drop_started.call(),
            .file_dropped => |count| win.callbacks.on_file_dropped.call(count),
            .file_drop_left => win.callbacks.on_file_drop_left.call(),
            .text_input => |ti| win.callbacks.on_text_input.call(ti),
            .appearance_changed => |a| win.callbacks.on_appearance_changed.call(a),
        }
    }

    // ── Input state queries ───────────────────────────────────────────────────
    /// Convenience wrappers that delegate to the `InputState` bitsets.
    /// These exist so user code can write `win.isKeyDown(.escape)` instead
    /// of `win.input_state.isKeyDown(.escape)`.
    /// Returns `true` if the key is currently held down.
    pub fn isKeyDown(win: *const Window, key: event.Key) bool {
        return win.input_state.isKeyDown(key);
    }

    /// Returns `true` if the key was just pressed this frame.
    pub fn isKeyPressed(win: *const Window, key: event.Key) bool {
        return win.input_state.isKeyPressed(key);
    }

    /// Returns `true` if the key was just released this frame.
    pub fn isKeyReleased(win: *const Window, key: event.Key) bool {
        return win.input_state.isKeyReleased(key);
    }

    /// Returns `true` if the mouse button is currently held down.
    pub fn isMouseDown(win: *const Window, btn: event.MouseButton) bool {
        return win.input_state.isMouseBtnDown(btn);
    }

    /// Returns `true` if the mouse button was just pressed this frame.
    pub fn isMousePressed(win: *const Window, btn: event.MouseButton) bool {
        return win.input_state.isMouseBtnPressed(btn);
    }

    /// Returns `true` if the mouse button was just released this frame.
    pub fn isMouseReleased(win: *const Window, btn: event.MouseButton) bool {
        return win.input_state.isMouseBtnReleased(btn);
    }

    // ── State queries ──────────────────────────────────────────────────────────

    /// Returns `true` if the window currently has keyboard focus.
    pub fn isFocused(win: *const Window) bool {
        return win.is_focused;
    }

    /// Returns `true` if the window is currently minimised to the dock.
    pub fn isMinimized(win: *const Window) bool {
        return win.is_minimized;
    }

    /// Returns the current content area dimensions in pixels.
    pub fn getSize(win: *const Window) event.Size {
        return .{ .w = win.w, .h = win.h };
    }

    /// Returns the current window position (frame origin in screen coordinates).
    pub fn getPos(win: *const Window) event.Position {
        return .{ .x = win.x, .y = win.y };
    }

    // ── ObjC-backed mutations ──────────────────────────────────────────────────

    /// Change the window title bar text.
    pub fn setTitle(win: *Window, title: [:0]const u8) void {
        objc.msgSend(void, win.ns_window, "setTitle:", .{objc.ns_string(title)});
    }

    /// Resize the window's content area to the given dimensions (in points).
    /// The window position is preserved — only the size changes.
    pub fn resize(win: *Window, w: i32, h: i32) void {
        const FnSetSize = fn (objc.id, objc.SEL, objc.NSSize) callconv(.c) void;
        const fn_set: *const FnSetSize = @ptrCast(&objc.objc_msgSend);
        fn_set(win.ns_window, objc.sel_registerName("setContentSize:"), .{
            .width = @floatFromInt(w),
            .height = @floatFromInt(h),
        });
    }

    /// Move the window to the given screen position (bottom-left origin,
    /// matching Cocoa's coordinate system).
    pub fn move(win: *Window, x: i32, y: i32) void {
        const FnPt = fn (objc.id, objc.SEL, objc.NSPoint) callconv(.c) void;
        const fn_ptr: *const FnPt = @ptrCast(&objc.objc_msgSend);
        const pt = objc.NSPoint{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
        fn_ptr(win.ns_window, objc.sel_registerName("setFrameOrigin:"), pt);
    }

    /// Minimise the window to the dock.
    ///
    /// Borderless windows lack `NSWindowStyleMaskMiniaturizable` by default,
    /// which causes `miniaturize:` to silently do nothing. We work around
    /// this by temporarily adding the flag, calling miniaturize:, then
    /// restoring the original style mask.
    pub fn minimize(win: *Window) void {
        if (win.is_borderless) {
            // Borderless windows lack NSWindowStyleMaskMiniaturizable, so
            // miniaturize: is a no-op. Temporarily add it, then let the
            // windowDidMiniaturize: delegate restore the mask after the
            // animation completes (restoring immediately would race it).
            const style = objc.msgSend(usize, win.ns_window, "styleMask", .{});
            win.saved_style_mask = style;
            objc.msgSend(void, win.ns_window, "setStyleMask:", .{style | cocoa.NSWindowStyleMaskMiniaturizable});
            objc.msgSend(void, win.ns_window, "miniaturize:", .{@as(?objc.id, null)});
        } else {
            objc.msgSend(void, win.ns_window, "miniaturize:", .{@as(?objc.id, null)});
        }
    }

    /// Restore the window from the dock (de-miniaturise).
    pub fn restore(win: *Window) void {
        objc.msgSend(void, win.ns_window, "deminiaturize:", .{@as(?objc.id, null)});
    }

    /// Maximise the window.
    ///
    /// For titled windows, uses `zoom:` (the standard macOS maximise).
    /// For borderless windows, `zoom:` doesn't work reliably — instead we
    /// use `setFrame:display:` to fill the current screen's visible area
    /// (excluding the menu bar and dock).
    pub fn maximize(win: *Window) void {
        if (win.is_borderless) {
            const FnScreen = fn (objc.id, objc.SEL) callconv(.c) ?objc.id;
            const fn_screen: *const FnScreen = @ptrCast(&objc.objc_msgSend);
            const screen = fn_screen(win.ns_window, objc.sel_registerName("screen")) orelse return;
            const FnRect = fn (objc.id, objc.SEL) callconv(.c) objc.NSRect;
            const fn_rect: *const FnRect = @ptrCast(&objc.objc_msgSend);
            const visible = fn_rect(screen, objc.sel_registerName("visibleFrame"));
            const FnSetFrame = fn (objc.id, objc.SEL, objc.NSRect, objc.BOOL) callconv(.c) void;
            const fn_set: *const FnSetFrame = @ptrCast(&objc.objc_msgSend);
            fn_set(win.ns_window, objc.sel_registerName("setFrame:display:"), visible, objc.YES);
        } else {
            objc.msgSend(void, win.ns_window, "zoom:", .{@as(?objc.id, null)});
        }
    }

    /// Enter or leave native fullscreen mode (the macOS green button behaviour).
    /// Only toggles if the current state differs from `enable`.
    pub fn setFullscreen(win: *Window, enable: bool) void {
        const style = objc.msgSend(usize, win.ns_window, "styleMask", .{});
        const is_full = (style & cocoa.NSWindowStyleMaskFullScreen) != 0;
        if (enable != is_full) {
            objc.msgSend(void, win.ns_window, "toggleFullScreen:", .{@as(?objc.id, null)});
        }
    }

    /// Show or hide the mouse cursor. Uses NSCursor's class-level hide/unhide
    /// which operates a global reference count.
    pub fn setCursorVisible(win: *Window, visible: bool) void {
        if (visible == win.is_cursor_visible) return; // avoid unbalancing the global counter
        if (visible) {
            objc.msgSend(void, objc.ns_class("NSCursor"), "unhide", .{});
        } else {
            objc.msgSend(void, objc.ns_class("NSCursor"), "hide", .{});
        }
        win.is_cursor_visible = visible;
    }

    /// Returns `true` if the cursor is currently visible.
    pub fn isCursorVisible(win: *const Window) bool {
        return win.is_cursor_visible;
    }

    /// Query this window's effective appearance (light or dark mode).
    /// Returns the per-window override if set, otherwise the system appearance.
    pub fn getAppearance(win: *const Window) event.Appearance {
        return win.appearance_override orelse query_system_appearance();
    }

    /// Override this window's appearance to light or dark mode, independent
    /// of the system setting. Pass `null` to follow the system appearance.
    pub fn setAppearance(win: *Window, appearance: ?event.Appearance) void {
        win.appearance_override = appearance;
        const ns_appearance: ?objc.id = if (appearance) |a| blk: {
            const name = switch (a) {
                .light => objc.ns_string("NSAppearanceNameAqua"),
                .dark => objc.ns_string("NSAppearanceNameDarkAqua"),
            };
            break :blk objc.msgSend(objc.id, objc.ns_class("NSAppearance"), "appearanceNamed:", .{name});
        } else null;
        objc.msgSend(void, win.ns_window, "setAppearance:", .{ns_appearance});
    }

    /// Set the window background style at runtime. `.blurred` and `.ultra_dark`
    /// use `NSVisualEffectView` (created lazily on first use). `.solid` and
    /// `.transparent` hide the effect view if present.
    pub fn setBackground(win: *Window, bg: Options.WindowBackground) void {
        apply_background(win, bg, .sidebar);
    }

    /// Change the NSVisualEffectView material while keeping the current
    /// background mode. Only has visible effect when `background == .blurred`.
    pub fn setBlurMaterial(win: *Window, material: Options.BlurMaterial) void {
        const ev = win.ns_effect_view orelse return;
        objc.msgSend(void, ev, "setMaterial:", .{blur_material_value(material)});
    }

    /// Set the window to float above all other windows (always-on-top) or
    /// restore normal window level.
    pub fn setAlwaysOnTop(win: *Window, enable: bool) void {
        const level: objc.NSInteger = if (enable) cocoa.NSFloatingWindowLevel else cocoa.NSNormalWindowLevel;
        const FnLvl = fn (objc.id, objc.SEL, objc.NSInteger) callconv(.c) void;
        const fn_ptr: *const FnLvl = @ptrCast(&objc.objc_msgSend);
        fn_ptr(win.ns_window, objc.sel_registerName("setLevel:"), level);
    }

    /// Returns `true` if the window is currently visible (not hidden via `hide()`).
    pub fn isVisible(win: *const Window) bool {
        return win.is_visible;
    }

    /// Returns `true` if the window was created with `borderless: true`.
    pub fn isBorderless(win: *const Window) bool {
        return win.is_borderless;
    }

    /// Returns `true` if the window is currently in native fullscreen mode.
    pub fn isFullscreen(win: *Window) bool {
        const style = objc.msgSend(usize, win.ns_window, "styleMask", .{});
        return (style & cocoa.NSWindowStyleMaskFullScreen) != 0;
    }

    /// Returns `true` if the window is currently zoomed (maximised).
    pub fn isMaximized(win: *Window) bool {
        return objc.msgSend(objc.BOOL, win.ns_window, "isZoomed", .{}) != objc.NO;
    }

    /// Set the window opacity (0.0 = fully transparent, 1.0 = fully opaque).
    pub fn setOpacity(win: *Window, opacity: f32) void {
        const FnAlpha = fn (objc.id, objc.SEL, objc.CGFloat) callconv(.c) void;
        const fn_ptr: *const FnAlpha = @ptrCast(&objc.objc_msgSend);
        const alpha: objc.CGFloat = @floatCast(std.math.clamp(opacity, 0.0, 1.0));
        fn_ptr(win.ns_window, objc.sel_registerName("setAlphaValue:"), alpha);
    }

    /// Bring the window to the front and give it keyboard focus.
    pub fn focus(win: *Window) void {
        objc.msgSend(void, win.ns_window, "makeKeyAndOrderFront:", .{@as(?objc.id, null)});
    }

    /// Hide the window (remove from screen without destroying it).
    pub fn hide(win: *Window) void {
        objc.msgSend(void, win.ns_window, "orderOut:", .{@as(?objc.id, null)});
        win.is_visible = false;
    }

    /// Show a previously hidden window and give it focus.
    pub fn show(win: *Window) void {
        objc.msgSend(void, win.ns_window, "makeKeyAndOrderFront:", .{@as(?objc.id, null)});
        win.is_visible = true;
    }

    /// Centre the window on its current screen.
    pub fn center(win: *Window) void {
        objc.msgSend(void, win.ns_window, "center", .{});
    }

    // ── User pointer ────────────────────────────────────────────────────────

    /// Attach an arbitrary pointer to this window. Useful for associating
    /// application state without globals. Retrieve with `getUserPtr()`.
    pub fn setUserPtr(win: *Window, ptr: ?*anyopaque) void {
        win.user_ptr = ptr;
    }

    /// Retrieve the pointer previously set with `setUserPtr()`, or `null`.
    pub fn getUserPtr(win: *const Window) ?*anyopaque {
        return win.user_ptr;
    }

    // ── Native handles ──────────────────────────────────────────────────────

    /// Returns the underlying `NSWindow` object for interop with native macOS code.
    pub fn getNativeWindow(win: *const Window) objc.id {
        return win.ns_window;
    }

    /// Returns the underlying `NSView` (content view) for interop with native macOS code.
    pub fn getNativeView(win: *const Window) objc.id {
        return win.ns_view;
    }

    // ── Constraints ─────────────────────────────────────────────────────────

    /// Set the minimum allowed content area size (in points).
    pub fn setMinSize(win: *Window, w: i32, h: i32) void {
        const FnSize = fn (objc.id, objc.SEL, objc.NSSize) callconv(.c) void;
        const fn_ptr: *const FnSize = @ptrCast(&objc.objc_msgSend);
        fn_ptr(win.ns_window, objc.sel_registerName("setContentMinSize:"), .{
            .width = @floatFromInt(w),
            .height = @floatFromInt(h),
        });
    }

    /// Set the maximum allowed content area size (in points).
    pub fn setMaxSize(win: *Window, w: i32, h: i32) void {
        const FnSize = fn (objc.id, objc.SEL, objc.NSSize) callconv(.c) void;
        const fn_ptr: *const FnSize = @ptrCast(&objc.objc_msgSend);
        fn_ptr(win.ns_window, objc.sel_registerName("setContentMaxSize:"), .{
            .width = @floatFromInt(w),
            .height = @floatFromInt(h),
        });
    }

    /// Lock the window's content area to a fixed aspect ratio.
    pub fn setAspectRatio(win: *Window, w: i32, h: i32) void {
        const FnSize = fn (objc.id, objc.SEL, objc.NSSize) callconv(.c) void;
        const fn_ptr: *const FnSize = @ptrCast(&objc.objc_msgSend);
        fn_ptr(win.ns_window, objc.sel_registerName("setContentAspectRatio:"), .{
            .width = @floatFromInt(w),
            .height = @floatFromInt(h),
        });
    }

    // ── Clipboard ────────────────────────────────────────────────────────

    /// Read plain text from the system clipboard, or `null` if the clipboard
    /// is empty or doesn't contain text. The returned pointer is backed by
    /// ObjC-managed memory and is valid until the next clipboard operation.
    pub fn clipboardRead(_: *Window) ?[*:0]const u8 {
        const pb = objc.msgSend(objc.id, objc.ns_class("NSPasteboard"), "generalPasteboard", .{});
        const ns_str_type = objc.ns_string("public.utf8-plain-text");
        const ns_str: ?objc.id = objc.msgSend(?objc.id, pb, "stringForType:", .{ns_str_type});
        if (ns_str) |s| {
            return objc.msgSend([*:0]const u8, s, "UTF8String", .{});
        }
        return null;
    }

    /// Write plain text to the system clipboard, replacing any existing content.
    pub fn clipboardWrite(_: *Window, text: [:0]const u8) void {
        const pb = objc.msgSend(objc.id, objc.ns_class("NSPasteboard"), "generalPasteboard", .{});
        objc.msgSend(void, pb, "clearContents", .{});
        const ns_str = objc.ns_string(text.ptr);
        const ns_str_type = objc.ns_string("public.utf8-plain-text");
        _ = objc.msgSend(objc.BOOL, pb, "setString:forType:", .{ ns_str, ns_str_type });
    }

    // ── Drag and drop ────────────────────────────────────────────────────

    /// Enable or disable file drag-and-drop on this window. When enabled,
    /// the view registers for `public.file-url` drags and you'll receive
    /// `.file_drop_started`, `.file_dropped`, and `.file_drop_left` events.
    pub fn setDragAndDrop(win: *Window, enable: bool) void {
        if (enable) {
            const file_url_type = objc.ns_string("public.file-url");
            const array = objc.msgSend(objc.id, objc.ns_class("NSArray"), "arrayWithObject:", .{file_url_type});
            objc.msgSend(void, win.ns_view, "registerForDraggedTypes:", .{array});
        } else {
            objc.msgSend(void, win.ns_view, "unregisterDraggedTypes", .{});
        }
    }

    /// Get the file paths from the most recent drop operation. Returns a
    /// slice of null-terminated UTF-8 strings. Valid until the next drop.
    pub fn getDroppedFiles(win: *const Window) []const [*:0]const u8 {
        return win.drop_paths[0..win.drop_count];
    }

    /// Release retained NSString objects backing drop_paths.
    fn releaseDropStrings(win: *Window) void {
        for (&win.drop_strings) |*slot| {
            if (slot.*) |s| {
                objc.msgSend(void, s, "release", .{});
                slot.* = null;
            }
        }
        win.drop_count = 0;
    }

    // ── Mouse cursor ─────────────────────────────────────────────────────

    /// Warp the mouse cursor to the given screen-absolute position.
    /// Uses `CGWarpMouseCursorPosition` which bypasses mouse acceleration.
    pub fn moveMouse(_: *Window, x: i32, y: i32) void {
        _ = objc.CGWarpMouseCursorPosition(.{
            .x = @floatFromInt(x),
            .y = @floatFromInt(y),
        });
    }

    /// Get the current mouse position in screen coordinates (top-left origin).
    /// Uses `[NSEvent mouseLocation]` and flips Y from Cocoa's bottom-left
    /// origin to a top-left origin.
    pub fn getMousePos(_: *Window) event.Position {
        const loc = objc.msgSend(objc.NSPoint, objc.ns_class("NSEvent"), "mouseLocation", .{});

        // Find the screen containing the cursor for correct Y flip.
        const FnRect = fn (objc.id, objc.SEL) callconv(.c) objc.NSRect;
        const fn_rect: *const FnRect = @ptrCast(&objc.objc_msgSend);
        const FnIdx = fn (objc.id, objc.SEL, objc.NSUInteger) callconv(.c) objc.id;
        const fn_idx: *const FnIdx = @ptrCast(&objc.objc_msgSend);

        const screens = objc.msgSend(objc.id, objc.ns_class("NSScreen"), "screens", .{});
        const count = objc.msgSend(objc.NSUInteger, screens, "count", .{});
        var screen_frame: objc.NSRect = undefined;
        var found = false;

        var i: objc.NSUInteger = 0;
        while (i < count) : (i += 1) {
            const scr = fn_idx(screens, objc.sel_registerName("objectAtIndex:"), i);
            const sf = fn_rect(scr, objc.sel_registerName("frame"));
            if (loc.x >= sf.origin.x and loc.x < sf.origin.x + sf.size.width and
                loc.y >= sf.origin.y and loc.y < sf.origin.y + sf.size.height)
            {
                screen_frame = sf;
                found = true;
                break;
            }
        }

        if (!found) {
            // Fallback to main screen if cursor is between screens.
            screen_frame = fn_rect(
                objc.msgSend(objc.id, objc.ns_class("NSScreen"), "mainScreen", .{}),
                objc.sel_registerName("frame"),
            );
        }

        return .{
            .x = @intFromFloat(loc.x - screen_frame.origin.x),
            .y = @intFromFloat((screen_frame.origin.y + screen_frame.size.height) - loc.y),
        };
    }

    /// Set the mouse cursor to one of the standard system cursor shapes.
    pub fn setStandardCursor(_: *Window, cursor: @import("../../event.zig").Cursor) void {
        const sel_name: [*:0]const u8 = switch (cursor) {
            .arrow => "arrowCursor",
            .ibeam => "IBeamCursor",
            .crosshair => "crosshairCursor",
            .closed_hand => "closedHandCursor",
            .open_hand => "openHandCursor",
            .pointing_hand => "pointingHandCursor",
            .resize_left_right => "resizeLeftRightCursor",
            .resize_up_down => "resizeUpDownCursor",
            .not_allowed => "operationNotAllowedCursor",
        };
        const ns_cursor = objc.msgSend(objc.id, objc.ns_class("NSCursor"), sel_name, .{});
        objc.msgSend(void, ns_cursor, "set", .{});
    }

    /// Reset the cursor to the default arrow.
    pub fn resetCursor(_: *Window) void {
        const arrow = objc.msgSend(objc.id, objc.ns_class("NSCursor"), "arrowCursor", .{});
        objc.msgSend(void, arrow, "set", .{});
    }

    // ── Attention request ───────────────────────────────────────────────────

    /// Bounce the application's dock icon once to request user attention.
    pub fn flash(_: *Window) void {
        const app = objc.msgSend(objc.id, objc.objc_getClass("NSApplication"), "sharedApplication", .{});
        const FnAttn = fn (objc.id, objc.SEL, objc.NSUInteger) callconv(.c) void;
        const fn_ptr: *const FnAttn = @ptrCast(&objc.objc_msgSend);
        fn_ptr(app, objc.sel_registerName("requestUserAttention:"), 10); // NSInformationalRequest
    }

    // ── Monitor/display ─────────────────────────────────────────────────────

    /// Returns info about the primary (main) display.
    pub fn getPrimaryMonitor(_: *Window) Monitor {
        const screen = objc.msgSend(objc.id, objc.ns_class("NSScreen"), "mainScreen", .{});
        return monitor_from_screen(screen);
    }

    /// Returns info about the display the window is currently on.
    /// Returns the primary monitor as a fallback if the window is off-screen
    /// (e.g. minimized to the dock).
    pub fn getWindowMonitor(win: *Window) Monitor {
        const FnScreen = fn (objc.id, objc.SEL) callconv(.c) ?objc.id;
        const fn_screen: *const FnScreen = @ptrCast(&objc.objc_msgSend);
        const screen = fn_screen(win.ns_window, objc.sel_registerName("screen")) orelse
            objc.msgSend(objc.id, objc.ns_class("NSScreen"), "mainScreen", .{});
        return monitor_from_screen(screen);
    }

    /// Returns a slice of all connected monitors (up to `MAX_MONITORS`).
    ///
    /// **Important:** The returned slice points into a static buffer that is
    /// overwritten on every call. Copy the data if you need it to persist
    /// beyond the next call to `getMonitors`.
    pub fn getMonitors(_: *Window) []const Monitor {
        const screens = objc.msgSend(objc.id, objc.ns_class("NSScreen"), "screens", .{});
        const count = objc.msgSend(objc.NSUInteger, screens, "count", .{});
        const n = @min(count, MAX_MONITORS);

        const S = struct {
            var buf: [MAX_MONITORS]Monitor = undefined;
        };

        var i: objc.NSUInteger = 0;
        while (i < n) : (i += 1) {
            const FnObjAtIdx = fn (objc.id, objc.SEL, objc.NSUInteger) callconv(.c) objc.id;
            const fn_idx: *const FnObjAtIdx = @ptrCast(&objc.objc_msgSend);
            const screen = fn_idx(screens, objc.sel_registerName("objectAtIndex:"), i);
            S.buf[i] = monitor_from_screen(screen);
        }
        return S.buf[0..n];
    }

    /// Move the window to the given monitor, preserving its current size.
    pub fn moveToMonitor(win: *Window, mon: Monitor) void {
        const FnRect = fn (objc.id, objc.SEL) callconv(.c) objc.NSRect;
        const fn_rect: *const FnRect = @ptrCast(&objc.objc_msgSend);
        const cur_frame = fn_rect(win.ns_window, objc.sel_registerName("frame"));

        const new_frame = objc.NSRect{
            .origin = .{
                .x = @floatFromInt(mon.x),
                .y = @floatFromInt(mon.y),
            },
            .size = cur_frame.size,
        };
        const FnSetFrame = fn (objc.id, objc.SEL, objc.NSRect, objc.BOOL) callconv(.c) void;
        const fn_set: *const FnSetFrame = @ptrCast(&objc.objc_msgSend);
        fn_set(win.ns_window, objc.sel_registerName("setFrame:display:"), new_frame, objc.YES);
    }

    // ── OpenGL context ────────────────────────────────────────────────────

    /// Create an NSOpenGL context and attach it to this window's view.
    ///
    /// Builds a pixel format attribute array from the given hints, creates
    /// an `NSOpenGLPixelFormat` + `NSOpenGLContext`, and makes it current.
    /// Call `deleteContext()` to clean up, or let `close()` handle it.
    pub fn createGLContext(win: *Window, hints: GLHints) !void {
        // Clean up any existing context before creating a new one.
        if (win.gl_context != null) win.deleteContext();

        // Build null-terminated attribute array for NSOpenGLPixelFormat.
        var attrs: [30]u32 = undefined;
        var i: usize = 0;

        attrs[i] = cocoa.NSOpenGLPFAColorSize;
        i += 1;
        attrs[i] = 8;
        i += 1;
        attrs[i] = cocoa.NSOpenGLPFAAlphaSize;
        i += 1;
        attrs[i] = 8;
        i += 1;
        attrs[i] = cocoa.NSOpenGLPFADepthSize;
        i += 1;
        attrs[i] = hints.depth_bits;
        i += 1;
        attrs[i] = cocoa.NSOpenGLPFAStencilSize;
        i += 1;
        attrs[i] = hints.stencil_bits;
        i += 1;

        if (hints.samples > 0) {
            attrs[i] = cocoa.NSOpenGLPFASampleBuffers;
            i += 1;
            attrs[i] = 1;
            i += 1;
            attrs[i] = cocoa.NSOpenGLPFASamples;
            i += 1;
            attrs[i] = hints.samples;
            i += 1;
        }

        if (hints.double_buffer) {
            attrs[i] = cocoa.NSOpenGLPFADoubleBuffer;
            i += 1;
        }

        attrs[i] = cocoa.NSOpenGLPFAClosestPolicy;
        i += 1;
        attrs[i] = cocoa.NSOpenGLPFAAccelerated;
        i += 1;

        // Profile selection (note: RGFW had a bug where 4_1Core = 0x3200)
        attrs[i] = cocoa.NSOpenGLPFAOpenGLProfile;
        i += 1;
        attrs[i] = if (hints.major >= 4)
            cocoa.NSOpenGLProfileVersion4_1Core
        else if (hints.major >= 3)
            cocoa.NSOpenGLProfileVersion3_2Core
        else
            cocoa.NSOpenGLProfileVersionLegacy;
        i += 1;

        attrs[i] = 0; // null terminator

        // Create pixel format
        const FnInitAttrs = fn (objc.id, objc.SEL, [*]const u32) callconv(.c) ?objc.id;
        const fn_init_attrs: *const FnInitAttrs = @ptrCast(&objc.objc_msgSend);
        const fmt_alloc = objc.msgSend(objc.id, objc.ns_class("NSOpenGLPixelFormat"), "alloc", .{});
        const fmt = fn_init_attrs(fmt_alloc, objc.sel_registerName("initWithAttributes:"), &attrs) orelse
            return error.PixelFormatFailed;

        // Create context
        const FnInitCtx = fn (objc.id, objc.SEL, objc.id, ?objc.id) callconv(.c) ?objc.id;
        const fn_init_ctx: *const FnInitCtx = @ptrCast(&objc.objc_msgSend);
        const ctx_alloc = objc.msgSend(objc.id, objc.ns_class("NSOpenGLContext"), "alloc", .{});
        const ctx = fn_init_ctx(ctx_alloc, objc.sel_registerName("initWithFormat:shareContext:"), fmt, null) orelse {
            objc.msgSend(void, fmt, "release", .{});
            return error.ContextCreationFailed;
        };

        // Attach to view
        objc.msgSend(void, ctx, "setView:", .{win.ns_view});
        objc.msgSend(void, win.ns_view, "setWantsLayer:", .{objc.YES});

        // Transparent surface if requested
        if (hints.transparent) {
            var opacity: i32 = 0;
            const FnSetValues = fn (objc.id, objc.SEL, *const i32, i32) callconv(.c) void;
            const fn_sv: *const FnSetValues = @ptrCast(&objc.objc_msgSend);
            fn_sv(ctx, objc.sel_registerName("setValues:forParameter:"), &opacity, cocoa.NSOpenGLContextParameterSurfaceOpacity);
        }

        objc.msgSend(void, ctx, "makeCurrentContext", .{});
        win.gl_context = ctx;
        win.gl_format = fmt;
        win.setSwapInterval(0);
    }

    /// Make this window's GL context the current context for the calling thread.
    pub fn makeContextCurrent(win: *Window) void {
        if (win.gl_context) |ctx| {
            objc.msgSend(void, ctx, "makeCurrentContext", .{});
        }
    }

    /// Swap the front and back buffers (present the rendered frame).
    pub fn swapBuffers(win: *Window) void {
        if (win.gl_context) |ctx| {
            objc.msgSend(void, ctx, "flushBuffer", .{});
        }
    }

    /// Set the swap interval (0 = no vsync, 1 = vsync).
    pub fn setSwapInterval(win: *Window, interval: i32) void {
        if (win.gl_context) |ctx| {
            var val = interval;
            const FnSetValues = fn (objc.id, objc.SEL, *const i32, i32) callconv(.c) void;
            const fn_sv: *const FnSetValues = @ptrCast(&objc.objc_msgSend);
            fn_sv(ctx, objc.sel_registerName("setValues:forParameter:"), &val, cocoa.NSOpenGLContextParameterSwapInterval);
        }
    }

    /// Destroy the GL context and pixel format.
    pub fn deleteContext(win: *Window) void {
        if (win.gl_context) |ctx| {
            // Only clear the thread's current context if it belongs to this window,
            // so other windows' GL contexts are not disturbed.
            const FnCur = fn (objc.id, objc.SEL) callconv(.c) ?objc.id;
            const fn_cur: *const FnCur = @ptrCast(&objc.objc_msgSend);
            const current = fn_cur(objc.ns_class("NSOpenGLContext"), objc.sel_registerName("currentContext"));
            if (current) |cur| {
                if (cur == ctx) {
                    objc.msgSend(void, objc.ns_class("NSOpenGLContext"), "clearCurrentContext", .{});
                }
            }
            objc.msgSend(void, ctx, "release", .{});
            win.gl_context = null;
        }
        if (win.gl_format) |fmt| {
            objc.msgSend(void, fmt, "release", .{});
            win.gl_format = null;
        }
    }

    /// Sends `[NSOpenGLContext update]` if an OpenGL context is attached.
    /// Called automatically on resize; exposed for manual use if needed.
    pub fn updateGLContextIfNeeded(win: *Window) void {
        if (win.gl_context) |ctx| {
            objc.msgSend(void, ctx, "update", .{});
        }
    }

    /// Load an OpenGL function pointer by name at runtime.
    ///
    /// Uses CFBundle to look up symbols in the `com.apple.opengl` framework.
    /// The bundle handle is cached on first call. Returns `null` if the
    /// function is not found.
    pub fn getProcAddress(_: *Window, name: [*:0]const u8) ?*anyopaque {
        const S = struct {
            var bundle: ?*anyopaque = null;
        };
        if (S.bundle == null) {
            const bundle_id = CFStringCreateWithCString(null, "com.apple.opengl", kCFStringEncodingASCII) orelse return null;
            defer CFRelease(bundle_id);
            S.bundle = CFBundleGetBundleWithIdentifier(bundle_id);
        }
        const bundle = S.bundle orelse return null;
        const cf_name = CFStringCreateWithCString(null, name, kCFStringEncodingASCII) orelse return null;
        defer CFRelease(cf_name);
        return CFBundleGetFunctionPointerForName(bundle, cf_name);
    }

    /// OpenGL proc-address loader compatible with zgl's `loadExtensions`.
    ///
    /// Thin adapter around `getProcAddress` that converts the string type
    /// (`[:0]const u8` → `[*:0]const u8`) and adds the alignment cast that
    /// zgl requires for its `binding.FunctionPointer` type.
    ///
    /// Usage with zgl:
    /// ```zig
    /// const gl = @import("zgl");
    /// try gl.loadExtensions(&win, wndw.Window.glGetProcAddress);
    /// ```
    pub fn glGetProcAddress(win: *Window, name: [:0]const u8) ?FnPtr {
        const raw = win.getProcAddress(name.ptr) orelse return null;
        return @ptrCast(@alignCast(raw));
    }

    // ── CVDisplayLink ────────────────────────────────────────────────────────

    /// Create and start a CVDisplayLink for this window. The display link
    /// fires on every vsync and sets `frame_ready` to `true`. Call
    /// `waitForFrame()` in your render loop to block until the next vsync.
    ///
    /// Only one display link per window. Calling again is a no-op.
    pub fn createDisplayLink(win: *Window) !void {
        if (win.display_link != null) return;
        var link: ?CVDisplayLinkRef = null;
        if (CVDisplayLinkCreateWithActiveCGDisplays(&link) != 0) return error.DisplayLinkFailed;
        const dl = link orelse return error.DisplayLinkFailed;
        if (CVDisplayLinkSetOutputCallback(dl, &display_link_callback, win) != 0) {
            CVDisplayLinkRelease(dl);
            return error.DisplayLinkFailed;
        }
        if (CVDisplayLinkStart(dl) != 0) {
            CVDisplayLinkRelease(dl);
            return error.DisplayLinkFailed;
        }
        win.display_link = dl;
    }

    /// Stop the CVDisplayLink. Safe to call if none exists.
    /// Note: intentionally does not call CVDisplayLinkRelease — the background
    /// timer thread may still be accessing it (same pattern as GPUI).
    pub fn destroyDisplayLink(win: *Window) void {
        if (win.display_link) |dl| {
            _ = CVDisplayLinkStop(dl);
            win.display_link = null;
        }
    }

    /// Block until the next vsync (display link fires). Returns immediately
    /// if no display link is active. Clears the `frame_ready` flag.
    pub fn waitForFrame(win: *Window) void {
        if (win.display_link == null) return;
        while (!win.frame_ready.load(.acquire)) {
            std.atomic.spinLoopHint();
        }
        win.frame_ready.store(false, .release);
    }
};

// ── Background helpers ────────────────────────────────────────────────────────

fn blur_material_value(material: Options.BlurMaterial) objc.NSInteger {
    return switch (material) {
        .sidebar => cocoa.NSVisualEffectMaterialSidebar,
        .popover => cocoa.NSVisualEffectMaterialPopover,
        .hud => cocoa.NSVisualEffectMaterialHUDWindow,
        .titlebar => cocoa.NSVisualEffectMaterialTitlebar,
        .under_window => cocoa.NSVisualEffectMaterialUnderWindowBackground,
    };
}

/// Create an NSVisualEffectView sized to fill the window content area and
/// configure it with the specified material. The caller is responsible for
/// inserting it into the view hierarchy. Returns an object with retain +1.
fn create_effect_view(content_rect: objc.NSRect, material: objc.NSInteger) objc.id {
    const FnInitFrame = fn (objc.id, objc.SEL, objc.NSRect) callconv(.c) objc.id;
    const fn_init: *const FnInitFrame = @ptrCast(&objc.objc_msgSend);
    const ev = fn_init(
        objc.msgSend(objc.id, objc.ns_class("NSVisualEffectView"), "alloc", .{}),
        objc.sel_registerName("initWithFrame:"),
        content_rect,
    );
    objc.msgSend(void, ev, "setMaterial:", .{material});
    objc.msgSend(void, ev, "setBlendingMode:", .{cocoa.NSVisualEffectBlendingModeBehindWindow});
    objc.msgSend(void, ev, "setState:", .{cocoa.NSVisualEffectStateActive});
    objc.msgSend(void, ev, "setAutoresizingMask:", .{cocoa.NSViewWidthSizable | cocoa.NSViewHeightSizable});
    return ev;
}

/// Apply a background mode to an already-created window. Creates the
/// NSVisualEffectView lazily on first blurred/ultra_dark request.
fn apply_background(win: *Window, bg: Options.WindowBackground, material: Options.BlurMaterial) void {
    switch (bg) {
        .solid => {
            if (win.ns_effect_view) |ev| objc.msgSend(void, ev, "setHidden:", .{objc.YES});
            objc.msgSend(void, win.ns_window, "setOpaque:", .{objc.YES});
            const col = objc.msgSend(objc.id, objc.ns_class("NSColor"), "windowBackgroundColor", .{});
            objc.msgSend(void, win.ns_window, "setBackgroundColor:", .{col});
        },
        .transparent => {
            if (win.ns_effect_view) |ev| objc.msgSend(void, ev, "setHidden:", .{objc.YES});
            objc.msgSend(void, win.ns_window, "setOpaque:", .{objc.NO});
            const col = objc.msgSend(objc.id, objc.ns_class("NSColor"), "clearColor", .{});
            objc.msgSend(void, win.ns_window, "setBackgroundColor:", .{col});
        },
        .blurred, .ultra_dark => {
            // Lazily create the effect view if not yet present.
            if (win.ns_effect_view == null) {
                const FnRect = fn (objc.id, objc.SEL) callconv(.c) objc.NSRect;
                const fn_bounds: *const FnRect = @ptrCast(&objc.objc_msgSend);
                const bounds = fn_bounds(win.ns_view, objc.sel_registerName("bounds"));
                const ev = create_effect_view(bounds, 0);
                win.ns_effect_view = ev;
                // Insert behind WndwView in the content view's subview list.
                // NSWindowBelow = -1 places it as the backmost subview.
                const FnAddSubview = fn (objc.id, objc.SEL, objc.id, objc.NSInteger, ?objc.id) callconv(.c) void;
                const fn_add: *const FnAddSubview = @ptrCast(&objc.objc_msgSend);
                fn_add(win.ns_view, objc.sel_registerName("addSubview:positioned:relativeTo:"), ev, -1, null);
            }
            const ev = win.ns_effect_view.?;
            const mat: objc.NSInteger = if (bg == .ultra_dark)
                cocoa.NSVisualEffectMaterialHUDWindow
            else
                blur_material_value(material);
            objc.msgSend(void, ev, "setMaterial:", .{mat});
            objc.msgSend(void, ev, "setHidden:", .{objc.NO});
            objc.msgSend(void, win.ns_window, "setOpaque:", .{objc.NO});
            const col = objc.msgSend(objc.id, objc.ns_class("NSColor"), "clearColor", .{});
            objc.msgSend(void, win.ns_window, "setBackgroundColor:", .{col});
        },
    }
}

// ── init ──────────────────────────────────────────────────────────────────────

/// Create and show a new window. Bootstraps NSApplication on first call.
pub fn init(title: [:0]const u8, w: i32, h: i32, opts: Options) !*Window {
    if (w <= 0 or h <= 0) return error.InvalidDimensions;
    if (!g.initialised) try setup_app();

    const win = try std.heap.c_allocator.create(Window);
    win.* = .{
        .ns_window = undefined,
        .ns_view = undefined,
        .ns_delegate = undefined,
        .w = w,
        .h = h,
        .x = 0,
        .y = 0,
    };

    // Cocoa uses bottom-left origin — compute the screen height for Y-flip.
    const screen = objc.msgSend(objc.id, objc.ns_class("NSScreen"), "mainScreen", .{});
    const frame = objc.msgSend(objc.NSRect, screen, "frame", .{});
    const screen_h = frame.size.height;

    // Build NSWindowStyleMask from Options.
    const use_panel = opts.kind != .normal;
    var mask: usize = cocoa.NSWindowStyleMaskTitled |
        cocoa.NSWindowStyleMaskClosable |
        cocoa.NSWindowStyleMaskMiniaturizable;
    if (opts.resizable) mask |= cocoa.NSWindowStyleMaskResizable;
    if (opts.inset_titlebar) mask |= cocoa.NSWindowStyleMaskFullSizeContentView;
    if (opts.borderless) mask = cocoa.NSWindowStyleMaskBorderless;
    // Floating and popup panels use NSNonactivatingPanel so they don't
    // steal focus from the main window.
    if (opts.kind == .floating or opts.kind == .popup)
        mask |= cocoa.NSWindowStyleMaskNonactivatingPanel;

    // Compute initial position (centred or top-left).
    const cx: f64 = if (opts.centred)
        (frame.size.width - @as(f64, @floatFromInt(w))) / 2.0
    else
        0.0;
    const cy: f64 = screen_h - @as(f64, @floatFromInt(h)) -
        if (opts.centred)
            (screen_h - @as(f64, @floatFromInt(h))) / 2.0
        else
            0.0;

    const rect = objc.NSRect{
        .origin = .{ .x = cx, .y = cy },
        .size = .{ .width = @floatFromInt(w), .height = @floatFromInt(h) },
    };

    // Create NSWindow or NSPanel depending on window kind.
    const win_cls = if (use_panel) objc.ns_class("NSPanel") else objc.ns_class("NSWindow");
    const FnType = fn (objc.id, objc.SEL, objc.NSRect, usize, usize, objc.BOOL) callconv(.c) objc.id;
    const init_sel = objc.sel_registerName("initWithContentRect:styleMask:backing:defer:");
    const fn_ptr: *const FnType = @ptrCast(&objc.objc_msgSend);
    const ns_win_alloc = objc.msgSend(objc.id, win_cls, "alloc", .{});
    const ns_win = fn_ptr(
        ns_win_alloc,
        init_sel,
        rect,
        mask,
        cocoa.NSBackingStoreBuffered,
        objc.NO,
    );
    win.ns_window = ns_win;
    win.is_borderless = opts.borderless;
    win.is_panel = use_panel;

    // Configure panel-specific behavior.
    if (use_panel) {
        // Floating panels: always-on-top, does not hide on deactivate.
        if (opts.kind == .floating) {
            const FnLvl = fn (objc.id, objc.SEL, objc.NSInteger) callconv(.c) void;
            const fn_lvl: *const FnLvl = @ptrCast(&objc.objc_msgSend);
            fn_lvl(ns_win, objc.sel_registerName("setLevel:"), cocoa.NSFloatingWindowLevel);
            objc.msgSend(void, ns_win, "setHidesOnDeactivate:", .{objc.NO});
        }
        // Popup panels: don't become key window (becomesKeyOnlyIfNeeded).
        if (opts.kind == .popup) {
            objc.msgSend(void, ns_win, "setBecomesKeyOnlyIfNeeded:", .{objc.YES});
        }
        // Floating panels: respond to keyboard without becoming key.
        if (opts.kind == .floating) {
            objc.msgSend(void, ns_win, "setFloatingPanel:", .{objc.YES});
        }
    }

    // Allow native fullscreen via the green title bar button / toggleFullScreen:.
    // (Only for normal windows — panels don't support fullscreen.)
    if (!use_panel) {
        const FnSetBehavior = fn (objc.id, objc.SEL, objc.NSUInteger) callconv(.c) void;
        const fn_behav: *const FnSetBehavior = @ptrCast(&objc.objc_msgSend);
        fn_behav(ns_win, objc.sel_registerName("setCollectionBehavior:"), cocoa.NSWindowCollectionBehaviorFullScreenPrimary);
    }

    objc.msgSend(void, ns_win, "setTitle:", .{objc.ns_string(title)});

    // Create and attach the window delegate (for resize/move/focus callbacks).
    const delegate = objc.msgSend(objc.id, objc.msgSend(objc.id, g.win_delegate_cls, "alloc", .{}), "init", .{});
    _ = objc.object_setInstanceVariable(delegate, "wndw_win", win);
    objc.msgSend(void, ns_win, "setDelegate:", .{delegate});
    win.ns_delegate = delegate;

    // Create and attach our custom NSView subclass.
    const FnTypeView = fn (objc.id, objc.SEL, *Window) callconv(.c) objc.id;
    const view_init_sel = objc.sel_registerName("initWithWndwWindow:");
    const fn_ptr_view: *const FnTypeView = @ptrCast(&objc.objc_msgSend);
    const view_alloc = objc.msgSend(objc.id, g.view_cls, "alloc", .{});
    const ns_view = fn_ptr_view(view_alloc, view_init_sel, win);
    win.ns_view = ns_view;
    objc.msgSend(void, ns_win, "setContentView:", .{ns_view});

    // Set up mouse tracking area for mouseEntered:/mouseExited: events.
    objc.msgSend(void, ns_win, "setAcceptsMouseMovedEvents:", .{objc.YES});

    const tracking_opts: objc.NSUInteger = (0x01 | 0x80 | 0x200); // MouseEnteredAndExited | ActiveAlways | InVisibleRect
    const FnTrackInit = fn (objc.id, objc.SEL, objc.NSRect, objc.NSUInteger, ?objc.id, ?*anyopaque) callconv(.c) objc.id;
    const fn_track: *const FnTrackInit = @ptrCast(&objc.objc_msgSend);
    const FnRect = fn (objc.id, objc.SEL) callconv(.c) objc.NSRect;
    const fn_bounds: *const FnRect = @ptrCast(&objc.objc_msgSend);
    const bounds = fn_bounds(ns_view, objc.sel_registerName("bounds"));
    const tracking_area = fn_track(
        objc.msgSend(objc.id, objc.ns_class("NSTrackingArea"), "alloc", .{}),
        objc.sel_registerName("initWithRect:options:owner:userInfo:"),
        bounds,
        tracking_opts,
        ns_view,
        null,
    );
    objc.msgSend(void, ns_view, "addTrackingArea:", .{tracking_area});
    objc.msgSend(void, tracking_area, "release", .{}); // balance alloc/init; view retains its own ref

    // Apply background mode. `transparent: true` is the legacy alias for `.transparent`.
    const bg: Options.WindowBackground = if (opts.transparent) .transparent else opts.background;
    apply_background(win, bg, opts.blur_material);

    if (opts.inset_titlebar) {
        objc.msgSend(void, ns_win, "setTitlebarAppearsTransparent:", .{objc.YES});
        objc.msgSend(void, ns_win, "setTitleVisibility:", .{@as(objc.NSInteger, 1)}); // NSWindowTitleHidden
    }

    // Make the view first responder so key events route to it.
    objc.msgSend(void, ns_win, "makeFirstResponder:", .{ns_view});

    // Show the window. Dialogs are presented as sheets on the parent;
    // other kinds are shown normally.
    if (opts.kind == .dialog) {
        if (opts.parent) |parent| {
            // beginSheet:completionHandler: presents as a modal sheet.
            const FnSheet = fn (objc.id, objc.SEL, objc.id, ?objc.id) callconv(.c) void;
            const fn_sheet: *const FnSheet = @ptrCast(&objc.objc_msgSend);
            fn_sheet(parent.ns_window, objc.sel_registerName("beginSheet:completionHandler:"), ns_win, null);
        } else {
            // Fallback: no parent, show as a normal window.
            objc.msgSend(void, ns_win, "makeKeyAndOrderFront:", .{@as(?objc.id, null)});
        }
    } else {
        objc.msgSend(void, ns_win, "makeKeyAndOrderFront:", .{@as(?objc.id, null)});
    }
    objc.msgSend(void, g.app, "activateIgnoringOtherApps:", .{objc.YES});

    // Read back the actual window position from AppKit so win.x/win.y are
    // consistent with what delegate_window_did_move stores (raw Cocoa coords).
    const FnActualFrame = fn (objc.id, objc.SEL) callconv(.c) objc.NSRect;
    const fn_actual: *const FnActualFrame = @ptrCast(&objc.objc_msgSend);
    const actual_frame = fn_actual(ns_win, objc.sel_registerName("frame"));
    win.x = @intFromFloat(actual_frame.origin.x);
    win.y = @intFromFloat(actual_frame.origin.y);

    register_live_window(win);

    return win;
}

// ── NSApp event drain ─────────────────────────────────────────────────────────

/// Drain all pending NSEvents from the application run loop and translate
/// them into wndw Events. Called by `poll()` when the queue is empty.
fn drain_ns_events(win: *Window) void {
    // Wrap the drain in an autorelease pool so autoreleased objects created by
    // nextEventMatchingMask: and sendEvent: are collected each frame rather
    // than accumulating indefinitely.
    const pool = objc.msgSend(objc.id, objc.msgSend(objc.id, objc.ns_class("NSAutoreleasePool"), "alloc", .{}), "init", .{});
    defer objc.msgSend(void, pool, "drain", .{});

    const mode = g.run_loop_mode;
    const FnNext = fn (objc.id, objc.SEL, usize, ?objc.id, objc.id, objc.BOOL) callconv(.c) ?objc.id;
    const next_sel = objc.sel_registerName("nextEventMatchingMask:untilDate:inMode:dequeue:");
    const fn_next: *const FnNext = @ptrCast(&objc.objc_msgSend);

    while (true) {
        const ns_ev = fn_next(g.app, next_sel, cocoa.NSEventMaskAny, null, mode, objc.YES) orelse break;

        // Read event data BEFORE sendEvent: to avoid ambiguity with AppKit's
        // default key handling.
        const ev_type = objc.msgSend(usize, ns_ev, "type", .{});
        translate_event(win, ns_ev, ev_type);

        // Let AppKit handle the event too (cursor updates, menu shortcuts, etc.)
        objc.msgSend(void, g.app, "sendEvent:", .{ns_ev});
    }
}

/// Extract modifier key state from NSEvent modifier flags.
fn mods_from_flags(flags: usize) @import("../../event.zig").Modifiers {
    return .{
        .shift = (flags & cocoa.NSEventModifierFlagShift) != 0,
        .ctrl = (flags & cocoa.NSEventModifierFlagControl) != 0,
        .alt = (flags & cocoa.NSEventModifierFlagOption) != 0,
        .super = (flags & cocoa.NSEventModifierFlagCommand) != 0,
        .caps_lock = (flags & cocoa.NSEventModifierFlagCapsLock) != 0,
    };
}

/// Translate a single NSEvent into wndw Event(s) and push onto the queue.
fn translate_event(win: *Window, ns_ev: objc.id, ev_type: usize) void {
    const FnCGFloat = fn (objc.id, objc.SEL) callconv(.c) objc.CGFloat;

    switch (ev_type) {
        cocoa.NSEventTypeKeyDown => {
            if (objc.msgSend(objc.BOOL, ns_ev, "isARepeat", .{}) != objc.NO) return;
            const kc = objc.msgSend(u16, ns_ev, "keyCode", .{});
            const flags = objc.msgSend(usize, ns_ev, "modifierFlags", .{});
            win.queue.push(.{ .key_pressed = .{
                .key = macos_keycode(kc),
                .mods = mods_from_flags(flags),
                .character = resolve_character(kc, flags),
            } });
        },
        cocoa.NSEventTypeKeyUp => {
            const kc = objc.msgSend(u16, ns_ev, "keyCode", .{});
            const flags = objc.msgSend(usize, ns_ev, "modifierFlags", .{});
            win.queue.push(.{ .key_released = .{
                .key = macos_keycode(kc),
                .mods = mods_from_flags(flags),
                .character = resolve_character(kc, flags),
            } });
        },
        cocoa.NSEventTypeFlagsChanged => {
            // Diff against prev_flags to determine press vs release.
            const flags = objc.msgSend(usize, ns_ev, "modifierFlags", .{});
            const changed = flags ^ win.prev_flags;
            win.prev_flags = flags;
            const kc = objc.msgSend(u16, ns_ev, "keyCode", .{});
            const key = macos_keycode(kc);
            const mods = mods_from_flags(flags);
            if (changed != 0) {
                const pressed = (flags & changed) != 0;
                if (pressed) win.queue.push(.{ .key_pressed = .{ .key = key, .mods = mods } }) else win.queue.push(.{ .key_released = .{ .key = key, .mods = mods } });
            }
        },

        cocoa.NSEventTypeLeftMouseDown => win.queue.push(.{ .mouse_pressed = .left }),
        cocoa.NSEventTypeLeftMouseUp => win.queue.push(.{ .mouse_released = .left }),
        cocoa.NSEventTypeRightMouseDown => win.queue.push(.{ .mouse_pressed = .right }),
        cocoa.NSEventTypeRightMouseUp => win.queue.push(.{ .mouse_released = .right }),
        cocoa.NSEventTypeOtherMouseDown => {
            if (other_mouse_button(objc.msgSend(objc.NSInteger, ns_ev, "buttonNumber", .{}))) |btn|
                win.queue.push(.{ .mouse_pressed = btn });
        },
        cocoa.NSEventTypeOtherMouseUp => {
            if (other_mouse_button(objc.msgSend(objc.NSInteger, ns_ev, "buttonNumber", .{}))) |btn|
                win.queue.push(.{ .mouse_released = btn });
        },

        cocoa.NSEventTypeMouseMoved,
        cocoa.NSEventTypeLeftMouseDragged,
        cocoa.NSEventTypeRightMouseDragged,
        cocoa.NSEventTypeOtherMouseDragged,
        => {
            const p = mouse_pos(ns_ev, win.h);
            win.queue.push(.{ .mouse_moved = .{ .x = p.x, .y = p.y } });
        },

        cocoa.NSEventTypeScrollWheel => {
            const fp: *const FnCGFloat = @ptrCast(&objc.objc_msgSend);
            const dx: f32 = @floatCast(fp(ns_ev, objc.sel_registerName("deltaX")));
            const dy: f32 = @floatCast(fp(ns_ev, objc.sel_registerName("deltaY")));
            win.queue.push(.{ .scroll = .{ .dx = dx, .dy = dy } });
        },

        else => {},
    }
}

/// Map NSEvent `buttonNumber` to `MouseButton`. Handles "other" buttons only
/// (left=0 and right=1 are handled by their own event types).
fn other_mouse_button(btn: objc.NSInteger) ?event.MouseButton {
    return switch (btn) {
        2 => .middle,
        3 => .x1,
        4 => .x2,
        else => null,
    };
}

/// Convert NSEvent's `locationInWindow` (bottom-left origin) to top-left origin.
fn mouse_pos(ns_ev: objc.id, win_h: i32) struct { x: i32, y: i32 } {
    const FnPt = fn (objc.id, objc.SEL) callconv(.c) objc.NSPoint;
    const sel = objc.sel_registerName("locationInWindow");
    const fn_ptr: *const FnPt = @ptrCast(&objc.objc_msgSend);
    const p = fn_ptr(ns_ev, sel);
    return .{
        .x = @intFromFloat(p.x),
        .y = win_h - @as(i32, @intFromFloat(p.y)),
    };
}

// ── App + class setup ─────────────────────────────────────────────────────────

/// One-time NSApplication bootstrap. Creates the shared application,
/// registers our custom ObjC classes, and calls `finishLaunching`.
// ── Live window tracking ─────────────────────────────────────────────────────

fn register_live_window(win: *Window) void {
    for (&g.live_windows) |*slot| {
        if (slot.* == null) {
            slot.* = win;
            return;
        }
    }
}

fn unregister_live_window(win: *Window) void {
    for (&g.live_windows) |*slot| {
        if (slot.* == win) {
            slot.* = null;
            return;
        }
    }
}

// ── Appearance tracking ─────────────────────────────────────────────────────

/// Query the current system appearance by inspecting `[NSApp effectiveAppearance].name`.
fn query_system_appearance() event.Appearance {
    const appearance = objc.msgSend(objc.id, g.app, "effectiveAppearance", .{});
    const name = objc.msgSend(objc.id, appearance, "name", .{});
    // Compare against the known dark appearance name string.
    const dark_name = objc.ns_string("NSAppearanceNameDarkAqua");
    const is_equal = objc.msgSend(objc.BOOL, name, "isEqualToString:", .{dark_name});
    return if (is_equal != objc.NO) .dark else .light;
}

/// NSNotificationCenter callback for `NSAppearanceDidChangeNotification` (macOS 10.14+)
/// and `AppleInterfaceThemeChangedNotification` from NSDistributedNotificationCenter.
fn appearance_did_change(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    const current = query_system_appearance();
    if (current == g.last_appearance) return;
    g.last_appearance = current;
    // Broadcast to all live windows.
    for (g.live_windows) |maybe_win| {
        if (maybe_win) |win| {
            win.queue.push(.{ .appearance_changed = current });
        }
    }
}

fn setup_app() !void {
    g.app = objc.msgSend(objc.id, objc.ns_class("NSApplication"), "sharedApplication", .{});
    _ = objc.ns_retain(g.app);

    const FnPolicy = fn (objc.id, objc.SEL, objc.NSInteger) callconv(.c) void;
    const policy_sel = objc.sel_registerName("setActivationPolicy:");
    const fp_policy: *const FnPolicy = @ptrCast(&objc.objc_msgSend);
    fp_policy(g.app, policy_sel, cocoa.NSApplicationActivationPolicyRegular);

    g.app_delegate_cls = objc.objc_allocateClassPair(objc.objc_getClass("NSObject"), "WndwAppDelegate", 0) orelse
        return error.ClassAllocFailed;
    _ = objc.class_addMethod(g.app_delegate_cls, objc.sel_registerName("appearanceDidChange:"), @ptrCast(&appearance_did_change), "v@:@");
    objc.objc_registerClassPair(g.app_delegate_cls);
    g.app_delegate = objc.msgSend(objc.id, objc.msgSend(objc.id, g.app_delegate_cls, "alloc", .{}), "init", .{});
    objc.msgSend(void, g.app, "setDelegate:", .{g.app_delegate});

    objc.msgSend(void, g.app, "finishLaunching", .{});

    g.run_loop_mode = objc.ns_retain(NSDefaultRunLoopMode);

    // Record initial appearance and observe changes via NSDistributedNotificationCenter.
    // "AppleInterfaceThemeChangedNotification" is the standard way to detect dark/light
    // mode toggles — it fires on all macOS versions that support dark mode (10.14+).
    g.last_appearance = query_system_appearance();
    const dist_center = objc.msgSend(objc.id, objc.ns_class("NSDistributedNotificationCenter"), "defaultCenter", .{});
    const FnAddObserver = fn (objc.id, objc.SEL, objc.id, objc.SEL, ?objc.id, objc.id, objc.NSUInteger) callconv(.c) void;
    const fn_add: *const FnAddObserver = @ptrCast(&objc.objc_msgSend);
    fn_add(
        dist_center,
        objc.sel_registerName("addObserver:selector:name:object:suspensionBehavior:"),
        g.app_delegate,
        objc.sel_registerName("appearanceDidChange:"),
        null,
        objc.ns_string("AppleInterfaceThemeChangedNotification"),
        2, // NSNotificationSuspensionBehaviorDeliverImmediately
    );

    try setup_window_delegate_class();
    try setup_view_class();

    g.initialised = true;
}

/// Register the `WndwWindowDelegate` class. Implements NSWindowDelegate
/// methods to track resize, move, focus, and minimize state changes.
fn setup_window_delegate_class() !void {
    g.win_delegate_cls = objc.objc_allocateClassPair(objc.objc_getClass("NSObject"), "WndwWindowDelegate", 0) orelse
        return error.ClassAllocFailed;

    // ObjC runtime expects log2(alignment_in_bytes), not raw bytes.
    _ = objc.class_addIvar(g.win_delegate_cls, "wndw_win", @sizeOf(*anyopaque), @ctz(@as(usize, @alignOf(*anyopaque))), "^v");

    _ = objc.class_addMethod(g.win_delegate_cls, objc.sel_registerName("windowShouldClose:"), @ptrCast(&delegate_window_should_close), "B@:@");
    _ = objc.class_addMethod(g.win_delegate_cls, objc.sel_registerName("windowDidResize:"), @ptrCast(&delegate_window_did_resize), "v@:@");
    _ = objc.class_addMethod(g.win_delegate_cls, objc.sel_registerName("windowDidMove:"), @ptrCast(&delegate_window_did_move), "v@:@");
    _ = objc.class_addMethod(g.win_delegate_cls, objc.sel_registerName("windowDidBecomeKey:"), @ptrCast(&delegate_window_did_become_key), "v@:@");
    _ = objc.class_addMethod(g.win_delegate_cls, objc.sel_registerName("windowDidResignKey:"), @ptrCast(&delegate_window_did_resign_key), "v@:@");
    _ = objc.class_addMethod(g.win_delegate_cls, objc.sel_registerName("windowDidMiniaturize:"), @ptrCast(&delegate_window_did_miniaturize), "v@:@");
    _ = objc.class_addMethod(g.win_delegate_cls, objc.sel_registerName("windowDidDeminiaturize:"), @ptrCast(&delegate_window_did_deminiaturize), "v@:@");

    objc.objc_registerClassPair(g.win_delegate_cls);
}

/// Register the `WndwView` NSView subclass. Handles mouse tracking,
/// display scale changes, and NSDraggingDestination for file drops.
fn setup_view_class() !void {
    g.view_cls = objc.objc_allocateClassPair(objc.objc_getClass("NSView"), "WndwView", 0) orelse
        return error.ClassAllocFailed;

    // ObjC runtime expects log2(alignment_in_bytes), not raw bytes.
    _ = objc.class_addIvar(g.view_cls, "wndw_win", @sizeOf(*anyopaque), @ctz(@as(usize, @alignOf(*anyopaque))), "^v");

    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("initWithWndwWindow:"), @ptrCast(&view_init_with_window), "@@:^v");
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("acceptsFirstResponder"), @ptrCast(&view_accepts_first_responder), "B@:");
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("mouseEntered:"), @ptrCast(&view_mouse_entered), "v@:@");
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("mouseExited:"), @ptrCast(&view_mouse_exited), "v@:@");
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("drawRect:"), @ptrCast(&view_draw_rect), "v@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("viewDidChangeBackingProperties"), @ptrCast(&view_did_change_backing_properties), "v@:");
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("draggingEntered:"), @ptrCast(&view_dragging_entered), "Q@:@");
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("draggingExited:"), @ptrCast(&view_dragging_exited), "v@:@");
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("performDragOperation:"), @ptrCast(&view_perform_drag_operation), "B@:@");
    // Text input: keyDown: calls interpretKeyEvents: which triggers insertText:replacementRange:
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("keyDown:"), @ptrCast(&view_key_down), "v@:@");
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("insertText:replacementRange:"), @ptrCast(&view_insert_text), "v@:@{_NSRange=QQ}");
    // Required for NSTextInputClient protocol conformance.
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("hasMarkedText"), @ptrCast(&view_has_marked_text), "B@:");
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("setMarkedText:selectedRange:replacementRange:"), @ptrCast(&view_set_marked_text), "v@:@{_NSRange=QQ}{_NSRange=QQ}");
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("unmarkText"), @ptrCast(&view_unmark_text), "v@:");

    objc.objc_registerClassPair(g.view_cls);
}

// ── Delegate callbacks ────────────────────────────────────────────────────────

/// Retrieve the `*Window` back-pointer from a delegate/view ivar.
fn get_win_from_delegate(delegate: objc.id) ?*Window {
    var ptr: ?*anyopaque = null;
    _ = objc.object_getInstanceVariable(delegate, "wndw_win", &ptr);
    const p = ptr orelse return null;
    return @ptrCast(@alignCast(p));
}

/// `windowShouldClose:` — close button or Cmd+W.
/// If an `on_close_requested` callback is set, the event is enqueued and
/// AppKit is told NOT to close (the user decides by calling `win.quit()`).
/// Otherwise, `should_close` is set automatically so the window closes
/// without requiring manual polling — child windows "just work."
fn delegate_window_should_close(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) objc.BOOL {
    if (get_win_from_delegate(self)) |win| {
        win.queue.push(.close_requested);
        if (win.callbacks.on_close_requested.func == null) {
            win.should_close = true;
            return objc.YES;
        }
    }
    return objc.NO;
}

/// `windowDidResize:` — window frame changed size.
fn delegate_window_did_resize(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    const win = get_win_from_delegate(self) orelse return;
    const content_view = objc.msgSend(objc.id, win.ns_window, "contentView", .{});
    const FnRect = fn (objc.id, objc.SEL) callconv(.c) objc.NSRect;
    const fn_ptr: *const FnRect = @ptrCast(&objc.objc_msgSend);
    const frame = fn_ptr(content_view, objc.sel_registerName("frame"));
    win.w = @intFromFloat(frame.size.width);
    win.h = @intFromFloat(frame.size.height);
    win.queue.push(.{ .resized = .{ .w = win.w, .h = win.h } });
    win.updateGLContextIfNeeded();
    if (objc.msgSend(objc.BOOL, win.ns_window, "isZoomed", .{}) != objc.NO) {
        win.queue.push(.maximized);
    }
}

/// `windowDidMove:` — window was dragged to a new position.
fn delegate_window_did_move(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    const win = get_win_from_delegate(self) orelse return;
    const FnRect = fn (objc.id, objc.SEL) callconv(.c) objc.NSRect;
    const fn_ptr: *const FnRect = @ptrCast(&objc.objc_msgSend);
    const frame = fn_ptr(win.ns_window, objc.sel_registerName("frame"));
    win.x = @intFromFloat(frame.origin.x);
    win.y = @intFromFloat(frame.origin.y);
    win.queue.push(.{ .moved = .{ .x = win.x, .y = win.y } });
}

/// `windowDidBecomeKey:` — window gained keyboard focus.
fn delegate_window_did_become_key(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    if (get_win_from_delegate(self)) |win| {
        win.is_focused = true;
        win.queue.push(.focus_gained);
    }
}

/// `windowDidResignKey:` — window lost keyboard focus.
fn delegate_window_did_resign_key(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    if (get_win_from_delegate(self)) |win| {
        win.is_focused = false;
        win.queue.push(.focus_lost);
    }
}

/// `windowDidMiniaturize:` — window minimised to dock.
fn delegate_window_did_miniaturize(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    if (get_win_from_delegate(self)) |win| {
        // Restore the original style mask if minimize() temporarily added
        // NSWindowStyleMaskMiniaturizable for a borderless window.
        if (win.saved_style_mask) |mask| {
            objc.msgSend(void, win.ns_window, "setStyleMask:", .{mask});
            win.saved_style_mask = null;
        }
        win.is_minimized = true;
        win.queue.push(.minimized);
    }
}

/// `windowDidDeminiaturize:` — window restored from dock.
fn delegate_window_did_deminiaturize(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    if (get_win_from_delegate(self)) |win| {
        win.is_minimized = false;
        win.queue.push(.restored);
    }
}

// ── View callbacks ────────────────────────────────────────────────────────────

/// Retrieve the `*Window` back-pointer from a WndwView ivar.
fn get_win_from_view(view: objc.id) ?*Window {
    var ptr: ?*anyopaque = null;
    _ = objc.object_getInstanceVariable(view, "wndw_win", &ptr);
    const p = ptr orelse return null;
    return @ptrCast(@alignCast(p));
}

/// Custom initialiser: stores the Window back-pointer, calls `[super initWithFrame:]`.
fn view_init_with_window(self: objc.id, _: objc.SEL, win: *Window) callconv(.c) objc.id {
    const FnSuperInit = fn (*const objc.ObjcSuper, objc.SEL, objc.NSRect) callconv(.c) objc.id;
    const fn_super: *const FnSuperInit = @ptrCast(&objc.objc_msgSendSuper);
    const zero = objc.NSRect{ .origin = .{ .x = 0, .y = 0 }, .size = .{ .width = 0, .height = 0 } };
    const sup = objc.ObjcSuper{ .receiver = self, .super_class = objc.ns_class("NSView") };
    const result = fn_super(&sup, objc.sel_registerName("initWithFrame:"), zero);
    _ = objc.object_setInstanceVariable(result, "wndw_win", win);
    return result;
}

/// `acceptsFirstResponder` → YES (required for key events to reach this view).
fn view_accepts_first_responder(_: objc.id, _: objc.SEL) callconv(.c) objc.BOOL {
    return objc.YES;
}

/// `mouseEntered:` — cursor entered the view's tracking area.
fn view_mouse_entered(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    if (get_win_from_view(self)) |win| win.queue.push(.mouse_entered);
}

/// `mouseExited:` — cursor left the view's tracking area.
fn view_mouse_exited(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    if (get_win_from_view(self)) |win| win.queue.push(.mouse_left);
}

/// `drawRect:` — the view needs a redraw.
fn view_draw_rect(self: objc.id, _: objc.SEL, _: objc.NSRect) callconv(.c) void {
    if (get_win_from_view(self)) |win| win.queue.push(.refresh_requested);
}

/// `viewDidChangeBackingProperties` — scale factor changed (e.g. moved to Retina).
fn view_did_change_backing_properties(self: objc.id, _: objc.SEL) callconv(.c) void {
    const win = get_win_from_view(self) orelse return;
    const FnScale = fn (objc.id, objc.SEL) callconv(.c) objc.CGFloat;
    const fn_ptr: *const FnScale = @ptrCast(&objc.objc_msgSend);
    const scale: f32 = @floatCast(fn_ptr(win.ns_window, objc.sel_registerName("backingScaleFactor")));
    win.queue.push(.{ .scale_changed = scale });
}

/// `draggingEntered:` — file drag entered the view.
fn view_dragging_entered(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) objc.NSUInteger {
    if (get_win_from_view(self)) |win| win.queue.push(.file_drop_started);
    return 1; // NSDragOperationCopy
}

/// `draggingExited:` — file drag left without dropping.
fn view_dragging_exited(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    if (get_win_from_view(self)) |win| win.queue.push(.file_drop_left);
}

/// `performDragOperation:` — files were dropped. Extracts NSURL paths and
/// queues a `file_dropped` event.
fn view_perform_drag_operation(self: objc.id, _: objc.SEL, sender: objc.id) callconv(.c) objc.BOOL {
    const win = get_win_from_view(self) orelse return objc.NO;
    // Release previously retained path strings before storing new ones.
    win.releaseDropStrings();

    const pb = objc.msgSend(objc.id, sender, "draggingPasteboard", .{});
    const url_cls = objc.ns_class("NSURL");
    const cls_array = objc.msgSend(objc.id, objc.ns_class("NSArray"), "arrayWithObject:", .{url_cls});
    const urls = objc.msgSend(?objc.id, pb, "readObjectsForClasses:options:", .{ cls_array, @as(?objc.id, null) });
    if (urls) |url_array| {
        const count = objc.msgSend(objc.NSUInteger, url_array, "count", .{});
        var i: objc.NSUInteger = 0;
        while (i < count and win.drop_count < Window.MAX_DROP_FILES) : (i += 1) {
            const FnObjAtIdx = fn (objc.id, objc.SEL, objc.NSUInteger) callconv(.c) objc.id;
            const fn_idx: *const FnObjAtIdx = @ptrCast(&objc.objc_msgSend);
            const url = fn_idx(url_array, objc.sel_registerName("objectAtIndex:"), i);
            const path_str: ?objc.id = objc.msgSend(?objc.id, url, "path", .{});
            if (path_str) |ps| {
                // Retain the NSString so UTF8String remains valid until the
                // next drop operation or window close.
                _ = objc.msgSend(objc.id, ps, "retain", .{});
                win.drop_strings[win.drop_count] = ps;
                const utf8 = objc.msgSend([*:0]const u8, ps, "UTF8String", .{});
                win.drop_paths[win.drop_count] = utf8;
                win.drop_count += 1;
            }
        }
    }
    win.queue.push(.{ .file_dropped = win.drop_count });
    return objc.YES;
}

// ── Text input view methods ──────────────────────────────────────────────────

/// NSRange (location, length) used by NSTextInputClient methods.
const NSRange = extern struct { location: objc.NSUInteger, length: objc.NSUInteger };

/// `keyDown:` — route key events through interpretKeyEvents: for IME processing.
/// This triggers insertText:replacementRange: for committed text.
fn view_key_down(self: objc.id, _: objc.SEL, ns_ev: objc.id) callconv(.c) void {
    // Wrap the event in a single-element NSArray for interpretKeyEvents:.
    const arr = objc.msgSend(objc.id, objc.ns_class("NSArray"), "arrayWithObject:", .{ns_ev});
    objc.msgSend(void, self, "interpretKeyEvents:", .{arr});
}

/// `insertText:replacementRange:` — called by the input system when text
/// is committed (after IME/dead-key processing).
fn view_insert_text(self: objc.id, _: objc.SEL, text_obj: objc.id, _: NSRange) callconv(.c) void {
    const win = get_win_from_view(self) orelse return;
    // text_obj may be NSString or NSAttributedString. Get the plain string.
    const str: objc.id = if (objc.msgSend(objc.BOOL, text_obj, "isKindOfClass:", .{objc.ns_class("NSAttributedString")}) != objc.NO)
        objc.msgSend(objc.id, text_obj, "string", .{})
    else
        text_obj;
    const utf8 = objc.msgSend([*:0]const u8, str, "UTF8String", .{});
    const len = objc.msgSend(objc.NSUInteger, str, "lengthOfBytesUsingEncoding:", .{@as(objc.NSUInteger, 4)}); // NSUTF8StringEncoding = 4
    if (len == 0) return;
    const copy_len = @min(len, win.text_buf.len);
    @memcpy(win.text_buf[0..copy_len], utf8[0..copy_len]);
    win.text_len = copy_len;
    win.queue.push(.{ .text_input = .{ .text = win.text_buf[0..copy_len] } });
}

/// `hasMarkedText` — required by NSTextInputClient. We don't support marked text (pre-edit).
fn view_has_marked_text(_: objc.id, _: objc.SEL) callconv(.c) objc.BOOL {
    return objc.NO;
}

/// `setMarkedText:selectedRange:replacementRange:` — stub for NSTextInputClient.
fn view_set_marked_text(_: objc.id, _: objc.SEL, _: objc.id, _: NSRange, _: NSRange) callconv(.c) void {}

/// `unmarkText` — stub for NSTextInputClient.
fn view_unmark_text(_: objc.id, _: objc.SEL) callconv(.c) void {}

// ── macOS hardware keycode → Key ──────────────────────────────────────────────

const macos_keycode = @import("keymap.zig").macos_keycode;

// ── CVDisplayLink callback ───────────────────────────────────────────────────

/// Called on a background CoreVideo thread at each vsync. Sets the
/// atomic `frame_ready` flag so the main thread can unblock.
fn display_link_callback(
    _: CVDisplayLinkRef,
    _: *const anyopaque,
    _: *const anyopaque,
    _: u64,
    _: *u64,
    userInfo: ?*anyopaque,
) callconv(.c) i32 {
    const win: *Window = @ptrCast(@alignCast(userInfo.?));
    win.frame_ready.store(true, .release);
    return 0; // kCVReturnSuccess
}

/// Resolve the Unicode character for a keycode + modifier flags using UCKeyTranslate.
/// Returns null for non-character keys (function keys, modifiers, arrows, etc.)
/// or if the keyboard layout cannot be queried.
fn resolve_character(keycode: u16, flags: usize) ?u21 {
    const input_source = TISCopyCurrentKeyboardLayoutInputSource() orelse return null;
    defer CFRelease(input_source);
    const layout_data = TISGetInputSourceProperty(input_source, kTISPropertyUnicodeKeyLayoutData) orelse return null;
    const layout = CFDataGetBytePtr(layout_data);

    // Convert NSEvent modifier flags to Carbon modifier bits (right-shifted by 8).
    // Carbon expects: cmdKey=8, shiftKey=9, alphaLock=10, optionKey=11, controlKey=12
    const carbon_mods: u32 = @truncate((flags >> 16) & 0xFF);

    var dead_key_state: u32 = 0;
    var length: usize = 0;
    var chars: [4]u16 = undefined;

    const status = UCKeyTranslate(
        layout,
        keycode,
        kUCKeyActionDown,
        carbon_mods,
        @intCast(LMGetKbdType()),
        kUCKeyTranslateNoDeadKeysMask,
        &dead_key_state,
        chars.len,
        &length,
        &chars,
    );

    if (status != 0 or length == 0) return null;

    // Filter out control characters (< 0x20) except tab/return/etc which
    // are already handled by Key enum and shouldn't be characters.
    const ch = chars[0];
    if (ch < 0x20 or ch == 0x7F) return null;

    // Handle UTF-16 surrogate pairs for characters > U+FFFF
    if (length >= 2 and ch >= 0xD800 and ch <= 0xDBFF) {
        const lo = chars[1];
        if (lo >= 0xDC00 and lo <= 0xDFFF) {
            return @intCast((@as(u21, ch - 0xD800) << 10) + (lo - 0xDC00) + 0x10000);
        }
    }

    return @intCast(ch);
}
