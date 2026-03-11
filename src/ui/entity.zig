// ── Entity Pool (generational slab) ─────────────────────────────────
//
// Type-erased storage for retained state. Entities are addressed by
// (index, generation) pairs — destroyed slots are recycled, and stale
// handles are caught by generation mismatch.
//
// Subscriptions: observers can register callbacks on an entity ID.
// When an entity is updated via Handle.update(), all observers fire.

const std = @import("std");

// ── EntityId ────────────────────────────────────────────────────────

pub const EntityId = struct {
    index: u32,
    generation: u32,
};

// ── Handle(T) ───────────────────────────────────────────────────────

pub fn Handle(comptime T: type) type {
    return struct {
        id: EntityId,

        const Self = @This();

        /// Read the entity value. Asserts the handle is still valid.
        pub fn read(self: Self, pool: *const EntityPool) *const T {
            const slot = pool.slots.items[self.id.index];
            std.debug.assert(slot.alive and slot.generation == self.id.generation);
            return @ptrCast(@alignCast(slot.data));
        }

        /// Replace the entity value and notify all observers.
        pub fn update(self: Self, pool: *EntityPool, value: T) void {
            const slot = pool.slots.items[self.id.index];
            std.debug.assert(slot.alive and slot.generation == self.id.generation);
            const ptr: *T = @ptrCast(@alignCast(slot.data));
            ptr.* = value;
            pool.notifySubscribers(self.id);
        }
    };
}

// ── Callback ────────────────────────────────────────────────────────

const Callback = struct {
    ctx: ?*anyopaque = null,
    func: ?*const fn (?*anyopaque) void = null,

    fn call(self: Callback) void {
        if (self.func) |f| f(self.ctx);
    }
};

// ── Subscription ────────────────────────────────────────────────────

const Subscription = struct {
    entity_index: u32,
    cb: Callback,
};

// ── EntityPool ──────────────────────────────────────────────────────

pub const EntityPool = struct {
    const DestroyFn = *const fn (std.mem.Allocator, [*]u8) void;

    const Slot = struct {
        data: [*]u8,
        generation: u32,
        alive: bool,
        destroy_fn: ?DestroyFn,
    };

    slots: std.ArrayListUnmanaged(Slot) = .{},
    free_list: std.ArrayListUnmanaged(u32) = .{},
    subscriptions: std.ArrayListUnmanaged(Subscription) = .{},
    gpa: std.mem.Allocator,

    pub fn init(gpa: std.mem.Allocator) EntityPool {
        return .{ .gpa = gpa };
    }

    pub fn deinit(self: *EntityPool) void {
        for (self.slots.items) |slot| {
            if (slot.alive) {
                if (slot.destroy_fn) |dfn| dfn(self.gpa, slot.data);
            }
        }
        self.slots.deinit(self.gpa);
        self.free_list.deinit(self.gpa);
        self.subscriptions.deinit(self.gpa);
    }

    fn makeDestroyFn(comptime T: type) DestroyFn {
        return &struct {
            fn destroy(gpa: std.mem.Allocator, raw: [*]u8) void {
                const ptr: *T = @ptrCast(@alignCast(raw));
                gpa.destroy(ptr);
            }
        }.destroy;
    }

    /// Create a new entity with the given value. Returns a typed Handle.
    pub fn create(self: *EntityPool, comptime T: type, value: T) Handle(T) {
        const ptr = self.gpa.create(T) catch unreachable;
        ptr.* = value;

        const idx: u32 = if (self.free_list.items.len > 0)
            self.free_list.pop().?
        else blk: {
            self.slots.append(self.gpa, .{
                .data = undefined,
                .generation = 0,
                .alive = false,
                .destroy_fn = null,
            }) catch unreachable;
            break :blk @intCast(self.slots.items.len - 1);
        };

        var slot = &self.slots.items[idx];
        slot.data = @ptrCast(ptr);
        slot.generation +%= 1;
        slot.alive = true;
        slot.destroy_fn = makeDestroyFn(T);

        return .{ .id = .{ .index = idx, .generation = slot.generation } };
    }

    /// Destroy an entity. Frees its storage and recycles the slot.
    pub fn destroy(self: *EntityPool, id: EntityId) void {
        var slot = &self.slots.items[id.index];
        std.debug.assert(slot.alive and slot.generation == id.generation);

        if (slot.destroy_fn) |dfn| dfn(self.gpa, slot.data);
        slot.alive = false;

        // Remove subscriptions for this entity
        var i: usize = 0;
        while (i < self.subscriptions.items.len) {
            if (self.subscriptions.items[i].entity_index == id.index) {
                _ = self.subscriptions.swapRemove(i);
            } else {
                i += 1;
            }
        }

        self.free_list.append(self.gpa, id.index) catch unreachable;
    }

    /// Check if an entity ID refers to a live entity with matching generation.
    pub fn isAlive(self: *const EntityPool, id: EntityId) bool {
        if (id.index >= self.slots.items.len) return false;
        const slot = self.slots.items[id.index];
        return slot.alive and slot.generation == id.generation;
    }

    /// Register a callback that fires whenever the entity is updated.
    pub fn observe(self: *EntityPool, id: EntityId, ctx: ?*anyopaque, func: *const fn (?*anyopaque) void) void {
        self.subscriptions.append(self.gpa, .{
            .entity_index = id.index,
            .cb = .{ .ctx = ctx, .func = func },
        }) catch unreachable;
    }

    /// Fire all observers registered for this entity.
    fn notifySubscribers(self: *EntityPool, id: EntityId) void {
        for (self.subscriptions.items) |sub| {
            if (sub.entity_index == id.index) {
                sub.cb.call();
            }
        }
    }

    /// Return the number of active subscriptions for an entity.
    pub fn subscriberCount(self: *const EntityPool, id: EntityId) usize {
        var count: usize = 0;
        for (self.subscriptions.items) |sub| {
            if (sub.entity_index == id.index) count += 1;
        }
        return count;
    }
};
