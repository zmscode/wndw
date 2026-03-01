# wndw

A Zig-idiomatic wrapper around [RGFW](https://github.com/ColleagueRiley/RGFW) -- a lightweight, single-header, cross-platform windowing library. Packaged for the Zig build system with `zig fetch` support.

`wndw` wraps the entire RGFW C API into clean Zig namespaces with native `bool`s, optional-based returns, doc comments, and zero allocations on top of the C layer.

## Table of Contents

- [Install](#install)
- [Quick Start](#quick-start)
- [Build Options](#build-options)
- [Window Creation](#window-creation)
- [Window Flags](#window-flags)
- [Event Loop](#event-loop)
- [Event Types](#event-types)
- [Keyboard Input](#keyboard-input)
- [Mouse Input](#mouse-input)
- [Cursors](#cursors)
- [Drag & Drop](#drag--drop)
- [Monitors](#monitors)
- [Clipboard](#clipboard)
- [OpenGL](#opengl)
- [EGL](#egl)
- [Vulkan](#vulkan)
- [DirectX](#directx)
- [WebGPU](#webgpu)
- [Software Rendering](#software-rendering)
- [Callbacks](#callbacks)
- [Platform-Native Handles](#platform-native-handles)
- [Memory Management](#memory-management)
- [Utilities](#utilities)
- [API Reference](#api-reference)
- [License](#license)

---

## Install

```sh
zig fetch --save=wndw git+https://github.com/zmscode/wndw.git
```

Then in your `build.zig`:

```zig
const wndw_dep = b.dependency("wndw", .{
    .target = target,
    .optimize = optimize,

    // Optional toggles (all default to false):
    // .rgfw_debug   = true,
    // .rgfw_opengl  = true,
    // .rgfw_native  = true,
    // .rgfw_vulkan  = true,
    // .rgfw_directx = true,
    // .rgfw_webgpu  = true,
});

exe.root_module.addImport("wndw", wndw_dep.module("wndw"));
```

---

## Quick Start

```zig
const wndw = @import("wndw");

pub fn main() !void {
    var win = try wndw.init("my app", 800, 600, .{
        .centred = true,
        .resizable = true,
    });
    defer win.close();

    while (!win.shouldClose()) {
        win.poll();

        if (win.isKeyPressed(wndw.key.escape)) {
            win.setShouldClose(true);
        }

        if (win.isMousePressed(wndw.mouse.left)) {
            const pos = win.mousePosition();
            _ = pos; // use it
        }
    }
}
```

---

## Build Options

| Option | Default | Description |
|--------|---------|-------------|
| `-Drgfw_debug=true` | `false` | Enable RGFW debug logging and error callbacks |
| `-Drgfw_opengl=true` | `false` | Enable OpenGL context management helpers |
| `-Drgfw_native=true` | `false` | Expose native backend structs (platform-specific) |
| `-Drgfw_vulkan=true` | `false` | Enable Vulkan surface creation (requires Vulkan SDK) |
| `-Drgfw_directx=true` | `false` | Enable DirectX swap chain creation (Windows only) |
| `-Drgfw_webgpu=true` | `false` | Enable WebGPU surface creation |

When a graphics API option is disabled, the corresponding namespace (`vulkan`, `directx`, `webgpu`) resolves to an empty struct and the related `Window` methods resolve to `null`, so your code can reference them without `#ifdef`-style branching.

---

## Window Creation

```zig
// Centred at (0, 0) with flags
var win = try wndw.init("title", 800, 600, .{ .resizable = true });
defer win.close();

// At a specific screen position
var win2 = try wndw.initAt("title", 100, 200, 800, 600, .{});
defer win2.close();

// Into pre-allocated memory (advanced -- pair with closePtr)
const buf: *@import("wndw").rgfw_h.RGFW_window = @ptrCast(@alignCast(wndw.alloc(wndw.sizeofWindow())));
var win3 = try wndw.createWindowPtr("title", 0, 0, 800, 600, .{}, buf);
defer win3.closePtr();
```

---

## Window Flags

Flags can be set at creation time or changed at runtime:

```zig
var win = try wndw.init("app", 800, 600, .{ .border = false, .centred = true });

// Change at runtime
win.setFlags(.{ .fullscreen = true });
```

All fields are `?bool` and default to `null` (unchanged):

| Flag | Description |
|------|-------------|
| `centered` / `centred` | Centre the window on screen |
| `resizable` | Allow user resizing |
| `border` | Show window decorations (title bar, border) |
| `fullscreen` | Exclusive fullscreen mode |
| `floating` | Always-on-top |
| `hidden` | Create hidden (call `show()` later) |
| `maximize` | Start maximized |
| `minimize` | Start minimized |
| `hide_mouse` | Hide mouse cursor over the window |
| `focus_on_show` | Auto-focus when shown |
| `focus` | Request input focus immediately |
| `transparent` | Per-pixel transparency (compositing WM required) |
| `allow_dnd` | Accept drag-and-drop file events |

Additional raw flags are available via `wndw.window_flag.*` for advanced use cases:

| Constant | Description |
|----------|-------------|
| `raw_mouse` | Start with raw (unaccelerated) mouse input |
| `scale_to_monitor` | Auto-scale to monitor DPI |
| `center_cursor` | Centre the cursor in the window |
| `capture_mouse` | Confine mouse to window bounds |
| `opengl` | Auto-create an OpenGL context |
| `egl` | Auto-create an EGL context |
| `no_deinit_on_close` | Don't tear down RGFW when last window closes |
| `windowed_fullscreen` | Borderless fullscreen (composite flag) |
| `capture_raw_mouse` | Capture + raw mouse (composite flag) |

---

## Event Loop

wndw supports two event processing models:

### Queued (recommended)

Call `win.poll()` to process all pending platform events, then drain with `win.pollEvent()`:

```zig
while (!win.shouldClose()) {
    win.poll();

    var ev: wndw.Event = undefined;
    while (win.pollEvent(&ev)) {
        switch (ev.type) {
            wndw.event_type.key_pressed => { /* ... */ },
            wndw.event_type.quit => win.setShouldClose(true),
            else => {},
        }
    }
}
```

### Non-queued (direct polling)

Use `win.checkEvent()` to directly fetch the next OS event one at a time:

```zig
var ev: wndw.Event = undefined;
while (win.checkEvent(&ev)) {
    // handle event
}
```

### Global helpers

```zig
wndw.pollEvents();                     // process events across all windows
wndw.waitForEvent(wndw.event_wait.next); // block until next event
wndw.waitForEvent(1000);               // block up to 1 second
wndw.setQueueEvents(true);             // enable/disable queuing globally
```

---

## Event Types

Match against `wndw.event_type.*` constants:

| Constant | Description |
|----------|-------------|
| `key_pressed` / `key_released` | Key press/release |
| `key_char` | Unicode character input (codepoint) |
| `mouse_button_pressed` / `mouse_button_released` | Mouse button press/release |
| `mouse_pos_changed` | Mouse moved |
| `mouse_scroll` | Scroll wheel |
| `focus_in` / `focus_out` | Window focus changed |
| `mouse_enter` / `mouse_leave` | Cursor entered/left window |
| `window_moved` / `window_resized` | Window geometry changed |
| `window_refresh` | Window needs redraw |
| `window_maximized` / `window_minimized` / `window_restored` | Window state changed |
| `quit` | Window close requested |
| `data_drop` / `data_drag` | File drag and drop |
| `scale_updated` | DPI/content scale changed |
| `monitor_connected` / `monitor_disconnected` | Monitor hotplug |

### Event sub-structs

Access typed event data through the `Event` union:

| Type | Access | Contents |
|------|--------|----------|
| `KeyEvent` | `event.key` | Keycode, scancode, modifiers, repeat |
| `KeyCharEvent` | `event.keyChar` | Unicode codepoint |
| `MouseButtonEvent` | `event.button` | Button ID, position |
| `MouseScrollEvent` | `event.scroll` | Scroll delta (x, y) |
| `MousePosEvent` | `event.mouse` | Cursor position |
| `DataDropEvent` | `event.drop` | Dropped file paths |
| `DataDragEvent` | `event.drag` | Dragged file info + position |
| `ScaleUpdatedEvent` | `event.scale` | New scale factor |
| `MonitorEvent` | `event.monitor` | Monitor handle + connected/disconnected |
| `CommonEvent` | `event.common` | Type discriminator + window pointer |

### Event filtering

Control which event types a window receives:

```zig
// Only receive keyboard and mouse events
win.setEnabledEvents(wndw.event_flag.key_events | wndw.event_flag.mouse_events);

// Disable specific events
win.setDisabledEvents(wndw.event_flag.mouse_pos_changed);

// Toggle a single event type
win.setEventState(wndw.event_flag.window_refresh, false);
```

---

## Keyboard Input

### Per-window (recommended)

```zig
if (win.isKeyPressed(wndw.key.space))   { /* just pressed this frame */ }
if (win.isKeyDown(wndw.key.w))          { /* currently held */ }
if (win.isKeyReleased(wndw.key.escape)) { /* just released */ }
```

### Global (across all windows)

```zig
if (wndw.input.isKeyPressed(wndw.key.space))   { /* ... */ }
if (wndw.input.isKeyDown(wndw.key.w))          { /* ... */ }
if (wndw.input.isKeyReleased(wndw.key.escape)) { /* ... */ }
```

### Exit key shortcut

```zig
win.setExitKey(wndw.key.escape); // pressing Escape will set shouldClose
```

### Key constants (`wndw.key.*`)

Letters: `a`-`z` | Numbers: `@"0"`-`@"9"` | Function keys: `f1`-`f25`

Navigation: `up`, `down`, `left`, `right`, `home`, `end`, `page_up`, `page_down`, `insert`, `delete`

Modifiers: `shift_l`, `shift_r`, `control_l`, `control_r`, `alt_l`, `alt_r`, `super_l`, `super_r`

Special: `escape`, `space`, `tab`, `back_space`, `@"return"` (or alias `enter`), `caps_lock`, `num_lock`, `scroll_lock`, `print_screen`, `pause`, `menu`

Symbols: `minus`, `equal` (alias `equals`), `period`, `comma`, `slash`, `bracket`, `close_bracket`, `semicolon`, `apostrophe`, `back_slash`, `backtick`

Keypad: `kp_0`-`kp_9`, `kp_slash`, `kp_multiply`, `kp_plus`, `kp_minus`, `kp_equal` (alias `kp_equals`), `kp_return`, `kp_period`

Other: `world1`, `world2`, `last` (sentinel = 256), `null_key`

### Modifier masks (`wndw.keymod.*`)

`shift`, `control`, `alt`, `super`, `caps_lock`, `num_lock`, `scroll_lock`

### Key conversion

```zig
const native = wndw.keyToApiKey(wndw.key.a);     // wndw key -> platform keycode
const key = wndw.apiKeyToKey(native);             // platform keycode -> wndw key
const mapped = wndw.physicalToMappedKey(wndw.key.a); // physical -> logical layout key
```

---

## Mouse Input

### Per-window

```zig
if (win.isMousePressed(wndw.mouse.left))  { /* just clicked */ }
if (win.isMouseDown(wndw.mouse.right))    { /* held */ }
if (win.isMouseReleased(wndw.mouse.middle)) { /* just released */ }

const pos = win.mousePosition();          // position relative to window
const inside = win.isMouseInside();       // cursor within client area?
const entered = win.didMouseEnter();      // entered this frame?
const left = win.didMouseLeave();         // left this frame?
```

### Global

```zig
if (wndw.input.isMousePressed(wndw.mouse.left)) { /* ... */ }

const scroll = wndw.input.mouseScroll();  // { x, y } scroll delta
const delta = wndw.input.mouseVector();   // { x, y } movement delta
const screen_pos = wndw.input.globalMouse(); // ?Point in screen coords
```

### Mouse button constants (`wndw.mouse.*`)

`left`, `middle`, `right`, `misc1`, `misc2`, `misc3`, `misc4`, `misc5`

### Mouse control

```zig
win.showMouse(false);                     // hide cursor
win.moveMouse(400, 300);                  // warp cursor
win.captureMouse(true);                   // confine to window
win.setRawMouseMode(true);                // unaccelerated input
win.captureRawMouse(true);                // capture + raw in one call
```

---

## Cursors

### Standard shapes

```zig
_ = win.setMouseCursor(wndw.cursor.ibeam);
_ = win.setMouseCursor(wndw.cursor.pointing_hand);
_ = win.resetMouseCursor();
```

Available in `wndw.cursor.*`: `normal`, `arrow`, `ibeam`, `crosshair`, `pointing_hand`, `resize_ew`, `resize_ns`, `resize_nwse`, `resize_nesw`, `resize_all`, `not_allowed`, `wait`, `progress`, `resize_nw`, `resize_n`, `resize_ne`, `resize_e`, `resize_se`, `resize_s`, `resize_sw`, `resize_w`

### Custom cursors

```zig
var custom = wndw.Mouse.load(pixels.ptr, 32, 32, wndw.format.rgba8) orelse return;
defer custom.free();
win.setCustomMouse(custom);
```

---

## Drag & Drop

Enable drag-and-drop at creation or runtime:

```zig
var win = try wndw.init("app", 800, 600, .{ .allow_dnd = true });
// or: win.setDND(true);

// In event loop:
if (win.isDataDragging()) {
    if (win.dataDragPosition()) |pos| {
        // draw drop indicator at pos.x, pos.y
    }
}

if (win.didDataDrop()) {
    if (win.getDataDrop()) |drop| {
        for (0..drop.count) |i| {
            const path = std.mem.span(drop.files[i]);
            // handle dropped file
        }
    }
}
```

---

## Monitors

```zig
// Get primary monitor
if (wndw.getPrimaryMonitor()) |mon| {
    const name = mon.name();             // []const u8
    const pos = mon.position();          // { x, y }
    const scl = mon.scale();             // { x, y } -- 2.0 for Retina
    const phys = mon.physicalSize();     // { w, h } in inches
    const ratio = mon.pixelRatio();      // f32
    const cur_mode = mon.mode();         // { w, h, refresh_rate }
    const wa = mon.workarea();           // { x, y, w, h } -- excludes taskbar
}

// Enumerate all monitors
var buf: [8]wndw.Monitor = undefined;
const monitors = wndw.getMonitors(&buf);
for (monitors) |mon| {
    // ...
}

// Move window to a monitor
if (wndw.getPrimaryMonitor()) |mon| {
    win.moveToMonitor(mon);
    win.scaleToMonitor();                // scale to match monitor DPI
}

// Gamma
if (wndw.getPrimaryMonitor()) |mon| {
    _ = mon.setGamma(1.0);
    if (mon.getGammaRamp()) |ramp| {
        defer wndw.freeGammaRamp(ramp);
        // inspect ramp channels
    }
}

// Display modes
if (wndw.getPrimaryMonitor()) |mon| {
    if (wndw.getMonitorModes(mon)) |result| {
        defer wndw.freeModes(result.modes);
        for (result.modes[0..result.count]) |m| {
            // m.w, m.h, m.refreshRate
        }
    }
}

// User data
mon.setUserPtr(@ptrCast(my_data));
if (mon.getUserPtr(MyType)) |data| { /* ... */ }
```

---

## Clipboard

```zig
wndw.clipboard.write("Hello, clipboard!");

if (wndw.clipboard.read()) |text| {
    // text is a borrowed []const u8 -- do not free
}

// Or read into your own buffer:
var buf: [1024]u8 = undefined;
if (wndw.clipboard.readInto(&buf)) |text| {
    // text is a slice into buf
}
```

---

## OpenGL

Requires `-Drgfw_opengl=true`.

### Context setup

```zig
// Set hints before creating window
var hints: wndw.GlHints = undefined;
wndw.gl.resetGlobalHints();
wndw.gl.setGlobalHints(&hints);

// Window automatically gets a context when rgfw_opengl is enabled
var win = try wndw.init("GL App", 800, 600, .{});
defer win.close();
```

### Render loop

```zig
while (!win.shouldClose()) {
    win.poll();

    // ... OpenGL calls ...

    win.swapBuffers();
}
```

### Context management

```zig
win.makeContextCurrent();               // make this window's GL context current
win.swapInterval(1);                     // enable VSync (0 = off, -1 = adaptive)
win.deleteContext();                     // destroy the GL context

// Load GL function pointers
const glClear = wndw.gl.getProcAddress("glClear");

// Extension queries
if (wndw.gl.extensionSupported("GL_ARB_debug_output")) { /* ... */ }
```

### Advanced context management

```zig
// Create additional contexts
var ctx = win.createOpenGLContext(&hints) orelse return error.ContextFailed;

// Get native handle
const native_ctx = wndw.gl.getSourceContext(&ctx);
const current = wndw.gl.getCurrentContext();
const current_win = wndw.gl.getCurrentWindow();
```

---

## EGL

Available on Linux/Wayland, Android, and embedded platforms.

```zig
var ctx = win.createEGLContext(&hints) orelse return;
defer win.deleteEGLContext(&ctx);

win.swapBuffersEGL();
win.swapIntervalEGL(1);
win.makeCurrentContextEGL();

// Global EGL queries
const display = wndw.egl.getDisplay();
const native_ctx = wndw.egl.getSourceContext(&ctx);
const surface = wndw.egl.getSurface(&ctx);
const proc = wndw.egl.getProcAddress("eglSwapBuffers");
```

---

## Vulkan

Requires `-Drgfw_vulkan=true`. When disabled, `wndw.vulkan` is an empty struct.

```zig
// Get required instance extensions
const exts = wndw.vulkan.getRequiredInstanceExtensions();
// exts.extensions[0..exts.count]

// Create surface
var surface: wndw.vulkan.VkSurfaceKHR = undefined;
const result = win.createVulkanSurface.?(instance, &surface);

// Check presentation support
const supported = wndw.vulkan.getPresentationSupport(physical_device, queue_family);
```

---

## DirectX

Requires `-Drgfw_directx=true` (Windows only). When disabled, `wndw.directx` is an empty struct.

```zig
var swapchain: *wndw.directx.IDXGISwapChain = undefined;
const hr = win.createDirectXSwapChain.?(factory, device, &swapchain);
```

---

## WebGPU

Requires `-Drgfw_webgpu=true`. When disabled, `wndw.webgpu` is an empty struct.

```zig
const surface = win.createWebGPUSurface.?(wgpu_instance);
```

---

## Software Rendering

Create a pixel buffer and blit it to the window without any GPU API:

```zig
var pixels: [800 * 600 * 4]u8 = undefined;

if (win.createSurface(&pixels, 800, 600, wndw.format.rgba8)) |surface| {
    defer wndw.freeSurface(surface);

    // Write pixels...
    pixels[0] = 255; // R
    pixels[1] = 0;   // G
    pixels[2] = 0;   // B
    pixels[3] = 255; // A

    win.blitSurface(surface);
}
```

### Pixel formats (`wndw.format.*`)

`rgb8`, `bgr8`, `rgba8`, `argb8`, `bgra8`, `abgr8`

### Format conversion

```zig
wndw.copyImageData(dest.ptr, 800, 600, wndw.format.bgra8, src.ptr, wndw.format.rgba8, null);
```

---

## Callbacks

Register global callbacks for event-driven architectures:

```zig
_ = wndw.callbacks.setKey(struct {
    fn cb(win_ptr: *wndw.rgfw_h.RGFW_window, k: wndw.Key, _: [*c]u8, pressed: wndw.rgfw_h.RGFW_bool, _: wndw.rgfw_h.RGFW_bool) callconv(.c) void {
        _ = win_ptr;
        if (wndw.toBool(pressed)) {
            // key pressed
            _ = k;
        }
    }
}.cb);
```

Available callback setters in `wndw.callbacks.*`:

| Setter | Event |
|--------|-------|
| `setKey` | Key press/release |
| `setKeyChar` | Unicode character input |
| `setMouseButton` | Mouse button press/release |
| `setMouseScroll` | Mouse scroll |
| `setMousePos` | Mouse move |
| `setMouseNotify` | Mouse enter/leave |
| `setWindowMoved` | Window moved |
| `setWindowResized` | Window resized |
| `setWindowQuit` | Window close requested |
| `setWindowRefresh` | Window needs redraw |
| `setWindowMaximized` | Window maximized |
| `setWindowMinimized` | Window minimized |
| `setWindowRestored` | Window restored |
| `setFocus` | Focus change |
| `setDataDrop` | File drop |
| `setDataDrag` | File drag |
| `setScaleUpdated` | DPI/scale change |
| `setMonitor` | Monitor connected/disconnected |
| `setDebug` | Debug/error messages |

---

## Platform-Native Handles

For interop with platform-specific or third-party libraries:

```zig
// macOS
const ns_view = win.getViewOSX();       // ?*anyopaque (NSView*)
const ns_window = win.getWindowOSX();   // ?*anyopaque (NSWindow*)
win.setLayerOSX(layer);
const layer = wndw.getLayerOSX();

// Windows
const hwnd = win.getHWND();             // ?*anyopaque (HWND)
const hdc = win.getHDC();               // ?*anyopaque (HDC)

// X11
const x11_win = win.getWindowX11();     // u64 (Window)
const x11_display = wndw.getDisplayX11(); // ?*anyopaque (Display*)

// Wayland
const wl_surface = win.getWindowWayland(); // ?*anyopaque (wl_surface*)
const wl_display = wndw.getDisplayWayland(); // ?*anyopaque (wl_display*)

// General
const src = win.getSrc();               // platform-specific internal struct
const is_wayland = wndw.usingWayland(); // check backend on Linux
```

---

## Memory Management

### Pre-allocated window memory

For when you need to control allocation:

```zig
const win_size = wndw.sizeofWindow();
const buf = wndw.alloc(win_size) orelse return error.OutOfMemory;
defer wndw.free(buf);

var win = try wndw.createWindowPtr("title", 0, 0, 800, 600, .{}, @ptrCast(@alignCast(buf)));
defer win.closePtr(); // closePtr doesn't free -- you manage the memory
```

### RGFW library lifecycle

```zig
// Custom Info management (advanced)
const info_size = wndw.sizeofInfo();
// ... allocate info_size bytes ...
_ = wndw.initPtr(info);
defer wndw.deinitPtr(info);

// Query/replace global state
wndw.setInfo(info);
const current = wndw.getInfo();
```

### Sizeof helpers

```zig
wndw.sizeofWindow()      // RGFW_window struct size
wndw.sizeofWindowSrc()   // platform-specific window source size
wndw.sizeofNativeImage()  // native image handle size
wndw.sizeofSurface()      // surface struct size
wndw.sizeofInfo()         // global Info struct size
```

---

## Utilities

### Window operations

```zig
win.setName("New Title");
win.setOpacity(200);                      // 0-255
win.setAspectRatio(16, 9);
win.setMinSize(400, 300);
win.setMaxSize(1920, 1080);
win.flashWindow(wndw.flash_request.briefly);
win.setMousePassthrough(true);

// Icon
_ = win.setIcon(pixels.ptr, 32, 32, wndw.format.rgba8);
_ = win.setIconEx(pixels.ptr, 32, 32, wndw.format.rgba8, wndw.icon_type.both);
```

### User data

Attach arbitrary data to windows or monitors:

```zig
win.setUserPtr(@ptrCast(my_data));
if (win.getUserPtr(MyType)) |data| {
    // use data
}
```

### Platform helpers

```zig
wndw.setClassName("my-app");              // X11 window class name
wndw.setXInstName("my-app");             // X11 instance name
wndw.moveToMacOSResourceDir();           // cd to .app/Contents/Resources
wndw.useWayland(true);                   // force Wayland on Linux
const native_fmt = wndw.nativeFormat();  // platform-native pixel format
```

### UTF-8

```zig
var idx: usize = 0;
const codepoint = wndw.decodeUTF8(string.ptr, &idx);
const is_latin = wndw.isLatin(string);
```

### Debug system

```zig
wndw.sendDebugInfo(wndw.debug_type.info, wndw.error_code.no_error, "hello from wndw");
```

Error codes in `wndw.error_code.*`: `no_error`, `out_of_memory`, `opengl_context`, `egl_context`, `wayland`, `x11`, `directx_context`, `iokit`, `clipboard`, `failed_func_load`, `buffer`, `metal`, `platform`, `event_queue`, `info_window`, `info_buffer`, `info_global`, `info_opengl`, `warning_wayland`, `warning_opengl`

---

## API Reference

### Namespaces

| Namespace | Contents |
|-----------|----------|
| `wndw.key.*` | Keyboard scancodes (`escape`, `space`, `a`-`z`, `f1`-`f25`, ...) |
| `wndw.keymod.*` | Modifier bitmasks (`shift`, `control`, `alt`, `super`, ...) |
| `wndw.mouse.*` | Mouse button IDs (`left`, `right`, `middle`, `misc1`-`misc5`) |
| `wndw.cursor.*` | Cursor shapes (`arrow`, `ibeam`, `hand`, `resize_*`, ...) |
| `wndw.event_type.*` | Event discriminators (`key_pressed`, `quit`, ...) |
| `wndw.event_flag.*` | Event filter bitmasks + composites (`key_events`, `all`, ...) |
| `wndw.format.*` | Pixel formats (`rgba8`, `bgra8`, `rgb8`, ...) |
| `wndw.window_flag.*` | Raw window flags (`raw_mouse`, `opengl`, ...) |
| `wndw.event_wait.*` | Wait timeout constants (`no_wait`, `next`) |
| `wndw.flash_request.*` | Flash modes (`cancel`, `briefly`, `until_focused`) |
| `wndw.icon_type.*` | Icon targets (`taskbar`, `window`, `both`) |
| `wndw.debug_type.*` | Debug severity (`error`, `warning`, `info`) |
| `wndw.error_code.*` | Error/warning/info codes |
| `wndw.mode_request.*` | Monitor mode request flags (`scale`, `refresh`, `rgb`, `all`) |
| `wndw.gl_profile.*` | OpenGL profiles (`core`, `compatibility`, `es`) |
| `wndw.gl_renderer.*` | GL renderer hints (`accelerated`, `software`) |
| `wndw.gl_release.*` | GL release behaviour (`flush`, `none`) |
| `wndw.gl.*` | OpenGL global functions |
| `wndw.egl.*` | EGL global functions |
| `wndw.vulkan.*` | Vulkan types + functions (conditional) |
| `wndw.directx.*` | DirectX types (conditional) |
| `wndw.webgpu.*` | WebGPU types (conditional) |
| `wndw.callbacks.*` | Callback registration functions |
| `wndw.input.*` | Global input queries |
| `wndw.clipboard.*` | Clipboard read/write |

### Type aliases

| Zig Type | C Type | Description |
|----------|--------|-------------|
| `Event` | `RGFW_event` | Tagged event union |
| `Key` | `RGFW_key` | Keycode |
| `MouseButton` | `RGFW_mouseButton` | Mouse button ID |
| `EventType` | `RGFW_eventType` | Event discriminator |
| `KeyMod` | `RGFW_keymod` | Modifier bitmask |
| `MouseIcon` | `RGFW_mouseIcons` | Cursor shape |
| `WindowFlags` | `RGFW_windowFlags` | Window flag bitmask |
| `EventFlag` | `RGFW_eventFlag` | Event filter bitmask |
| `Format` | `RGFW_format` | Pixel format |
| `FlashRequest` | `RGFW_flashRequest` | Flash mode |
| `IconType` | `RGFW_icon` | Icon target |
| `GlProfile` | `RGFW_glProfile` | GL profile |
| `GlHints` | `RGFW_glHints` | GL context hints |
| `GlContext` | `RGFW_glContext` | GL context handle |
| `EglContext` | `RGFW_eglContext` | EGL context handle |
| `MonitorMode` | `RGFW_monitorMode` | Display mode |
| `GammaRamp` | `RGFW_gammaRamp` | Gamma LUT |
| `Surface` | `RGFW_surface` | Software surface |
| `ModeRequest` | `RGFW_modeRequest` | Mode change flags |
| `DebugType` | `RGFW_debugType` | Debug severity |
| `ErrorCode` | `RGFW_errorCode` | Error/info/warning code |
| `Info` | `RGFW_info` | Library global state |
| `Point` | -- | `struct { x: i32, y: i32 }` |
| `Size` | -- | `struct { w: i32, h: i32 }` |

---

## Design

- **Single-file Zig API**: everything lives in `src/root.zig`
- **RGFW vendored**: C header at `vendor/rgfw/RGFW.h`, compiled STB-style via `build.zig`
- **Idiomatic Zig**: native `bool`, `?T` optionals, `error` unions, `[:0]const u8` strings
- **Zero overhead**: thin wrappers that compile down to direct C calls
- **Conditional compilation**: graphics API namespaces use `@hasDecl` to resolve to empty structs when their build option is off

## Local Development

```sh
zig build                    # compile the library
zig build test               # run tests
zig build -Drgfw_opengl=true # compile with OpenGL support
```

## License

Same license as [RGFW](https://github.com/ColleagueRiley/RGFW) (zlib).
