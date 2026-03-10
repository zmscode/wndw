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

## 3. Callbacks with Context

**Why third**: Bare `fn` pointers force users into global state or `@ptrCast` hacks. Blocks ergonomic use of the callback system.

**Tests**:
- Callback receives user-provided context pointer
- Multiple windows with different contexts get correct pointer
- Setting a callback to `null` removes it
- Context pointer lifetime is caller-managed (no use-after-free by design)

**Implementation**:
- Change callback signatures from `?*const fn(Event) void` to `?*const fn(*anyopaque, Event) void`
- Store context pointer alongside each callback
- Alternative: single `ctx: ?*anyopaque` on the `Callbacks` struct (simpler, matches `setUserPtr` pattern)
- Update all `setOn*` methods to accept context parameter

---

## 4. CVDisplayLink Frame Sync

**Why fourth**: Proper vsync eliminates tearing and busy-waiting. Required for smooth rendering.

**Tests**:
- Display link can be created and destroyed without crash
- Callback fires at approximately display refresh rate
- Display link pauses when window is not visible
- Display link resumes on restore/show
- Multiple windows each get independent display links

**Implementation**:
- Add `extern fn` declarations for `CVDisplayLinkCreateWithActiveCGDisplays`, `CVDisplayLinkSetOutputCallback`, `CVDisplayLinkStart/Stop`, `CVDisplayLinkRelease`
- Create display link during window init
- Route callback through `dispatch_source` (GCD) to main thread
- Add `.frame_ready` event (or expose as `win.waitForVSync()`)
- Pause/resume on minimize/restore and hide/show
- Intentionally leak on teardown (GPUI pattern — avoids background thread segfault)

---

## 5. Window Kinds (NSPanel)

**Why fifth**: Floating palettes, tooltips, and popup menus need different focus semantics than normal windows. Without `NSPanel`, floating tool windows steal focus incorrectly.

**Tests**:
- `WindowKind` enum: `.normal`, `.floating`, `.popup`, `.dialog`
- `.floating` creates `NSPanel` with `NSNonactivatingPanelMask`
- `.popup` creates `NSPanel` that doesn't become key window
- `.dialog` creates sheet-style panel attached to parent
- `.normal` creates standard `NSWindow` (existing behavior)
- Focus behavior differs per kind (floating doesn't deactivate parent)

**Implementation**:
- Add `WindowKind` to `Options`
- Register `WndwPanel` ObjC class pair extending `NSPanel`
- Branch window creation on kind: `NSWindow` vs `NSPanel`
- Set appropriate style masks and levels per kind
- `.dialog` takes optional parent `*Window` for sheet attachment

---

## 6. Blurred / Vibrancy Backgrounds

**Why sixth**: Major visual feature for modern macOS apps (sidebars, toolbars, HUDs). Builds on existing `transparent` option.

**Tests**:
- `WindowBackground` enum: `.opaque`, `.transparent`, `.blurred`, `.ultra_dark`
- `.blurred` inserts `NSVisualEffectView` behind content view
- `.blurred` material can be set (sidebar, popover, HUD, etc.)
- Transparent + blurred composites correctly
- Blurred background works on macOS 12+ via `NSVisualEffectView`
- Fallback to `CGSSetWindowBackgroundBlurRadius` on older versions

**Implementation**:
- Replace `transparent: bool` in `Options` with `background: WindowBackground`
- Add `NSVisualEffectView` extern declarations
- Create and insert effect view as lowest subview of content view
- Set material, blending mode, state to `.active`
- Add `win.setBackground()` for runtime changes
- Backward compat: keep `transparent` as alias for `.transparent`

---

## 7. Display Content Bounds

**Why seventh**: Apps need to know usable screen area (excluding dock and menu bar) for correct window placement.

**Tests**:
- `Monitor` struct gains `content_x`, `content_y`, `content_w`, `content_h` fields
- Content bounds exclude menu bar and dock
- Content bounds update when dock position/size changes
- Primary monitor content bounds differ from full bounds (menu bar)

**Implementation**:
- Query `[NSScreen visibleFrame]` instead of (or in addition to) `[NSScreen frame]`
- Convert from bottom-left to top-left coordinates
- Add fields to `Monitor` struct

---

## 8. Stable Display UUIDs

**Why eighth**: Display identification survives reconnects. Important for remembering window positions per-monitor.

**Tests**:
- `Monitor` struct gains `uuid: u128` (or `[16]u8`) field
- UUID is stable across app restarts for same physical display
- UUID differs between displays
- UUID survives disconnect/reconnect of same display

**Implementation**:
- Add `extern fn` for `CGDisplayCreateUUIDFromDisplayID`
- Call `CFUUIDGetUUIDBytes` to extract 128-bit value
- Store in `Monitor` struct

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
