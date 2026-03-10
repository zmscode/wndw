// ── UI Framework — public API ────────────────────────────────────────
//
// Re-exports all UI types from a single import point.
// Usage: const ui = @import("ui");

pub const element = @import("element.zig");
pub const style = @import("style.zig");
pub const layout = @import("layout.zig");
pub const context = @import("context.zig");
pub const draw_list = @import("render/draw_list.zig");
pub const paint = @import("render/paint.zig");
pub const renderer = @import("render/native.zig");

// ── Convenience re-exports ──────────────────────────────────────────

pub const div = element.div;
pub const Div = element.Div;
pub const Element = element.Element;
pub const Color = style.Color;
pub const Style = style.Style;
pub const Len = style.Len;
pub const Edges = style.Edges;
pub const Rect = layout.Rect;
pub const Size = layout.Size;
pub const Constraints = layout.Constraints;
pub const ChildLayout = layout.ChildLayout;
pub const Align = style.Align;
pub const Justify = style.Justify;
pub const FlexDirection = style.FlexDirection;
pub const WindowContext = context.WindowContext;
pub const PaintContext = paint.PaintContext;
pub const DrawList = draw_list.DrawList;
pub const QuadCmd = draw_list.QuadCmd;
pub const Renderer = renderer.Renderer;
