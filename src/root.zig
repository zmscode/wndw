pub const c = @cImport({
    @cInclude("RGFW.h");
});

pub inline fn toBool(value: c.RGFW_bool) bool {
    return value != c.RGFW_FALSE;
}

pub inline fn fromBool(value: bool) c.RGFW_bool {
    return if (value) c.RGFW_TRUE else c.RGFW_FALSE;
}

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
        self.pumpEvents();
        return self.shouldCloseRaw();
    }

    pub fn shouldCloseRaw(self: Window) bool {
        return toBool(c.RGFW_window_shouldClose(self.handle));
    }

    pub fn pumpEvents(self: Window) void {
        var event: c.RGFW_event = undefined;
        while (toBool(c.RGFW_window_checkEvent(self.handle, &event))) {
            if (event.type == c.RGFW_quit) break;
        }
    }

    pub fn setFlags(self: Window, options: FlagOptions) void {
        var flags: u32 = @as(u32, @intCast(c.RGFW_window_getFlags(self.handle)));

        const centered = options.centered orelse options.centred;
        if (centered) |enabled| setFlag(&flags, c.RGFW_windowCenter, enabled);
        if (options.resizable) |enabled| setFlag(&flags, c.RGFW_windowNoResize, !enabled);
        if (options.border) |enabled| setFlag(&flags, c.RGFW_windowNoBorder, !enabled);
        if (options.fullscreen) |enabled| setFlag(&flags, c.RGFW_windowFullscreen, enabled);
        if (options.floating) |enabled| setFlag(&flags, c.RGFW_windowFloating, enabled);
        if (options.hidden) |enabled| setFlag(&flags, c.RGFW_windowHide, enabled);

        c.RGFW_window_setFlags(self.handle, @as(c.RGFW_windowFlags, @intCast(flags)));
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

fn setFlag(flags: *u32, mask: anytype, enabled: bool) void {
    const bit = @as(u32, @intCast(mask));
    if (enabled) {
        flags.* |= bit;
    } else {
        flags.* &= ~bit;
    }
}

test "wrapper surface compiles" {
    _ = Window;
    _ = Error;
    const options: Window.FlagOptions = .{
        .centred = true,
        .resizable = false,
    };
    _ = options;
}
