# wndw

A pure Zig windowing library. No C dependencies, no generated bindings -- platform APIs are called directly via Zig's `extern fn` declarations.

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
                .key_pressed => |k| if (k == .escape) win.quit(),
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

## API

### Window Creation

```zig
var win = try wndw.init("title", 800, 600, .{
    .centred = true,       // centre on screen
    .resizeable = true,    // allow user resizing
    .borderless = false,   // window decorations (title bar, border)
    .transparent = false,  // per-pixel transparency
});
defer win.close();
```

### Event Loop

`win.poll()` returns the next event, or `null` when the queue is empty. OS events are drained lazily -- only when the Zig-side queue runs out.

```zig
while (win.poll()) |ev| {
    switch (ev) {
        .key_pressed => |k| { },
        .key_released => |k| { },
        .mouse_pressed => |btn| { },
        .mouse_released => |btn| { },
        .mouse_moved => |m| { _ = m.x; _ = m.y; },
        .scroll => |s| { _ = s.dx; _ = s.dy; },
        .resized => |r| { _ = r.w; _ = r.h; },
        .moved => |m| { _ = m.x; _ = m.y; },
        .focus_gained => {},
        .focus_lost => {},
        .close_requested => {},
        .minimized => {},
        .restored => {},
    }
}
```

### Window Control

```zig
win.setTitle("new title");
win.resize(1024, 768);
win.move(100, 200);
win.minimize();
win.restore();
win.maximize();
win.setFullscreen(true);
win.setCursorVisible(false);
win.setAlwaysOnTop(true);
```

### Window State

```zig
const focused = win.isFocused();
const minimized = win.isMinimized();
const size = win.getSize();   // .w, .h
const pos = win.getPos();     // .x, .y
const closing = win.shouldClose();
```

### Types

**`Key`** -- all keyboard keys: letters (`a`-`z`), digits (`@"0"`-`@"9"`), function keys (`f1`-`f20`), navigation (`left`, `right`, `up`, `down`, `home`, `end`, `page_up`, `page_down`), editing (`enter`, `escape`, `backspace`, `delete`, `tab`, `space`, `insert`), modifiers (`left_shift`, `right_shift`, `left_ctrl`, `right_ctrl`, `left_alt`, `right_alt`, `left_super`, `right_super`, `caps_lock`), punctuation (`minus`, `equal`, `left_bracket`, `right_bracket`, `backslash`, `semicolon`, `apostrophe`, `grave`, `comma`, `period`, `slash`), numpad (`kp_0`-`kp_9`, `kp_decimal`, `kp_divide`, `kp_multiply`, `kp_subtract`, `kp_add`, `kp_enter`, `kp_equal`), and `unknown`.

**`MouseButton`** -- `left`, `right`, `middle`, `x1`, `x2`.

**`Event`** -- tagged union with 13 variants (see event loop example above).

## Architecture

```
src/
  root.zig                  -- public API, comptime platform dispatch
  event.zig                 -- shared Event union, Key enum, MouseButton enum
  event_queue.zig           -- fixed-capacity circular buffer (128 events)
  tests.zig                 -- test runner (module root for src/tests/)
  tests/
    event_queue_test.zig    -- FIFO, overflow, wrap-around tests
    keymap_test.zig         -- all 128 macOS hardware keycodes
    api_test.zig            -- compile-time API surface tests
    event_types_test.zig    -- minimized/restored event tag tests
    window_methods_test.zig -- Window state fields and method existence
  platform/
    macos/
      objc.zig              -- ObjC runtime extern declarations + msgSend helper
      cocoa.zig             -- numeric Cocoa/AppKit constants (stable ABI values)
      window.zig            -- NSApp setup, NSWindow/NSView subclasses, event loop
      keymap.zig            -- 128-entry hardware keycode -> Key lookup table
build.zig
demo.zig
```

Platform dispatch is comptime -- `src/root.zig` selects the backend based on `builtin.os.tag`. Adding a new platform is one new file plus one `switch` branch.

The ObjC runtime is accessed purely through `extern fn` declarations (`objc_msgSend`, `objc_getClass`, etc.). No `@cImport`, no C source files, no SDK headers. Linking `-framework Cocoa` is the only requirement.

## Testing

```sh
zig build test
```

Tests are pure Zig with no platform linkage required. ObjC-backed methods are verified at compile time via `@hasDecl`/`@hasField` checks.

## License

MIT
