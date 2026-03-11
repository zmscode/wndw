// ── UI Phase 5 Demo — Reactivity / Observer Pattern ───────────────────
//
// Demonstrates the UI framework's Phase 5 capabilities:
//   - EntityPool for retained state management
//   - Handle(T) for typed entity access
//   - Observer pattern: update() auto-notifies subscribers
//   - Multiple UI views reacting to a shared model
//
// The demo has a shared "AppState" entity with a counter and a message.
// Three panels observe it: a counter display, a status bar, and a
// history log showing how many times each button was pressed.
//
// Run: zig build run -- observer_demo

const wndw = @import("wndw");
const ui = @import("ui");
const std = @import("std");

/// Catppuccin Mocha palette
const bg = ui.Color.hex(0x1E1E2E);
const surface0 = ui.Color.hex(0x313244);
const surface1 = ui.Color.hex(0x45475A);
const text_col = ui.Color.hex(0xCDD6F4);
const subtext = ui.Color.hex(0xA6ADC8);
const red = ui.Color.hex(0xF38BA8);
const green = ui.Color.hex(0xA6E3A1);
const blue = ui.Color.hex(0x89B4FA);
const mauve = ui.Color.hex(0xCBA6F7);
const yellow = ui.Color.hex(0xF9E2AF);

// ── Shared model ────────────────────────────────────────────────────

const AppState = struct {
    count: i32 = 0,
    increments: u32 = 0,
    decrements: u32 = 0,
    resets: u32 = 0,
};

var g_pool: ui.EntityPool = undefined;
var g_handle: ui.Handle(AppState) = undefined;
var g_measurer: ui.TextMeasurer = undefined;
var g_cx: *ui.WindowContext = undefined;
var g_win: *wndw.Window = undefined;
var g_mouse_x: f32 = 0;
var g_mouse_y: f32 = 0;

fn increment(_: ?*anyopaque) void {
    const state = g_handle.read(&g_pool);
    g_handle.update(&g_pool, .{
        .count = state.count + 1,
        .increments = state.increments + 1,
        .decrements = state.decrements,
        .resets = state.resets,
    });
}

fn decrement(_: ?*anyopaque) void {
    const state = g_handle.read(&g_pool);
    g_handle.update(&g_pool, .{
        .count = state.count - 1,
        .increments = state.increments,
        .decrements = state.decrements + 1,
        .resets = state.resets,
    });
}

fn reset(_: ?*anyopaque) void {
    const state = g_handle.read(&g_pool);
    g_handle.update(&g_pool, .{
        .count = 0,
        .increments = state.increments,
        .decrements = state.decrements,
        .resets = state.resets + 1,
    });
}

// ── Observer callback — triggers re-render ──────────────────────────

fn onStateChanged(_: ?*anyopaque) void {
    g_cx.needs_render = true;
}

// ── UI helpers ──────────────────────────────────────────────────────

fn makeButton(alloc: std.mem.Allocator, label: []const u8, color: ui.Color, click_fn: *const fn (?*anyopaque) void) ui.Element {
    const txt = ui.text(alloc, label, g_measurer)
        .font_size(14)
        .color(ui.Color.hex(0xFFFFFF))
        .font_weight(.semibold)
        .into_element();

    return ui.div(alloc)
        .bg(color)
        .padding_xy(20, 10)
        .corner_radius(8)
        .flex_row()
        .align_center()
        .justify_center()
        .set_cursor(.pointing_hand)
        .on_click(null, click_fn)
        .child(txt)
        .into_element();
}

fn fmtArena(alloc: std.mem.Allocator, comptime fmt: []const u8, args: anytype) []const u8 {
    var buf: [128]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, fmt, args) catch "?";
    return alloc.dupe(u8, s) catch unreachable;
}

// ── UI tree ─────────────────────────────────────────────────────────

fn renderUI(alloc: std.mem.Allocator) ui.Element {
    const state = g_handle.read(&g_pool);

    // ── Header ──────────────────────────────────────────────────────
    const header = ui.div(alloc)
        .flex_col().gap(4).padding_all(16).bg(surface0).corner_radius(12)
        .child(ui.text(alloc, "Observer Pattern Demo", g_measurer)
            .font_size(22).color(text_col).font_weight(.bold).into_element())
        .child(ui.text(alloc, "Phase 5 — EntityPool, Handle(T), subscriptions", g_measurer)
            .font_size(12).color(subtext).into_element())
        .into_element();

    // ── Panel 1: Counter display (observes count) ───────────────────
    const count_str = fmtArena(alloc, "{d}", .{state.count});
    const counter_panel = ui.div(alloc)
        .flex_col().gap(8).padding_all(20).bg(surface0).corner_radius(12)
        .child(ui.text(alloc, "Counter Value", g_measurer)
            .font_size(11).color(subtext).font_weight(.medium).into_element())
        .child(ui.text(alloc, count_str, g_measurer)
            .font_size(48).color(if (state.count > 0) green else if (state.count < 0) red else text_col)
            .font_weight(.bold).into_element())
        .into_element();

    // ── Panel 2: Action stats (observes increments/decrements/resets)
    const stats_panel = ui.div(alloc)
        .flex_col().gap(6).padding_all(16).bg(surface0).corner_radius(12)
        .child(ui.text(alloc, "Action History", g_measurer)
            .font_size(11).color(subtext).font_weight(.medium).into_element())
        .child(ui.text(alloc, fmtArena(alloc, "Increments: {d}", .{state.increments}), g_measurer)
            .font_size(14).color(green).into_element())
        .child(ui.text(alloc, fmtArena(alloc, "Decrements: {d}", .{state.decrements}), g_measurer)
            .font_size(14).color(red).into_element())
        .child(ui.text(alloc, fmtArena(alloc, "Resets: {d}", .{state.resets}), g_measurer)
            .font_size(14).color(yellow).into_element())
        .child(ui.text(alloc, fmtArena(alloc, "Total actions: {d}", .{state.increments + state.decrements + state.resets}), g_measurer)
            .font_size(14).color(mauve).font_weight(.semibold).into_element())
        .into_element();

    // ── Two panels side by side ─────────────────────────────────────
    const panels_row = ui.div(alloc)
        .flex_row().gap(12)
        .child(ui.div(alloc).flex_col().grow(1).child(counter_panel).into_element())
        .child(ui.div(alloc).flex_col().grow(1).child(stats_panel).into_element())
        .into_element();

    // ── Buttons ─────────────────────────────────────────────────────
    const button_row = ui.div(alloc)
        .flex_row().gap(10).justify_center()
        .child(makeButton(alloc, "- Decrement", red, &decrement))
        .child(makeButton(alloc, "Reset", surface1, &reset))
        .child(makeButton(alloc, "+ Increment", green, &increment))
        .into_element();

    // ── Status bar (observes all state) ─────────────────────────────
    const status_text = fmtArena(alloc, "State: count={d} | {d} inc, {d} dec, {d} rst", .{
        state.count, state.increments, state.decrements, state.resets,
    });
    const status = ui.div(alloc)
        .flex_row().padding_xy(16, 8).bg(surface0).corner_radius(8)
        .child(ui.text(alloc, status_text, g_measurer)
            .font_size(11).color(subtext).into_element())
        .into_element();

    // ── Root ─────────────────────────────────────────────────────────
    return ui.div(alloc)
        .bg(bg)
        .padding_all(20)
        .flex_col()
        .gap(14)
        .child(header)
        .child(panels_row)
        .child(button_row)
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
    var win = try wndw.init("UI Phase 5 \xe2\x80\x94 Observer Pattern", 650, 440, .{
        .centred = true,
        .resizable = true,
        .inset_titlebar = true,
    });
    defer win.close();

    var cx = ui.WindowContext.init(std.heap.page_allocator);
    defer cx.deinit();

    // Initialize entity pool and create shared state
    g_pool = ui.EntityPool.init(std.heap.page_allocator);
    defer g_pool.deinit();
    g_handle = g_pool.create(AppState, .{});

    // Subscribe: when state changes, trigger re-render
    g_pool.observe(g_handle.id, null, &onStateChanged);

    g_measurer = cx.textMeasurer();
    cx.setRootRenderFn(&renderUI);

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
