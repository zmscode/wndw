/// Shared event types — platform-agnostic.
///
/// Every platform backend maps its native key/event values into these types.

// ── Key ───────────────────────────────────────────────────────────────────────

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

    // Modifiers
    left_shift,
    right_shift,
    left_ctrl,
    right_ctrl,
    left_alt,
    right_alt,
    left_super,
    right_super,
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

pub const MouseButton = enum { left, right, middle, x1, x2 };

// ── Cursor ───────────────────────────────────────────────────────────────────

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

// ── Modifiers ────────────────────────────────────────────────────────────────

pub const Modifiers = struct {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    super: bool = false,
    caps_lock: bool = false,
};

pub const KeyEvent = struct {
    key: Key,
    mods: Modifiers = .{},
};

// ── Event ─────────────────────────────────────────────────────────────────────

pub const Event = union(enum) {
    key_pressed: KeyEvent,
    key_released: KeyEvent,
    mouse_pressed: MouseButton,
    mouse_released: MouseButton,
    mouse_moved: struct { x: i32, y: i32 },
    scroll: struct { dx: f32, dy: f32 },
    resized: struct { w: i32, h: i32 },
    moved: struct { x: i32, y: i32 },
    focus_gained,
    focus_lost,
    close_requested,
    minimized,
    restored,
    mouse_entered,
    mouse_left,
    maximized,
    refresh_requested,
    scale_changed: f32,
    file_drop_started,
    file_dropped: u32, // number of files — retrieve paths via getDroppedFiles()
    file_drop_left,
};
