// ── UI Phase 1 Demo — Nested Colored Rectangles ─────────────────────
//
// Demonstrates the UI framework's Phase 1 capabilities:
//   - WindowContext with frame arena
//   - Div element with bg, padding, size, corner_radius, border, shadow
//   - NativeRenderer drawing QuadCmd list via CoreGraphics
//   - drawRect: hook for native rendering
//
// Run: zig build run -- ui_demo

const wndw = @import("wndw");
const ui = @import("ui");

/// Build the element tree for each frame.
fn renderUI(alloc: @import("std").mem.Allocator) ui.Element {
    // Inner boxes — a row of colored squares
    const box1 = ui.div(alloc)
        .bg(ui.Color.hex(0xF38BA8)) // red/pink
        .size(80, 80)
        .corner_radius(8)
        .into_element();

    const box2 = ui.div(alloc)
        .bg(ui.Color.hex(0xA6E3A1)) // green
        .size(80, 80)
        .corner_radius(8)
        .into_element();

    const box3 = ui.div(alloc)
        .bg(ui.Color.hex(0x89B4FA)) // blue
        .size(80, 80)
        .corner_radius(8)
        .into_element();

    const box4 = ui.div(alloc)
        .bg(ui.Color.hex(0xFAB387)) // orange
        .size(80, 80)
        .corner_radius(8)
        .into_element();

    // Row container
    const row = ui.div(alloc)
        .flex_row()
        .gap(16)
        .padding_all(24)
        .bg(ui.Color.hex(0x313244)) // surface
        .corner_radius(16)
        .border(2, ui.Color.hex(0x45475A))
        .shadow(20, ui.Color.rgba(0, 0, 0, 100))
        .child(box1)
        .child(box2)
        .child(box3)
        .child(box4)
        .into_element();

    // Nested card
    const card = ui.div(alloc)
        .padding_all(20)
        .bg(ui.Color.hex(0x45475A)) // surface hover
        .corner_radius(12)
        .shadow(10, ui.Color.rgba(0, 0, 0, 60))
        .child(
            ui.div(alloc)
                .bg(ui.Color.hex(0xCBA6F7)) // purple accent
                .size(200, 40)
                .corner_radius(6)
                .into_element(),
        )
        .into_element();

    // Root — dark background, centered content
    return ui.div(alloc)
        .bg(ui.Color.hex(0x1E1E2E)) // background
        .padding_all(40)
        .child(row)
        .child(card)
        .into_element();
}

// Global context pointer for the draw callback
var g_cx: *ui.WindowContext = undefined;

fn drawCallback(_: ?*anyopaque) void {
    g_cx.flush();
}

pub fn main() !void {
    var win = try wndw.init("UI Phase 1 — Colored Rectangles", 600, 400, .{
        .centred = true,
        .resizable = true,
        .inset_titlebar = true,
    });
    defer win.close();

    var cx = ui.WindowContext.init(@import("std").heap.page_allocator);
    defer cx.deinit();

    cx.setRootRenderFn(&renderUI);

    // Set initial view size from window before first render
    const initial_size = win.getSize();
    cx.setViewSize(@floatFromInt(initial_size.w), @floatFromInt(initial_size.h));

    // Store context globally for the draw callback
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
