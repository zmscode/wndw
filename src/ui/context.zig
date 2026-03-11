// ── WindowContext ────────────────────────────────────────────────────
//
// Central coordinator for the UI framework. Owns the frame arena,
// paint context, and renderer. Passed to all UI code.

const std = @import("std");
const element_mod = @import("element.zig");
const paint_mod = @import("render/paint.zig");
const renderer_mod = @import("render/native.zig");
const render_types = @import("render_types");

pub const Element = element_mod.Element;
pub const Div = element_mod.Div;
pub const PaintContext = paint_mod.PaintContext;
pub const Renderer = renderer_mod.Renderer;
pub const Constraints = element_mod.Constraints;
pub const Rect = element_mod.Rect;
pub const Size = element_mod.Size;
pub const TextMeasurer = render_types.TextMeasurer;

/// A type-erased render function: given an allocator (frame arena),
/// returns the root Element for this frame.
pub const RenderFn = *const fn (std.mem.Allocator) Element;

pub const WindowContext = struct {
    gpa: std.mem.Allocator,
    frame_arena: std.heap.ArenaAllocator,
    paint_cx: PaintContext,
    renderer: Renderer,
    needs_render: bool = true,
    root_render_fn: ?RenderFn = null,

    // Cached window dimensions (set before render)
    view_width: f32 = 800,
    view_height: f32 = 600,

    pub fn init(gpa: std.mem.Allocator) WindowContext {
        return .{
            .gpa = gpa,
            .frame_arena = std.heap.ArenaAllocator.init(gpa),
            .paint_cx = PaintContext.init(gpa),
            .renderer = Renderer.init(gpa),
        };
    }

    pub fn deinit(self: *WindowContext) void {
        self.frame_arena.deinit();
        self.paint_cx.deinit();
        self.renderer.deinit();
    }

    pub fn frameAlloc(self: *WindowContext) std.mem.Allocator {
        return self.frame_arena.allocator();
    }

    pub fn resetFrame(self: *WindowContext) void {
        _ = self.frame_arena.reset(.retain_capacity);
    }

    pub fn setRootRenderFn(self: *WindowContext, f: RenderFn) void {
        self.root_render_fn = f;
        self.needs_render = true;
    }

    pub fn setViewSize(self: *WindowContext, w: f32, h: f32) void {
        if (self.view_width != w or self.view_height != h) {
            self.view_width = w;
            self.view_height = h;
            self.needs_render = true;
        }
    }

    /// Build element tree, layout, and paint into the draw list.
    pub fn render(self: *WindowContext) void {
        const render_fn = self.root_render_fn orelse return;

        // Build element tree in frame arena
        const root = render_fn(self.frameAlloc());

        // Layout pass
        const constraints = Constraints.tight(self.view_width, self.view_height);
        _ = root.doLayout(constraints);

        // Paint pass — clear old commands first
        self.paint_cx.draw_list.clear();
        root.paint(&self.paint_cx, .{
            .x = 0,
            .y = 0,
            .w = self.view_width,
            .h = self.view_height,
        });

        self.needs_render = false;
    }

    /// Get the text measurer from the platform renderer.
    pub fn textMeasurer(self: *WindowContext) TextMeasurer {
        return self.renderer.textMeasurer();
    }

    /// Flush draw commands to the native renderer.
    pub fn flush(self: *WindowContext) void {
        self.renderer.flush(
            self.paint_cx.draw_list.quads.items,
            self.paint_cx.draw_list.clips.items,
            self.paint_cx.draw_list.texts.items,
            @floatCast(self.view_height),
        );
    }
};
