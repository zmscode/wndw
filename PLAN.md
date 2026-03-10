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

## ~~9. Ctrl+Click → Right-Click Synthesis~~ DONE

- `ctrl_synthesize(button, ctrl_held)` pure public function maps ctrl+left → right
- `translate_event()` applies ctrl_synthesize on LeftMouseDown/Up events
- 5 tests in `ctrl_click_test.zig`

---

## ~~10. First-Mouse Detection~~ DONE

- `Window.is_first_mouse: bool` field; `Window.isFirstMouse()` query method
- `acceptsFirstMouse:` view override returns YES and sets flag when window was unfocused
- 6 tests in `first_mouse_test.zig`

---

## ~~11. Drag Position During Drag-and-Drop~~ DONE

- `Event.file_drag_moved: Position` variant added to event.zig
- `draggingUpdated:` view handler extracts `[draggingInfo draggingLocation]`
- Converts Cocoa bottom-left coords to top-left origin and pushes event
- 5 tests in `drag_position_test.zig`

---

## ~~12. Synthetic Drag Events for Text Selection~~ DONE

- `Window.drag_timer: ?objc.id` NSTimer handle (null when inactive)
- `mouseDragged:` view method starts a 16ms repeating NSTimer
- `dragTimerFired:` queries `mouseLocationOutsideOfEventStream`, pushes `mouse_moved`
- `mouseUp:` cancels the timer; `close()` also invalidates it on teardown
- 5 tests in `synthetic_drag_test.zig`

---

## ~~13. Window Ordering / Stacking~~ DONE

- `Window.getWindowOrder()` queries `[NSApp orderedWindows]`, filters to wndw
  windows via delegate ivar, returns `[]const *Window` from static buffer
- 2 tests in `window_order_test.zig`

---

## ~~14. Appearance Observer (Live Theme Switching)~~ DONE

- Already covered by feature #1 (`NSDistributedNotificationCenter` broadcast to all live windows)
- Added multi-window dispatch/callback integration tests
- 5 tests in `appearance_observer_test.zig`

---

## ~~15. Traffic Light Button Repositioning~~ DONE

- `Window.traffic_light_offset: ?event.Position` stores the override (null = AppKit default)
- `setTrafficLightPosition(x, y)` positions the button container superview from top-left
- `resetTrafficLightPosition()` clears the override
- `apply_traffic_light_position()` private helper re-applied on every `windowDidResize:`
- 6 tests in `traffic_light_test.zig`

---

## ~~16. Async Window Operations~~ DONE

- `Event.fullscreen_entered` and `Event.fullscreen_exited` variants added
- `Window.is_transitioning_fullscreen: bool` tracks in-progress transitions
- `Window.isTransitioningFullscreen()` query method
- `windowWillEnterFullScreen:` / `windowDidEnterFullScreen:` delegate methods set flag and push event
- `windowWillExitFullScreen:` / `windowDidExitFullScreen:` same for exit
- `setOnFullscreenEntered` / `setOnFullscreenExited` callback setters
- `setFullscreen()` already returns immediately (toggleFullScreen: is async)
- 10 tests in `fullscreen_events_test.zig`

---

## ~~17. Thread-Safe Window State~~ DONE

- `Window.state_mutex: std.Thread.Mutex` field added for caller-side locking
- EventQueue ring buffer confirmed sequentially consistent (existing design)
- Thread-safety contract documented: lock `state_mutex` before reading/writing
  state fields from non-main threads
- 4 tests in `thread_safety_test.zig`
