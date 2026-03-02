# wndw — OpenGL Context Implementation Plan

Pure Zig NSOpenGL integration. No C headers — all calls via ObjC runtime.

**Approach: TDD** — write failing tests first, then implement until green.

**Reference:** RGFW's macOS OpenGL implementation (`RGFW.h` lines 14452–14587).

**Note:** Apple deprecated NSOpenGL in favour of Metal (macOS 10.14+). It still
works on macOS 14+ and is the standard cross-platform GL path. A Metal backend
can be added later.

---

## Existing Infrastructure

Already in place:
- All `NSOpenGLPFA*` constants in `cocoa.zig` (depth, stencil, samples, profiles, etc.)
- `NSOpenGLContextParameter*` constants (swap interval = 222, surface opacity = 236)
- `NSOpenGLProfileVersion3_2Core` (0x3200) and `4_1Core` (0x4100)
- `objc.msgSend` helper with per-arity fn pointer casts (handles up to 4 args)
- Manual fn pointer cast pattern for struct/pointer args (proven in Phases 1–8)
- NSView already attached to NSWindow — GL context will bind to it

**Missing constants (need to add to `cocoa.zig`):**
- `NSOpenGLPFAClosestPolicy = 74` — choose closest matching color buffer
- `NSOpenGLPFAAccelerated = 73` — require hardware acceleration
- `NSOpenGLPFAAuxBuffers = 7` — auxiliary buffers
- `NSOpenGLPFAAccumSize = 14` — accumulation buffer bits
- `NSOpenGLProfileVersionLegacy = 0x1000` — pre-3.0 profile

---

## RGFW Implementation Analysis

Key patterns from RGFW's macOS GL context code:

### 1. View Replacement
RGFW **replaces the entire NSView with an NSOpenGLView** when creating a GL context:
```c
// Releases old view, creates NSOpenGLView subclass
win->src.view = [[RGFWOpenGLCustomView alloc] initWithFrame:rect pixelFormat:format];
[window setContentView:view];
```
This is important — the view must be an `NSOpenGLView` (or at least support `setOpenGLContext:`).

**Our approach:** Instead of replacing our custom NSView, we'll use `setView:` on the
NSOpenGLContext to attach it to our existing view. This is simpler and avoids re-registering
all the delegate callbacks. If that doesn't work, we'll fall back to RGFW's approach.

### 2. Pixel Format Attribute Array
RGFW builds a stack-allocated `i32[40]` array with key-value pairs:
```c
attribs[i++] = NSOpenGLPFAColorSize;  attribs[i++] = 8;
attribs[i++] = NSOpenGLPFADepthSize;  attribs[i++] = 24;
// ...
attribs[i++] = NSOpenGLPFAAccelerated;  // flag-only, no value
// ...
attribs[i++] = 0;  // null terminator
```
Some attributes are flag-only (just the constant), others are key-value pairs.

### 3. Profile Selection
```c
profile = (major >= 4) ? NSOpenGLProfileVersion4_1Core
        : (major >= 3) ? NSOpenGLProfileVersion3_2Core
        : NSOpenGLProfileVersionLegacy;
```

### 4. Fallback on Format Failure
If `initWithAttributes:` returns nil with `NSOpenGLPFAAccelerated`, RGFW retries
with `kCGLRendererGenericFloatID` (software renderer). Good practice.

### 5. View Configuration
After creating the context:
```c
[view setOpenGLContext:context];
[window setContentView:view];
[view setWantsLayer:YES];
[view setLayerContentsPlacement:4];  // NSViewLayerContentsPlacementScaleProportionallyToFill
```

### 6. getProcAddress
RGFW uses **CFBundle**, not dlsym:
```c
CFBundleRef bundle = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.opengl"));
CFStringRef name = CFStringCreateWithCString(kCFAllocatorDefault, procname, kCFStringEncodingASCII);
symbol = CFBundleGetFunctionPointerForName(bundle, name);
CFRelease(name);
```
This is more robust than dlsym on macOS. We'll use the same approach.

### 7. Cleanup
```c
[format release];
[context release];
```
Both pixel format and context need explicit release.

---

## Phase 9a — GLHints Struct & Window Fields

Add the data structures and missing constants. No ObjC calls yet.

| # | Feature | Notes |
|---|---------|-------|
| 1 | `GLHints` struct | Matches RGFW defaults: depth=24, stencil=0, samples=0, etc. |
| 2 | `gl_context: ?objc.id` field | nullable — null until createGLContext |
| 3 | `gl_format: ?objc.id` field | store pixel format for cleanup (RGFW does this) |
| 4 | Add missing constants to `cocoa.zig` | ClosestPolicy, Accelerated, AuxBuffers, etc. |
| 5 | Re-export GLHints from root.zig | so consumers can `wndw.GLHints{ ... }` |

**GLHints struct (simplified from RGFW):**
```zig
pub const GLHints = struct {
    major: u32 = 3,           // GL version major (RGFW defaults to 1, we default to 3.2 core)
    minor: u32 = 2,           // GL version minor
    depth_bits: u32 = 24,     // depth buffer bits
    stencil_bits: u32 = 0,    // stencil buffer bits
    samples: u32 = 0,         // MSAA samples (0 = disabled)
    double_buffer: bool = true,
    srgb: bool = false,
    transparent: bool = false, // set surface opacity to 0
};
```
We simplify vs RGFW — drop aux buffers, accum buffers, stereo (rarely used).
Default to GL 3.2 Core (not legacy 1.0) since that's what most users want.

**TDD tests (red):**
- `@hasField(GLHints, "depth_bits")` etc.
- `@hasField(Window, "gl_context")`
- Default values check

---

## Phase 9b — createGLContext

Build NSOpenGLPixelFormat attribute array from GLHints, create NSOpenGLContext,
attach to view.

| # | Feature | macOS API |
|---|---------|-----------|
| 1 | Build pixel format attrs | Null-terminated `[_]u32` stack array from GLHints |
| 2 | Create NSOpenGLPixelFormat | `[[NSOpenGLPixelFormat alloc] initWithAttributes:]` |
| 3 | Create NSOpenGLContext | `[[NSOpenGLContext alloc] initWithFormat:shareContext:]` |
| 4 | Attach to view | `[context setView:]` on our existing NSView |
| 5 | Configure view | `[view setWantsLayer:YES]` |
| 6 | Store on Window | `win.gl_context = context`, `win.gl_format = format` |
| 7 | Make current + set swap interval 0 | Match RGFW's post-init behavior |

**TDD tests (red):**
- `@hasDecl(Window, "createGLContext")` existence check

**Implementation (following RGFW's pattern):**
```zig
pub fn createGLContext(win: *Window, hints: GLHints) !void {
    // 1. Build attribute array
    var attrs: [30]u32 = undefined;
    var i: usize = 0;
    attrs[i] = cocoa.NSOpenGLPFAColorSize;  i += 1; attrs[i] = 8;  i += 1;
    attrs[i] = cocoa.NSOpenGLPFAAlphaSize;  i += 1; attrs[i] = 8;  i += 1;
    attrs[i] = cocoa.NSOpenGLPFADepthSize;  i += 1; attrs[i] = hints.depth_bits;  i += 1;
    // ... stencil, samples, profile, accelerated, double_buffer, closest policy
    attrs[i] = 0; // null terminator

    // 2. Create pixel format
    const FnInitAttrs = fn (id, SEL, [*]const u32) callconv(.c) ?id;
    const fmt = ... initWithAttributes: ...
    if (fmt == null) return error.PixelFormatFailed;

    // 3. Create context
    const FnInitCtx = fn (id, SEL, id, ?id) callconv(.c) ?id;
    const ctx = ... initWithFormat:shareContext: ...
    if (ctx == null) return error.ContextCreationFailed;

    // 4. Attach to view
    objc.msgSend(void, ctx, "setView:", .{win.ns_view});
    objc.msgSend(void, win.ns_view, "setWantsLayer:", .{objc.YES});

    // 5. Make current + vsync off
    objc.msgSend(void, ctx, "makeCurrentContext", .{});
    // setSwapInterval(0)

    win.gl_context = ctx;
    win.gl_format = fmt;
}
```

**Key differences from RGFW:**
- We use `setView:` instead of replacing the view with NSOpenGLView
- We return `!void` (Zig error) instead of RGFW_bool
- No software renderer fallback initially (can add later)

---

## Phase 9c — Context Operations

Simple one-liner ObjC calls once the context exists.

| # | Feature | macOS API |
|---|---------|-----------|
| 1 | `makeContextCurrent()` | `[context makeCurrentContext]` (instance method) |
| 2 | `swapBuffers()` | `[context flushBuffer]` |
| 3 | `setSwapInterval(i32)` | `[context setValues:forParameter:]` with param 222 |
| 4 | `deleteContext()` | `[NSOpenGLContext clearCurrentContext]` + release both |

**TDD tests (red):**
- `@hasDecl` for each method

**Implementation notes (from RGFW):**
- `makeCurrentContext` — instance method: `[context makeCurrentContext]`
  RGFW also supports `makeCurrentContext(null)` → `[NSOpenGLContext clearCurrentContext]`
- `swapBuffers` — `[context flushBuffer]` — single call
- `setSwapInterval` — uses `setValues:forParameter:` with pointer-to-i32:
  ```zig
  const FnSetValues = fn (id, SEL, *const i32, i32) callconv(.c) void;
  fn_set(ctx, sel, &interval, 222); // NSOpenGLContextParameterSwapInterval
  ```
- `deleteContext` — RGFW releases both format and context:
  ```zig
  [format release];  win.gl_format = null;
  [context release]; win.gl_context = null;
  ```
- Guard all methods: no-op if `gl_context == null`

---

## Phase 9d — getProcAddress & Demo

Load GL function pointers at runtime for actual rendering.

| # | Feature | macOS API |
|---|---------|-----------|
| 1 | `getProcAddress(name)` | CFBundle approach (same as RGFW) |
| 2 | GL demo | Create context, clear to cornflower blue, swap in loop |

**TDD tests (red):**
- `@hasDecl(Window, "getProcAddress")` existence check

**Implementation (matching RGFW):**
RGFW uses CFBundle to load GL symbols, NOT dlsym:
```zig
pub fn getProcAddress(_: *Window, name: [*:0]const u8) ?*anyopaque {
    // Cache the bundle handle
    const S = struct { var bundle: ?*anyopaque = null; };
    if (S.bundle == null) {
        S.bundle = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.opengl"));
    }
    const cf_name = CFStringCreateWithCString(null, name, kCFStringEncodingASCII);
    defer CFRelease(cf_name);
    return CFBundleGetFunctionPointerForName(S.bundle, cf_name);
}
```

Requires adding extern declarations for:
- `CFBundleGetBundleWithIdentifier`
- `CFStringCreateWithCString`
- `CFBundleGetFunctionPointerForName`
- `CFRelease`

These are all in CoreFoundation (linked via Cocoa).

**Demo:**
```zig
var win = try wndw.init("OpenGL demo", 800, 600, .{ .centred = true });
defer win.close();

try win.createGLContext(.{});  // defaults: GL 3.2 Core, depth=24, double-buffered
defer win.deleteContext();

// Load GL functions
const glClearColor = @as(*const fn (f32, f32, f32, f32) callconv(.c) void,
    @ptrCast(win.getProcAddress("glClearColor") orelse unreachable));
const glClear = @as(*const fn (u32) callconv(.c) void,
    @ptrCast(win.getProcAddress("glClear") orelse unreachable));

while (!win.shouldClose()) {
    while (win.poll()) |ev| { ... }
    glClearColor(0.39, 0.58, 0.93, 1.0);  // cornflower blue
    glClear(0x4000);  // GL_COLOR_BUFFER_BIT
    win.swapBuffers();
}
```

---

## Phase Summary

| Phase | What | Tests | ObjC/CF calls |
|-------|------|-------|---------------|
| 9a | Struct + fields + constants | ~8 field checks | 0 |
| 9b | createGLContext | ~1 existence | ~7 ObjC calls |
| 9c | Context ops | ~4 existence | ~5 ObjC calls |
| 9d | getProcAddress + demo | ~1 existence | ~4 CF calls |

---

## Applicable Learnings (from Phases 1–11 + RGFW analysis)

- **Manual fn pointer casts** required for pointer/struct args. Will need for:
  - `initWithAttributes:` (`[*]const u32` arg)
  - `initWithFormat:shareContext:` (`id, ?id` args)
  - `setValues:forParameter:` (`*const i32, i32` args)
- **`alloc` → `init*:`** two-step pattern (same as NSTrackingArea in Phase 4)
- **Guard on nil**: `if (win.gl_context) |ctx| { ... }` for safe no-ops
- **Test without ObjC**: `@hasDecl` / `@hasField` only. Smoke test via demo.
- **`@Type(.@"fn")` unsupported** in Zig 0.16.0-dev — explicit fn type aliases
- **arm64**: `objc_msgSend` handles all return types, no `_stret`/`_fpret`
- **RGFW stores both format + context** — release both on cleanup
- **RGFW uses `setView:` + `setWantsLayer:YES`** after attaching context
- **RGFW uses CFBundle for getProcAddress** — more robust than dlsym on macOS
- **RGFW sets swap interval to 0** immediately after context creation
- **RGFW's `NSOpenGLProfileVersion4_1Core`** is defined as 0x3200 (same as 3_2Core) —
  this appears to be a bug in RGFW. We should use the correct value (0x4100).
