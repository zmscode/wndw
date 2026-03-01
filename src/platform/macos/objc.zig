/// ObjC runtime extern declarations.
///
/// No headers needed. libobjc is bundled inside Cocoa.framework — linking
/// `-framework Cocoa` is sufficient to resolve all symbols here.
///
/// On arm64 (Apple Silicon), objc_msgSend handles all return types including
/// structs and floats. objc_msgSend_stret / objc_msgSend_fpret are not needed.
const std = @import("std"); // used by ns_class panic

// ── Core types ────────────────────────────────────────────────────────────────

pub const id = *anyopaque;
pub const SEL = *anyopaque;
pub const Class = *anyopaque;
pub const IMP = *const fn () callconv(.c) void;

pub const BOOL = i8;
pub const NSUInteger = usize;
pub const NSInteger = isize;
pub const CGFloat = f64;

pub const YES: BOOL = 1;
pub const NO: BOOL = 0;

// ── Geometry ──────────────────────────────────────────────────────────────────

pub const NSPoint = extern struct { x: CGFloat, y: CGFloat };
pub const NSSize = extern struct { width: CGFloat, height: CGFloat };
pub const NSRect = extern struct { origin: NSPoint, size: NSSize };

// ── Runtime functions ─────────────────────────────────────────────────────────

pub extern fn objc_getClass(name: [*:0]const u8) ?Class;
pub extern fn sel_registerName(name: [*:0]const u8) SEL;
pub extern fn sel_getUid(name: [*:0]const u8) SEL;
pub extern fn objc_allocateClassPair(superclass: ?Class, name: [*:0]const u8, extra: usize) ?Class;
pub extern fn objc_registerClassPair(cls: Class) void;
pub extern fn class_addMethod(cls: Class, sel: SEL, imp: IMP, types: [*:0]const u8) BOOL;
pub extern fn class_addIvar(cls: Class, name: [*:0]const u8, size: usize, alignment: u8, types: [*:0]const u8) BOOL;
pub extern fn class_getSuperclass(cls: Class) ?Class;
pub extern fn object_getInstanceVariable(obj: id, name: [*:0]const u8, out: *?*anyopaque) void;
pub extern fn object_setInstanceVariable(obj: id, name: [*:0]const u8, value: ?*anyopaque) void;

/// Do not call directly — always cast via msgSend().
pub extern fn objc_msgSend() void;

// ── msgSend helper ────────────────────────────────────────────────────────────

/// Send an ObjC message. `obj` is the receiver (id or Class), `sel_name` is the
/// selector string, `args` is a tuple of additional arguments. Returns `Ret`.
///
/// Supports 0–4 extra arguments. Uses per-arity explicit casts; @Type(.fn) is
/// not supported for function types in this Zig version.
///
/// Example:
/// ```zig
///   const app = msgSend(id, ns_class("NSApplication"), "sharedApplication", .{});
///   msgSend(void, app, "activateIgnoringOtherApps:", .{YES});
/// ```
pub fn msgSend(comptime Ret: type, obj: anytype, sel_name: [*:0]const u8, args: anytype) Ret {
    const sel = sel_registerName(sel_name);
    const recv: id = @ptrCast(@alignCast(obj));
    const fi = @typeInfo(@TypeOf(args)).@"struct".fields;

    return switch (fi.len) {
        0 => @as(*const fn (id, SEL) callconv(.c) Ret, @ptrCast(&objc_msgSend))(recv, sel),
        1 => @as(*const fn (id, SEL, fi[0].type) callconv(.c) Ret, @ptrCast(&objc_msgSend))(recv, sel, args[0]),
        2 => @as(*const fn (id, SEL, fi[0].type, fi[1].type) callconv(.c) Ret, @ptrCast(&objc_msgSend))(recv, sel, args[0], args[1]),
        3 => @as(*const fn (id, SEL, fi[0].type, fi[1].type, fi[2].type) callconv(.c) Ret, @ptrCast(&objc_msgSend))(recv, sel, args[0], args[1], args[2]),
        4 => @as(*const fn (id, SEL, fi[0].type, fi[1].type, fi[2].type, fi[3].type) callconv(.c) Ret, @ptrCast(&objc_msgSend))(recv, sel, args[0], args[1], args[2], args[3]),
        else => @compileError("msgSend: max 4 extra arguments"),
    };
}

/// Convenience: get an ObjC class, panic if not found.
pub fn ns_class(name: [*:0]const u8) Class {
    return objc_getClass(name) orelse std.debug.panic("ObjC class not found: {s}", .{name});
}

/// Create an NSString from a null-terminated UTF-8 slice.
pub fn ns_string(s: [*:0]const u8) id {
    return msgSend(id, ns_class("NSString"), "stringWithUTF8String:", .{s});
}

/// Retain an ObjC object (returns the same object).
pub fn ns_retain(obj: id) id {
    return msgSend(id, obj, "retain", .{});
}
