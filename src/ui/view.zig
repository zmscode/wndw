// ── View ─────────────────────────────────────────────────────────────
//
// A View wraps a Handle(T) and delegates rendering to the model's
// `render` method. When the entity is updated, the view's dirty flag
// is set, triggering a re-render on the next frame.
//
// Any struct with `pub fn render(self: *const T, alloc, measurer) Element`
// can be used as a View model.

const std = @import("std");
const entity_mod = @import("entity.zig");
const element_mod = @import("element.zig");
const render_types = @import("render_types");

pub const EntityPool = entity_mod.EntityPool;
pub const EntityId = entity_mod.EntityId;
pub const Element = element_mod.Element;
pub const TextMeasurer = render_types.TextMeasurer;

pub fn View(comptime T: type) type {
    return struct {
        handle: entity_mod.Handle(T),
        dirty_flag: ?*bool = null,

        const Self = @This();

        pub fn init(handle: entity_mod.Handle(T)) Self {
            return .{ .handle = handle };
        }

        /// Render the view by reading the model and calling its render method.
        pub fn render(self: Self, pool: *const EntityPool, alloc: std.mem.Allocator, measurer: TextMeasurer) Element {
            const model = self.handle.read(pool);
            return model.render(alloc, measurer);
        }

        /// Subscribe this view to its entity. When the entity is updated,
        /// the dirty flag is set to true, signaling the framework to re-render.
        pub fn subscribe(self: *Self, pool: *EntityPool, dirty_flag: *bool) void {
            self.dirty_flag = dirty_flag;
            pool.observe(self.handle.id, @ptrCast(dirty_flag), &setDirty);
        }

        fn setDirty(ctx: ?*anyopaque) void {
            const flag: *bool = @ptrCast(@alignCast(ctx.?));
            flag.* = true;
        }
    };
}
