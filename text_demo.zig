// ── UI Phase 3 Demo — Text Rendering ─────────────────────────────────
//
// Demonstrates the UI framework's Phase 3 capabilities:
//   - Text element with font_size, color, font_weight
//   - Labels inside button-like containers
//   - Paragraph text with different sizes
//   - Text alongside Div elements in flex layouts
//
// Run: zig build run -- text_demo

const wndw = @import("wndw");
const ui = @import("ui");
const std = @import("std");

/// Catppuccin Mocha palette
const bg = ui.Color.hex(0x1E1E2E);
const surface0 = ui.Color.hex(0x313244);
const surface1 = ui.Color.hex(0x45475A);
const surface2 = ui.Color.hex(0x585B70);
const text_col = ui.Color.hex(0xCDD6F4);
const subtext = ui.Color.hex(0xA6ADC8);
const overlay = ui.Color.hex(0x6C7086);
const red = ui.Color.hex(0xF38BA8);
const green = ui.Color.hex(0xA6E3A1);
const blue = ui.Color.hex(0x89B4FA);
const mauve = ui.Color.hex(0xCBA6F7);
const peach = ui.Color.hex(0xFAB387);

var g_measurer: ui.TextMeasurer = undefined;

fn labelButton(alloc: std.mem.Allocator, label: []const u8, color: ui.Color) ui.Element {
    const txt = ui.text(alloc, label, g_measurer)
        .font_size(14)
        .color(ui.Color.hex(0xFFFFFF))
        .font_weight(.medium)
        .into_element();

    return ui.div(alloc)
        .bg(color)
        .padding_xy(16, 8)
        .corner_radius(8)
        .flex_row()
        .align_center()
        .justify_center()
        .child(txt)
        .into_element();
}

fn renderUI(alloc: std.mem.Allocator) ui.Element {
    // ── Section 1: Title + subtitle ──────────────────────────────────
    const title = ui.text(alloc, "Text Rendering Demo", g_measurer)
        .font_size(28)
        .color(text_col)
        .font_weight(.bold)
        .into_element();

    const subtitle = ui.text(alloc, "Phase 3 — CoreText glyph atlas with per-glyph mask blitting", g_measurer)
        .font_size(14)
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

    // ── Section 2: Buttons with text labels ──────────────────────────
    const toolbar = ui.div(alloc)
        .flex_row()
        .gap(8)
        .padding_all(12)
        .bg(surface0)
        .corner_radius(12)
        .child(labelButton(alloc, "Save", blue))
        .child(labelButton(alloc, "Cancel", surface2))
        .child(labelButton(alloc, "Delete", red))
        .child(labelButton(alloc, "Export", green))
        .into_element();

    // ── Section 3: Different font sizes ──────────────────────────────
    const sizes_section = ui.div(alloc)
        .flex_col()
        .gap(8)
        .padding_all(16)
        .bg(surface0)
        .corner_radius(12)
        .child(
            ui.text(alloc, "Heading 1 (24pt)", g_measurer)
                .font_size(24).color(text_col).font_weight(.bold).into_element(),
        )
        .child(
            ui.text(alloc, "Heading 2 (18pt)", g_measurer)
                .font_size(18).color(text_col).font_weight(.semibold).into_element(),
        )
        .child(
            ui.text(alloc, "Body text at 14pt — the quick brown fox jumps over the lazy dog.", g_measurer)
                .font_size(14).color(subtext).into_element(),
        )
        .child(
            ui.text(alloc, "Caption text at 11pt — smaller details and metadata", g_measurer)
                .font_size(11).color(overlay).into_element(),
        )
        .into_element();

    // ── Section 4: Card with icon placeholder + text ─────────────────
    const avatar = ui.div(alloc)
        .bg(mauve)
        .size(48, 48)
        .corner_radius(24)
        .into_element();

    const card_text = ui.div(alloc)
        .flex_col()
        .gap(4)
        .grow(1)
        .child(
            ui.text(alloc, "Zac Morrissey", g_measurer)
                .font_size(16).color(text_col).font_weight(.semibold).into_element(),
        )
        .child(
            ui.text(alloc, "Building a GPUI-inspired UI framework in Zig", g_measurer)
                .font_size(13).color(subtext).into_element(),
        )
        .into_element();

    const card = ui.div(alloc)
        .flex_row()
        .gap(12)
        .align_center()
        .padding_all(16)
        .bg(surface0)
        .corner_radius(12)
        .shadow(10, ui.Color.rgba(0, 0, 0, 60))
        .child(avatar)
        .child(card_text)
        .into_element();

    // ── Section 5: Status bar ────────────────────────────────────────
    const status = ui.div(alloc)
        .flex_row()
        .justify(.space_between)
        .align_center()
        .padding_xy(16, 8)
        .bg(surface0)
        .corner_radius(12)
        .child(
            ui.text(alloc, "Ready", g_measurer)
                .font_size(12).color(green).into_element(),
        )
        .child(
            ui.text(alloc, "Ln 42, Col 80", g_measurer)
                .font_size(12).color(overlay).into_element(),
        )
        .child(
            ui.text(alloc, "UTF-8", g_measurer)
                .font_size(12).color(overlay).into_element(),
        )
        .into_element();

    // ── Root layout ─────────────────────────────────────────────────
    return ui.div(alloc)
        .bg(bg)
        .padding_all(16)
        .flex_col()
        .gap(12)
        .child(header)
        .child(toolbar)
        .child(sizes_section)
        .child(card)
        .child(status)
        .into_element();
}

var g_cx: *ui.WindowContext = undefined;
var g_win: *wndw.Window = undefined;

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
    var win = try wndw.init("UI Phase 3 \xe2\x80\x94 Text Rendering", 700, 520, .{
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
