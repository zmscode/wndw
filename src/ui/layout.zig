// ── Layout primitives ────────────────────────────────────────────────
//
// Rect, Constraints, Size — used by layout and paint phases.
// Phase 1: hardcoded absolute positions only (no flexbox yet).

const std = @import("std");
const style = @import("style.zig");

pub const Size = struct {
    w: f32,
    h: f32,
};

pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    pub fn contains(self: Rect, px: f32, py: f32) bool {
        return px >= self.x and px < self.x + self.w and
            py >= self.y and py < self.y + self.h;
    }

    pub fn inset(self: Rect, edges: style.Edges) Rect {
        return .{
            .x = self.x + edges.left,
            .y = self.y + edges.top,
            .w = @max(self.w - edges.left - edges.right, 0),
            .h = @max(self.h - edges.top - edges.bottom, 0),
        };
    }
};

/// Computed position and size of a child element within its parent's content area.
pub const ChildLayout = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

pub const Constraints = struct {
    min_w: f32 = 0,
    min_h: f32 = 0,
    max_w: f32 = std.math.inf(f32),
    max_h: f32 = std.math.inf(f32),

    pub fn tight(w: f32, h: f32) Constraints {
        return .{ .min_w = w, .min_h = h, .max_w = w, .max_h = h };
    }

    pub fn clamp(self: Constraints, size: Size) Size {
        return .{
            .w = std.math.clamp(size.w, self.min_w, self.max_w),
            .h = std.math.clamp(size.h, self.min_h, self.max_h),
        };
    }
};
