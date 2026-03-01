const std = @import("std");
const wndw = @import("wndw");

pub fn main() !void {
    var win = try wndw.init("wndw", 800, 600, .{
        .centred = true,
        .resizeable = true,
        // .borderless = true,
    });
    defer win.close();

    while (!win.shouldClose()) {
        while (win.poll()) |ev| {
            switch (ev) {
                .key_pressed => |k| {
                    std.debug.print("key: {}\n", .{k});
                    if (k == .escape) win.quit();
                },
                .mouse_pressed => |btn| std.debug.print("mouse: {}\n", .{btn}),
                .resized => |r| std.debug.print("resize: {}x{}\n", .{ r.w, r.h }),
                else => {},
            }
        }
    }
}
