const std = @import("std");
const wndw = @import("wndw");

pub fn main() !void {
    var win = try wndw.init("wndw OpenGL demo", 800, 600, .{
        .centred = true,
        .resizeable = true,
    });
    defer win.close();

    // Create OpenGL 3.2 Core context with defaults (depth=24, double-buffered)
    try win.createGLContext(.{});
    defer win.deleteContext();

    win.setSwapInterval(1); // vsync on

    // Load GL functions via getProcAddress
    const glClearColor = glProc(win, "glClearColor", fn (f32, f32, f32, f32) callconv(.c) void) orelse
        return error.GLLoadFailed;
    const glClear = glProc(win, "glClear", fn (u32) callconv(.c) void) orelse
        return error.GLLoadFailed;
    const glGetString = glProc(win, "glGetString", fn (u32) callconv(.c) ?[*:0]const u8) orelse
        return error.GLLoadFailed;

    // Print GL info
    const GL_VENDOR = 0x1F00;
    const GL_RENDERER = 0x1F01;
    const GL_VERSION = 0x1F02;
    if (glGetString(GL_VENDOR)) |s| std.debug.print("GL vendor:   {s}\n", .{s});
    if (glGetString(GL_RENDERER)) |s| std.debug.print("GL renderer: {s}\n", .{s});
    if (glGetString(GL_VERSION)) |s| std.debug.print("GL version:  {s}\n", .{s});

    const GL_COLOR_BUFFER_BIT = 0x00004000;
    var hue: f32 = 0.0;

    std.debug.print("wndw OpenGL demo — escape to quit\n", .{});

    while (!win.shouldClose()) {
        while (win.poll()) |ev| {
            switch (ev) {
                .key_pressed => |kp| {
                    if (kp.key == .escape) win.quit();
                },
                .close_requested => win.quit(),
                else => {},
            }
        }

        // Animate background color
        hue += 0.005;
        if (hue > 1.0) hue -= 1.0;
        const rgb = hsvToRgb(hue, 0.6, 0.9);
        glClearColor(rgb[0], rgb[1], rgb[2], 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
        win.swapBuffers();
    }
}

fn hsvToRgb(h: f32, s: f32, v: f32) [3]f32 {
    const i: u32 = @intFromFloat(h * 6.0);
    const f = h * 6.0 - @as(f32, @floatFromInt(i));
    const p = v * (1.0 - s);
    const q = v * (1.0 - f * s);
    const t = v * (1.0 - (1.0 - f) * s);
    return switch (i % 6) {
        0 => .{ v, t, p },
        1 => .{ q, v, p },
        2 => .{ p, v, t },
        3 => .{ p, q, v },
        4 => .{ t, p, v },
        5 => .{ v, p, q },
        else => .{ 0, 0, 0 },
    };
}

fn glProc(win: anytype, name: [*:0]const u8, comptime T: type) ?*const T {
    const ptr = win.getProcAddress(name) orelse return null;
    return @ptrCast(@alignCast(ptr));
}
