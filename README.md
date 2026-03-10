# wndw

A pure Zig windowing library. No C dependencies, no generated bindings — platform APIs are called directly via Zig's `extern fn` declarations.

Currently supports **macOS** (Cocoa/AppKit via the ObjC runtime). Windows and Linux backends are planned.

**Requires Zig 0.16.0-dev** (master/nightly).

## Quick Start

```zig
const wndw = @import("wndw");

pub fn main() !void {
    var win = try wndw.init("hello", 800, 600, .{ .centred = true });
    defer win.close();

    while (!win.shouldClose()) {
        while (win.poll()) |ev| {
            switch (ev) {
                .key_pressed => |kp| if (kp.key == .escape) win.quit(),
                .close_requested => win.quit(),
                else => {},
            }
        }
    }
}
```

```sh
zig build run
```

## Install

```sh
zig fetch --save=wndw git+https://github.com/zmscode/wndw.git
```

Then in your `build.zig`:

```zig
const wndw_dep = b.dependency("wndw", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("wndw", wndw_dep.module("wndw"));
```

## Features

### Window Creation

```zig
var win = try wndw.init("title", 800, 600, .{
    .centred = true,
    .resizable = true,
    .borderless = false,
    .transparent = false,
    .inset_titlebar = true,   // transparent titlebar, content behind traffic lights
    .kind = .normal,          // .normal, .floating, .popup, or .dialog
    .parent = null,           // required for .dialog (sheet attachment)
});
defer win.close();
```

**Window kinds** control the underlying Cocoa class and focus behavior:

| Kind | Behavior |
|------|----------|
| `.normal` | Standard `NSWindow` — appears in window list, receives key and main status |
| `.floating` | `NSPanel` at floating level — stays above normal windows (tool palettes) |
| `.popup` | `NSPanel` that doesn't become key — tooltips, autocomplete, transient UI |
| `.dialog` | `NSPanel` presented as a sheet attached to `parent` — blocks parent until dismissed |

### Event Loop

`win.poll()` returns the next event, or `null` when the queue is empty.

```zig
while (win.poll()) |ev| {
    switch (ev) {
        .key_pressed => |kp| { _ = kp.key; _ = kp.mods; _ = kp.character; },
        .key_released => |kr| { _ = kr.key; _ = kr.mods; },
        .mouse_pressed => |btn| {},
        .mouse_released => |btn| {},
        .mouse_moved => |m| { _ = m.x; _ = m.y; },
        .scroll => |s| { _ = s.dx; _ = s.dy; },
        .resized => |r| { _ = r.w; _ = r.h; },
        .moved => |m| { _ = m.x; _ = m.y; },
        .focus_gained, .focus_lost => {},
        .close_requested => {},
        .minimized, .restored, .maximized => {},
        .mouse_entered, .mouse_left => {},
        .refresh_requested => {},
        .scale_changed => |s| { _ = s; },
        .text_input => |ti| { _ = ti.text; },
        .appearance_changed => |a| { _ = a; },  // .light or .dark
        .file_drop_started, .file_drop_left => {},
        .file_dropped => |count| { _ = count; },
    }
}
```

### Keyboard Layout Awareness

Key events include a `character` field with the translated Unicode codepoint (via `UCKeyTranslate`), so you get layout-correct characters regardless of hardware keycode:

```zig
.key_pressed => |kp| {
    if (kp.character) |ch| {
        // ch is a u21 Unicode codepoint from the active keyboard layout
    }
},
```

### Dark/Light Mode Tracking

Query the current appearance or react to system changes:

```zig
const appearance = win.getAppearance(); // .light or .dark

// Or via events:
.appearance_changed => |a| std.debug.print("switched to {}\n", .{a}),
```

### CVDisplayLink Frame Sync

Sync your render loop to the display's refresh rate:

```zig
try win.createDisplayLink();
defer win.destroyDisplayLink();

while (!win.shouldClose()) {
    win.waitForFrame();  // blocks until next vsync
    while (win.poll()) |ev| { ... }
    // render here
}
```

### Callbacks with Context Pointers

All callbacks accept a `?*anyopaque` context pointer, passed through to each invocation:

```zig
fn onResize(ctx: ?*anyopaque, size: wndw.Size) void {
    const app: *App = @ptrCast(@alignCast(ctx.?));
    app.handleResize(size);
}

win.setOnResize(app, onResize);
```

### Window Control

```zig
win.setTitle("new title");
win.resize(1024, 768);
win.move(100, 200);
win.center();
win.minimize();
win.restore();
win.maximize();
win.setFullscreen(true);
win.setOpacity(0.5);
win.setMinSize(400, 300);
win.setMaxSize(1920, 1080);
win.setCursorVisible(false);
win.setStandardCursor(.crosshair);  // .arrow, .ibeam, .pointing_hand, etc.
win.resetCursor();
win.setAlwaysOnTop(true);
win.setDragAndDrop(true);
win.clipboardWrite("text");
const text = win.clipboardRead();
```

### OpenGL

```zig
try win.createGLContext(.{});  // defaults: OpenGL 3.2 Core, depth=24, double-buffered
defer win.deleteContext();
win.setSwapInterval(1);

const glClear = @as(*const fn (u32) callconv(.c) void,
    @ptrCast(@alignCast(win.getProcAddress("glClear").?)));
```

See `gl_demo.zig` for a full animated example.

### Window State

```zig
const focused = win.isFocused();
const minimized = win.isMinimized();
const fullscreen = win.isFullscreen();
const size = win.getSize();   // .w, .h
const pos = win.getPos();     // .x, .y
const closing = win.shouldClose();
```

## Architecture

```
src/
  root.zig                  -- public API, comptime platform dispatch
  event.zig                 -- Event union, Key, MouseButton, Cursor, Appearance
  event_queue.zig           -- fixed-capacity circular buffer (128 events)
  platform/
    macos/
      objc.zig              -- ObjC runtime extern declarations + msgSend helper
      cocoa.zig             -- numeric Cocoa/AppKit constants (stable ABI values)
      window.zig            -- NSApp, NSWindow/NSPanel, NSView, event loop, callbacks
      keymap.zig            -- hardware keycode -> Key lookup table
demo.zig                    -- interactive feature demo
gl_demo.zig                 -- OpenGL animated background demo
build.zig
```

Platform dispatch is comptime — `src/root.zig` selects the backend based on `builtin.os.tag`. Adding a new platform means one new directory plus one `switch` branch.

The ObjC runtime is accessed purely through `extern fn` declarations (`objc_msgSend`, `objc_getClass`, etc.). No `@cImport`, no C source files, no SDK headers required.

## Testing

```sh
zig build test
```

Tests are pure Zig with no platform linkage required. ObjC-backed methods are verified at compile time via `@hasDecl`/`@hasField` checks.

## License

MIT
