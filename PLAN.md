# wndw — macOS Implementation Plan

Pure Zig windowing library. No C dependencies — platform APIs called directly via
`extern fn` declarations. macOS backend uses the ObjC runtime + Cocoa/AppKit.

**Approach: TDD** — write failing tests first, then implement until green.

**Zig version: 0.16.0-dev (master/nightly).**

---

## What We Have (Done)

- Window create/close/poll with Options (centred, borderless, resizeable, transparent)
- 13-tag Event union: key, mouse, scroll, resize, move, focus, close, minimize, restore
- 128-entry hardware keycode table, key repeat filtering, modifier diffing
- Window methods: setTitle, resize, move, minimize, restore, maximize, setFullscreen,
  setCursorVisible, setAlwaysOnTop, isFocused, isMinimized, getSize, getPos
- Delegate callbacks: resize, move, focus, miniaturize, deminiaturize, shouldClose
- EventQueue (circular buffer, cap 128), extracted and unit-tested
- Test suite: 6 test files in src/tests/ with runner at src/tests.zig
- Phase 1 methods: isFullscreen, isMaximized, isBorderless, isVisible, setOpacity,
  focus, hide, show, center
- Phase 2 methods: setMinSize, setMaxSize, setAspectRatio, setUserPtr, getUserPtr,
  flash, getNativeWindow, getNativeView
- Phase 3 methods: isCursorVisible, moveMouse, getMousePos, setStandardCursor,
  resetCursor + Cursor enum (9 variants)

---

## Phase 1 — Window State & Simple Queries ✅ DONE

Straightforward field additions and ObjC one-liners. No new delegate callbacks.

| # | Feature | macOS API | Status |
|---|---------|-----------|--------|
| 1 | `isFullscreen()` | read `styleMask` & `NSWindowStyleMaskFullScreen` | ✅ |
| 2 | `isMaximized()` | `[NSWindow isZoomed]` | ✅ |
| 3 | `isBorderless()` | `is_borderless` field, set from init opts | ✅ |
| 4 | `isVisible()` | `is_visible` field, toggled by hide/show | ✅ |
| 5 | `setOpacity(u8)` | `[NSWindow setAlphaValue:]` — map 0–255 to 0.0–1.0 | ✅ |
| 6 | `focus()` | `[NSWindow makeKeyAndOrderFront:]` | ✅ |
| 7 | `hide()` / `show()` | `orderOut:` / `makeKeyAndOrderFront:` | ✅ |
| 8 | `center()` | `[NSWindow center]` | ✅ |

**Tests:** merged into `src/tests/window_methods_test.zig`.

**Learnings:**
- `isFullscreen` and `isMaximized` query ObjC directly — the OS can change these via
  the green button without going through our API, so a cached field would go stale.
- `isVisible` and `isBorderless` use struct fields — these only change through our own
  `hide()`/`show()` and init opts, so fields are reliable and testable.
- `setOpacity` needs a manual `fn` pointer cast for the `CGFloat` arg — the generic
  `msgSend` helper doesn't handle float params directly on arm64.

---

## Phase 2 — Window Constraints & User Pointer ✅ DONE

Still simple — each is a single ObjC call or struct field.

| # | Feature | macOS API | Status |
|---|---------|-----------|--------|
| 1 | `setMinSize(w, h)` | `[NSWindow setContentMinSize:]` | ✅ |
| 2 | `setMaxSize(w, h)` | `[NSWindow setContentMaxSize:]` | ✅ |
| 3 | `setAspectRatio(w, h)` | `[NSWindow setContentAspectRatio:]` | ✅ |
| 4 | `setUserPtr(?*anyopaque)` | store on Window struct | ✅ |
| 5 | `getUserPtr() ?*anyopaque` | read from Window struct | ✅ |
| 6 | `flash()` | `[NSApp requestUserAttention:]` | ✅ |
| 7 | `getNativeWindow() objc.id` | return `win.ns_window` | ✅ |
| 8 | `getNativeView() objc.id` | return `win.ns_view` | ✅ |

**Tests:** merged into `src/tests/window_methods_test.zig`.

**Learnings:**
- `setMinSize`/`setMaxSize`/`setAspectRatio` all take `NSSize` — need manual fn pointer
  cast like `setOpacity` since the generic `msgSend` helper can't pass struct args.
- `flash()` doesn't need the window handle — it's an `NSApp` method. Still makes sense
  on `Window` for API ergonomics.
- `NSInformationalRequest` = 10 (bounces dock icon once, non-critical).

---

## Phase 3 — Mouse Cursor Control ✅ DONE

Cursor state tracking, CoreGraphics warp, NSCursor standard cursors.

| # | Feature | macOS API | Status |
|---|---------|-----------|--------|
| 1 | `isCursorVisible() bool` | `is_cursor_visible` field, toggled by `setCursorVisible` | ✅ |
| 2 | `moveMouse(x, y)` | `CGWarpMouseCursorPosition` | ✅ |
| 3 | `getMousePos() {x, y}` | `[NSEvent mouseLocation]` + Y-flip | ✅ |
| 4 | `Cursor` enum | 9 variants in `event.zig` | ✅ |
| 5 | `setStandardCursor(cursor)` | `[NSCursor <name>]` → `set` | ✅ |
| 6 | `resetCursor()` | `[NSCursor arrowCursor] set` | ✅ |

**Tests:** added to `src/tests/window_methods_test.zig` — 8 new tests.

**Learnings:**
- `CGWarpMouseCursorPosition` is in CoreGraphics, linked via Cocoa. Takes `CGPoint`
  (identical to `NSPoint` on 64-bit). Returns `i32` (CGError).
- `[NSEvent mouseLocation]` returns bottom-left screen coords — Y-flip uses main
  screen frame height.
- NSCursor selector names are quirky: `IBeamCursor` (capital I+B), `operationNotAllowedCursor`.
- Updated existing `setCursorVisible` to also track `is_cursor_visible` field.

---

## Phase 4 — New Event Types ✅ DONE

New NSView overrides and delegate callback additions.

| # | Feature | macOS callback | Status |
|---|---------|----------------|--------|
| 1 | `mouse_entered` / `mouse_left` | `mouseEntered:` / `mouseExited:` + NSTrackingArea | ✅ |
| 2 | `maximized` | detect in `windowDidResize:` via `isZoomed` | ✅ |
| 3 | `refresh_requested` | `drawRect:` on NSView | ✅ |
| 4 | `scale_changed: f32` | `viewDidChangeBackingProperties` | ✅ |

**Tests:** added to `src/tests/event_types_test.zig` — 6 new tests + updated tag count to 18.

**Learnings:**
- NSTrackingArea requires `InVisibleRect` flag (0x200) to auto-resize with the view.
  Options: `MouseEnteredAndExited | ActiveAlways | InVisibleRect` = 0x01 | 0x80 | 0x200.
- `initWithRect:options:owner:userInfo:` takes 4 args — needed manual fn pointer cast
  (5 args including self+SEL exceeds the generic msgSend helper's limit).
- `drawRect:` callback receives an NSRect arg — used manual cast for the struct param.
- `maximized` fires inside `windowDidResize:` after `isZoomed` — will fire alongside
  every resize when zoomed, but that's consistent with how the OS reports it.

---

## Phase 5 — Keyboard Modifiers in Events ✅ DONE

**Breaking change** — `key_pressed` and `key_released` payloads changed from bare `Key` to
`KeyEvent { key: Key, mods: Modifiers }`.

| # | Feature | Status |
|---|---------|--------|
| 1 | `Modifiers` struct (shift, ctrl, alt, super, caps_lock) | ✅ |
| 2 | `KeyEvent` struct attaching mods to key events | ✅ |
| 3 | Read `modifierFlags` from NSEvent in `translate_event` | ✅ |

**Tests:** added to `src/tests/event_types_test.zig` — 5 new tests (struct fields, defaults,
payload access, round-trip). Updated all existing tests in event_queue_test, api_test, event_types_test.

**Learnings:**
- `mods_from_flags()` helper reads macOS modifier constants that were already in `cocoa.zig`.
- FlagsChanged events also get mods — the mods reflect the state *after* the change.
- Updated `demo.zig` and `README.md` for the new payload shape.
- All consumers of `key_pressed`/`key_released` needed `.key` added: `|k| k == .escape`
  → `|kp| kp.key == .escape`.

---

## Phase 6 — Clipboard ✅ DONE

Read/write the system pasteboard. Pure ObjC runtime calls.

| # | Feature | macOS API | Status |
|---|---------|-----------|--------|
| 1 | `clipboardRead() ?[*:0]const u8` | `generalPasteboard` → `stringForType:` → `UTF8String` | ✅ |
| 2 | `clipboardWrite([*:0]const u8)` | `clearContents` → `setString:forType:` | ✅ |

**Tests:** added to `src/tests/window_methods_test.zig` — 2 `@hasDecl` checks.

**Learnings:**
- Pasteboard type string is `"public.utf8-plain-text"` — created via `ns_string()`.
- `stringForType:` returns nullable `?id` — maps to `?objc.id` in Zig.
- `UTF8String` returns `[*:0]const u8` — backed by the NSString's internal storage.
  Lifetime is autoreleased, so caller should copy if needed beyond the current event loop.
- `setString:forType:` takes two args — works with the generic 2-arg msgSend path.

---

## Phase 7 — Drag and Drop ✅ DONE

File drops onto the window via NSDraggingDestination protocol.

| # | Feature | macOS API | Status |
|---|---------|-----------|--------|
| 1 | `setDragAndDrop(bool)` | `registerForDraggedTypes:` / `unregisterDraggedTypes` | ✅ |
| 2 | `getDroppedFiles()` | returns stored paths from last drop | ✅ |
| 3 | `file_drop_started` event | `draggingEntered:` | ✅ |
| 4 | `file_dropped: u32` event | `performDragOperation:` — payload is file count | ✅ |
| 5 | `file_drop_left` event | `draggingExited:` | ✅ |

**Tests:** 3 event tag tests + 2 `@hasDecl` checks in window_methods_test. Tag count → 21.

**Learnings:**
- Used `readObjectsForClasses:options:` (modern pasteboard API) instead of older
  `propertyListForType:` for cleaner NSURL extraction.
- File paths stored in fixed `[MAX_DROP_FILES][*:0]const u8` buffer on Window (cap 64).
  Paths point to autoreleased NSString memory — valid until next event drain.
- `file_dropped` carries a `u32` count instead of a slice — avoids putting pointers
  in the event union. Caller uses `getDroppedFiles()` to access the paths.
- `draggingEntered:` must return `NSDragOperationCopy` (1) to accept the drop.

---

## Phase 8 — Monitor/Display Info ✅ DONE

Query connected displays. All reads, no mutations.

| # | Feature | macOS API | Status |
|---|---------|-----------|--------|
| 1 | `Monitor` struct | x, y, w, h, scale, ns_screen | ✅ |
| 2 | `getMonitors() []const Monitor` | `[NSScreen screens]` | ✅ |
| 3 | `getPrimaryMonitor() Monitor` | `[NSScreen mainScreen]` | ✅ |
| 4 | `getWindowMonitor() Monitor` | `[NSWindow screen]` | ✅ |
| 5 | `moveToMonitor(Monitor)` | `setFrame:display:` | ✅ |

**Tests:** 5 tests in `window_methods_test.zig` (struct fields, `@hasDecl`).

**Learnings:**
- Skipped `localizedName` (requires macOS 10.15+) and refresh rate (needs CoreVideo
  link) — kept Monitor simple with position, size, scale.
- `getMonitors` uses a `struct { var buf }` static buffer pattern (max 16) to avoid
  allocation. Returns a slice into the static buffer.
- `moveToMonitor` uses `setFrame:display:` — positions the window at the monitor's
  origin, keeping the current window size.

---

## Phase 9 — OpenGL Context

Create and manage an NSOpenGLContext. First graphics backend.

| # | Feature | macOS API |
|---|---------|-----------|
| 1 | `createGLContext(hints)` | `NSOpenGLPixelFormat` + `NSOpenGLContext` |
| 2 | `makeContextCurrent()` | `[NSOpenGLContext makeCurrentContext]` |
| 3 | `swapBuffers()` | `[NSOpenGLContext flushBuffer]` |
| 4 | `setSwapInterval(i32)` | `[NSOpenGLContext setValues:forParameter:]` |
| 5 | `deleteContext()` | `[NSOpenGLContext clearCurrentContext]` + release |

**TDD plan:**
- `@hasDecl` checks for all GL methods
- GLHints struct field checks
- Can't test actual GL without a window — use demo for smoke testing

**Implementation notes:**
- NSOpenGLPixelFormat attributes built from hints (depth bits, stencil, MSAA, profile)
- Constants already in `cocoa.zig` (NSOpenGLPFA*, profiles)
- Consider deprecation: Apple deprecated NSOpenGL in favour of Metal. Still works on
  macOS 14+. For maximum compat, may want Metal backend later.

---

## Phase 10 — Global Input State

Frame-based input tracking: "is key currently held", "was key just pressed this frame".

| # | Feature | Notes |
|---|---------|-------|
| 1 | `isKeyDown(Key) bool` | maintained bitset, set on press, cleared on release |
| 2 | `isKeyPressed(Key) bool` | true only on the frame it was first pressed |
| 3 | `isKeyReleased(Key) bool` | true only on the frame it was released |
| 4 | `isMouseDown(MouseButton) bool` | same pattern for mouse |
| 5 | `isMousePressed/Released` | |
| 6 | `beginFrame()` or implicit in `poll()` | swap current/previous state buffers |

**TDD plan:**
- Full logic tests: press → isDown, isPressed; next frame → isDown, !isPressed
- Release → !isDown, isReleased; next frame → !isDown, !isReleased
- No ObjC needed — pure struct logic, fully testable

**Implementation notes:**
- Key bitset: 140 keys → 3 × `u64` or `[3]u64` (current + previous frame)
- Mouse bitset: 5 buttons → single `u8` pair
- Frame boundary: either explicit `beginFrame()` or hook into first `poll()` per frame

---

## Phase 11 — Event Callbacks

Optional callback alternative to polling.

| # | Feature | Notes |
|---|---------|-------|
| 1 | `setOnKeyPress(fn)` | function pointer stored on Window |
| 2 | `setOnMousePress(fn)` etc. | one setter per event type |
| 3 | Callbacks fire during `poll()` | before event is queued |

**TDD plan:**
- `@hasDecl` for setters
- Callback invocation logic (set callback, push event, verify called)
- Can test without ObjC by manually pushing events

---

## Phase Summary

| Phase | Complexity | New ObjC | New Events | Breaking |
|-------|-----------|----------|------------|----------|
| 1. Window state & queries | Easy | ~5 calls | — | No | **Done** |
| 2. Constraints & user ptr | Easy | ~4 calls | — | No | **Done** |
| 3. Mouse cursor control | Easy | ~6 calls | — | No | **Done** |
| 4. New event types | Medium | ~4 callbacks | 4 new tags | No | **Done** |
| 5. Key modifiers | Medium | — | — | **Yes** (payload change) | **Done** |
| 6. Clipboard | Medium | ~4 calls | — | No | **Done** |
| 7. Drag and drop | Medium | ~3 callbacks | 3 new tags | No | **Done** |
| 8. Monitor/display | Medium | ~8 calls | — | No | **Done** |
| 9. OpenGL context | Hard | ~6 calls | — | No |
| 10. Global input state | Medium | — | — | No |
| 11. Event callbacks | Medium | — | — | No |

---

## TDD Workflow (Every Phase)

1. **Red** — write tests in `src/tests/` for new fields, methods, event tags
2. **Green** — implement the minimum code to pass
3. **Refactor** — clean up, extract helpers if needed
4. **Update** `src/tests.zig` — add new test file imports
5. **Demo** — update `demo.zig` to exercise new features interactively

Test files follow the existing patterns:
- `@hasField` / `@hasDecl` for compile-time existence checks
- `var w: Window = undefined; w.field = ...` for pure logic tests
- `@typeInfo` for return type inspection
- EventQueue round-trips for new event tags

---

## Learnings (Reference)

- **Key routing**: `finishLaunching` + `makeFirstResponder:` + read-before-sendEvent
- **Poll efficiency**: drain OS queue only when Zig-side queue is empty
- **NSView init**: must call `initWithFrame:`, not `init`
- **close() safety**: nil delegate before destroying Window struct
- **FlagsChanged**: XOR `prev_flags` to detect which modifier changed
- **Dragged events**: types 6, 7, 27 all map to `mouse_moved`
- **Key repeat**: `isARepeat` filter in KeyDown handler
- **Test runner**: `src/tests.zig` at module root so `src/tests/` can `../` import
- **Never `setStyleMask:` after creation** — triggers windowDidResize mid-calculation
- **arm64**: `objc_msgSend` handles all return types, no `_stret`/`_fpret` needed
- **`@Type(.@"fn")` unsupported** in Zig 0.16.0-dev — use switch on arity instead
