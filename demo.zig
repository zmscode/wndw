const std = @import("std");
const wndw = @import("wndw");

pub fn main() !void {
    var win = try wndw.init("wndw demo", 800, 600, .{
        .centred = true,
        .resizeable = true,
    });
    defer win.close();

    // Constraints
    win.setMinSize(400, 300);
    win.setMaxSize(1920, 1080);

    // Monitor info
    const mon = win.getPrimaryMonitor();
    std.debug.print("primary monitor: {}x{} @ ({},{}) scale={d:.1}\n", .{ mon.w, mon.h, mon.x, mon.y, mon.scale });

    // Enable drag-and-drop
    win.setDragAndDrop(true);

    std.debug.print("wndw demo running — press keys to interact:\n", .{});
    std.debug.print("  escape  → quit\n", .{});
    std.debug.print("  t       → change title\n", .{});
    std.debug.print("  c       → center window\n", .{});
    std.debug.print("  f       → toggle fullscreen\n", .{});
    std.debug.print("  h       → hide cursor\n", .{});
    std.debug.print("  s       → show cursor\n", .{});
    std.debug.print("  o       → set 50% opacity\n", .{});
    std.debug.print("  p       → restore full opacity\n", .{});
    std.debug.print("  m       → minimize\n", .{});
    std.debug.print("  x       → maximize\n", .{});
    std.debug.print("  r       → read clipboard\n", .{});
    std.debug.print("  w       → write to clipboard\n", .{});
    std.debug.print("  i       → crosshair cursor\n", .{});
    std.debug.print("  a       → reset cursor\n", .{});

    while (!win.shouldClose()) {
        while (win.poll()) |ev| {
            switch (ev) {
                .key_pressed => |kp| {
                    std.debug.print("key: {} mods: shift={} ctrl={} alt={} super={}\n", .{
                        kp.key, kp.mods.shift, kp.mods.ctrl, kp.mods.alt, kp.mods.super,
                    });
                    switch (kp.key) {
                        .escape => win.quit(),
                        .t => win.setTitle("wndw — title changed!"),
                        .c => win.center(),
                        .f => win.setFullscreen(!win.isFullscreen()),
                        .h => win.setCursorVisible(false),
                        .s => win.setCursorVisible(true),
                        .o => win.setOpacity(128),
                        .p => win.setOpacity(255),
                        .m => win.minimize(),
                        .x => win.maximize(),
                        .r => {
                            if (win.clipboardRead()) |text| {
                                std.debug.print("clipboard: {s}\n", .{text});
                            } else {
                                std.debug.print("clipboard: (empty)\n", .{});
                            }
                        },
                        .w => win.clipboardWrite("hello from wndw!"),
                        .i => win.setStandardCursor(.crosshair),
                        .a => win.resetCursor(),
                        else => {},
                    }
                },
                .key_released => |kr| {
                    _ = kr;
                },
                .mouse_pressed => |btn| std.debug.print("mouse pressed: {}\n", .{btn}),
                .mouse_released => |btn| std.debug.print("mouse released: {}\n", .{btn}),
                .mouse_moved => |pos| {
                    _ = pos;
                },
                .scroll => |s| std.debug.print("scroll: dx={d:.1} dy={d:.1}\n", .{ s.dx, s.dy }),
                .resized => |r| std.debug.print("resized: {}x{}\n", .{ r.w, r.h }),
                .moved => |p| std.debug.print("moved: ({}, {})\n", .{ p.x, p.y }),
                .focus_gained => std.debug.print("focus gained\n", .{}),
                .focus_lost => std.debug.print("focus lost\n", .{}),
                .minimized => std.debug.print("minimized\n", .{}),
                .restored => std.debug.print("restored\n", .{}),
                .maximized => std.debug.print("maximized\n", .{}),
                .mouse_entered => std.debug.print("mouse entered\n", .{}),
                .mouse_left => std.debug.print("mouse left\n", .{}),
                .scale_changed => |s| std.debug.print("scale changed: {d:.1}\n", .{s}),
                .file_drop_started => std.debug.print("file drop started\n", .{}),
                .file_dropped => |count| {
                    std.debug.print("files dropped: {}\n", .{count});
                    const files = win.getDroppedFiles();
                    for (files) |path| {
                        std.debug.print("  {s}\n", .{path});
                    }
                },
                .file_drop_left => std.debug.print("file drop left\n", .{}),
                .close_requested => win.quit(),
                .refresh_requested => {},
            }
        }
    }
}
