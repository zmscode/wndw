const std = @import("std");
const wndw = @import("wndw");

// ── Callbacks ─────────────────────────────────────────────────────────────────

fn onResize(_: ?*anyopaque, size: wndw.Size) void {
    std.debug.print("[callback] resized: {}x{}\n", .{ size.w, size.h });
}

fn onFocusGained(_: ?*anyopaque) void {
    std.debug.print("[callback] focus gained\n", .{});
}

fn onFocusLost(_: ?*anyopaque) void {
    std.debug.print("[callback] focus lost\n", .{});
}

fn onCloseRequested(_: ?*anyopaque) void {
    std.debug.print("[callback] close requested\n", .{});
}

fn onAppearanceChanged(_: ?*anyopaque, appearance: wndw.Appearance) void {
    std.debug.print("[callback] appearance changed: {}\n", .{appearance});
}

pub fn main() !void {
    var win = try wndw.init("wndw demo", 800, 600, .{
        .centred = true,
        .resizable = true,
        .inset_titlebar = true,
    });
    defer win.close();

    // Constraints
    win.setMinSize(400, 300);
    win.setMaxSize(1920, 1080);

    // Register callbacks (with context pointer — pass null when unused)
    win.setOnResize(null, onResize);
    win.setOnFocusGained(null, onFocusGained);
    win.setOnFocusLost(null, onFocusLost);
    win.setOnCloseRequested(null, onCloseRequested);
    win.setOnAppearanceChanged(null, onAppearanceChanged);

    // Monitor info
    const mon = win.getPrimaryMonitor();
    std.debug.print("primary monitor: {}x{} @ ({},{}) scale={d:.1}\n", .{ mon.w, mon.h, mon.x, mon.y, mon.scale });

    // Current appearance
    const appearance = win.getAppearance();
    std.debug.print("appearance: {}\n", .{appearance});

    // CVDisplayLink frame sync
    win.createDisplayLink() catch |err| {
        std.debug.print("display link unavailable: {}\n", .{err});
    };
    defer win.destroyDisplayLink();

    // Enable drag-and-drop
    win.setDragAndDrop(true);

    // Background cycle state (0=solid, 1=transparent, 2=blurred, 3=ultra_dark)
    var bg_index: u8 = 0;

    // Track child windows so we can close them on exit
    var floating_win: ?*wndw.Window = null;
    var popup_win: ?*wndw.Window = null;
    var dialog_win: ?*wndw.Window = null;

    defer {
        if (dialog_win) |d| d.close();
        if (popup_win) |p| p.close();
        if (floating_win) |fl| fl.close();
    }

    std.debug.print("wndw demo running — press keys to interact:\n", .{});
    std.debug.print("  escape → quit           t → change title\n", .{});
    std.debug.print("  c → center              f → toggle fullscreen\n", .{});
    std.debug.print("  h → hide cursor         s → show cursor\n", .{});
    std.debug.print("  o → 25%% opacity        p → full opacity\n", .{});
    std.debug.print("  m → minimize            x → maximize\n", .{});
    std.debug.print("  r → read clipboard      w → write clipboard\n", .{});
    std.debug.print("  i → crosshair cursor    a → reset cursor\n", .{});
    std.debug.print("  d → toggle dark/light   l → follow system appearance\n", .{});
    std.debug.print("  b → cycle background    (solid/transparent/blurred/ultra_dark)\n", .{});
    std.debug.print("  1 → floating window     2 → popup window\n", .{});
    std.debug.print("  3 → dialog (sheet)      0 → close child windows\n", .{});

    while (!win.shouldClose()) {
        // Sync to display refresh rate
        win.waitForFrame();

        while (win.poll()) |ev| {
            switch (ev) {
                .key_pressed => |kp| {
                    if (kp.character) |ch| {
                        var buf: [4]u8 = undefined;
                        const len = std.unicode.utf8Encode(ch, &buf) catch 0;
                        std.debug.print("key: {} char: '{s}' mods: shift={} ctrl={} alt={} super={}\n", .{
                            kp.key, buf[0..len], kp.mods.shift, kp.mods.ctrl, kp.mods.alt, kp.mods.super,
                        });
                    } else {
                        std.debug.print("key: {} mods: shift={} ctrl={} alt={} super={}\n", .{
                            kp.key, kp.mods.shift, kp.mods.ctrl, kp.mods.alt, kp.mods.super,
                        });
                    }
                    switch (kp.key) {
                        .escape => win.quit(),
                        .t => win.setTitle("wndw — title changed!"),
                        .c => win.center(),
                        .f => win.setFullscreen(!win.isFullscreen()),
                        .h => win.setCursorVisible(false),
                        .s => win.setCursorVisible(true),
                        .o => win.setOpacity(0.5),
                        .p => win.setOpacity(1.0),
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
                        .i => win.setStandardCursor(.closed_hand),
                        .a => win.resetCursor(),

                        // Appearance
                        .d => {
                            const current = win.getAppearance();
                            const target: wndw.Appearance = if (current == .dark) .light else .dark;
                            win.setAppearance(target);
                            if (floating_win) |fw| fw.setAppearance(target);
                            if (popup_win) |pw| pw.setAppearance(target);
                            if (dialog_win) |dw| dw.setAppearance(target);
                            std.debug.print("appearance → {}\n", .{target});
                        },
                        .l => {
                            win.setAppearance(null);
                            if (floating_win) |fw| fw.setAppearance(null);
                            if (popup_win) |pw| pw.setAppearance(null);
                            if (dialog_win) |dw| dw.setAppearance(null);
                            std.debug.print("appearance → follow system\n", .{});
                        },

                        // Background
                        .b => {
                            const BG = wndw.Options.WindowBackground;
                            bg_index = (bg_index + 1) % 4;
                            const target: BG = switch (bg_index) {
                                0 => .solid,
                                1 => .transparent,
                                2 => .blurred,
                                else => .ultra_dark,
                            };
                            win.setBackground(target);
                            std.debug.print("background → {}\n", .{target});
                        },

                        // Window kinds
                        .@"1" => {
                            if (floating_win == null) {
                                floating_win = wndw.init("floating palette", 300, 200, .{
                                    .centred = true,
                                    .resizable = true,
                                    .kind = .floating,
                                }) catch |err| blk: {
                                    std.debug.print("failed to create floating window: {}\n", .{err});
                                    break :blk null;
                                };
                                if (floating_win != null) std.debug.print("created floating window\n", .{});
                            } else {
                                std.debug.print("floating window already open\n", .{});
                            }
                        },
                        .@"2" => {
                            if (popup_win == null) {
                                popup_win = wndw.init("popup", 250, 150, .{
                                    .kind = .popup,
                                }) catch |err| blk: {
                                    std.debug.print("failed to create popup window: {}\n", .{err});
                                    break :blk null;
                                };
                                if (popup_win != null) std.debug.print("created popup window\n", .{});
                            } else {
                                std.debug.print("popup window already open\n", .{});
                            }
                        },
                        .@"3" => {
                            if (dialog_win == null) {
                                dialog_win = wndw.init("dialog sheet", 400, 200, .{
                                    .kind = .dialog,
                                    .parent = win,
                                }) catch |err| blk: {
                                    std.debug.print("failed to create dialog: {}\n", .{err});
                                    break :blk null;
                                };
                                if (dialog_win != null) std.debug.print("created dialog sheet\n", .{});
                            } else {
                                std.debug.print("dialog already open\n", .{});
                            }
                        },
                        .@"0" => {
                            if (dialog_win) |d| {
                                d.close();
                                dialog_win = null;
                                std.debug.print("closed dialog\n", .{});
                            }
                            if (popup_win) |p| {
                                p.close();
                                popup_win = null;
                                std.debug.print("closed popup\n", .{});
                            }
                            if (floating_win) |fl| {
                                fl.close();
                                floating_win = null;
                                std.debug.print("closed floating\n", .{});
                            }
                        },

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
                .text_input => |ti| std.debug.print("text: {s}\n", .{ti.text}),
                .appearance_changed => |a| std.debug.print("appearance: {}\n", .{a}),
            }
        }

        // Check if child windows were closed via their close button
        if (floating_win) |fw| if (fw.shouldClose()) {
            fw.close();
            floating_win = null;
            std.debug.print("floating window closed\n", .{});
        };
        if (popup_win) |pw| if (pw.shouldClose()) {
            pw.close();
            popup_win = null;
            std.debug.print("popup window closed\n", .{});
        };
        if (dialog_win) |dw| if (dw.shouldClose()) {
            dw.close();
            dialog_win = null;
            std.debug.print("dialog closed\n", .{});
        };
    }
}
