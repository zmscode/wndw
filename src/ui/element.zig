// ── Element tree ─────────────────────────────────────────────────────
//
// Element is the vtable interface for all UI primitives.
// Div is the universal container — supports bg, padding, size, children,
// corner radius, border, and shadow via a fluent API.

const std = @import("std");
const style_mod = @import("style.zig");
const layout_mod = @import("layout.zig");
const paint_mod = @import("render/paint.zig");
const draw_list_mod = @import("render/draw_list.zig");

pub const Style = style_mod.Style;
pub const Color = style_mod.Color;
pub const Len = style_mod.Len;
pub const Edges = style_mod.Edges;
pub const Size = layout_mod.Size;
pub const Rect = layout_mod.Rect;
pub const Constraints = layout_mod.Constraints;
pub const PaintContext = paint_mod.PaintContext;
pub const QuadCmd = draw_list_mod.QuadCmd;

// ── Element vtable ──────────────────────────────────────────────────

pub const Element = struct {
    vtable: *const VTable,
    data: *anyopaque,

    pub const VTable = struct {
        layout_fn: *const fn (*anyopaque, Constraints) Size,
        paint_fn: *const fn (*anyopaque, *PaintContext, Rect) void,
    };

    pub fn doLayout(self: Element, constraints: Constraints) Size {
        return self.vtable.layout_fn(self.data, constraints);
    }

    pub fn paint(self: Element, px: *PaintContext, bounds: Rect) void {
        self.vtable.paint_fn(self.data, px, bounds);
    }
};

// ── Div ─────────────────────────────────────────────────────────────

pub const Div = struct {
    sty: Style = .{},
    children_list: std.ArrayListUnmanaged(Element) = .{},
    child_sizes: std.ArrayListUnmanaged(Size) = .{},
    arena: std.mem.Allocator,

    // ── Fluent style methods ────────────────────────────────────────

    pub fn bg(self: *Div, color: Color) *Div {
        self.sty.background = color;
        return self;
    }

    pub fn corner_radius(self: *Div, r: f32) *Div {
        self.sty.corner_radius = .{ r, r, r, r };
        return self;
    }

    pub fn corner_radii(self: *Div, tl: f32, tr: f32, br: f32, bl: f32) *Div {
        self.sty.corner_radius = .{ tl, tr, br, bl };
        return self;
    }

    pub fn padding_all(self: *Div, p: f32) *Div {
        self.sty.padding = Edges.all(p);
        return self;
    }

    pub fn padding_xy(self: *Div, x: f32, y: f32) *Div {
        self.sty.padding = Edges.xy(x, y);
        return self;
    }

    pub fn size(self: *Div, w: f32, h: f32) *Div {
        self.sty.width = .{ .px = w };
        self.sty.height = .{ .px = h };
        return self;
    }

    pub fn width(self: *Div, w: f32) *Div {
        self.sty.width = .{ .px = w };
        return self;
    }

    pub fn height(self: *Div, h: f32) *Div {
        self.sty.height = .{ .px = h };
        return self;
    }

    pub fn border(self: *Div, w: f32, color: Color) *Div {
        self.sty.border_width = w;
        self.sty.border_color = color;
        return self;
    }

    pub fn shadow(self: *Div, blur: f32, color: Color) *Div {
        self.sty.shadow_blur = blur;
        self.sty.shadow_color = color;
        return self;
    }

    pub fn shadow_offset(self: *Div, ox: f32, oy: f32) *Div {
        self.sty.shadow_offset = .{ ox, oy };
        return self;
    }

    pub fn flex_row(self: *Div) *Div {
        self.sty.direction = .row;
        return self;
    }

    pub fn flex_col(self: *Div) *Div {
        self.sty.direction = .column;
        return self;
    }

    pub fn gap(self: *Div, g: f32) *Div {
        self.sty.gap = g;
        return self;
    }

    pub fn align_center(self: *Div) *Div {
        self.sty.align_items = .center;
        return self;
    }

    pub fn justify_center(self: *Div) *Div {
        self.sty.justify_content = .center;
        return self;
    }

    pub fn opacity(self: *Div, o: f32) *Div {
        self.sty.opacity = o;
        return self;
    }

    // ── Children ────────────────────────────────────────────────────

    pub fn child(self: *Div, el: Element) *Div {
        self.children_list.append(self.arena, el) catch unreachable;
        return self;
    }

    pub fn children(self: *Div, els: []const Element) *Div {
        self.children_list.appendSlice(self.arena, els) catch unreachable;
        return self;
    }

    // ── Convert to Element ──────────────────────────────────────────

    pub fn into_element(self: *Div) Element {
        return .{ .vtable = &div_vtable, .data = @ptrCast(self) };
    }

    // ── Layout (Phase 1: use explicit size or fill constraints) ─────

    fn doLayout(ptr: *anyopaque, constraints: Constraints) Size {
        const self: *Div = @ptrCast(@alignCast(ptr));
        const s = &self.sty;

        // Resolve own size
        var w: f32 = switch (s.width) {
            .px => |px| px,
            .auto => constraints.max_w,
            .percent => |p| constraints.max_w * p,
        };
        var h: f32 = switch (s.height) {
            .px => |px| px,
            .auto => constraints.max_h,
            .percent => |p| constraints.max_h * p,
        };

        w = std.math.clamp(w, constraints.min_w, constraints.max_w);
        h = std.math.clamp(h, constraints.min_h, constraints.max_h);

        // Layout children with remaining space after padding
        const inner_w = @max(w - s.padding.horizontal(), 0);
        const inner_h = @max(h - s.padding.vertical(), 0);
        const child_constraints = Constraints{
            .max_w = inner_w,
            .max_h = inner_h,
        };

        self.child_sizes.clearRetainingCapacity();
        for (self.children_list.items) |ch| {
            const sz = ch.doLayout(child_constraints);
            self.child_sizes.append(self.arena, sz) catch unreachable;
        }

        return .{ .w = w, .h = h };
    }

    // ── Paint ───────────────────────────────────────────────────────

    fn doPaint(ptr: *anyopaque, px: *PaintContext, bounds: Rect) void {
        const self: *Div = @ptrCast(@alignCast(ptr));
        const s = &self.sty;

        // Emit quad for this div's background/border/shadow
        if (s.background != null or s.border_width > 0 or s.shadow_blur > 0) {
            const bg_vec = if (s.background) |c| c.toVec4() else [4]f32{ 0, 0, 0, 0 };
            const border_vec = if (s.border_color) |c| c.toVec4() else [4]f32{ 0, 0, 0, 0 };
            const shadow_vec = if (s.shadow_color) |c| c.toVec4() else [4]f32{ 0, 0, 0, 0 };

            px.pushQuad(.{
                .bounds = .{ bounds.x, bounds.y, bounds.w, bounds.h },
                .bg = bg_vec,
                .border_color = border_vec,
                .border_width = s.border_width,
                .corner_radii = s.corner_radius,
                .shadow_color = shadow_vec,
                .shadow_blur = s.shadow_blur,
                .shadow_offset = s.shadow_offset,
            });
        }

        // Paint children into the padded content area
        const content = bounds.inset(s.padding);
        var offset_y: f32 = 0;
        var offset_x: f32 = 0;

        for (self.children_list.items, 0..) |ch, i| {
            const csz = if (i < self.child_sizes.items.len)
                self.child_sizes.items[i]
            else
                Size{ .w = content.w, .h = content.h };

            const child_bounds = Rect{
                .x = content.x + offset_x,
                .y = content.y + offset_y,
                .w = csz.w,
                .h = csz.h,
            };
            ch.paint(px, child_bounds);

            // Advance offset by the child's actual size
            switch (s.direction) {
                .column, .column_reverse => {
                    offset_y += csz.h + s.gap;
                },
                .row, .row_reverse => {
                    offset_x += csz.w + s.gap;
                },
            }
        }
    }
};

const div_vtable: Element.VTable = .{
    .layout_fn = &Div.doLayout,
    .paint_fn = &Div.doPaint,
};

/// Top-level constructor. Allocates a Div in the given allocator (frame arena).
pub fn div(alloc: std.mem.Allocator) *Div {
    const d = alloc.create(Div) catch unreachable;
    d.* = .{ .arena = alloc };
    return d;
}
