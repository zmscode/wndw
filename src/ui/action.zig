// ── Action / Keybinding System ───────────────────────────────────────
//
// Maps key combinations (key + modifiers) to callbacks.
// Dispatch returns true if a binding matched, false otherwise.

const std = @import("std");
const wndw = @import("wndw");

pub const Key = wndw.Key;

pub const Modifiers = struct {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    super: bool = false,

    pub fn eql(a: Modifiers, b: Modifiers) bool {
        return a.shift == b.shift and a.ctrl == b.ctrl and
            a.alt == b.alt and a.super == b.super;
    }
};

pub const KeyCombo = struct {
    key: Key,
    modifiers: Modifiers = .{},

    pub fn eql(a: KeyCombo, b: KeyCombo) bool {
        return a.key == b.key and a.modifiers.eql(b.modifiers);
    }
};

const Binding = struct {
    combo: KeyCombo,
    ctx: ?*anyopaque,
    func: *const fn (?*anyopaque) void,
};

pub const KeybindingTable = struct {
    bindings: std.ArrayListUnmanaged(Binding) = .{},
    gpa: std.mem.Allocator,

    pub fn init(gpa: std.mem.Allocator) KeybindingTable {
        return .{ .gpa = gpa };
    }

    pub fn deinit(self: *KeybindingTable) void {
        self.bindings.deinit(self.gpa);
    }

    /// Register a callback for a key combination.
    pub fn bind(self: *KeybindingTable, combo: KeyCombo, ctx: ?*anyopaque, func: *const fn (?*anyopaque) void) void {
        self.bindings.append(self.gpa, .{
            .combo = combo,
            .ctx = ctx,
            .func = func,
        }) catch unreachable;
    }

    /// Try to dispatch a key event. Returns true if a binding was found and fired.
    pub fn dispatch(self: *const KeybindingTable, combo: KeyCombo) bool {
        for (self.bindings.items) |b| {
            if (b.combo.eql(combo)) {
                b.func(b.ctx);
                return true;
            }
        }
        return false;
    }
};
