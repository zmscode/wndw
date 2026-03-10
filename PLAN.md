# wndw Feature Plan

Ordered by impact. Each feature follows TDD: write tests first, then implement.

---

## ~~1. Dark/Light Mode Tracking~~ DONE

- `Appearance` enum (`.light`, `.dark`) in `event.zig`, re-exported from `root.zig`
- `.appearance_changed: Appearance` event variant
- `win.getAppearance()` queries `[NSApp effectiveAppearance].name`
- `win.setOnAppearanceChanged(cb)` callback
- `NSDistributedNotificationCenter` observer on `AppleInterfaceThemeChangedNotification`
- Global live window tracking for broadcasting to all windows
- 8 tests in `appearance_test.zig`

---

## ~~2. Keyboard Layout Awareness~~ DONE

- `KeyEvent.character: ?u21` field (defaults to null, backward compatible)
- `UCKeyTranslate` resolves Unicode codepoint per keycode + modifier state
- `TISCopyCurrentKeyboardLayoutInputSource` queries active keyboard layout
- `LMGetKbdType` gets physical keyboard type for accurate translation
- Carbon.framework linked for UCKeyTranslate/TIS APIs
- Dead keys suppressed via `kUCKeyTranslateNoDeadKeysMask`
- Control characters filtered (< 0x20, 0x7F)
- UTF-16 surrogate pair handling for characters > U+FFFF
- Demo updated to print resolved character alongside key name
- 8 tests in `keyboard_layout_test.zig`

---

## ~~3. Callbacks with Context~~ DONE

- All 23 callback slots now hold `func + ctx` pairs via generic `Cb(Arg)` and `CbVoid` types
- `setOn*(ctx, fn)` — context is `?*anyopaque`, passed as first arg to callback
- `dispatchEvent` uses `.call()` method on each slot (null-check + invoke)
- Breaking change: all callback function signatures now take `?*anyopaque` as first param
- 8 tests in `callback_context_test.zig` (context delivery, multi-window, null safety)
- Existing `event_callbacks_test.zig` updated for new signatures

---

## ~~4. CVDisplayLink Frame Sync~~ DONE

- `win.createDisplayLink()` creates and starts a CVDisplayLink
- `win.waitForFrame()` blocks (spin-waits) until the next vsync
- `win.destroyDisplayLink()` stops the link (auto-called by `close()`)
- Background thread callback sets atomic `frame_ready` flag
- Intentional leak on teardown (no CVDisplayLinkRelease — avoids bg thread segfault)
- CoreVideo.framework linked in build.zig
- 6 tests in `display_link_test.zig`

---

## ~~5. Window Kinds (NSPanel)~~ DONE

- `Options.WindowKind` enum: `.normal`, `.floating`, `.popup`, `.dialog`
- `.normal` → NSWindow (unchanged behavior)
- `.floating` → NSPanel + `NSNonactivatingPanel` + `NSFloatingWindowLevel` + `setFloatingPanel:YES` + `setHidesOnDeactivate:NO`
- `.popup` → NSPanel + `NSNonactivatingPanel` + `setBecomesKeyOnlyIfNeeded:YES`
- `.dialog` → NSPanel presented as sheet via `beginSheet:completionHandler:` on `parent`
- `Options.parent: ?*Window` for dialog sheet attachment
- `Window.is_panel: bool` tracks whether created as NSPanel
- `NSWindowStyleMaskNonactivatingPanel` constant added to cocoa.zig
- Fullscreen disabled for panels (not supported by AppKit)
- 8 tests in `window_kind_test.zig`

---

## ~~6. Blurred / Vibrancy Backgrounds~~ DONE

- `Options.WindowBackground` enum: `.solid`, `.transparent`, `.blurred`, `.ultra_dark`
- `Options.BlurMaterial` enum: `.sidebar`, `.popover`, `.hud`, `.titlebar`, `.under_window`
- `NSVisualEffectView` inserted lazily behind `WndwView` on first blurred request
- `win.setBackground()` / `win.setBlurMaterial()` for runtime changes
- `transparent: bool` kept as deprecated alias for `.transparent` background
- NSVisualEffectMaterial/BlendingMode/State constants added to `cocoa.zig`
- 18 tests in `vibrancy_test.zig`

---

## ~~7. Display Content Bounds~~ DONE

- `Monitor` gains `content_x`, `content_y`, `content_w`, `content_h` from `[NSScreen visibleFrame]`
- Excludes menu bar and dock from usable area
- Y-coordinates flipped to top-left origin for both full and content bounds
- 10 tests in `monitor_test.zig`

---

## ~~8. Stable Display UUIDs~~ DONE

- `Monitor` gains `uuid: u128` via `CGDisplayCreateUUIDFromDisplayID` + `CFUUIDGetUUIDBytes`
- Display ID extracted from `[screen deviceDescription]["NSScreenNumber"]`
- Zero if UUID unavailable
- Tests in `monitor_test.zig` (combined with #7)

---

## 9. Ctrl+Click → Right-Click Synthesis

**Why ninth**: Standard macOS convention. Users with single-button trackpads/mice expect this.

**Tests**:
- Ctrl+left-click produces `.mouse_pressed: .right` event
- Ctrl+left-release produces `.mouse_released: .right` event
- Plain left-click with ctrl released is unaffected
- `isMouseDown(.right)` returns true during ctrl+left-click

**Implementation**:
- In `translate_event()`, check `NSEventModifierFlagControl` on left-click events
- Rewrite button from `.left` to `.right` when ctrl is held
- Strip ctrl from modifiers on the synthesized event

---

## 10. First-Mouse Detection

**Why tenth**: Apps need to know if a click was the one that focused the window (to avoid accidental actions).

**Tests**:
- First click on unfocused window has `first_mouse: true`
- Subsequent clicks have `first_mouse: false`
- Flag resets after window loses and regains focus

**Implementation**:
- Override `acceptsFirstMouse:` on `WndwView` to return `YES`
- Track `is_first_mouse` flag, set on `mouseDown:` when `!is_focused`
- Add `first_mouse: bool` field to mouse event payload (or expose via `win.isFirstMouse()`)

---

## 11. Drag Position During Drag-and-Drop

**Why eleventh**: Apps need cursor position during drag to show drop targets / insertion indicators.

**Tests**:
- `.file_drag_moved: Position` event fires during drag hover
- Position is in window content coordinates (top-left origin)
- Position updates on every `draggingUpdated:` call

**Implementation**:
- Add `.file_drag_moved: Position` event variant
- In `WndwView.draggingUpdated:`, extract `[draggingInfo draggingLocation]`
- Convert from view coordinates and push event

---

## 12. Synthetic Drag Events for Text Selection

**Why twelfth**: Smooth text selection during mouse drag needs position updates at regular intervals, not just on `mouseDragged:`.

**Tests**:
- During mouse drag, synthetic move events fire at ~60Hz
- Events stop when mouse button is released
- Events carry correct interpolated position

**Implementation**:
- On `mouseDragged:`, start a 16ms `dispatch_after` timer
- Timer re-queries mouse position via `[NSEvent mouseLocation]` and pushes `.mouse_moved`
- Cancel timer on `mouseUp:`

---

## 13. Window Ordering / Stacking

**Why thirteenth**: Multi-window apps need to know front-to-back order for rendering overlays, managing palettes.

**Tests**:
- `getWindowOrder()` returns windows in front-to-back order
- Order updates after `focus()` or click-to-front
- Minimized windows are excluded (or at end)

**Implementation**:
- Query `[NSApp orderedWindows]`
- Filter to windows with `WndwWindowDelegate`
- Map to `*Window` via `object_getInstanceVariable`
- Return as slice (static buffer, same pattern as `getMonitors`)

---

## 14. Appearance Observer (Live Theme Switching)

**Why fourteenth**: Complements feature #1. Apps should react in real-time when user toggles dark mode.

**Tests**:
- Theme change mid-run fires `.appearance_changed` event
- Multiple windows each receive the event
- Callback variant also fires

**Implementation**:
- Register `NSKeyValueObservation` on `[NSApp effectiveAppearance]`
- On change, push `.appearance_changed` to all live windows
- Note: may merge with feature #1 if KVO is set up there

---

## 15. Traffic Light Button Repositioning

**Why fifteenth**: Custom titlebar layouts (like Safari, Slack) need precise control over close/minimize/zoom button positions.

**Tests**:
- `win.setTrafficLightPosition(x, y)` moves buttons
- Position is relative to window's top-left
- Position updates correctly after resize
- Position resets on fullscreen enter/exit

**Implementation**:
- Query `[window standardWindowButton:NSWindowCloseButton]` etc.
- Set `frame.origin` on each button's superview
- Re-apply in `windowDidResize:` delegate callback
- Store offset in `Window` struct; apply `nil` to disable

---

## 16. Async Window Operations

**Why sixteenth**: Fullscreen/zoom transitions on macOS are animated. Blocking on them freezes the event loop.

**Tests**:
- `setFullscreen(true)` returns immediately
- `.fullscreen_entered` / `.fullscreen_exited` events fire when transition completes
- Window state queries return correct values during transition

**Implementation**:
- Implement `windowWillEnterFullScreen:`, `windowDidEnterFullScreen:`, `windowWillExitFullScreen:`, `windowDidExitFullScreen:` delegate methods
- Add transition state tracking
- Fire events on completion callbacks

---

## 17. Thread-Safe Window State

**Why last**: Only matters for multi-threaded rendering pipelines. Most games and apps use single-threaded event loops.

**Tests**:
- Window methods are safe to call from multiple threads
- Event queue push/pop is atomic
- State queries don't tear under concurrent mutation

**Implementation**:
- Wrap mutable state in `std.Thread.Mutex` or use atomic operations
- Event queue already lock-free; verify correctness under contention
- Document thread-safety guarantees per method
