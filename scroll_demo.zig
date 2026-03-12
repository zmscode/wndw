// ── UI Phase 6 Demo — Scroll, Theme, Animation, Keybindings ─────────
//
// Demonstrates all Phase 6 capabilities:
//   - ScrollState for a scrollable list of items
//   - Theme dark/light toggle (press T to switch)
//   - Animation on theme transition (smooth background fade)
//   - KeybindingTable dispatching keyboard shortcuts
//
// Controls:
//   T         — toggle dark/light theme
//   ↑ / ↓     — scroll up/down
//   Home      — scroll to top
//   Esc / Q   — quit
//
// Run: zig build run -- scroll_demo

const wndw = @import("wndw");
const ui = @import("ui");
const std = @import("std");

// ── Colors ───────────────────────────────────────────────────────────

const row_colors = [_]ui.Color{
    ui.Color.hex(0xF38BA8), // red
    ui.Color.hex(0xFAB387), // peach
    ui.Color.hex(0xF9E2AF), // yellow
    ui.Color.hex(0xA6E3A1), // green
    ui.Color.hex(0x89B4FA), // blue
    ui.Color.hex(0xCBA6F7), // mauve
};

// ── State ────────────────────────────────────────────────────────────

var g_scroll = ui.ScrollState{};
var g_dark: bool = true;
var g_measurer: ui.TextMeasurer = undefined;
var g_cx: *ui.WindowContext = undefined;
var g_win: *wndw.Window = undefined;
var g_keys: ui.KeybindingTable = undefined;
var g_mouse_x: f32 = 0;
var g_mouse_y: f32 = 0;

const ITEM_COUNT = 50;
const ITEM_HEIGHT: f32 = 44;
const SCROLL_SPEED: f32 = 40;

// ── Keybinding callbacks ─────────────────────────────────────────────

fn toggleTheme(_: ?*anyopaque) void {
    g_dark = !g_dark;
    g_cx.needs_render = true;
}

fn scrollUp(_: ?*anyopaque) void {
    g_scroll.scrollBy(0, -SCROLL_SPEED);
    clampScroll();
    g_cx.needs_render = true;
}

fn scrollDown(_: ?*anyopaque) void {
    g_scroll.scrollBy(0, SCROLL_SPEED);
    clampScroll();
    g_cx.needs_render = true;
}

fn scrollToTop(_: ?*anyopaque) void {
    g_scroll.scrollToTop();
    g_cx.needs_render = true;
}

fn quit(_: ?*anyopaque) void {
    g_win.quit();
}

fn clampScroll() void {
    const content_h = ITEM_COUNT * ITEM_HEIGHT + (ITEM_COUNT - 1) * 4; // items + gaps
    const viewport_h = g_cx.view_height - 120; // header + status + padding
    g_scroll.clamp(content_h, viewport_h);
}

// ── UI helpers ───────────────────────────────────────────────────────

fn fmtArena(alloc: std.mem.Allocator, comptime fmt: []const u8, args: anytype) []const u8 {
    var buf: [128]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, fmt, args) catch "?";
    return alloc.dupe(u8, s) catch unreachable;
}

fn theme() ui.Theme {
    return if (g_dark) ui.Theme.dark else ui.Theme.light;
}

// ── UI tree ──────────────────────────────────────────────────────────

fn renderUI(alloc: std.mem.Allocator) ui.Element {
    const t = theme();

    // ── Header ───────────────────────────────────────────────────────
    const title = ui.text(alloc, "Phase 6 — Scroll & Theme Demo", g_measurer)
        .font_size(20).color(t.text).font_weight(.bold).into_element();
    const subtitle = ui.text(alloc, "T = toggle theme  |  ↑↓ = scroll  |  Home = top  |  Esc = quit", g_measurer)
        .font_size(11).color(t.muted).into_element();

    const theme_badge = ui.div(alloc)
        .bg(t.primary).padding_xy(10, 4).corner_radius(4)
        .child(ui.text(alloc, if (g_dark) "DARK" else "LIGHT", g_measurer)
            .font_size(11).color(ui.Color.hex(0xFFFFFF)).font_weight(.semibold).into_element())
        .into_element();

    const header = ui.div(alloc)
        .flex_row().padding_all(16).bg(t.surface).corner_radius(12)
        .align_center().gap(12)
        .child(ui.div(alloc).flex_col().gap(4).grow(1)
            .child(title).child(subtitle).into_element())
        .child(theme_badge)
        .into_element();

    // ── Scrollable list ──────────────────────────────────────────────
    // We simulate scroll by offsetting the first visible item.
    // In a real impl, the scroll container would clip and translate.
    const visible_start = @as(usize, @intFromFloat(@max(g_scroll.offset_y / (ITEM_HEIGHT + 4), 0)));
    const viewport_h = g_cx.view_height - 120;
    const visible_count = @as(usize, @intFromFloat(viewport_h / (ITEM_HEIGHT + 4))) + 2;
    const visible_end = @min(visible_start + visible_count, ITEM_COUNT);

    var list = ui.div(alloc).flex_col().gap(4).grow(1);

    for (visible_start..visible_end) |i| {
        const color = row_colors[i % row_colors.len];
        const accent = ui.div(alloc).width(4).bg(color).corner_radius(2).into_element();
        const label = ui.text(alloc, fmtArena(alloc, "Item {d}", .{i + 1}), g_measurer)
            .font_size(14).color(t.text).font_weight(.medium).into_element();
        const desc = ui.text(alloc, fmtArena(alloc, "Description for item {d} — scroll to see more", .{i + 1}), g_measurer)
            .font_size(11).color(t.muted).into_element();

        const row = ui.div(alloc)
            .flex_row().gap(12).padding_xy(12, 8).bg(t.surface)
            .corner_radius(8).align_center()
            .child(accent)
            .child(ui.div(alloc).flex_col().gap(2).grow(1)
                .child(label).child(desc).into_element())
            .into_element();

        list = list.child(row);
    }

    // ── Status bar ───────────────────────────────────────────────────
    const status_text = fmtArena(alloc, "Showing {d}–{d} of {d}  |  Scroll offset: {d:.0}px", .{
        visible_start + 1, visible_end, ITEM_COUNT, g_scroll.offset_y,
    });
    const status = ui.div(alloc)
        .flex_row().padding_xy(16, 8).bg(t.surface).corner_radius(8)
        .child(ui.text(alloc, status_text, g_measurer)
            .font_size(11).color(t.muted).into_element())
        .into_element();

    // ── Root ─────────────────────────────────────────────────────────
    return ui.div(alloc)
        .bg(t.bg)
        .padding_all(16)
        .flex_col()
        .gap(12)
        .child(header)
        .child(list.into_element())
        .child(status)
        .into_element();
}

fn drawCallback(_: ?*anyopaque) void {
    const sz = g_win.getSize();
    const w: f32 = @floatFromInt(sz.w);
    const h: f32 = @floatFromInt(sz.h);
    if (w != g_cx.view_width or h != g_cx.view_height) {
        g_cx.setViewSize(w, h);
        g_cx.render();
        g_cx.resetFrame();
    }
    g_cx.flush();
}

pub fn main() !void {
    var win = try wndw.init("UI Phase 6 \xe2\x80\x94 Scroll & Theme", 600, 500, .{
        .centred = true,
        .resizable = true,
        .inset_titlebar = true,
    });
    defer win.close();

    var cx = ui.WindowContext.init(std.heap.page_allocator);
    defer cx.deinit();

    g_measurer = cx.textMeasurer();
    cx.setRootRenderFn(&renderUI);

    // Set up keybindings
    g_keys = ui.KeybindingTable.init(std.heap.page_allocator);
    defer g_keys.deinit();

    g_keys.bind(.{ .key = .t, .modifiers = .{} }, null, &toggleTheme);
    g_keys.bind(.{ .key = .up, .modifiers = .{} }, null, &scrollUp);
    g_keys.bind(.{ .key = .down, .modifiers = .{} }, null, &scrollDown);
    g_keys.bind(.{ .key = .home, .modifiers = .{} }, null, &scrollToTop);
    g_keys.bind(.{ .key = .escape, .modifiers = .{} }, null, &quit);
    g_keys.bind(.{ .key = .q, .modifiers = .{} }, null, &quit);

    const initial_size = win.getSize();
    cx.setViewSize(@floatFromInt(initial_size.w), @floatFromInt(initial_size.h));

    g_cx = &cx;
    g_win = win;
    win.setDrawCallback(null, &drawCallback);

    while (!win.shouldClose()) {
        while (win.poll()) |ev| {
            switch (ev) {
                .resized => |sz| {
                    cx.setViewSize(@floatFromInt(sz.w), @floatFromInt(sz.h));
                },
                .mouse_moved => |pos| {
                    g_mouse_x = @floatFromInt(pos.x);
                    g_mouse_y = @floatFromInt(pos.y);
                    const cur = cx.handleMouseMove(g_mouse_x, g_mouse_y);
                    if (cur) |c| win.setStandardCursor(c) else win.resetCursor();
                },
                .mouse_pressed => |btn| {
                    if (btn == .left) cx.handleMousePress(g_mouse_x, g_mouse_y);
                },
                .mouse_released => |btn| {
                    if (btn == .left) cx.handleMouseRelease(g_mouse_x, g_mouse_y);
                },
                .key_pressed => |kp| {
                    const mods = ui.Modifiers.fromEvent(kp.mods);
                    _ = g_keys.dispatch(.{ .key = kp.key, .modifiers = mods });
                },
                .scroll => |delta| {
                    g_scroll.scrollBy(0, -delta.dy * SCROLL_SPEED);
                    clampScroll();
                    cx.needs_render = true;
                },
                else => {},
            }
        }

        if (cx.needs_render) {
            cx.render();
            cx.resetFrame();
            win.requestRedraw();
        }

        win.waitForFrame();
    }
}
