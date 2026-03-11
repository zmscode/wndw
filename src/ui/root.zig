// ── UI Framework — public API ────────────────────────────────────────
//
// Re-exports all UI types from a single import point.
// Usage: const ui = @import("ui");

pub const element = @import("element.zig");
pub const text_mod = @import("text.zig");
pub const style = @import("style.zig");
pub const layout = @import("layout.zig");
pub const context = @import("context.zig");
pub const interaction = @import("interaction.zig");
pub const entity_mod = @import("entity.zig");
pub const view_mod = @import("view.zig");
pub const theme_mod = @import("theme.zig");
pub const scroll_mod = @import("scroll.zig");
pub const animation_mod = @import("animation.zig");
pub const action_mod = @import("action.zig");
pub const draw_list = @import("render/draw_list.zig");
pub const paint = @import("render/paint.zig");
pub const renderer = @import("render/native.zig");
const render_types = @import("render_types");

// ── Convenience re-exports ──────────────────────────────────────────

pub const div = element.div;
pub const Div = element.Div;
pub const Element = element.Element;
pub const text = text_mod.text;
pub const Text = text_mod.Text;
pub const Color = style.Color;
pub const Style = style.Style;
pub const Len = style.Len;
pub const Edges = style.Edges;
pub const FontWeight = style.FontWeight;
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
pub const TextCmd = draw_list.TextCmd;
pub const TextMeasurer = render_types.TextMeasurer;
pub const TextMetrics = render_types.TextMetrics;
pub const Renderer = renderer.Renderer;
pub const Callback = interaction.Callback;
pub const HitBox = interaction.HitBox;
pub const HitTestList = interaction.HitTestList;
pub const Cursor = context.Cursor;
pub const EntityPool = entity_mod.EntityPool;
pub const EntityId = entity_mod.EntityId;
pub const Handle = entity_mod.Handle;
pub const View = view_mod.View;
pub const Theme = theme_mod.Theme;
pub const ScrollState = scroll_mod.ScrollState;
pub const Easing = animation_mod.Easing;
pub const Animation = animation_mod.Animation;
pub const KeyCombo = action_mod.KeyCombo;
pub const Modifiers = action_mod.Modifiers;
pub const KeybindingTable = action_mod.KeybindingTable;
