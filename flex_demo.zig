// ── UI Phase 2 Demo — Flexbox Layout ────────────────────────────────
//
// Demonstrates the UI framework's Phase 2 capabilities:
//   - flex_row / flex_col layout with gap
//   - flex_grow for distributing remaining space
//   - align_items (center, stretch) for cross-axis alignment
//   - justify_content (space_between, center) for main-axis distribution
//   - Nested flex containers
//   - Auto-sized shrink-wrap containers
//   - Responsive layout that reflows on window resize
//
// Run: zig build run -- flex_demo

const wndw = @import("wndw");
const ui = @import("ui");
const std = @import("std");

/// Catppuccin Mocha palette
const bg = ui.Color.hex(0x1E1E2E);
const surface0 = ui.Color.hex(0x313244);
const surface1 = ui.Color.hex(0x45475A);
const surface2 = ui.Color.hex(0x585B70);
const text_dim = ui.Color.hex(0x6C7086);
const red = ui.Color.hex(0xF38BA8);
const green = ui.Color.hex(0xA6E3A1);
const blue = ui.Color.hex(0x89B4FA);
const yellow = ui.Color.hex(0xF9E2AF);
const mauve = ui.Color.hex(0xCBA6F7);
const peach = ui.Color.hex(0xFAB387);
const teal = ui.Color.hex(0x94E2D5);

fn button(alloc: std.mem.Allocator, color: ui.Color, w: f32) ui.Element {
    return ui.div(alloc)
        .bg(color)
        .size(w, 36)
        .corner_radius(8)
        .into_element();
}

fn growButton(alloc: std.mem.Allocator, color: ui.Color, g: f32) ui.Element {
    return ui.div(alloc)
        .bg(color)
        .height(36)
        .grow(g)
        .corner_radius(8)
        .into_element();
}

fn renderUI(alloc: std.mem.Allocator) ui.Element {
    // ── Section 1: Toolbar with fixed-size buttons + gap ───────────
    const toolbar = ui.div(alloc)
        .flex_row()
        .gap(8)
        .padding_all(12)
        .bg(surface0)
        .corner_radius(12)
        .child(button(alloc, red, 80))
        .child(button(alloc, green, 80))
        .child(button(alloc, blue, 80))
        .child(button(alloc, yellow, 80))
        .child(button(alloc, mauve, 80))
        .into_element();

    // ── Section 2: flex_grow — buttons that fill available width ───
    const grow_row = ui.div(alloc)
        .flex_row()
        .gap(8)
        .padding_all(12)
        .bg(surface0)
        .corner_radius(12)
        .child(growButton(alloc, peach, 1))
        .child(growButton(alloc, teal, 2))
        .child(growButton(alloc, mauve, 1))
        .into_element();

    // ── Section 3: justify_content space_between ──────────────────
    const spaced_row = ui.div(alloc)
        .flex_row()
        .justify(.space_between)
        .align_center()
        .padding_all(12)
        .bg(surface0)
        .corner_radius(12)
        .child(button(alloc, red, 60))
        .child(button(alloc, green, 60))
        .child(button(alloc, blue, 60))
        .into_element();

    // ── Section 4: Mixed layout — fixed sidebar + flexible content ─
    const sidebar = ui.div(alloc)
        .bg(surface1)
        .width(120)
        .grow(0)
        .corner_radius(8)
        .padding_all(8)
        .child(
            ui.div(alloc)
                .bg(surface2)
                .height(24)
                .corner_radius(4)
                .into_element(),
        )
        .into_element();

    const content = ui.div(alloc)
        .bg(surface1)
        .grow(1)
        .corner_radius(8)
        .padding_all(12)
        .flex_row()
        .gap(8)
        .justify_center()
        .align_center()
        .child(button(alloc, yellow, 50))
        .child(button(alloc, peach, 50))
        .child(button(alloc, teal, 50))
        .into_element();

    const split_view = ui.div(alloc)
        .flex_row()
        .gap(8)
        .padding_all(12)
        .bg(surface0)
        .corner_radius(12)
        .child(sidebar)
        .child(content)
        .into_element();

    // ── Section 5: Centered card (justify + align center) ─────────
    const card = ui.div(alloc)
        .bg(surface1)
        .corner_radius(12)
        .padding_all(16)
        .shadow(15, ui.Color.rgba(0, 0, 0, 80))
        .flex_row()
        .gap(12)
        .align_center()
        .child(ui.div(alloc).bg(mauve).size(48, 48).corner_radius(24).into_element())
        .child(
            ui.div(alloc)
                .flex_col()
                .gap(6)
                .child(ui.div(alloc).bg(surface2).size(120, 14).corner_radius(3).into_element())
                .child(ui.div(alloc).bg(text_dim).size(80, 10).corner_radius(3).into_element())
                .into_element(),
        )
        .into_element();

    const centered_section = ui.div(alloc)
        .flex_row()
        .justify_center()
        .padding_all(12)
        .bg(surface0)
        .corner_radius(12)
        .child(card)
        .into_element();

    // ── Root layout ─────────────────────────────────────────────────
    return ui.div(alloc)
        .bg(bg)
        .padding_all(16)
        .flex_col()
        .gap(12)
        .child(toolbar)
        .child(grow_row)
        .child(spaced_row)
        .child(split_view)
        .child(centered_section)
        .into_element();
}

var g_cx: *ui.WindowContext = undefined;

fn drawCallback(_: ?*anyopaque) void {
    g_cx.flush();
}

pub fn main() !void {
    var win = try wndw.init("UI Phase 2 — Flexbox Layout", 700, 520, .{
        .centred = true,
        .resizable = true,
        .inset_titlebar = true,
    });
    defer win.close();

    var cx = ui.WindowContext.init(std.heap.page_allocator);
    defer cx.deinit();

    cx.setRootRenderFn(&renderUI);

    g_cx = &cx;
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
