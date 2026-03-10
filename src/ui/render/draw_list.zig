// ── Draw command buffer ──────────────────────────────────────────────
//
// Backend-agnostic draw commands accumulated during the paint phase.
// The renderer (native CG or GL) consumes these each frame.
//
// QuadCmd/ClipCmd are defined in the "render_types" module (shared
// between UI and platform renderer to avoid circular deps).

const std = @import("std");
const types = @import("render_types");

pub const QuadCmd = types.QuadCmd;
pub const ClipCmd = types.ClipCmd;

pub const DrawList = struct {
    quads: std.ArrayListUnmanaged(QuadCmd) = .{},
    clips: std.ArrayListUnmanaged(ClipCmd) = .{},

    pub fn pushQuad(self: *DrawList, alloc: std.mem.Allocator, q: QuadCmd) void {
        self.quads.append(alloc, q) catch unreachable;
    }

    pub fn pushClip(self: *DrawList, alloc: std.mem.Allocator, c: ClipCmd) void {
        self.clips.append(alloc, c) catch unreachable;
    }

    pub fn clear(self: *DrawList) void {
        self.quads.clearRetainingCapacity();
        self.clips.clearRetainingCapacity();
    }

    pub fn deinit(self: *DrawList, alloc: std.mem.Allocator) void {
        self.quads.deinit(alloc);
        self.clips.deinit(alloc);
    }
};
