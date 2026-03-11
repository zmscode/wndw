// ── UI Phase 4 Demo — Interactive Counter ─────────────────────────────
//
// Demonstrates the UI framework's Phase 4 capabilities:
//   - on_click event handlers
//   - Cursor changes on hover (pointing hand for buttons)
//   - Hit testing with painter's order (topmost wins)
//   - Re-rendering on state change
//
// Run: zig build run -- counter_demo

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
const peach = ui.Color.hex(0xFAB387);

// ── App state ───────────────────────────────────────────────────────

var g_count: i32 = 0;
var g_measurer: ui.TextMeasurer = undefined;
var g_cx: *ui.WindowContext = undefined;
var g_win: *wndw.Window = undefined;

fn increment(_: ?*anyopaque) void {
    g_count += 1;
    g_cx.needs_render = true;
}

fn decrement(_: ?*anyopaque) void {
    g_count -= 1;
    g_cx.needs_render = true;
}

fn reset(_: ?*anyopaque) void {
    g_count = 0;
    g_cx.needs_render = true;
}

// ── UI tree ─────────────────────────────────────────────────────────

fn makeButton(alloc: std.mem.Allocator, label: []const u8, color: ui.Color, click_fn: *const fn (?*anyopaque) void) ui.Element {
    const txt = ui.text(alloc, label, g_measurer)
        .font_size(16)
        .color(ui.Color.hex(0xFFFFFF))
        .font_weight(.semibold)
        .into_element();

    return ui.div(alloc)
        .bg(color)
        .padding_xy(24, 12)
        .corner_radius(10)
        .flex_row()
        .align_center()
        .justify_center()
        .set_cursor(.pointing_hand)
        .on_click(null, click_fn)
        .child(txt)
        .into_element();
}

fn renderUI(alloc: std.mem.Allocator) ui.Element {
    // Format counter value
    var buf: [32]u8 = undefined;
    const count_str = std.fmt.bufPrint(&buf, "{d}", .{g_count}) catch "?";
    // Copy to arena so it survives the frame
    const count_text = alloc.dupe(u8, count_str) catch unreachable;

    // ── Title ────────────────────────────────────────────────────────
    const title = ui.text(alloc, "Interactive Counter", g_measurer)
        .font_size(24)
        .color(text_col)
        .font_weight(.bold)
        .into_element();

    const subtitle = ui.text(alloc, "Phase 4 — Hit testing, on_click, cursor changes", g_measurer)
        .font_size(13)
        .color(subtext)
        .into_element();

    const header = ui.div(alloc)
        .flex_col()
        .gap(4)
        .padding_all(16)
        .bg(surface0)
        .corner_radius(12)
        .child(title)
        .child(subtitle)
        .into_element();

    // ── Counter display ──────────────────────────────────────────────
    const count_label = ui.text(alloc, count_text, g_measurer)
        .font_size(72)
        .color(if (g_count > 0) green else if (g_count < 0) red else text_col)
        .font_weight(.bold)
        .into_element();

    const counter_display = ui.div(alloc)
        .flex_row()
        .justify_center()
        .align_center()
        .padding_all(32)
        .bg(surface0)
        .corner_radius(16)
        .child(count_label)
        .into_element();

    // ── Buttons ──────────────────────────────────────────────────────
    const dec_btn = makeButton(alloc, "- Decrement", red, &decrement);
    const reset_btn = makeButton(alloc, "Reset", surface1, &reset);
    const inc_btn = makeButton(alloc, "+ Increment", green, &increment);

    const button_row = ui.div(alloc)
        .flex_row()
        .gap(12)
        .justify_center()
        .child(dec_btn)
        .child(reset_btn)
        .child(inc_btn)
        .into_element();

    // ── Info text ────────────────────────────────────────────────────
    const info = ui.text(alloc, "Click the buttons above. Hover to see cursor change.", g_measurer)
        .font_size(12)
        .color(subtext)
        .into_element();

    const info_row = ui.div(alloc)
        .flex_row()
        .justify_center()
        .child(info)
        .into_element();

    // ── Root ─────────────────────────────────────────────────────────
    return ui.div(alloc)
        .bg(bg)
        .padding_all(24)
        .flex_col()
        .gap(16)
        .child(header)
        .child(counter_display)
        .child(button_row)
        .child(info_row)
        .into_element();
}

// ── Draw callback (for live resize) ─────────────────────────────────

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

// ── Main ─────────────────────────────────────────────────────────────

pub fn main() !void {
    var win = try wndw.init("UI Phase 4 \xe2\x80\x94 Interactive Counter", 600, 420, .{
        .centred = true,
        .resizable = true,
        .inset_titlebar = true,
    });
    defer win.close();

    var cx = ui.WindowContext.init(std.heap.page_allocator);
    defer cx.deinit();

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
                    cx.setViewSize(
                        @floatFromInt(sz.w),
                        @floatFromInt(sz.h),
                    );
                },
                .mouse_moved => |pos| {
                    const cursor = cx.handleMouseMove(
                        @floatFromInt(pos.x),
                        @floatFromInt(pos.y),
                    );
                    if (cursor) |c| {
                        win.setStandardCursor(c);
                    } else {
                        win.resetCursor();
                    }
                },
                .mouse_pressed => |btn| {
                    if (btn == .left) {
                        const pos = win.getMousePos();
                        cx.handleMousePress(
                            @floatFromInt(pos.x),
                            @floatFromInt(pos.y),
                        );
                    }
                },
                .mouse_released => |btn| {
                    if (btn == .left) {
                        const pos = win.getMousePos();
                        cx.handleMouseRelease(
                            @floatFromInt(pos.x),
                            @floatFromInt(pos.y),
                        );
                    }
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
