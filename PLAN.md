# Plan: Pure Zig Window Library

A pure Zig windowing library — no C dependencies, no RGFW. Platform APIs are called
directly via Zig's `extern fn` declarations.

The key advantage over the current C-binding approach: declaring ObjC runtime
functions as `extern fn` in Zig requires no SDK headers, no `xcrun`, no Xcode
license agreement — just link `-framework Cocoa` at the exe stage.

**Zig version: 0.16.0-dev (master/nightly).** All code targets this version.
Key differences from stable:
- `addExecutable` takes `.root_module` (a `*Module`), not `.root_source_file`
- `b.graph.environ_map`, not `b.graph.env_map`
- `std.fs.accessAbsolute` and `std.posix.access` are removed

---

## Design Goals

- **Pure Zig**: no RGFW, no C implementation files, no generated C translation units
- **Minimal**: start with the smallest useful thing — open a window, poll events, close it
- **Backends**: `native` (blank window, software blit later) and `opengl` (platform GL context)
- **Platform-idiomatic**: use each platform's actual API, not a lowest-common-denominator shim
- **Extensible**: the dispatch layer is designed so adding a new platform or backend is
  a single new file + one `switch` branch — no changes to the public API

---

## Architecture: Platform Dispatch

The public API in `src/root.zig` dispatches to a platform module at comptime:

```zig
const platform = switch (builtin.os.tag) {
    .macos   => @import("platform/macos/window.zig"),
    // future: .windows => @import("platform/windows/window.zig"),
    // future: .linux   => @import("platform/linux/x11.zig"),
    else     => @compileError("Platform not yet supported"),
};
```

Each platform module must export the same interface:
```zig
pub const Window = struct { ... };  // opaque platform state
pub fn init(title: [:0]const u8, w: i32, h: i32, opts: Options) !Window;
pub fn close(win: *Window) void;
pub fn poll(win: *Window) ?Event;
pub fn shouldClose(win: *Window) bool;
```

The `Event` union and `Key`/`Mouse` enums live in `src/event.zig` and are shared
across all platforms. New platforms only need to map their native key/event values
into these shared types.

Backend dispatch works the same way via a build option (`-Dbackend=opengl`):
```zig
// src/backend.zig — selected at build time
pub const Backend = switch (build_options.backend) {
    .native => @import("backend/native.zig"),
    .opengl => @import("backend/opengl.zig"),  // delegates further to platform
};
```

---

## Implementation: macOS

### `src/platform/macos/objc.zig` — ObjC runtime externs

No headers needed. `libobjc` is bundled inside `Cocoa.framework`.

```zig
pub const id         = *opaque {};
pub const SEL        = *opaque {};
pub const Class      = *opaque {};
pub const IMP        = *const fn () callconv(.c) void;
pub const BOOL       = i8;
pub const NSUInteger = usize;
pub const NSInteger  = isize;

pub extern fn objc_getClass(name: [*:0]const u8) ?Class;
pub extern fn sel_registerName(name: [*:0]const u8) SEL;
pub extern fn sel_getUid(name: [*:0]const u8) SEL;
pub extern fn objc_allocateClassPair(superclass: ?Class, name: [*:0]const u8, extra: usize) ?Class;
pub extern fn objc_registerClassPair(cls: Class) void;
pub extern fn class_addMethod(cls: Class, sel: SEL, imp: IMP, types: [*:0]const u8) BOOL;
pub extern fn class_addIvar(cls: Class, name: [*:0]const u8, size: usize, alignment: u8, types: [*:0]const u8) BOOL;
pub extern fn class_getSuperclass(cls: Class) ?Class;
pub extern fn object_getInstanceVariable(obj: id, name: [*:0]const u8, out: *?*anyopaque) void;
pub extern fn object_setInstanceVariable(obj: id, name: [*:0]const u8, value: ?*anyopaque) void;
pub extern fn objc_msgSend() void;  // cast per call-site — never call directly
```

**The `msgSend` casting pattern** — RGFW casts `objc_msgSend` to a typed function
pointer per call-site based on return type + argument types. In Zig, a comptime
helper builds the function type:

```zig
pub fn msgSend(comptime Ret: type, obj: anytype, sel_name: [*:0]const u8, args: anytype) Ret {
    const sel = sel_registerName(sel_name);
    // build fn(id, SEL, ...args) callconv(.c) Ret at comptime, @ptrCast, then call
}
```

On arm64 (Apple Silicon — primary target), `objc_msgSend` handles all return types
including structs and floats. No `objc_msgSend_stret` / `objc_msgSend_fpret` needed.

---

### `src/platform/macos/cocoa.zig` — numeric constants

No headers needed. Values sourced from RGFW and Apple documentation.

```zig
// NSWindowStyleMask
pub const NSWindowStyleMaskBorderless          = 0;
pub const NSWindowStyleMaskTitled              = 1 << 0;   // 0x001
pub const NSWindowStyleMaskClosable            = 1 << 1;   // 0x002
pub const NSWindowStyleMaskMiniaturizable      = 1 << 2;   // 0x004
pub const NSWindowStyleMaskResizable           = 1 << 3;   // 0x008
pub const NSWindowStyleMaskFullScreen          = 1 << 14;  // 0x4000
pub const NSWindowStyleMaskFullSizeContentView = 1 << 15;  // 0x8000

// NSBackingStoreType
pub const NSBackingStoreBuffered = 2;

// NSApplicationActivationPolicy
pub const NSApplicationActivationPolicyRegular = 0;

// Event polling — pass as mask to nextEventMatchingMask:
pub const NSEventMaskAny: usize = std.math.maxInt(usize);

// NSEventModifierFlags
pub const NSEventModifierFlagCapsLock   = 1 << 16; // 0x010000
pub const NSEventModifierFlagShift      = 1 << 17; // 0x020000
pub const NSEventModifierFlagControl    = 1 << 18; // 0x040000
pub const NSEventModifierFlagOption     = 1 << 19; // 0x080000
pub const NSEventModifierFlagCommand    = 1 << 20; // 0x100000
pub const NSEventModifierFlagNumericPad = 1 << 21; // 0x200000

// NSOpenGLContextParameter (for OpenGL backend)
pub const NSOpenGLContextParameterSwapInterval   = 222;
pub const NSOpenGLContextParameterSurfaceOpacity = 236;

// NSOpenGLPFA (pixel format attributes — for OpenGL backend)
pub const NSOpenGLPFADoubleBuffer  = 5;
pub const NSOpenGLPFAColorSize     = 8;
pub const NSOpenGLPFAAlphaSize     = 11;
pub const NSOpenGLPFADepthSize     = 12;
pub const NSOpenGLPFAStencilSize   = 13;
pub const NSOpenGLPFASampleBuffers = 55;
pub const NSOpenGLPFASamples       = 56;
pub const NSOpenGLPFAOpenGLProfile        = 99;
pub const NSOpenGLProfileVersion3_2Core   = 0x3200;
pub const NSOpenGLProfileVersion4_1Core   = 0x4100;
```

---

### `src/platform/macos/window.zig` — implementation

#### NSApplication setup (once, global)

```
1. NSApplication.sharedApplication  → save as g_app
2. g_app.setActivationPolicy(NSApplicationActivationPolicyRegular)
3. Allocate NSObject subclass "WndwAppDelegate"
4.   class_addMethod("applicationDidChangeScreenParameters:", imp, "v@:@")
5. objc_registerClassPair(WndwAppDelegate)
6. Instantiate + set as g_app.delegate
```

#### NSWindowDelegate subclass

Selectors registered via `class_addMethod`. All `"v@:@"` unless noted:
```
windowDidResize:
windowDidMove:
windowDidMiniaturize:
windowDidDeminiaturize:
windowDidBecomeKey:
windowDidResignKey:
windowShouldClose:    "B@:"  ← returns BOOL
```

Store back-pointer to `Window` struct on the delegate object:
```zig
object_setInstanceVariable(delegate, "wndw_win", win_ptr);
// retrieve in callbacks:
object_getInstanceVariable(delegate, "wndw_win", &out);
```

#### NSView subclass

Registered selectors:
```
initWithWndwWindow:              "@@:^v"
acceptsFirstResponder            "B@:"  → always YES
keyDown:  keyUp:                 "v@:@"
flagsChanged:                    "v@:@"   (modifier keys)
mouseDown:  mouseUp:             "v@:@"
rightMouseDown:  rightMouseUp:   "v@:@"
otherMouseDown:  otherMouseUp:   "v@:@"
mouseMoved:  mouseDragged:       "v@:@"
rightMouseDragged:               "v@:@"
scrollWheel:                     "v@:@"
mouseEntered:  mouseExited:      "v@:@"
drawRect:                        "v@:{NSRect={NSPoint=dd}{NSSize=dd}}"
viewDidChangeBackingProperties   "v@:"
```

#### NSWindow creation sequence

```
1. Compute NSRect: { x, screen_h - y - h, w, h }
   (Cocoa origin is bottom-left; screen_h from NSScreen.mainScreen.frame.size.height)
2. Build style mask:
   base = Titled | Closable | Miniaturizable
   if !resizeable: mask |= Resizable
   if borderless:  mask  = Borderless
3. alloc + initWithContentRect:styleMask:backing:defer:
4. setTitle:(NSString from UTF-8)
5. alloc + init WindowDelegate; set back-pointer; setDelegate:
6. setAcceptsMouseMovedEvents:YES
7. alloc + initWithWndwWindow: NSView; setContentView:
8. makeKeyWindow
9. g_app.activateIgnoringOtherApps:YES  (on first window only)
```

Note: never call `setStyleMask:` after creation. RGFW's macOS borderless window
bug (height becomes screen height) is caused by `setStyleMask:` triggering
`windowDidResize:` mid-calculation. We sidestep this entirely.

#### Event polling

```zig
// Non-blocking drain — NULL date = return immediately if no events
while (true) {
    const e = msgSend(?id, g_app,
        "nextEventMatchingMask:untilDate:inMode:dequeue:",
        .{ NSEventMaskAny, @as(?id, null),
           nsString("kCFRunLoopDefaultMode"), @as(BOOL, 1) });
    if (e == null) break;
    msgSend(void, g_app, "sendEvent:", .{e});
}
```

For a blocking wait, pass a date:
```zig
const date = msgSend(id, objc_getClass("NSDate"),
    "dateWithTimeIntervalSinceNow:", .{seconds});
```

#### Mouse + scroll extraction from NSEvent

```zig
// Mouse position (Y flipped to top-left origin):
const p  = msgSend(NSPoint, event, "locationInWindow", .{});
const x  = @as(i32, @intFromFloat(p.x));
const y  = win.h - @as(i32, @intFromFloat(p.y));

// Scroll deltas:
const dx = msgSend(f64, event, "deltaX", .{});
const dy = msgSend(f64, event, "deltaY", .{});
```

#### Key mapping table

128-entry array: `keycodes[hardware_keycode] = Key` (hardware keycodes 0x00–0x7F).
Values sourced from RGFW's `RGFW_init_keycodes`. Partial table:
```
0x00→a  0x01→s  0x02→d  0x03→f  0x04→h  0x05→g  0x06→z  0x07→x
0x08→c  0x09→v  0x0B→b  0x0C→q  0x0D→w  0x0E→e  0x0F→tab
0x10→r  0x11→y  0x12→1  0x13→2  0x14→3  0x15→4  0x16→6  0x17→5
0x18→=  0x19→9  0x1A→7  0x1B→-  0x1C→8  0x1D→0
0x24→enter  0x30→tab  0x31→space  0x33→backspace  0x35→escape
0x38→left_shift  0x39→caps_lock  0x3A→left_alt  0x3B→left_ctrl
0x3C→right_shift  0x3D→right_alt  0x3E→right_ctrl
0x7B→left  0x7C→right  0x7D→down  0x7E→up
```

---

### `src/event.zig` — shared types

```zig
pub const Key = enum { a, b, ..., escape, enter, space, left, right, up, down, ... };
pub const MouseButton = enum { left, right, middle, x1, x2 };
pub const Event = union(enum) {
    key_pressed:    Key,
    key_released:   Key,
    mouse_pressed:  MouseButton,
    mouse_released: MouseButton,
    mouse_moved:    struct { x: i32, y: i32 },
    scroll:         struct { dx: f32, dy: f32 },
    resized:        struct { w: i32, h: i32 },
    moved:          struct { x: i32, y: i32 },
    focus_gained,
    focus_lost,
    close_requested,
    minimized,
    restored,
};
```

13 tags total. These types are platform-agnostic. Each platform maps its native values into them.

---

### `build.zig`

```zig
// macOS: link Cocoa only — no C source files at all.
// ObjC runtime (libobjc) is bundled inside Cocoa.framework.
// addSystemFrameworkPath is linker-only; it does NOT expose SDK headers
// to a C compiler (there are no C files), so the libDER/DERItem.h error
// that affects the RGFW build cannot occur here.
if (target.result.os.tag == .macos) {
    if (b.sysroot == null) {
        if (macOSSdkPath(b)) |sdk| {
            mod.addSystemFrameworkPath(.{ .cwd_relative =
                b.fmt("{s}/System/Library/Frameworks", .{sdk}) });
            mod.addLibraryPath(.{ .cwd_relative =
                b.fmt("{s}/usr/lib", .{sdk}) });
        }
    }
    mod.linkFramework("Cocoa", .{});
}

// Adding a new platform later = one new branch here + one file.
```

Demo runner (`zig build run -- demo`):
```zig
const demo_name = if (b.args) |args| (if (args.len > 0) args[0] else "demo") else "demo";
const demo_mod  = b.createModule(.{
    .root_source_file = b.path(b.fmt("{s}.zig", .{demo_name})),
    .target = target, .optimize = optimize, .link_libc = true,
});
demo_mod.addImport("wndw", mod);
const demo_exe = b.addExecutable(.{ .name = demo_name, .root_module = demo_mod });
const run_step = b.step("run", "Run a demo (e.g. `zig build run -- demo`)");
run_step.dependOn(&b.addRunArtifact(demo_exe).step);
```

---

### `demo.zig`

```zig
const wndw = @import("wndw");

pub fn main() !void {
    var win = try wndw.init("hello", 800, 600, .{});
    defer win.close();

    while (!win.shouldClose()) {
        while (win.poll()) |ev| {
            switch (ev) {
                .key_pressed => |k| if (k == .escape) win.quit(),
                else => {},
            }
        }
    }
}
```

---

## File Layout

```
src/
  root.zig                  Public API — comptime platform dispatch
  event.zig                 Shared Event union (13 tags), Key, MouseButton enums
  event_queue.zig           Platform-agnostic circular buffer (cap 128)
  tests.zig                 Test runner — module root for src/tests/
  tests/
    event_queue_test.zig    FIFO, overflow, wrap-around, mixed events, len
    keymap_test.zig         All 128 macOS hardware keycodes
    api_test.zig            Compile-time API surface (Key, MouseButton, Event)
    event_types_test.zig    minimized/restored event tags + EventQueue round-trip
    window_methods_test.zig Window state fields, query methods, @hasDecl checks
  platform/
    macos/
      objc.zig              ObjC runtime extern declarations + msgSend helper
      cocoa.zig             Numeric Cocoa/AppKit/OpenGL constants
      window.zig            NSApp setup, NSWindow + NSView subclasses, event loop
      keymap.zig            128-entry hardware keycode → Key table
    // windows/             (future)
    // linux/               (future)
  backend/
    opengl.zig              (future — Phase 2)
    opengl/
      macos.zig             NSOpenGLContext (future — Phase 2)
      // windows.zig        (future)
      // linux.zig          (future)
build.zig
demo.zig
```

---

## Implementation Order

1. ✅ `src/platform/macos/objc.zig` — extern declarations + `msgSend` helper
2. ✅ `src/platform/macos/cocoa.zig` — numeric constants
3. ✅ `src/event.zig` — `Key` enum, `Event` union (13 tags), `MouseButton` enum
4. ✅ `src/platform/macos/window.zig` — NSApp, NSWindow, NSView, event loop, key table
5. ✅ `src/root.zig` — public API, comptime platform dispatch
6. ✅ `build.zig` — link Cocoa, demo runner step (no C files)
7. ✅ `demo.zig` — smoke test: open window, handle Escape
8. ✅ Bug fixes: `finishLaunching`, `makeFirstResponder:`, read-before-sendEvent, `initWithFrame:`, `destroy(win)`, cached run loop mode, key repeat filtering
9. ✅ `src/event_queue.zig` — extracted EventQueue (testable, public `isEmpty`/`len`)
10. ✅ `src/platform/macos/keymap.zig` — extracted keycode table
11. ✅ Unit tests: `event_queue_test`, `keymap_test`, `api_test` (TDD green)
12. ✅ TDD: `event_types_test` — `minimized`/`restored` Event tags
13. ✅ TDD: `window_methods_test` — state fields (`is_focused`, `is_minimized`), query methods (`isFocused`, `isMinimized`, `getSize`, `getPos`), ObjC-backed methods (`setTitle`, `resize`, `move`, `minimize`, `restore`, `maximize`, `setFullscreen`, `setCursorVisible`, `setAlwaysOnTop`)
14. ✅ Delegate callbacks: `windowDidMiniaturize:`/`windowDidDeminiaturize:`, focus delegates update `is_focused`
15. ✅ Test organisation: `src/tests/` directory with `src/tests.zig` runner (module root at `src/`)

Then, when ready:

16. `src/backend/opengl/macos.zig` — NSOpenGLContext
17. Windows platform (`src/platform/windows/window.zig`)
18. Linux platform (`src/platform/linux/x11.zig`)
19. Full event coverage: drag-and-drop, clipboard, IME text input

---

## Notes

- **No SDK header issues**: pure `extern fn` for ObjC runtime; no `@cImport`,
  no C files. The `libDER/DERItem.h` error that blocks the current RGFW demo
  runner is impossible here.
- **arm64 primary target** (Apple Silicon). `objc_msgSend` handles all return
  types on arm64 — no `_stret`/`_fpret` variants needed.
- **Cocoa Y-axis**: origin is bottom-left. Transform: `cocoa_y = screen_h - y - h`.
- **Never call `setStyleMask:` after creation** — doing so can trigger
  `windowDidResize:` synchronously, corrupting size state (RGFW bug we avoid).
- **Adding a platform**: create `src/platform/<os>/window.zig` exporting the
  same interface, add one `switch` branch in `root.zig` and one `if` branch in
  `build.zig`. Nothing else changes.
- **Wayland** deferred — requires protocol XML → Zig code-gen.
- **Metal** deferred — OpenGL first for cross-platform parity.
- **`@Type(.{ .@"fn" = ... })` unsupported** in Zig 0.16.0-dev. `msgSend` uses
  a `switch (fi.len)` over 0–4 arities with explicit casts instead.

---

## Implementation Learnings

### Key routing (three-part fix)

Key events only reach `WndwView` if all three conditions hold:
1. `[NSApp finishLaunching]` called before first window (required for menu/event system init)
2. `[NSWindow makeFirstResponder: view]` called after `setContentView:` (routes keys to our view)
3. Read `ev_type`/`keyCode` **before** `sendEvent:` — AppKit's default handlers
   (e.g. `cancelOperation:` for Escape) cannot mutate an NSEvent, but reading first
   avoids any ambiguity about which copy of the data we see.

### Poll efficiency
`poll()` must only drain the OS event queue when the Zig-side queue is empty.
Draining on every call causes double-processing and wastes CPU between frames.

### NSView designated initializer
`-initWithWndwWindow:` must call `initWithFrame:` (NSView's designated initializer),
not `init`. Calling `init` on `self` worked because WndwView doesn't override `init`,
but using the designated initializer is correct and safe against future overrides.

### Memory and delegate safety
`close()` must nil the window's delegate **before** destroying the `Window` struct
(which the delegate's `wndw_win` ivar points to). Order: setDelegate:nil → orderOut: → close → destroy.

### FlagsChanged (modifier keys)
NSEventTypeFlagsChanged fires once per state change. XOR against stored `prev_flags`
to determine which modifier changed and whether it was pressed or released.

### Dragged events
Types 6 (LeftMouseDragged), 7 (RightMouseDragged), 27 (OtherMouseDragged) are separate
from MouseMoved (5) — all four map to `mouse_moved` in our API.

### Key repeat filtering
macOS sends repeated `NSEventTypeKeyDown` while a key is held. Checking
`[NSEvent isARepeat]` at the start of the KeyDown handler prevents multiple
`key_pressed` events from a single physical press.

### Testability via extraction
`EventQueue` and the keymap table are now in separate files (`event_queue.zig`,
`platform/macos/keymap.zig`) so they can be unit-tested without touching ObjC/AppKit.
ObjC-backed Window methods are verified at compile time via `@hasDecl` checks,
while pure-logic methods (`isFocused`, `getSize`, etc.) can be called on
`var w: Window = undefined` since they only read struct fields.

### Test module runner pattern
Zig 0.16.0-dev enforces that `@import` relative paths cannot escape above the module
root (the directory of the `root_source_file`). To keep tests in `src/tests/` while
allowing them to import from `src/`, a runner file `src/tests.zig` serves as the
module root. It uses `comptime { _ = @import("tests/foo_test.zig"); }` to pull in
all test suites. Since the runner lives in `src/`, the module root is `src/`, and
`../event.zig` from `src/tests/` resolves to `src/event.zig` -- within bounds.
