// ── Interaction / Hit Testing ────────────────────────────────────────
//
// Hit boxes are registered during the paint phase. On mouse events,
// WindowContext walks the list back-to-front (painter's order) to find
// the topmost element under the cursor.
//
// Each hit box carries an optional callback context so the framework
// can dispatch click/hover events without the element tree being alive.

const std = @import("std");
const layout = @import("layout.zig");
const wndw = @import("wndw");

pub const Rect = layout.Rect;
pub const Cursor = wndw.Cursor;

/// Callback that takes a user-provided context pointer.
pub const Callback = struct {
    ctx: ?*anyopaque = null,
    func: ?*const fn (?*anyopaque) void = null,

    pub fn call(self: Callback) void {
        if (self.func) |f| f(self.ctx);
    }

    pub fn isSet(self: Callback) bool {
        return self.func != null;
    }
};

/// A hit box registered during paint. Stored in painter's order
/// (last = topmost).
pub const HitBox = struct {
    bounds: Rect,
    on_click: Callback = .{},
    on_mouse_enter: Callback = .{},
    on_mouse_leave: Callback = .{},
    cursor: ?Cursor = null,
};

/// Accumulates hit boxes during paint and dispatches mouse events.
pub const HitTestList = struct {
    boxes: std.ArrayListUnmanaged(HitBox) = .{},
    /// Index of the currently hovered hit box, or null.
    hovered: ?usize = null,
    /// Index of the hit box where a press started (for click matching).
    pressed: ?usize = null,

    pub fn clear(self: *HitTestList) void {
        self.boxes.clearRetainingCapacity();
    }

    pub fn push(self: *HitTestList, alloc: std.mem.Allocator, box: HitBox) void {
        self.boxes.append(alloc, box) catch unreachable;
    }

    /// Find the topmost hit box containing (x, y). Walks back-to-front.
    pub fn hitTest(self: *const HitTestList, x: f32, y: f32) ?usize {
        var idx: usize = self.boxes.items.len;
        while (idx > 0) {
            idx -= 1;
            if (self.boxes.items[idx].bounds.contains(x, y)) {
                return idx;
            }
        }
        return null;
    }

    /// Called on mouse move. Returns the cursor to set (null = default arrow).
    pub fn handleMouseMove(self: *HitTestList, x: f32, y: f32) ?Cursor {
        const new_hover = self.hitTest(x, y);
        const old_hover = self.hovered;

        if (new_hover != old_hover) {
            // Leave old
            if (old_hover) |old_idx| {
                if (old_idx < self.boxes.items.len) {
                    self.boxes.items[old_idx].on_mouse_leave.call();
                }
            }
            // Enter new
            if (new_hover) |new_idx| {
                self.boxes.items[new_idx].on_mouse_enter.call();
            }
            self.hovered = new_hover;
        }

        if (new_hover) |idx| {
            return self.boxes.items[idx].cursor;
        }
        return null;
    }

    /// Called on mouse press.
    pub fn handleMousePress(self: *HitTestList, x: f32, y: f32) void {
        self.pressed = self.hitTest(x, y);
    }

    /// Called on mouse release. Fires on_click if press and release
    /// are on the same hit box.
    pub fn handleMouseRelease(self: *HitTestList, x: f32, y: f32) void {
        const release_target = self.hitTest(x, y);
        if (self.pressed) |press_idx| {
            if (release_target == press_idx) {
                if (press_idx < self.boxes.items.len) {
                    self.boxes.items[press_idx].on_click.call();
                }
            }
        }
        self.pressed = null;
    }

    pub fn deinit(self: *HitTestList, alloc: std.mem.Allocator) void {
        self.boxes.deinit(alloc);
    }
};
