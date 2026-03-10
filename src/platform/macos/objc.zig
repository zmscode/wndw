/// ObjC runtime extern declarations — the foundation of the pure-Zig macOS backend.
///
/// No headers needed. libobjc is bundled inside Cocoa.framework — linking
/// `-framework Cocoa` in build.zig is sufficient to resolve all symbols here.
///
/// On arm64 (Apple Silicon), `objc_msgSend` handles ALL return types including
/// structs (NSRect, NSPoint, NSSize) and floats. The x86-only variants
/// `objc_msgSend_stret` and `objc_msgSend_fpret` are not needed.
///
/// The key abstraction is the `msgSend()` helper function which wraps
/// `objc_msgSend` with a type-safe Zig interface. Instead of:
///   `@as(*const fn(id,SEL,id)callconv(.c)void, @ptrCast(&objc_msgSend))(obj, sel, arg)`
/// you write:
///   `msgSend(void, obj, "setTitle:", .{ns_string_obj})`
const std = @import("std");

// ── Core types ────────────────────────────────────────────────────────────────
/// These mirror the ObjC runtime's fundamental types.
/// An ObjC object pointer (equivalent to `id` in ObjC).
pub const id = *anyopaque;
/// An ObjC selector (equivalent to `SEL`).
pub const SEL = *anyopaque;
/// An ObjC class object (equivalent to `Class`).
pub const Class = *anyopaque;
/// An ObjC method implementation pointer.
pub const IMP = *const fn () callconv(.c) void;

/// ObjC `BOOL` — `YES` (1) or `NO` (0). Signed i8 to match the ABI.
pub const BOOL = i8;
/// Unsigned pointer-sized integer (NSUInteger in ObjC).
pub const NSUInteger = usize;
/// Signed pointer-sized integer (NSInteger in ObjC).
pub const NSInteger = isize;
/// Core Graphics floating point type (always f64 on 64-bit).
pub const CGFloat = f64;

pub const YES: BOOL = 1;
pub const NO: BOOL = 0;

// ── Geometry ──────────────────────────────────────────────────────────────────
/// These `extern struct` types match the C ABI layout of their CoreGraphics
/// equivalents. They can be passed to/from `objc_msgSend` directly on arm64.
pub const NSPoint = extern struct { x: CGFloat, y: CGFloat };
pub const NSSize = extern struct { width: CGFloat, height: CGFloat };
pub const NSRect = extern struct { origin: NSPoint, size: NSSize };

// ── Runtime functions ─────────────────────────────────────────────────────────
/// Direct `extern fn` declarations against libobjc. These are linked at
/// build time via `-framework Cocoa` and resolved by the dynamic linker.
/// Look up a class by name. Returns `null` if the class isn't loaded.
pub extern fn objc_getClass(name: [*:0]const u8) ?Class;
/// Register (or look up) a selector by name.
pub extern fn sel_registerName(name: [*:0]const u8) SEL;
/// Alias for `sel_registerName` — same behaviour.
pub extern fn sel_getUid(name: [*:0]const u8) SEL;
/// Create a new ObjC class at runtime (not yet registered — call
/// `objc_registerClassPair` after adding ivars and methods).
pub extern fn objc_allocateClassPair(superclass: ?Class, name: [*:0]const u8, extra: usize) ?Class;
/// Finalise a runtime-created class so it can be instantiated.
pub extern fn objc_registerClassPair(cls: Class) void;
/// Add a method to a class. `types` is an ObjC type encoding string
/// (e.g. "v@:@" for `void (id self, SEL _cmd, id arg)`).
pub extern fn class_addMethod(cls: Class, sel: SEL, imp: IMP, types: [*:0]const u8) BOOL;
/// Add an instance variable to a class (must be called before registering).
pub extern fn class_addIvar(cls: Class, name: [*:0]const u8, size: usize, alignment: u8, types: [*:0]const u8) BOOL;
/// Get the superclass of a class.
pub extern fn class_getSuperclass(cls: Class) ?Class;
/// Opaque ObjC instance variable handle.
pub const Ivar = *anyopaque;
/// Read an instance variable's value (as a raw pointer). Returns the Ivar handle, or null if not found.
pub extern fn object_getInstanceVariable(obj: id, name: [*:0]const u8, out: *?*anyopaque) ?Ivar;
/// Write an instance variable's value. Returns the Ivar handle, or null if not found.
pub extern fn object_setInstanceVariable(obj: id, name: [*:0]const u8, value: ?*anyopaque) ?Ivar;

/// The universal message-sending function. NEVER call directly — always
/// cast to the correct function pointer type via `msgSend()` below.
pub extern fn objc_msgSend() void;

/// Message send to the superclass. Used for calling `[super initWithFrame:]`
/// etc. from within a subclass method implementation.
pub extern fn objc_msgSendSuper() void;

/// Argument struct for `objc_msgSendSuper`.
pub const ObjcSuper = extern struct {
    receiver: id,
    super_class: Class,
};

// ── CoreGraphics ─────────────────────────────────────────────────────────────

/// Alias: `CGPoint` and `NSPoint` are identical on 64-bit.
pub const CGPoint = NSPoint;
/// Warp the mouse cursor to an absolute screen position.
pub extern fn CGWarpMouseCursorPosition(point: CGPoint) i32;

// ── msgSend helper ────────────────────────────────────────────────────────────

/// Type-safe ObjC message send. Casts `objc_msgSend` to a function pointer
/// matching the return type `Ret` and the argument tuple `args`.
///
/// Supports 0–4 extra arguments (beyond the implicit `self` and `_cmd`).
/// Uses per-arity explicit casts because `@Type(.{ .@"fn" = ... })` is not
/// supported for building function types in Zig 0.16.0-dev.
///
/// Example:
/// ```zig
/// const app = msgSend(id, ns_class("NSApplication"), "sharedApplication", .{});
/// msgSend(void, app, "activateIgnoringOtherApps:", .{YES});
/// ```
pub fn msgSend(comptime Ret: type, obj: anytype, sel_name: [*:0]const u8, args: anytype) Ret {
    // On x86_64, structs larger than 16 bytes must use objc_msgSend_stret.
    // This backend only supports arm64 where objc_msgSend handles all return types.
    if (comptime @sizeOf(Ret) > 16 and @import("builtin").cpu.arch != .aarch64) {
        @compileError("msgSend: returning structs >16 bytes (e.g. NSRect) requires objc_msgSend_stret on x86_64; this backend only supports arm64");
    }

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

/// Look up an ObjC class by name, panicking if not found.
/// Use this for classes that must exist (NSWindow, NSApplication, etc.).
pub fn ns_class(name: [*:0]const u8) Class {
    return objc_getClass(name) orelse std.debug.panic("ObjC class not found: {s}", .{name});
}

/// Create an autoreleased NSString from a null-terminated UTF-8 C string.
/// Panics if the input is not valid UTF-8 (stringWithUTF8String: returns nil).
pub fn ns_string(s: [*:0]const u8) id {
    return msgSend(?id, ns_class("NSString"), "stringWithUTF8String:", .{s}) orelse
        std.debug.panic("ns_string: invalid UTF-8 input", .{});
}

/// Retain an ObjC object (increment reference count). Returns the same pointer.
pub fn ns_retain(obj: id) id {
    return msgSend(id, obj, "retain", .{});
}
