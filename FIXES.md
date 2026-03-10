# Code Review Fixes

## CRITICAL

### 1. Missing autorelease pool in event loop
**`window.zig:1224-1241`** — `drain_ns_events` runs with no `NSAutoreleasePool`. Every `nextEventMatchingMask:` returns an autoreleased `NSEvent`, and `sendEvent:` creates more autoreleased objects internally. Without a pool, these accumulate indefinitely — hundreds per second in a typical game loop.

**Status:** DONE — Added `NSAutoreleasePool alloc/init` + `defer drain` wrapping the event loop in `drain_ns_events`.

### 2. `delegate_window_should_close` makes close prevention impossible
**`window.zig:1420-1426`** — Sets `should_close = true` *and* returns `YES` to AppKit before the `close_requested` event is ever polled. The doc comment on `close_requested` says "ignore to prevent closing," but that's impossible.

**Status:** DONE — Removed `should_close = true` from delegate. Now returns `NO` to AppKit so the user must call `win.quit()` explicitly.

### 3. `class_addIvar` alignment passed as bytes instead of log2(bytes)
**`window.zig:1375, 1394`** — Both call sites pass `@alignOf(*anyopaque)` which is `8`. The ObjC runtime expects `log2(alignment)`, so `3`.

**Status:** DONE — Changed to `@ctz(@as(usize, @alignOf(*anyopaque)))` at both call sites.

### 4. `NSRect` return via `objc_msgSend` is ABI-broken on x86_64
**`objc.zig:101-113`** — `NSRect` is 32 bytes. On x86_64, structs >16 bytes must use `objc_msgSend_stret`. The `msgSend` helper unconditionally uses `objc_msgSend`.

**Status:** DONE — Added comptime guard in `msgSend` that emits `@compileError` for structs >16 bytes on non-arm64.

## HIGH

### 5. Null dereference: `[NSWindow screen]` returns nil
**`window.zig:611, 878`** — `maximize()` and `getWindowMonitor()` call `[NSWindow screen]` which returns nil when the window is minimized or off-screen.

**Status:** DONE — `maximize()` now returns early if screen is nil. `getWindowMonitor()` falls back to `mainScreen`.

### 6. NSTrackingArea leaked on every window creation
**`window.zig:1190-1198`** — `alloc`+`init` gives +1 retain. `addTrackingArea:` retains again. The caller's +1 is never released.

**Status:** DONE — Added `release` call after `addTrackingArea:`.

### 7. CFString leaked in `getProcAddress`
**`window.zig:1072-1075`** — `CFStringCreateWithCString` returns +1 `bundle_id`, never `CFRelease`d.

**Status:** DONE — Added `defer CFRelease(bundle_id)`.

### 8. `ns_delegate` leaked in `close()`
**`window.zig:406-412`** — Created with `alloc`+`init` (retain +1), never released. Also a potential use-after-free if late AppKit notifications fire after `close()`.

**Status:** DONE — Zero the delegate's `wndw_win` ivar and release the delegate before closing.

### 9. Drop path pointers dangle after autorelease pool drain
**`window.zig:1564-1569`** — `[NSString UTF8String]` returns a pointer into the NSString's internal storage, but the NSString is autoreleased and not retained.

**Status:** DONE — Added `drop_strings` array to retain NSStrings. Released on next drop or `close()`.

### 10. `deleteContext` clears the *global* GL context unconditionally
**`window.zig:1043-1053`** — `[NSOpenGLContext clearCurrentContext]` is class-level. With multiple windows, deleting one window's context unbinds another's.

**Status:** DONE — Now checks `[NSOpenGLContext currentContext]` first; only clears if it matches this window's context.

### 11. `getSize`/`getPos` return anonymous structs instead of named types
**`window.zig:543-550`** — `event.zig` defines `Size` and `Position` types, but these methods return anonymous structs.

**Status:** DONE — `getSize` returns `event.Size`, `getPos` and `getMousePos` return `event.Position`.

### 12. `Monitor` not re-exported from `root.zig`
**`root.zig:40-53`** — `getPrimaryMonitor`, `getWindowMonitor`, `getMonitors` all return `Monitor`, but users can't write `wndw.Monitor`.

**Status:** DONE — Added `pub const Monitor = platform.Monitor` to `root.zig`.

### 13. `super` init called via `objc_msgSend` instead of `objc_msgSendSuper`
**`window.zig:1498-1504`** — `view_init_with_window` sends `initWithFrame:` to `self` via `objc_msgSend`. Works only because `WndwView` doesn't override `initWithFrame:`.

**Status:** DONE — Added `objc_msgSendSuper` + `ObjcSuper` struct to `objc.zig`. `view_init_with_window` now uses super dispatch.

## MEDIUM

### 14. `setCursorVisible` doesn't guard against repeated calls
**`window.zig:635-642`** — `[NSCursor hide]`/`[NSCursor unhide]` use a global counter. Calling `setCursorVisible(false)` twice then `true` once leaves the cursor hidden.

**Status:** DONE — Early return if `visible == win.is_cursor_visible`.

### 15. `resize` uses `setFrame:` instead of `setContentSize:`
**`window.zig:561-570`** — Sets the full window frame (including title bar), so the content area ends up smaller than requested.

**Status:** DONE — Now uses `setContentSize:` which sets the content area directly.

### 16. Unknown mouse buttons silently mapped to `.middle`
**`window.zig:1319-1326`** — Buttons >= 5 produce phantom `.middle` events.

**Status:** DONE — `other_mouse_button` returns `?MouseButton`; callers skip the event on `null`.

### 17. `NSWindowCollectionBehaviorFullScreenPrimary` never applied
**`cocoa.zig:79`** — The constant is defined but never set on windows. `toggleFullScreen:` may silently no-op.

**Status:** DONE — Applied `setCollectionBehavior:` with `NSWindowCollectionBehaviorFullScreenPrimary` after window creation.

### 18. `object_getInstanceVariable`/`object_setInstanceVariable` return type declared `void`
**`objc.zig:72-74`** — The real C signatures return `Ivar`.

**Status:** DONE — Added `Ivar` type alias. Both functions now return `?Ivar`. Callers updated to discard with `_ =`.

### 19. `ns_string` returns non-optional `id` but `stringWithUTF8String:` can return nil
**`objc.zig:122-125`** — If invalid UTF-8 is passed, the nil return is silently cast to a non-null pointer.

**Status:** DONE — `ns_string` now uses `?id` return from `msgSend` and panics with a clear message on nil.

### 20. No double-creation guard on `createGLContext`
**`window.zig:928`** — Calling it twice leaks the old context and format.

**Status:** DONE — `createGLContext` now calls `deleteContext()` first if `gl_context != null`.

### 21. `win.y` calculation inconsistent with delegate callbacks
**`window.zig:1130-1141`** — `init()` computes a flipped Y, but `delegate_window_did_move` stores the raw Cocoa `frame.origin.y`.

**Status:** DONE — Removed manual position calculation. Now reads back actual frame from AppKit after showing window.

### 22. `getMousePos` Y flip uses wrong screen on multi-monitor
**`window.zig:825-833`** — Always uses `mainScreen` height, not the screen the cursor is actually on.

**Status:** DONE — Now iterates `[NSScreen screens]` to find the screen containing the cursor and flips Y relative to that screen's frame.

### 23. `clipboardWrite` takes `[*:0]const u8` while all other string APIs take `[:0]const u8`
**`window.zig:782`**

**Status:** DONE — Changed to `[:0]const u8`, passes `.ptr` to `ns_string`.

### 24. `setOpacity` takes `u8` (0-255) while everything else uses floats
**`window.zig:680`**

**Status:** DONE — Changed to `f32` (0.0–1.0) with `std.math.clamp`. Updated demo.zig.

### 25. No validation on negative `w`/`h` in `init()`
**`window.zig:1102`** — Negative dimensions produce a corrupt `NSRect`.

**Status:** DONE — Returns `error.InvalidDimensions` if `w <= 0` or `h <= 0`.

## LOW

### 26. Path traversal in build.zig demo runner
**`build.zig:61-67`** — `demo_name` from `b.args[0]` is unsanitized.

**Status:** TODO

### 27. No comptime assertion that `KEY_WORDS * 64 >= Key enum size`
**`window.zig:317-329`**

**Status:** TODO

### 28. `resizeable` typo — standard spelling is `resizable`
**`window.zig:53`**

**Status:** TODO

### 29. `Callbacks` covers only 11 of 20 event types
**`window.zig:233-245`**

**Status:** TODO

### 30. `getMonitors` returns slice into static buffer, silently invalidated on re-call
**`window.zig:884-901`**

**Status:** TODO

### 31. `run_loop_mode` string works by coincidence
**`window.zig:1361`**

**Status:** TODO

### 32. `minimize()` restores style mask immediately, racing the animation
**`window.zig:587-596`**

**Status:** TODO

### 33. No `char_input`/`text_input` event for Unicode/IME text entry
**`event.zig:151-205`**

**Status:** TODO
