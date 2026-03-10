/// Platform-agnostic event types.
///
/// Every platform backend maps its native key codes and OS events into
/// these shared types. This file is the single source of truth for the
/// public event API — adding a new event means adding a tag to `Event`,
/// and each backend's translate_event() must produce it.
///
/// Design decisions:
///   - `Key` is an enum (not raw scancodes) so user code reads naturally:
///     `if (kp.key == .escape) win.quit();`
///   - `MouseButton` is a small enum — 5 buttons covers 99% of hardware.
///   - `Event` is a tagged union so `switch` is exhaustive and the compiler
///     catches unhandled cases when new events are added.
///   - Payload types (`Position`, `Size`, `ScrollDelta`) are named structs
///     rather than anonymous — Zig treats anonymous structs from different
///     files as distinct types, which breaks callback signatures.

// ── Key ───────────────────────────────────────────────────────────────────────

/// Keyboard key identifiers. Platform backends translate hardware keycodes
/// into these values (see `keymap.zig` for the macOS mapping table).
///
/// The enum ordering is arbitrary — only the tag names matter for user code.
/// `unknown` is the sentinel for unmapped keycodes.
pub const Key = enum {
    unknown,

    // Letters
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,

    // Digits
    @"0",
    @"1",
    @"2",
    @"3",
    @"4",
    @"5",
    @"6",
    @"7",
    @"8",
    @"9",

    // Function keys
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
    f13,
    f14,
    f15,
    f16,
    f17,
    f18,
    f19,
    f20,

    // Navigation
    left,
    right,
    up,
    down,
    home,
    end,
    page_up,
    page_down,

    // Editing
    enter,
    escape,
    backspace,
    delete,
    tab,
    space,
    insert,

    // Modifiers — left/right variants for apps that distinguish them.
    left_shift,
    right_shift,
    left_ctrl,
    right_ctrl,
    left_alt,
    right_alt,
    left_super,
    right_super, // Cmd on macOS, Win key on Windows
    caps_lock,
    num_lock,
    scroll_lock,

    // Punctuation / symbols
    minus, // -
    equal, // =
    left_bracket, // [
    right_bracket, // ]
    backslash, // \
    semicolon, // ;
    apostrophe, // '
    grave, // `
    comma, // ,
    period, // .
    slash, // /

    // Numpad
    kp_0,
    kp_1,
    kp_2,
    kp_3,
    kp_4,
    kp_5,
    kp_6,
    kp_7,
    kp_8,
    kp_9,
    kp_decimal,
    kp_divide,
    kp_multiply,
    kp_subtract,
    kp_add,
    kp_enter,
    kp_equal,

    // Misc
    print_screen,
    pause,
    menu,
};

// ── MouseButton ───────────────────────────────────────────────────────────────

/// Five-button mouse model: left, right, middle, plus two side buttons (x1/x2).
/// On macOS, `buttonNumber` 2 → middle, 3 → x1, 4 → x2.
pub const MouseButton = enum { left, right, middle, x1, x2 };

// ── Cursor ────────────────────────────────────────────────────────────────────

/// Standard system cursor shapes. Each platform backend maps these to
/// native cursor resources (e.g. `[NSCursor arrowCursor]` on macOS).
pub const Cursor = enum {
    arrow,
    ibeam,
    crosshair,
    closed_hand,
    open_hand,
    pointing_hand,
    resize_left_right,
    resize_up_down,
    not_allowed,
};

// ── Modifiers ─────────────────────────────────────────────────────────────────

/// Modifier key state at the time of a key event. Extracted from the OS
/// event's modifier flags (e.g. `NSEventModifierFlags` on macOS).
/// All fields default to `false`.
pub const Modifiers = struct {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    super: bool = false, // Cmd on macOS, Win on Windows
    caps_lock: bool = false,
};

/// Key event payload: which key was pressed/released, plus which modifiers
/// were held at that instant. Carried by `.key_pressed` and `.key_released`.
pub const KeyEvent = struct {
    key: Key,
    mods: Modifiers = .{},
    /// The Unicode codepoint produced by this key with the current keyboard
    /// layout and modifier state. `null` for non-character keys (modifiers,
    /// function keys, arrows, etc.).
    character: ?u21 = null,
};

// ── Payload types ─────────────────────────────────────────────────────────────
/// Named structs shared between Event payloads and callback function
/// signatures. Using named types avoids Zig's anonymous-struct-identity
/// issues where identical-looking anonymous structs from different files
/// are treated as incompatible types.
/// Screen or window position in pixels (top-left origin for mouse_moved,
/// bottom-left origin for window moved — matching Cocoa conventions).
pub const Position = struct { x: i32, y: i32 };

/// Window content area dimensions in pixels.
pub const Size = struct { w: i32, h: i32 };

/// Scroll wheel delta. Positive `dy` = scroll up; positive `dx` = scroll right.
/// Values are in "lines" on macOS (continuous trackpad deltas are fractional).
pub const ScrollDelta = struct { dx: f32, dy: f32 };

// ── Event ─────────────────────────────────────────────────────────────────────

/// Tagged union of all window events. Returned by `Window.poll()`.
///
/// The typical event loop pattern:
/// ```zig
/// while (win.poll()) |ev| {
///     switch (ev) {
///         .key_pressed  => |kp| { ... },
///         .close_requested => win.quit(),
///         else => {},
///     }
/// }
/// ```
///
/// Each event is also dispatched to optional callbacks (see `Window.Callbacks`)
/// and updates the global input state bitsets (see `Window.InputState`).
pub const Event = union(enum) {
    /// A key was pressed (not a repeat — auto-repeat is filtered out).
    key_pressed: KeyEvent,
    /// A key was released.
    key_released: KeyEvent,

    /// A mouse button was pressed.
    mouse_pressed: MouseButton,
    /// A mouse button was released.
    mouse_released: MouseButton,

    /// The mouse moved within the window. Coordinates are relative to the
    /// content area, with (0,0) at the top-left corner.
    mouse_moved: Position,
    /// The scroll wheel (or trackpad) was scrolled.
    scroll: ScrollDelta,

    /// The window's content area was resized (by user drag or programmatic resize).
    resized: Size,
    /// The window was moved to a new position on screen.
    moved: Position,

    /// The window gained keyboard focus (became the key window).
    focus_gained,
    /// The window lost keyboard focus.
    focus_lost,
    /// The user clicked the close button (or Cmd+W). Call `win.quit()` to
    /// actually close, or ignore to prevent closing.
    close_requested,
    /// The window was minimised to the dock.
    minimized,
    /// The window was restored from the dock.
    restored,
    /// The window was maximised (zoomed on macOS).
    maximized,

    /// The mouse cursor entered the window's content area.
    mouse_entered,
    /// The mouse cursor left the window's content area.
    mouse_left,

    /// The view needs a redraw (triggered by `drawRect:` on macOS).
    refresh_requested,
    /// The backing scale factor changed (e.g. window moved to a Retina display).
    /// Payload is the new scale factor (1.0 = standard, 2.0 = Retina).
    scale_changed: f32,

    /// A file drag entered the window area.
    file_drop_started,
    /// Files were dropped on the window. Payload is the number of files —
    /// retrieve paths via `win.getDroppedFiles()`.
    file_dropped: u32,
    /// A file drag left the window without dropping.
    file_drop_left,
    /// The cursor moved within the window while a file drag is in progress.
    /// Coordinates are in window content space (top-left origin).
    file_drag_moved: Position,

    /// Text input from keyboard (after IME/dead-key processing).
    /// Contains a UTF-8 string slice valid until the next `poll()` cycle.
    text_input: TextInput,

    /// The system appearance changed (e.g. user toggled dark mode).
    appearance_changed: Appearance,
};

/// Payload for `text_input` events. The text is a UTF-8 encoded slice
/// pointing into a static buffer, valid until the next `poll()` cycle.
pub const TextInput = struct {
    /// UTF-8 encoded text (e.g. a single character, or an IME composition result).
    text: []const u8,
};

// ── Appearance ──────────────────────────────────────────────────────────────

/// System appearance (light or dark mode). On macOS this maps to
/// `NSAppearanceNameAqua` and `NSAppearanceNameDarkAqua`.
pub const Appearance = enum {
    light,
    dark,
};
