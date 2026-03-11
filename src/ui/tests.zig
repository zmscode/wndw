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

// ── Phase 2: Flexbox layout tests ───────────────────────────────────

test "flex row positions children horizontally" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const c1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).size(60, 40).into_element();
    const c2 = ui.div(alloc).bg(ui.Color.hex(0x00FF00)).size(80, 40).into_element();

    const row = ui.div(alloc).flex_row().child(c1).child(c2).into_element();
    _ = row.doLayout(ui.Constraints.tight(400, 200));
    row.paint(&px, .{ .x = 0, .y = 0, .w = 400, .h = 200 });

    // First child at x=0, second at x=60
    try testing.expectEqual(@as(usize, 2), px.draw_list.quads.items.len);
    try testing.expectApproxEqAbs(@as(f32, 0), px.draw_list.quads.items[0].bounds[0], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 60), px.draw_list.quads.items[1].bounds[0], 0.1);
}

test "flex column positions children vertically" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const c1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).size(100, 30).into_element();
    const c2 = ui.div(alloc).bg(ui.Color.hex(0x00FF00)).size(100, 50).into_element();

    const col = ui.div(alloc).flex_col().child(c1).child(c2).into_element();
    _ = col.doLayout(ui.Constraints.tight(400, 400));
    col.paint(&px, .{ .x = 0, .y = 0, .w = 400, .h = 400 });

    try testing.expectEqual(@as(usize, 2), px.draw_list.quads.items.len);
    try testing.expectApproxEqAbs(@as(f32, 0), px.draw_list.quads.items[0].bounds[1], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 30), px.draw_list.quads.items[1].bounds[1], 0.1);
}

test "flex row with gap adds spacing" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const c1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).size(50, 40).into_element();
    const c2 = ui.div(alloc).bg(ui.Color.hex(0x00FF00)).size(50, 40).into_element();
    const c3 = ui.div(alloc).bg(ui.Color.hex(0x0000FF)).size(50, 40).into_element();

    const row = ui.div(alloc).flex_row().gap(10).child(c1).child(c2).child(c3).into_element();
    _ = row.doLayout(ui.Constraints.tight(400, 200));
    row.paint(&px, .{ .x = 0, .y = 0, .w = 400, .h = 200 });

    // Positions: 0, 60 (50+10), 120 (50+10+50+10)
    try testing.expectApproxEqAbs(@as(f32, 0), px.draw_list.quads.items[0].bounds[0], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 60), px.draw_list.quads.items[1].bounds[0], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 120), px.draw_list.quads.items[2].bounds[0], 0.1);
}

test "flex_grow distributes remaining space equally" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const c1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).grow(1).into_element();
    const c2 = ui.div(alloc).bg(ui.Color.hex(0x00FF00)).grow(1).into_element();

    const row = ui.div(alloc).flex_row().child(c1).child(c2).into_element();
    _ = row.doLayout(ui.Constraints.tight(300, 100));
    row.paint(&px, .{ .x = 0, .y = 0, .w = 300, .h = 100 });

    try testing.expectApproxEqAbs(@as(f32, 150), px.draw_list.quads.items[0].bounds[2], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 150), px.draw_list.quads.items[1].bounds[2], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 0), px.draw_list.quads.items[0].bounds[0], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 150), px.draw_list.quads.items[1].bounds[0], 0.1);
}

test "flex_grow proportional distribution" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    // Fixed 100px child + two flex children (grow 1 and 2)
    // Container: 400px. Remaining = 400 - 100 = 300
    // grow(1) gets 100, grow(2) gets 200
    const fixed = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).width(100).into_element();
    const flex1 = ui.div(alloc).bg(ui.Color.hex(0x00FF00)).grow(1).into_element();
    const flex2 = ui.div(alloc).bg(ui.Color.hex(0x0000FF)).grow(2).into_element();

    const row = ui.div(alloc).flex_row().child(fixed).child(flex1).child(flex2).into_element();
    _ = row.doLayout(ui.Constraints.tight(400, 100));
    row.paint(&px, .{ .x = 0, .y = 0, .w = 400, .h = 100 });

    try testing.expectApproxEqAbs(@as(f32, 100), px.draw_list.quads.items[0].bounds[2], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 100), px.draw_list.quads.items[1].bounds[2], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 200), px.draw_list.quads.items[2].bounds[2], 0.1);
}

test "align_items center positions on cross axis" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const c1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).size(60, 40).into_element();
    const row = ui.div(alloc).flex_row().align_center().child(c1).into_element();
    _ = row.doLayout(ui.Constraints.tight(400, 200));
    row.paint(&px, .{ .x = 0, .y = 0, .w = 400, .h = 200 });

    // Center: y = (200 - 40) / 2 = 80
    try testing.expectApproxEqAbs(@as(f32, 80), px.draw_list.quads.items[0].bounds[1], 0.1);
}

test "align_items stretch fills cross axis" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const c1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).width(60).into_element();
    const row = ui.div(alloc).flex_row().child(c1).into_element();
    _ = row.doLayout(ui.Constraints.tight(400, 200));
    row.paint(&px, .{ .x = 0, .y = 0, .w = 400, .h = 200 });

    // Default align_items is stretch → child height fills 200
    try testing.expectApproxEqAbs(@as(f32, 200), px.draw_list.quads.items[0].bounds[3], 0.1);
}

test "align_self overrides align_items" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const c1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).size(60, 40).align_self(.end).into_element();
    const row = ui.div(alloc).flex_row().align_center().child(c1).into_element();
    _ = row.doLayout(ui.Constraints.tight(400, 200));
    row.paint(&px, .{ .x = 0, .y = 0, .w = 400, .h = 200 });

    // align_self: end → y = 200 - 40 = 160
    try testing.expectApproxEqAbs(@as(f32, 160), px.draw_list.quads.items[0].bounds[1], 0.1);
}

test "justify_content center centers on main axis" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const c1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).size(100, 40).into_element();
    const row = ui.div(alloc).flex_row().justify_center().child(c1).into_element();
    _ = row.doLayout(ui.Constraints.tight(400, 200));
    row.paint(&px, .{ .x = 0, .y = 0, .w = 400, .h = 200 });

    // Center: x = (400 - 100) / 2 = 150
    try testing.expectApproxEqAbs(@as(f32, 150), px.draw_list.quads.items[0].bounds[0], 0.1);
}

test "justify_content end aligns to end" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const c1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).size(100, 40).into_element();
    const row = ui.div(alloc).flex_row().justify(.end).child(c1).into_element();
    _ = row.doLayout(ui.Constraints.tight(400, 200));
    row.paint(&px, .{ .x = 0, .y = 0, .w = 400, .h = 200 });

    try testing.expectApproxEqAbs(@as(f32, 300), px.draw_list.quads.items[0].bounds[0], 0.1);
}

test "justify_content space_between distributes evenly" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const c1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).size(50, 40).into_element();
    const c2 = ui.div(alloc).bg(ui.Color.hex(0x00FF00)).size(50, 40).into_element();
    const c3 = ui.div(alloc).bg(ui.Color.hex(0x0000FF)).size(50, 40).into_element();

    const row = ui.div(alloc).flex_row().justify(.space_between).child(c1).child(c2).child(c3).into_element();
    _ = row.doLayout(ui.Constraints.tight(300, 100));
    row.paint(&px, .{ .x = 0, .y = 0, .w = 300, .h = 100 });

    // space_between: spacing = (300-150)/2 = 75
    try testing.expectApproxEqAbs(@as(f32, 0), px.draw_list.quads.items[0].bounds[0], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 125), px.draw_list.quads.items[1].bounds[0], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 250), px.draw_list.quads.items[2].bounds[0], 0.1);
}

test "justify_content space_evenly distributes with equal gaps" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const c1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).size(50, 40).into_element();
    const c2 = ui.div(alloc).bg(ui.Color.hex(0x00FF00)).size(50, 40).into_element();

    const row = ui.div(alloc).flex_row().justify(.space_evenly).child(c1).child(c2).into_element();
    _ = row.doLayout(ui.Constraints.tight(200, 100));
    row.paint(&px, .{ .x = 0, .y = 0, .w = 200, .h = 100 });

    // space_evenly: gap = (200-100)/3 = 33.33
    try testing.expectApproxEqAbs(@as(f32, 33.33), px.draw_list.quads.items[0].bounds[0], 0.5);
    try testing.expectApproxEqAbs(@as(f32, 116.67), px.draw_list.quads.items[1].bounds[0], 0.5);
}

test "auto-sized flex row shrink-wraps to children" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const c1 = ui.div(alloc).size(60, 30).into_element();
    const c2 = ui.div(alloc).size(80, 50).into_element();

    const row = ui.div(alloc).flex_row().gap(10).child(c1).child(c2).into_element();
    const sz = row.doLayout(.{ .max_w = std.math.inf(f32), .max_h = std.math.inf(f32) });

    // Width = 60 + 10 + 80 = 150, Height = max(30, 50) = 50
    try testing.expectApproxEqAbs(@as(f32, 150), sz.w, 0.1);
    try testing.expectApproxEqAbs(@as(f32, 50), sz.h, 0.1);
}

test "auto-sized flex column shrink-wraps to children" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const c1 = ui.div(alloc).size(60, 30).into_element();
    const c2 = ui.div(alloc).size(80, 50).into_element();

    const col = ui.div(alloc).flex_col().gap(5).child(c1).child(c2).into_element();
    const sz = col.doLayout(.{ .max_w = std.math.inf(f32), .max_h = std.math.inf(f32) });

    // Width = max(60, 80) = 80, Height = 30 + 5 + 50 = 85
    try testing.expectApproxEqAbs(@as(f32, 80), sz.w, 0.1);
    try testing.expectApproxEqAbs(@as(f32, 85), sz.h, 0.1);
}

test "flex_grow with gap distributes correctly" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const c1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).grow(1).into_element();
    const c2 = ui.div(alloc).bg(ui.Color.hex(0x00FF00)).grow(1).into_element();

    const row = ui.div(alloc).flex_row().gap(20).child(c1).child(c2).into_element();
    _ = row.doLayout(ui.Constraints.tight(200, 100));
    row.paint(&px, .{ .x = 0, .y = 0, .w = 200, .h = 100 });

    // Available = 200 - 0 - 20 = 180, each gets 90
    try testing.expectApproxEqAbs(@as(f32, 90), px.draw_list.quads.items[0].bounds[2], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 110), px.draw_list.quads.items[1].bounds[0], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 90), px.draw_list.quads.items[1].bounds[2], 0.1);
}

test "padding + flex layout" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const c1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).size(60, 40).into_element();
    const row = ui.div(alloc)
        .bg(ui.Color.hex(0x333333))
        .flex_row()
        .padding_all(20)
        .child(c1)
        .into_element();

    _ = row.doLayout(ui.Constraints.tight(400, 200));
    row.paint(&px, .{ .x = 0, .y = 0, .w = 400, .h = 200 });

    try testing.expectEqual(@as(usize, 2), px.draw_list.quads.items.len);
    try testing.expectApproxEqAbs(@as(f32, 20), px.draw_list.quads.items[1].bounds[0], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 20), px.draw_list.quads.items[1].bounds[1], 0.1);
}

test "nested flex containers" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    // Inner row with 2 items
    const b1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).size(40, 20).into_element();
    const b2 = ui.div(alloc).bg(ui.Color.hex(0x00FF00)).size(40, 20).into_element();
    const inner_row = ui.div(alloc).flex_row().gap(10).child(b1).child(b2).into_element();

    // Outer column
    const header = ui.div(alloc).bg(ui.Color.hex(0x0000FF)).size(200, 30).into_element();
    const outer = ui.div(alloc).flex_col().child(header).child(inner_row).into_element();

    _ = outer.doLayout(ui.Constraints.tight(200, 200));
    outer.paint(&px, .{ .x = 0, .y = 0, .w = 200, .h = 200 });

    // header at y=0, inner_row children at y=30
    try testing.expectEqual(@as(usize, 3), px.draw_list.quads.items.len);
    try testing.expectApproxEqAbs(@as(f32, 0), px.draw_list.quads.items[0].bounds[1], 0.1); // header y
    try testing.expectApproxEqAbs(@as(f32, 30), px.draw_list.quads.items[1].bounds[1], 0.1); // b1 y
    try testing.expectApproxEqAbs(@as(f32, 0), px.draw_list.quads.items[1].bounds[0], 0.1); // b1 x
    try testing.expectApproxEqAbs(@as(f32, 50), px.draw_list.quads.items[2].bounds[0], 0.1); // b2 x
    try testing.expectApproxEqAbs(@as(f32, 30), px.draw_list.quads.items[2].bounds[1], 0.1); // b2 y
}

test "flex_shrink shrinks children when overflowing" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    // Two 100px children in a 120px container → 80px overflow
    // Default flex_shrink=1, so each shrinks proportionally by size
    // Each has same size, so each shrinks by 40 → 60px each
    const c1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).width(100).into_element();
    const c2 = ui.div(alloc).bg(ui.Color.hex(0x00FF00)).width(100).into_element();

    const row = ui.div(alloc).flex_row().child(c1).child(c2).into_element();
    _ = row.doLayout(ui.Constraints.tight(120, 100));
    row.paint(&px, .{ .x = 0, .y = 0, .w = 120, .h = 100 });

    try testing.expectApproxEqAbs(@as(f32, 60), px.draw_list.quads.items[0].bounds[2], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 60), px.draw_list.quads.items[1].bounds[2], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 60), px.draw_list.quads.items[1].bounds[0], 0.1);
}

test "flex_shrink proportional to size" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    // 200px + 100px = 300px in 240px container → 60px overflow
    // shrink_basis: 200*1=200, 100*1=100, total=300
    // big shrinks by 60*(200/300) = 40 → 160px
    // small shrinks by 60*(100/300) = 20 → 80px
    const big = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).width(200).into_element();
    const small = ui.div(alloc).bg(ui.Color.hex(0x00FF00)).width(100).into_element();

    const row = ui.div(alloc).flex_row().child(big).child(small).into_element();
    _ = row.doLayout(ui.Constraints.tight(240, 100));
    row.paint(&px, .{ .x = 0, .y = 0, .w = 240, .h = 100 });

    try testing.expectApproxEqAbs(@as(f32, 160), px.draw_list.quads.items[0].bounds[2], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 80), px.draw_list.quads.items[1].bounds[2], 0.1);
}

test "flex_shrink with gap accounts for gap in overflow" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    // Two 100px children + 20px gap = 220px in 180px container → 40px overflow
    // Each shrinks by 20 → 80px each
    const c1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).width(100).into_element();
    const c2 = ui.div(alloc).bg(ui.Color.hex(0x00FF00)).width(100).into_element();

    const row = ui.div(alloc).flex_row().gap(20).child(c1).child(c2).into_element();
    _ = row.doLayout(ui.Constraints.tight(180, 100));
    row.paint(&px, .{ .x = 0, .y = 0, .w = 180, .h = 100 });

    try testing.expectApproxEqAbs(@as(f32, 80), px.draw_list.quads.items[0].bounds[2], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 80), px.draw_list.quads.items[1].bounds[2], 0.1);
    // Second child at 80 + 20 gap = 100
    try testing.expectApproxEqAbs(@as(f32, 100), px.draw_list.quads.items[1].bounds[0], 0.1);
}

// ── Re-measurement / Taffy-inspired tests ───────────────────────────

test "stretched flex_grow children get correct width after re-layout" {
    // Scenario: column parent (tight 400x300) with auto-width row child.
    // Row child has flex_grow children. Parent stretches row to 400.
    // After re-layout, flex_grow children should fill the 400px.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    // Row with two flex_grow children (no explicit width)
    const g1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).height(30).grow(1).into_element();
    const g2 = ui.div(alloc).bg(ui.Color.hex(0x00FF00)).height(30).grow(1).into_element();
    const row = ui.div(alloc).flex_row().child(g1).child(g2).into_element();

    // Column parent — default align_items is stretch → row stretched to 400
    const col = ui.div(alloc).flex_col().child(row).into_element();
    _ = col.doLayout(ui.Constraints.tight(400, 300));
    col.paint(&px, .{ .x = 0, .y = 0, .w = 400, .h = 300 });

    // Each flex_grow child should be 200px wide (400 / 2)
    try testing.expectApproxEqAbs(@as(f32, 200), px.draw_list.quads.items[0].bounds[2], 1.0);
    try testing.expectApproxEqAbs(@as(f32, 200), px.draw_list.quads.items[1].bounds[2], 1.0);
}

test "stretched flex_grow with gap after re-layout" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const g1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).height(30).grow(1).into_element();
    const g2 = ui.div(alloc).bg(ui.Color.hex(0x00FF00)).height(30).grow(2).into_element();
    const g3 = ui.div(alloc).bg(ui.Color.hex(0x0000FF)).height(30).grow(1).into_element();
    const row = ui.div(alloc).flex_row().gap(8).child(g1).child(g2).child(g3).into_element();

    const col = ui.div(alloc).flex_col().child(row).into_element();
    _ = col.doLayout(ui.Constraints.tight(400, 300));
    col.paint(&px, .{ .x = 0, .y = 0, .w = 400, .h = 300 });

    // Content = 400, gaps = 16, remaining = 384
    // grow(1:2:1) → 96, 192, 96
    try testing.expectApproxEqAbs(@as(f32, 96), px.draw_list.quads.items[0].bounds[2], 1.0);
    try testing.expectApproxEqAbs(@as(f32, 192), px.draw_list.quads.items[1].bounds[2], 1.0);
    try testing.expectApproxEqAbs(@as(f32, 96), px.draw_list.quads.items[2].bounds[2], 1.0);
}

test "padded parent stretches flex_grow row correctly" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const g1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).height(30).grow(1).into_element();
    const g2 = ui.div(alloc).bg(ui.Color.hex(0x00FF00)).height(30).grow(1).into_element();
    const row = ui.div(alloc).flex_row().child(g1).child(g2).into_element();

    const col = ui.div(alloc).flex_col().padding_all(20).child(row).into_element();
    _ = col.doLayout(ui.Constraints.tight(400, 300));
    col.paint(&px, .{ .x = 0, .y = 0, .w = 400, .h = 300 });

    // Content width = 400 - 40 = 360, each child = 180
    // Quads: parent bg (none), row bg (none), so just the 2 grow children
    try testing.expectApproxEqAbs(@as(f32, 180), px.draw_list.quads.items[0].bounds[2], 1.0);
    try testing.expectApproxEqAbs(@as(f32, 180), px.draw_list.quads.items[1].bounds[2], 1.0);
}

test "deeply nested flex_grow re-layout works" {
    // Root (col, 400x300) → section (col, auto, stretched) → row (auto, stretched)
    // → flex_grow children
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const g1 = ui.div(alloc).bg(ui.Color.hex(0xFF0000)).height(30).grow(1).into_element();
    const g2 = ui.div(alloc).bg(ui.Color.hex(0x00FF00)).height(30).grow(1).into_element();
    const row = ui.div(alloc).flex_row().child(g1).child(g2).into_element();

    const section = ui.div(alloc)
        .bg(ui.Color.hex(0x333333))
        .padding_all(10)
        .child(row)
        .into_element();

    const root = ui.div(alloc).flex_col().padding_all(10).child(section).into_element();
    _ = root.doLayout(ui.Constraints.tight(400, 300));
    root.paint(&px, .{ .x = 0, .y = 0, .w = 400, .h = 300 });

    // Root content = 380, section stretched to 380, section content = 360
    // row stretched to 360, each grow child = 180
    const q0 = px.draw_list.quads.items[0]; // section bg
    try testing.expectApproxEqAbs(@as(f32, 380), q0.bounds[2], 1.0);

    const q1 = px.draw_list.quads.items[1]; // g1
    const q2 = px.draw_list.quads.items[2]; // g2
    try testing.expectApproxEqAbs(@as(f32, 180), q1.bounds[2], 1.0);
    try testing.expectApproxEqAbs(@as(f32, 180), q2.bounds[2], 1.0);
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

// ── Phase 3: Text element tests ─────────────────────────────────────

/// Stub text measurer for testing — returns width = 7 * len, height = font_size.
fn stubMeasureFn(_: *anyopaque, txt: []const u8, font_size: f32, _: u8, _: f32) ui.TextMetrics {
    return .{
        .width = 7.0 * @as(f32, @floatFromInt(txt.len)),
        .height = font_size,
        .ascent = font_size * 0.8,
        .descent = font_size * 0.2,
    };
}

var stub_measurer_ctx: u8 = 0;
const stub_measurer = ui.TextMeasurer{
    .ctx = @ptrCast(&stub_measurer_ctx),
    .measure_fn = &stubMeasureFn,
};

test "Text element fluent API sets properties" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const t = ui.text(alloc, "Hello", stub_measurer)
        .font_size(18)
        .color(ui.Color.hex(0xFF0000))
        .font_weight(.bold);

    try testing.expectEqual(@as(f32, 18), t.font_size_val);
    try testing.expect(t.color_val.eql(ui.Color.hex(0xFF0000)));
    try testing.expectEqual(ui.FontWeight.bold, t.weight_val);
}

test "Text element layout returns measured size" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const el = ui.text(alloc, "Hello", stub_measurer)
        .font_size(14)
        .into_element();

    const sz = el.doLayout(ui.Constraints{ .max_w = 800, .max_h = 600 });
    // "Hello" = 5 chars, stub returns 7*5=35 wide, 14 high
    try testing.expectApproxEqAbs(@as(f32, 35), sz.w, 0.1);
    try testing.expectApproxEqAbs(@as(f32, 14), sz.h, 0.1);
}

test "Text element layout clamps to constraints" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const el = ui.text(alloc, "A very long string for testing", stub_measurer)
        .font_size(14)
        .into_element();

    // 30 chars * 7 = 210, but constrained to max_w=100
    const sz = el.doLayout(ui.Constraints{ .max_w = 100, .max_h = 600 });
    try testing.expect(sz.w <= 100);
}

test "Text element paint emits TextCmd" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const el = ui.text(alloc, "Hi", stub_measurer)
        .font_size(16)
        .color(ui.Color.hex(0x00FF00))
        .into_element();

    _ = el.doLayout(ui.Constraints{ .max_w = 800, .max_h = 600 });
    el.paint(&px, .{ .x = 10, .y = 20, .w = 100, .h = 16 });

    try testing.expectEqual(@as(usize, 1), px.draw_list.texts.items.len);
    const cmd = px.draw_list.texts.items[0];
    try testing.expectEqualStrings("Hi", cmd.text);
    try testing.expectApproxEqAbs(@as(f32, 10), cmd.bounds[0], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 20), cmd.bounds[1], 0.1);
    try testing.expectApproxEqAbs(@as(f32, 16), cmd.font_size, 0.1);
}

test "Text inside Div layout and paint" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var px = ui.PaintContext.init(testing.allocator);
    defer px.deinit();

    const label = ui.text(alloc, "Click", stub_measurer)
        .font_size(14)
        .color(ui.Color.hex(0xFFFFFF))
        .into_element();

    const btn = ui.div(alloc)
        .bg(ui.Color.hex(0x0000FF))
        .padding_all(8)
        .flex_row()
        .align_center()
        .justify_center()
        .child(label)
        .into_element();

    _ = btn.doLayout(ui.Constraints{ .max_w = 200, .max_h = 50 });
    btn.paint(&px, .{ .x = 0, .y = 0, .w = 200, .h = 50 });

    // Should have 1 quad (button bg) + 1 text
    try testing.expectEqual(@as(usize, 1), px.draw_list.quads.items.len);
    try testing.expectEqual(@as(usize, 1), px.draw_list.texts.items.len);
    try testing.expectEqualStrings("Click", px.draw_list.texts.items[0].text);
}

test "DrawList pushText and clear" {
    var dl = ui.DrawList{};
    defer dl.deinit(testing.allocator);

    dl.pushText(testing.allocator, .{
        .text = "test",
        .bounds = .{ 0, 0, 50, 14 },
        .color = .{ 1, 1, 1, 1 },
        .font_size = 14,
        .weight = 3,
    });
    try testing.expectEqual(@as(usize, 1), dl.texts.items.len);

    dl.clear();
    try testing.expectEqual(@as(usize, 0), dl.texts.items.len);
}
