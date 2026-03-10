// ── UI framework tests ──────────────────────────────────────────────
//
// Tests for style, layout, draw_list, element, and paint modules.

const std = @import("std");
const testing = std.testing;
const ui = @import("root.zig");

// ── Color tests ─────────────────────────────────────────────────────

test "Color.hex creates correct RGB" {
    const c = ui.Color.hex(0xFF8800);
    try testing.expectEqual(@as(u8, 0xFF), c.r);
    try testing.expectEqual(@as(u8, 0x88), c.g);
    try testing.expectEqual(@as(u8, 0x00), c.b);
    try testing.expectEqual(@as(u8, 255), c.a);
}

test "Color.rgba creates correct values" {
    const c = ui.Color.rgba(10, 20, 30, 128);
    try testing.expectEqual(@as(u8, 10), c.r);
    try testing.expectEqual(@as(u8, 20), c.g);
    try testing.expectEqual(@as(u8, 30), c.b);
    try testing.expectEqual(@as(u8, 128), c.a);
}

test "Color.toVec4 normalizes to 0-1" {
    const c = ui.Color.rgba(255, 0, 128, 255);
    const v = c.toVec4();
    try testing.expectApproxEqAbs(@as(f32, 1.0), v[0], 0.01);
    try testing.expectApproxEqAbs(@as(f32, 0.0), v[1], 0.01);
    try testing.expectApproxEqAbs(@as(f32, 0.502), v[2], 0.01);
    try testing.expectApproxEqAbs(@as(f32, 1.0), v[3], 0.01);
}

test "Color.eql compares all channels" {
    const a = ui.Color.hex(0xFF0000);
    const b = ui.Color.hex(0xFF0000);
    const c = ui.Color.hex(0x00FF00);
    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
}

// ── Edges tests ─────────────────────────────────────────────────────

test "Edges.all sets uniform padding" {
    const e = ui.Edges.all(10);
    try testing.expectEqual(@as(f32, 10), e.top);
    try testing.expectEqual(@as(f32, 10), e.right);
    try testing.expectEqual(@as(f32, 10), e.bottom);
    try testing.expectEqual(@as(f32, 10), e.left);
}

test "Edges.xy sets horizontal and vertical" {
    const e = ui.Edges.xy(5, 10);
    try testing.expectEqual(@as(f32, 10), e.top);
    try testing.expectEqual(@as(f32, 5), e.right);
    try testing.expectEqual(@as(f32, 10), e.bottom);
    try testing.expectEqual(@as(f32, 5), e.left);
}

test "Edges.horizontal and vertical sum correctly" {
    const e = ui.Edges{ .top = 1, .right = 2, .bottom = 3, .left = 4 };
    try testing.expectEqual(@as(f32, 6), e.horizontal());
    try testing.expectEqual(@as(f32, 4), e.vertical());
}

// ── Rect tests ──────────────────────────────────────────────────────

test "Rect.contains point inside" {
    const r = ui.Rect{ .x = 10, .y = 20, .w = 100, .h = 50 };
    try testing.expect(r.contains(50, 40));
    try testing.expect(r.contains(10, 20)); // top-left corner
    try testing.expect(!r.contains(110, 70)); // just outside bottom-right
    try testing.expect(!r.contains(9, 20)); // just outside left
}

test "Rect.inset shrinks by edges" {
    const r = ui.Rect{ .x = 0, .y = 0, .w = 100, .h = 80 };
    const inset = r.inset(ui.Edges.all(10));
    try testing.expectEqual(@as(f32, 10), inset.x);
    try testing.expectEqual(@as(f32, 10), inset.y);
    try testing.expectEqual(@as(f32, 80), inset.w);
    try testing.expectEqual(@as(f32, 60), inset.h);
}

test "Rect.inset clamps to zero" {
    const r = ui.Rect{ .x = 0, .y = 0, .w = 10, .h = 10 };
    const inset = r.inset(ui.Edges.all(20));
    try testing.expectEqual(@as(f32, 0), inset.w);
    try testing.expectEqual(@as(f32, 0), inset.h);
}

// ── Constraints tests ───────────────────────────────────────────────

test "Constraints.tight creates min==max" {
    const c = ui.Constraints.tight(800, 600);
    try testing.expectEqual(@as(f32, 800), c.min_w);
    try testing.expectEqual(@as(f32, 800), c.max_w);
    try testing.expectEqual(@as(f32, 600), c.min_h);
    try testing.expectEqual(@as(f32, 600), c.max_h);
}

test "Constraints.clamp restricts size" {
    const c = ui.Constraints{ .min_w = 50, .min_h = 50, .max_w = 200, .max_h = 200 };
    const small = c.clamp(.{ .w = 10, .h = 10 });
    try testing.expectEqual(@as(f32, 50), small.w);
    try testing.expectEqual(@as(f32, 50), small.h);
    const big = c.clamp(.{ .w = 500, .h = 500 });
    try testing.expectEqual(@as(f32, 200), big.w);
    try testing.expectEqual(@as(f32, 200), big.h);
}

// ── DrawList tests ──────────────────────────────────────────────────

test "DrawList push and clear" {
    var dl = ui.DrawList{};
    defer dl.deinit(testing.allocator);

    dl.pushQuad(testing.allocator, .{
        .bounds = .{ 0, 0, 100, 50 },
        .bg = .{ 1, 0, 0, 1 },
    });
    dl.pushQuad(testing.allocator, .{
        .bounds = .{ 10, 10, 80, 30 },
        .bg = .{ 0, 1, 0, 1 },
    });

    try testing.expectEqual(@as(usize, 2), dl.quads.items.len);

    dl.clear();
    try testing.expectEqual(@as(usize, 0), dl.quads.items.len);
}

test "DrawList preserves quad data" {
    var dl = ui.DrawList{};
    defer dl.deinit(testing.allocator);

    dl.pushQuad(testing.allocator, .{
        .bounds = .{ 10, 20, 30, 40 },
        .bg = .{ 0.5, 0.5, 0.5, 1.0 },
        .corner_radii = .{ 8, 8, 8, 8 },
        .border_width = 2,
    });

    const q = dl.quads.items[0];
    try testing.expectEqual(@as(f32, 10), q.bounds[0]);
    try testing.expectEqual(@as(f32, 20), q.bounds[1]);
    try testing.expectEqual(@as(f32, 8), q.corner_radii[0]);
    try testing.expectEqual(@as(f32, 2), q.border_width);
}

// ── PaintContext tests ──────────────────────────────────────────────

test "PaintContext accumulates quads" {
    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    px.pushQuad(.{ .bounds = .{ 0, 0, 100, 100 }, .bg = .{ 1, 0, 0, 1 } });
    px.pushQuad(.{ .bounds = .{ 10, 10, 50, 50 }, .bg = .{ 0, 0, 1, 1 } });

    try testing.expectEqual(@as(usize, 2), px.draw_list.quads.items.len);
}

test "PaintContext clip stack push/pop" {
    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    try testing.expectEqual(@as(i32, -1), px.currentClipIndex());

    px.pushClip(.{ .x = 0, .y = 0, .w = 100, .h = 100 });
    const idx = px.currentClipIndex();
    try testing.expect(idx >= 0);

    px.popClip();
    try testing.expectEqual(@as(i32, -1), px.currentClipIndex());
}

// ── Div / Element tests ─────────────────────────────────────────────

test "Div fluent API sets style" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const d = ui.div(alloc)
        .bg(ui.Color.hex(0xFF0000))
        .corner_radius(8)
        .padding_all(16)
        .size(200, 100)
        .border(2, ui.Color.hex(0x333333))
        .shadow(10, ui.Color.rgba(0, 0, 0, 128));

    try testing.expect(d.sty.background != null);
    try testing.expect(d.sty.background.?.eql(ui.Color.hex(0xFF0000)));
    try testing.expectEqual(@as(f32, 8), d.sty.corner_radius[0]);
    try testing.expectEqual(@as(f32, 16), d.sty.padding.top);
    try testing.expectEqual(ui.Len{ .px = 200 }, d.sty.width);
    try testing.expectEqual(ui.Len{ .px = 100 }, d.sty.height);
    try testing.expectEqual(@as(f32, 2), d.sty.border_width);
    try testing.expectEqual(@as(f32, 10), d.sty.shadow_blur);
}

test "Div children append" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const child1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).size(50, 50).into_element();
    const child2 = ui.div(alloc).bg(ui.Color.hex(0x00FF00)).size(50, 50).into_element();

    const parent = ui.div(alloc)
        .child(child1)
        .child(child2);

    try testing.expectEqual(@as(usize, 2), parent.children_list.items.len);
}

test "Div into_element returns valid Element" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const el = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).size(100, 50).into_element();
    // Verify element is callable (vtable is valid)
    const sz = el.doLayout(ui.Constraints.tight(100, 50));
    try testing.expectEqual(@as(f32, 100), sz.w);
}

test "Div layout returns explicit size" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const el = ui.div(alloc).size(200, 100).into_element();
    const sz = el.doLayout(ui.Constraints{ .max_w = 800, .max_h = 600 });
    try testing.expectEqual(@as(f32, 200), sz.w);
    try testing.expectEqual(@as(f32, 100), sz.h);
}

test "Div layout auto fills constraints" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const el = ui.div(alloc).into_element();
    const sz = el.doLayout(ui.Constraints.tight(800, 600));
    try testing.expectEqual(@as(f32, 800), sz.w);
    try testing.expectEqual(@as(f32, 600), sz.h);
}

test "Div paint emits quad with background" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const el = ui.div(alloc)
        .bg(ui.Color.hex(0xFF0000))
        .size(100, 50)
        .into_element();

    el.paint(&px, .{ .x = 10, .y = 20, .w = 100, .h = 50 });

    try testing.expectEqual(@as(usize, 1), px.draw_list.quads.items.len);
    const q = px.draw_list.quads.items[0];
    try testing.expectEqual(@as(f32, 10), q.bounds[0]);
    try testing.expectEqual(@as(f32, 20), q.bounds[1]);
    try testing.expectEqual(@as(f32, 100), q.bounds[2]);
    try testing.expectEqual(@as(f32, 50), q.bounds[3]);
    // Red background
    try testing.expectApproxEqAbs(@as(f32, 1.0), q.bg[0], 0.01);
}

test "Div paint does not emit quad without visual properties" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const el = ui.div(alloc).size(100, 50).into_element();
    el.paint(&px, .{ .x = 0, .y = 0, .w = 100, .h = 50 });

    try testing.expectEqual(@as(usize, 0), px.draw_list.quads.items.len);
}

test "Nested divs emit multiple quads" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const inner = ui.div(alloc)
        .bg(ui.Color.hex(0x00FF00))
        .size(50, 50)
        .into_element();

    const outer = ui.div(alloc)
        .bg(ui.Color.hex(0xFF0000))
        .padding_all(20)
        .child(inner)
        .into_element();

    // Layout first
    _ = outer.doLayout(ui.Constraints.tight(200, 200));
    // Then paint
    outer.paint(&px, .{ .x = 0, .y = 0, .w = 200, .h = 200 });

    // Outer bg + inner bg = 2 quads
    try testing.expectEqual(@as(usize, 2), px.draw_list.quads.items.len);

    // Inner quad should be offset by padding
    const inner_q = px.draw_list.quads.items[1];
    try testing.expectEqual(@as(f32, 20), inner_q.bounds[0]); // x offset by left padding
    try testing.expectEqual(@as(f32, 20), inner_q.bounds[1]); // y offset by top padding
}

// ── WindowContext tests ─────────────────────────────────────────────

test "WindowContext init and deinit" {
    var cx = ui.WindowContext.init(testing.allocator);
    defer cx.deinit();

    try testing.expect(cx.needs_render);
    try testing.expectEqual(@as(f32, 800), cx.view_width);
    try testing.expectEqual(@as(f32, 600), cx.view_height);
}

test "WindowContext frame arena reset" {
    var cx = ui.WindowContext.init(testing.allocator);
    defer cx.deinit();

    // Allocate something in the frame arena
    const alloc = cx.frameAlloc();
    const ptr = try alloc.create(u64);
    ptr.* = 42;

    // Reset should not crash
    cx.resetFrame();
}

test "WindowContext render builds draw list" {
    var cx = ui.WindowContext.init(testing.allocator);
    defer cx.deinit();
    cx.setViewSize(400, 300);

    cx.setRootRenderFn(&testRenderFn);
    cx.render();

    // Should have produced quads
    try testing.expect(cx.paint_cx.draw_list.quads.items.len > 0);
    try testing.expect(!cx.needs_render);
}

fn testRenderFn(alloc: std.mem.Allocator) ui.Element {
    const inner = ui.div(alloc)
        .bg(ui.Color.hex(0x00FF00))
        .size(100, 100)
        .corner_radius(8)
        .into_element();

    return ui.div(alloc)
        .bg(ui.Color.hex(0x1E1E2E))
        .padding_all(20)
        .child(inner)
        .into_element();
}

test "WindowContext setViewSize marks dirty" {
    var cx = ui.WindowContext.init(testing.allocator);
    defer cx.deinit();

    cx.needs_render = false;
    cx.setViewSize(1024, 768);
    try testing.expect(cx.needs_render);
}

// ── Style defaults test ─────────────────────────────────────────────

test "Style defaults are sensible" {
    const s = ui.Style{};
    try testing.expectEqual(ui.style.FlexDirection.column, s.direction);
    try testing.expectEqual(ui.style.Align.stretch, s.align_items);
    try testing.expectEqual(ui.Len.auto, s.width);
    try testing.expectEqual(ui.Len.auto, s.height);
    try testing.expect(s.background == null);
    try testing.expectEqual(@as(f32, 1.0), s.opacity);
    try testing.expectEqual(@as(f32, 0), s.border_width);
}
