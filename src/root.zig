pub const c = @cImport({
    @cInclude("RGFW.h");
});

pub inline fn toBool(value: c.RGFW_bool) bool {
    return value != c.RGFW_FALSE;
}

pub inline fn fromBool(value: bool) c.RGFW_bool {
    return if (value) c.RGFW_TRUE else c.RGFW_FALSE;
}

pub const Key = c.RGFW_key;
pub const MouseButton = c.RGFW_mouseButton;
pub const Event = c.RGFW_event;
pub const EventType = c.RGFW_eventType;

pub const quit: EventType = c.RGFW_quit;

pub const key = struct {
    pub const escape: Key = c.RGFW_escape;
    pub const space: Key = c.RGFW_space;
    pub const w: Key = c.RGFW_w;
    pub const a: Key = c.RGFW_a;
    pub const s: Key = c.RGFW_s;
    pub const d: Key = c.RGFW_d;
    pub const up: Key = c.RGFW_up;
    pub const down: Key = c.RGFW_down;
    pub const left: Key = c.RGFW_left;
    pub const right: Key = c.RGFW_right;
};

pub const mouse = struct {
    pub const left: MouseButton = c.RGFW_mouseLeft;
    pub const middle: MouseButton = c.RGFW_mouseMiddle;
    pub const right: MouseButton = c.RGFW_mouseRight;
};

pub const Error = error{
    RGFWCreateWindowFailed,
};

pub const Window = struct {
    handle: *c.RGFW_window,

    pub const FlagOptions = struct {
        centered: ?bool = null,
        centred: ?bool = null,
        resizable: ?bool = null,
        border: ?bool = null,
        fullscreen: ?bool = null,
        floating: ?bool = null,
        hidden: ?bool = null,
        maximize: ?bool = null,
        minimize: ?bool = null,
        hide_mouse: ?bool = null,
        focus_on_show: ?bool = null,
        focus: ?bool = null,
        transparent: ?bool = null,
        allow_dnd: ?bool = null,

        fn toFlags(opts: FlagOptions, current: c.RGFW_windowFlags) c.RGFW_windowFlags {
            var flags = current;
            const set = struct {
                fn apply(f: *c.RGFW_windowFlags, bit: c.RGFW_windowFlags, val: ?bool) void {
                    if (val) |v| {
                        if (v) f.* |= bit else f.* &= ~bit;
                    }
                }
            };
            // border=true means no NoBorder flag, so invert
            if (opts.border) |b| set.apply(&flags, c.RGFW_windowNoBorder, !b);
            // resizable=false means NoResize flag, so invert
            if (opts.resizable) |r| set.apply(&flags, c.RGFW_windowNoResize, !r);
            set.apply(&flags, c.RGFW_windowFullscreen, opts.fullscreen);
            set.apply(&flags, c.RGFW_windowFloating, opts.floating);
            set.apply(&flags, c.RGFW_windowHide, opts.hidden);
            set.apply(&flags, c.RGFW_windowMaximize, opts.maximize);
            set.apply(&flags, c.RGFW_windowMinimize, opts.minimize);
            set.apply(&flags, c.RGFW_windowHideMouse, opts.hide_mouse);
            set.apply(&flags, c.RGFW_windowFocusOnShow, opts.focus_on_show);
            set.apply(&flags, c.RGFW_windowFocus, opts.focus);
            set.apply(&flags, c.RGFW_windowTransparent, opts.transparent);
            set.apply(&flags, c.RGFW_windowAllowDND, opts.allow_dnd);
            const centered_val = opts.centered orelse opts.centred;
            set.apply(&flags, c.RGFW_windowCenter, centered_val);
            return flags;
        }
    };

    pub fn close(self: Window) void {
        c.RGFW_window_close(self.handle);
    }

    pub fn shouldClose(self: Window) bool {
        return toBool(c.RGFW_window_shouldClose(self.handle));
    }

    pub fn setShouldClose(self: Window, should_close: bool) void {
        c.RGFW_window_setShouldClose(self.handle, fromBool(should_close));
    }

    /// Poll platform events and update key/mouse state (raylib-style frame update).
    pub fn poll(self: Window) void {
        _ = self;
        c.RGFW_setQueueEvents(c.RGFW_TRUE);
        c.RGFW_pollEvents();
    }

    /// Pop the next event for this window.
    pub fn pollEvent(self: Window, out: *Event) bool {
        c.RGFW_setQueueEvents(c.RGFW_TRUE);
        return toBool(c.RGFW_window_checkQueuedEvent(self.handle, out));
    }

    pub fn isKeyPressed(self: Window, k: Key) bool {
        return toBool(c.RGFW_window_isKeyPressed(self.handle, k));
    }

    pub fn isKeyDown(self: Window, k: Key) bool {
        return toBool(c.RGFW_window_isKeyDown(self.handle, k));
    }

    pub fn isKeyReleased(self: Window, k: Key) bool {
        return toBool(c.RGFW_window_isKeyReleased(self.handle, k));
    }

    pub fn isMousePressed(self: Window, button: MouseButton) bool {
        return toBool(c.RGFW_window_isMousePressed(self.handle, button));
    }

    pub fn isMouseDown(self: Window, button: MouseButton) bool {
        return toBool(c.RGFW_window_isMouseDown(self.handle, button));
    }

    pub fn isMouseReleased(self: Window, button: MouseButton) bool {
        return toBool(c.RGFW_window_isMouseReleased(self.handle, button));
    }

    pub fn mousePosition(self: Window) struct { x: i32, y: i32 } {
        var x: i32 = 0;
        var y: i32 = 0;
        _ = c.RGFW_window_getMouse(self.handle, &x, &y);
        return .{ .x = x, .y = y };
    }

    pub fn setFlags(self: Window, options: FlagOptions) void {
        c.RGFW_window_setFlags(self.handle, options.toFlags(self.handle.*.internal.flags));
    }
};

pub fn init(title: [:0]const u8, width: i32, height: i32, options: Window.FlagOptions) Error!Window {
    const window = c.RGFW_createWindow(
        title.ptr,
        0,
        0,
        width,
        height,
        options.toFlags(0),
    ) orelse return error.RGFWCreateWindowFailed;

    return .{ .handle = window };
}

test "wrapper surface compiles" {
    _ = Window;
    _ = Error;
    _ = Event;
    _ = EventType;
    _ = quit;
    _ = key.escape;
    _ = mouse.left;
    const options: Window.FlagOptions = .{
        .centred = true,
        .resizable = false,
    };
    // Verify toFlags produces correct bitmask
    const flags = options.toFlags(0);
    const expected: c.RGFW_windowFlags = c.RGFW_windowCenter | c.RGFW_windowNoResize;
    try @import("std").testing.expectEqual(expected, flags);
}
