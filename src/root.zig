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
        const currently_hidden = toBool(c.RGFW_window_isHidden(self.handle));
        const style_change = options.border != null or
            options.resizable != null or
            options.fullscreen != null or
            options.floating != null;

        // Runtime style-mask mutations can be glitchy on some backends (notably macOS).
        // Apply them while hidden, then show/focus again.
        const hide_for_transition = style_change and !currently_hidden and options.hidden == null;
        if (hide_for_transition) {
            c.RGFW_window_hide(self.handle);
        }

        if (options.border) |enabled| {
            c.RGFW_window_setBorder(self.handle, fromBool(enabled));
        }

        if (options.resizable) |enabled| {
            if (enabled) {
                c.RGFW_window_setMinSize(self.handle, 0, 0);
                c.RGFW_window_setMaxSize(self.handle, 0, 0);
            } else {
                var w: i32 = 0;
                var h: i32 = 0;
                _ = c.RGFW_window_getSize(self.handle, &w, &h);
                c.RGFW_window_setMinSize(self.handle, w, h);
                c.RGFW_window_setMaxSize(self.handle, w, h);
            }
        }

        if (options.fullscreen) |enabled| {
            c.RGFW_window_setFullscreen(self.handle, fromBool(enabled));
        }

        if (options.floating) |enabled| {
            c.RGFW_window_setFloating(self.handle, fromBool(enabled));
        }

        if (options.hidden) |enabled| {
            if (enabled) {
                c.RGFW_window_hide(self.handle);
            } else {
                c.RGFW_window_show(self.handle);
            }
        } else if (hide_for_transition) {
            c.RGFW_window_show(self.handle);
        }

        const centered = options.centered orelse options.centred;
        if (centered) |enabled| {
            if (enabled) {
                c.RGFW_window_center(self.handle);
            }
        }

        if (!toBool(c.RGFW_window_isHidden(self.handle))) {
            c.RGFW_window_focus(self.handle);
        }
    }
};

pub fn init(title: [:0]const u8, width: i32, height: i32) Error!Window {
    const window = c.RGFW_createWindow(
        title.ptr,
        0,
        0,
        width,
        height,
        @as(c.RGFW_windowFlags, 0),
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
    _ = options;
}
