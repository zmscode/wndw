// ── Text element ─────────────────────────────────────────────────────
//
// Platform-agnostic text element. Delegates measurement to a
// TextMeasurer (provided by the platform) and emits TextCmd during
// paint for the renderer to draw.

const std = @import("std");
const style_mod = @import("style.zig");
const layout_mod = @import("layout.zig");
const paint_mod = @import("render/paint.zig");
const element_mod = @import("element.zig");
const render_types = @import("render_types");

pub const Color = style_mod.Color;
pub const FontWeight = style_mod.FontWeight;
pub const Element = element_mod.Element;
pub const Constraints = layout_mod.Constraints;
pub const Size = layout_mod.Size;
pub const Rect = layout_mod.Rect;
pub const PaintContext = paint_mod.PaintContext;
pub const TextMeasurer = render_types.TextMeasurer;
pub const TextMetrics = render_types.TextMetrics;

pub const Text = struct {
    content: []const u8,
    font_size_val: f32 = 14,
    color_val: Color = Color.hex(0xFFFFFF),
    weight_val: FontWeight = .regular,
    measurer: TextMeasurer,
    arena: std.mem.Allocator,

    // Cached measurement from layout pass
    cached_metrics: TextMetrics = .{ .width = 0, .height = 0, .ascent = 0, .descent = 0 },

    // ── Fluent API ──────────────────────────────────────────────────

    pub fn font_size(self: *Text, s: f32) *Text {
        self.font_size_val = s;
        return self;
    }

    pub fn color(self: *Text, c: Color) *Text {
        self.color_val = c;
        return self;
    }

    pub fn font_weight(self: *Text, w: FontWeight) *Text {
        self.weight_val = w;
        return self;
    }

    // ── Convert to Element ──────────────────────────────────────────

    pub fn into_element(self: *Text) Element {
        return .{
            .vtable = &text_vtable,
            .data = @ptrCast(self),
        };
    }

    // ── Layout ──────────────────────────────────────────────────────

    fn doLayout(ptr: *anyopaque, constraints: Constraints) Size {
        const self: *Text = @ptrCast(@alignCast(ptr));
        const metrics = self.measurer.measure(
            self.content,
            self.font_size_val,
            @intFromEnum(self.weight_val),
            constraints.max_w,
        );
        self.cached_metrics = metrics;

        return .{
            .w = std.math.clamp(metrics.width, constraints.min_w, constraints.max_w),
            .h = std.math.clamp(metrics.height, constraints.min_h, constraints.max_h),
        };
    }

    // ── Paint ───────────────────────────────────────────────────────

    fn doPaint(ptr: *anyopaque, px: *PaintContext, bounds: Rect) void {
        const self: *Text = @ptrCast(@alignCast(ptr));
        const color_vec = self.color_val.toVec4();

        px.pushText(.{
            .text = self.content,
            .bounds = .{ bounds.x, bounds.y, bounds.w, bounds.h },
            .color = color_vec,
            .font_size = self.font_size_val,
            .weight = @intFromEnum(self.weight_val),
        });
    }
};

const text_vtable: Element.VTable = .{
    .layout_fn = &Text.doLayout,
    .paint_fn = &Text.doPaint,
};

/// Top-level constructor. Allocates a Text element in the given allocator.
pub fn text(alloc: std.mem.Allocator, content: []const u8, measurer: TextMeasurer) *Text {
    const t = alloc.create(Text) catch unreachable;
    t.* = .{
        .content = content,
        .measurer = measurer,
        .arena = alloc,
    };
    return t;
}
