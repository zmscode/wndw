// ── Element tree ─────────────────────────────────────────────────────
//
// Element is the vtable interface for all UI primitives.
// Div is the universal container — supports bg, padding, size, children,
// corner radius, border, shadow, and flexbox layout via a fluent API.

const std = @import("std");
const style_mod = @import("style.zig");
const layout_mod = @import("layout.zig");
const paint_mod = @import("render/paint.zig");
const draw_list_mod = @import("render/draw_list.zig");

pub const Style = style_mod.Style;
pub const Color = style_mod.Color;
pub const Len = style_mod.Len;
pub const Edges = style_mod.Edges;
pub const Align = style_mod.Align;
pub const Justify = style_mod.Justify;
pub const FlexDirection = style_mod.FlexDirection;
pub const Size = layout_mod.Size;
pub const Rect = layout_mod.Rect;
pub const Constraints = layout_mod.Constraints;
pub const ChildLayout = layout_mod.ChildLayout;
pub const PaintContext = paint_mod.PaintContext;
pub const QuadCmd = draw_list_mod.QuadCmd;

// ── Element vtable ──────────────────────────────────────────────────

pub const Element = struct {
    vtable: *const VTable,
    data: *anyopaque,
    /// Flex grow factor — how much of remaining main-axis space this element claims.
    flex_grow: f32 = 0,
    /// Flex shrink factor — how much this element shrinks when overflowing.
    flex_shrink: f32 = 1,
    /// Per-element cross-axis alignment override.
    align_self: ?Align = null,

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
    child_layouts: std.ArrayListUnmanaged(ChildLayout) = .{},
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

    pub fn grow(self: *Div, g: f32) *Div {
        self.sty.flex_grow = g;
        return self;
    }

    pub fn shrink(self: *Div, s: f32) *Div {
        self.sty.flex_shrink = s;
        return self;
    }

    pub fn align_items(self: *Div, a: Align) *Div {
        self.sty.align_items = a;
        return self;
    }

    pub fn align_center(self: *Div) *Div {
        self.sty.align_items = .center;
        return self;
    }

    pub fn align_self(self: *Div, a: Align) *Div {
        self.sty.align_self = a;
        return self;
    }

    pub fn justify(self: *Div, j: Justify) *Div {
        self.sty.justify_content = j;
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
        return .{
            .vtable = &div_vtable,
            .data = @ptrCast(self),
            .flex_grow = self.sty.flex_grow,
            .flex_shrink = self.sty.flex_shrink,
            .align_self = self.sty.align_self,
        };
    }

    // ── Flexbox Layout ──────────────────────────────────────────────

    fn doLayout(ptr: *anyopaque, constraints: Constraints) Size {
        const self: *Div = @ptrCast(@alignCast(ptr));
        const s = &self.sty;
        const n = self.children_list.items.len;
        const is_row = s.direction == .row or s.direction == .row_reverse;

        // ── 1. Resolve own size ─────────────────────────────────────
        // For auto-sized dimensions, we'll compute content-based size
        // after measuring children. Use constraint max as initial bound.
        const auto_w = s.width == .auto;
        const auto_h = s.height == .auto;

        var w: f32 = switch (s.width) {
            .px => |px| px,
            .percent => |p| constraints.max_w * p,
            .auto => if (constraints.max_w == std.math.inf(f32)) 0 else constraints.max_w,
        };
        var h: f32 = switch (s.height) {
            .px => |px| px,
            .percent => |p| constraints.max_h * p,
            .auto => if (constraints.max_h == std.math.inf(f32)) 0 else constraints.max_h,
        };

        w = std.math.clamp(w, constraints.min_w, constraints.max_w);
        h = std.math.clamp(h, constraints.min_h, constraints.max_h);

        // ── 2. Content area after padding ───────────────────────────
        const pad_h = s.padding.horizontal();
        const pad_v = s.padding.vertical();
        const content_w = @max(w - pad_h, 0);
        const content_h = @max(h - pad_v, 0);

        // ── 3. First pass: measure each child ───────────────────────
        // Main axis: unbounded (let children report natural size)
        // Cross axis: bounded to content area
        self.child_layouts.clearRetainingCapacity();

        var total_main: f32 = 0;
        var max_cross: f32 = 0;
        var total_grow: f32 = 0;

        // Temporary storage for natural child sizes
        const child_sizes = self.arena.alloc(Size, n) catch unreachable;

        for (self.children_list.items, 0..) |ch, i| {
            // Main axis: unbounded (measure natural size).
            // Cross axis: use content area, or inf if auto-sized (shrink-wrap).
            const cross_max = if (is_row)
                (if (auto_h) std.math.inf(f32) else content_h)
            else
                (if (auto_w) std.math.inf(f32) else content_w);
            const child_c = if (is_row)
                Constraints{ .max_w = std.math.inf(f32), .max_h = cross_max }
            else
                Constraints{ .max_w = cross_max, .max_h = std.math.inf(f32) };

            var sz = ch.doLayout(child_c);
            // Clamp infinite sizes to 0 (auto-sized childless elements)
            if (sz.w == std.math.inf(f32)) sz.w = 0;
            if (sz.h == std.math.inf(f32)) sz.h = 0;

            child_sizes[i] = sz;
            if (is_row) {
                total_main += sz.w;
                max_cross = @max(max_cross, sz.h);
            } else {
                total_main += sz.h;
                max_cross = @max(max_cross, sz.w);
            }
            total_grow += ch.flex_grow;
        }

        // ── 4. Gap total ────────────────────────────────────────────
        const n_gaps: f32 = if (n > 1) @floatFromInt(n - 1) else 0;
        const gap_total = s.gap * n_gaps;

        // ── 5. Shrink-wrap auto-sized dimensions ────────────────────
        if (auto_w and n > 0) {
            if (is_row) {
                w = total_main + gap_total + pad_h;
            } else {
                w = max_cross + pad_h;
            }
            w = std.math.clamp(w, constraints.min_w, constraints.max_w);
        }
        if (auto_h and n > 0) {
            if (is_row) {
                h = max_cross + pad_v;
            } else {
                h = total_main + gap_total + pad_v;
            }
            h = std.math.clamp(h, constraints.min_h, constraints.max_h);
        }

        // Recompute content area after auto-sizing
        const final_content_main = if (is_row) @max(w - pad_h, 0) else @max(h - pad_v, 0);
        const final_content_cross = if (is_row) @max(h - pad_v, 0) else @max(w - pad_h, 0);

        // ── 6. flex_grow / flex_shrink distribution ────────────────
        const available = final_content_main - total_main - gap_total;
        if (available > 0 and total_grow > 0) {
            // Positive space → distribute to flex_grow children
            for (self.children_list.items, 0..) |ch, i| {
                if (ch.flex_grow > 0) {
                    const extra = available * (ch.flex_grow / total_grow);
                    if (is_row) {
                        child_sizes[i].w += extra;
                    } else {
                        child_sizes[i].h += extra;
                    }
                }
            }
        } else if (available < 0) {
            // Overflow → shrink children proportional to flex_shrink * size
            const deficit = -available;
            var total_shrink_basis: f32 = 0;
            for (self.children_list.items, 0..) |ch, i| {
                const child_main_sz = if (is_row) child_sizes[i].w else child_sizes[i].h;
                total_shrink_basis += ch.flex_shrink * child_main_sz;
            }
            if (total_shrink_basis > 0) {
                for (self.children_list.items, 0..) |ch, i| {
                    const child_main_sz = if (is_row) child_sizes[i].w else child_sizes[i].h;
                    const shrink_amount = deficit * (ch.flex_shrink * child_main_sz) / total_shrink_basis;
                    if (is_row) {
                        child_sizes[i].w = @max(child_sizes[i].w - shrink_amount, 0);
                    } else {
                        child_sizes[i].h = @max(child_sizes[i].h - shrink_amount, 0);
                    }
                }
            }
        }

        // ── 7. justify_content — compute main-axis start & spacing ─
        var main_offset: f32 = 0;
        var main_spacing: f32 = s.gap; // default gap between items

        const used_main = blk: {
            var sum: f32 = 0;
            for (child_sizes[0..n]) |sz| {
                sum += if (is_row) sz.w else sz.h;
            }
            break :blk sum;
        };
        const free_main = @max(final_content_main - used_main - gap_total, 0);

        switch (s.justify_content) {
            .start => {},
            .end => {
                main_offset = free_main;
            },
            .center => {
                main_offset = free_main / 2;
            },
            .space_between => {
                if (n > 1) {
                    main_spacing = (final_content_main - used_main) / @as(f32, @floatFromInt(n - 1));
                }
            },
            .space_around => {
                if (n > 0) {
                    const space = (final_content_main - used_main) / @as(f32, @floatFromInt(n));
                    main_offset = space / 2;
                    main_spacing = space;
                }
            },
            .space_evenly => {
                if (n > 0) {
                    const space = (final_content_main - used_main) / @as(f32, @floatFromInt(n + 1));
                    main_offset = space;
                    main_spacing = space;
                }
            },
        }

        // ── 8. Position children ────────────────────────────────────
        var cursor: f32 = main_offset;

        for (self.children_list.items, 0..) |ch, i| {
            const csz = child_sizes[i];
            var child_main = if (is_row) csz.w else csz.h;
            const child_cross = if (is_row) csz.h else csz.w;

            // Cross-axis alignment
            const alignment = ch.align_self orelse s.align_items;
            var cross_size = child_cross;
            var cross_offset: f32 = 0;

            switch (alignment) {
                .start => {},
                .end => {
                    cross_offset = final_content_cross - child_cross;
                },
                .center => {
                    cross_offset = (final_content_cross - child_cross) / 2;
                },
                .stretch => {
                    cross_size = final_content_cross;
                },
            }

            // Re-layout child if its final size differs from measured size.
            // This handles: stretch making cross-axis larger, flex_grow making
            // main-axis larger. The child's internal layout (e.g. its own
            // flex_grow children) needs the resolved size to distribute space.
            const final_w = if (is_row) child_main else cross_size;
            const final_h = if (is_row) cross_size else child_main;
            const measured_w = csz.w;
            const measured_h = csz.h;
            if (@abs(final_w - measured_w) > 0.5 or @abs(final_h - measured_h) > 0.5) {
                const resized = ch.doLayout(Constraints.tight(final_w, final_h));
                // Update main/cross from re-layout result
                child_main = if (is_row) resized.w else resized.h;
                cross_size = if (is_row) resized.h else resized.w;
            }

            const cl = if (is_row) ChildLayout{
                .x = cursor,
                .y = cross_offset,
                .w = child_main,
                .h = cross_size,
            } else ChildLayout{
                .x = cross_offset,
                .y = cursor,
                .w = cross_size,
                .h = child_main,
            };

            self.child_layouts.append(self.arena, cl) catch unreachable;
            cursor += child_main + main_spacing;
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

        // Paint children using positions computed during layout
        const content = bounds.inset(s.padding);

        // Clip children to content area so they don't overflow
        px.pushClip(content);

        for (self.children_list.items, 0..) |ch, i| {
            const cl = if (i < self.child_layouts.items.len)
                self.child_layouts.items[i]
            else
                ChildLayout{ .x = 0, .y = 0, .w = content.w, .h = content.h };

            ch.paint(px, .{
                .x = content.x + cl.x,
                .y = content.y + cl.y,
                .w = cl.w,
                .h = cl.h,
            });
        }

        px.popClip();
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
