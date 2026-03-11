// ── PaintContext ─────────────────────────────────────────────────────
//
// Accumulates draw commands during the paint phase of the element tree.
// Phase 1: no hit testing — just quad drawing.

const std = @import("std");
const draw_list_mod = @import("draw_list.zig");
const layout = @import("../layout.zig");

pub const DrawList = draw_list_mod.DrawList;
pub const QuadCmd = draw_list_mod.QuadCmd;
pub const TextCmd = draw_list_mod.TextCmd;

pub const PaintContext = struct {
    draw_list: DrawList = .{},
    clip_stack: std.ArrayListUnmanaged(layout.Rect) = .{},
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) PaintContext {
        return .{ .alloc = alloc };
    }

    pub fn pushQuad(self: *PaintContext, q: QuadCmd) void {
        var quad = q;
        // Auto-assign clip from current clip stack if quad has no explicit clip
        if (quad.clip_index < 0 and self.clip_stack.items.len > 0) {
            quad.clip_index = self.currentClipIndex();
        }
        self.draw_list.pushQuad(self.alloc, quad);
    }

    pub fn pushClip(self: *PaintContext, rect: layout.Rect) void {
        self.clip_stack.append(self.alloc, rect) catch unreachable;
    }

    pub fn popClip(self: *PaintContext) void {
        _ = self.clip_stack.pop();
    }

    pub fn currentClipIndex(self: *PaintContext) i32 {
        if (self.clip_stack.items.len == 0) return -1;
        const rect = self.clip_stack.items[self.clip_stack.items.len - 1];
        self.draw_list.pushClip(self.alloc, .{ .bounds = .{ rect.x, rect.y, rect.w, rect.h } });
        return @intCast(self.draw_list.clips.items.len - 1);
    }

    pub fn pushText(self: *PaintContext, t: TextCmd) void {
        var cmd = t;
        if (cmd.clip_index < 0 and self.clip_stack.items.len > 0) {
            cmd.clip_index = self.currentClipIndex();
        }
        self.draw_list.pushText(self.alloc, cmd);
    }

    pub fn deinit(self: *PaintContext) void {
        self.draw_list.deinit(self.alloc);
        self.clip_stack.deinit(self.alloc);
    }
};
