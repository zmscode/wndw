/// macOS window backend — pure ObjC runtime, no C headers.
///
/// Linking `-framework Cocoa` provides libobjc + AppKit symbols.
/// No @cImport, no C source files.
const std = @import("std");
const objc = @import("objc.zig");
const cocoa = @import("cocoa.zig");
const event = @import("../../event.zig");

pub const Event = event.Event;
pub const Key = event.Key;

// ── Options ───────────────────────────────────────────────────────────────────

pub const Options = struct {
    centred: bool = false,
    transparent: bool = false,
    borderless: bool = false,
    resizeable: bool = false,
};

// ── Global app state (initialised once) ───────────────────────────────────────

const Global = struct {
    app: objc.id = undefined,
    app_delegate_cls: objc.Class = undefined,
    app_delegate: objc.id = undefined,
    win_delegate_cls: objc.Class = undefined,
    view_cls: objc.Class = undefined,
    run_loop_mode: objc.id = undefined, // retained NSString, cached for drain
    initialised: bool = false,
};
var g: Global = .{};

// ── Event queue ───────────────────────────────────────────────────────────────

const EventQueue = @import("../../event_queue.zig").EventQueue;

// ── Monitor ───────────────────────────────────────────────────────────────────

pub const Monitor = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    scale: f32,
    ns_screen: objc.id,
};

const MAX_MONITORS = 16;

fn monitor_from_screen(screen: objc.id) Monitor {
    const FnRect = fn (objc.id, objc.SEL) callconv(.c) objc.NSRect;
    const fn_rect: *const FnRect = @ptrCast(&objc.objc_msgSend);
    const frame = fn_rect(screen, objc.sel_registerName("frame"));
    const FnScale = fn (objc.id, objc.SEL) callconv(.c) objc.CGFloat;
    const fn_scale: *const FnScale = @ptrCast(&objc.objc_msgSend);
    const scale: f32 = @floatCast(fn_scale(screen, objc.sel_registerName("backingScaleFactor")));
    return .{
        .x = @intFromFloat(frame.origin.x),
        .y = @intFromFloat(frame.origin.y),
        .w = @intFromFloat(frame.size.width),
        .h = @intFromFloat(frame.size.height),
        .scale = scale,
        .ns_screen = screen,
    };
}

// ── Window ────────────────────────────────────────────────────────────────────

pub const Window = struct {
    ns_window: objc.id,
    ns_view: objc.id,
    ns_delegate: objc.id,
    w: i32,
    h: i32,
    x: i32,
    y: i32,
    queue: EventQueue = .{},
    should_close: bool = false,
    prev_flags: usize = 0, // for FlagsChanged diffing
    is_focused: bool = false,
    is_minimized: bool = false,
    is_visible: bool = true,
    is_borderless: bool = false,
    user_ptr: ?*anyopaque = null,
    is_cursor_visible: bool = true,
    drop_count: u32 = 0,
    drop_paths: [MAX_DROP_FILES][*:0]const u8 = undefined,

    const MAX_DROP_FILES = 64;

    pub fn close(win: *Window) void {
        // Nil delegate before destroying win to prevent callbacks after free.
        objc.msgSend(void, win.ns_window, "setDelegate:", .{@as(?objc.id, null)});
        objc.msgSend(void, win.ns_window, "orderOut:", .{@as(?objc.id, null)});
        objc.msgSend(void, win.ns_window, "close", .{});
        std.heap.c_allocator.destroy(win);
    }

    pub fn shouldClose(win: *Window) bool {
        return win.should_close;
    }

    pub fn quit(win: *Window) void {
        win.should_close = true;
    }

    /// Return the next queued event, or null.
    /// Drains the OS event queue only when the Zig-side queue is empty.
    pub fn poll(win: *Window) ?Event {
        if (win.queue.isEmpty()) drain_ns_events(win);
        return win.queue.pop();
    }

    // ── State queries ──────────────────────────────────────────────────────────

    pub fn isFocused(win: *const Window) bool {
        return win.is_focused;
    }

    pub fn isMinimized(win: *const Window) bool {
        return win.is_minimized;
    }

    pub fn getSize(win: *const Window) struct { w: i32, h: i32 } {
        return .{ .w = win.w, .h = win.h };
    }

    pub fn getPos(win: *const Window) struct { x: i32, y: i32 } {
        return .{ .x = win.x, .y = win.y };
    }

    // ── ObjC-backed mutations ──────────────────────────────────────────────────

    pub fn setTitle(win: *Window, title: [:0]const u8) void {
        objc.msgSend(void, win.ns_window, "setTitle:", .{objc.ns_string(title)});
    }

    pub fn resize(win: *Window, w: i32, h: i32) void {
        const FnGet = fn (objc.id, objc.SEL) callconv(.c) objc.NSRect;
        const fn_get: *const FnGet = @ptrCast(&objc.objc_msgSend);
        var frame = fn_get(win.ns_window, objc.sel_registerName("frame"));
        frame.size.width = @floatFromInt(w);
        frame.size.height = @floatFromInt(h);
        const FnSet = fn (objc.id, objc.SEL, objc.NSRect, objc.BOOL) callconv(.c) void;
        const fn_set: *const FnSet = @ptrCast(&objc.objc_msgSend);
        fn_set(win.ns_window, objc.sel_registerName("setFrame:display:"), frame, objc.YES);
    }

    pub fn move(win: *Window, x: i32, y: i32) void {
        const FnPt = fn (objc.id, objc.SEL, objc.NSPoint) callconv(.c) void;
        const fn_ptr: *const FnPt = @ptrCast(&objc.objc_msgSend);
        const pt = objc.NSPoint{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
        fn_ptr(win.ns_window, objc.sel_registerName("setFrameOrigin:"), pt);
    }

    pub fn minimize(win: *Window) void {
        objc.msgSend(void, win.ns_window, "miniaturize:", .{@as(?objc.id, null)});
    }

    pub fn restore(win: *Window) void {
        objc.msgSend(void, win.ns_window, "deminiaturize:", .{@as(?objc.id, null)});
    }

    pub fn maximize(win: *Window) void {
        objc.msgSend(void, win.ns_window, "zoom:", .{@as(?objc.id, null)});
    }

    pub fn setFullscreen(win: *Window, enable: bool) void {
        const style = objc.msgSend(usize, win.ns_window, "styleMask", .{});
        const is_full = (style & cocoa.NSWindowStyleMaskFullScreen) != 0;
        if (enable != is_full) {
            objc.msgSend(void, win.ns_window, "toggleFullScreen:", .{@as(?objc.id, null)});
        }
    }

    pub fn setCursorVisible(win: *Window, visible: bool) void {
        if (visible) {
            objc.msgSend(void, objc.ns_class("NSCursor"), "unhide", .{});
        } else {
            objc.msgSend(void, objc.ns_class("NSCursor"), "hide", .{});
        }
        win.is_cursor_visible = visible;
    }

    pub fn isCursorVisible(win: *const Window) bool {
        return win.is_cursor_visible;
    }

    pub fn setAlwaysOnTop(win: *Window, enable: bool) void {
        const level: objc.NSInteger = if (enable) cocoa.NSFloatingWindowLevel else cocoa.NSNormalWindowLevel;
        const FnLvl = fn (objc.id, objc.SEL, objc.NSInteger) callconv(.c) void;
        const fn_ptr: *const FnLvl = @ptrCast(&objc.objc_msgSend);
        fn_ptr(win.ns_window, objc.sel_registerName("setLevel:"), level);
    }

    pub fn isVisible(win: *const Window) bool {
        return win.is_visible;
    }

    pub fn isBorderless(win: *const Window) bool {
        return win.is_borderless;
    }

    pub fn isFullscreen(win: *Window) bool {
        const style = objc.msgSend(usize, win.ns_window, "styleMask", .{});
        return (style & cocoa.NSWindowStyleMaskFullScreen) != 0;
    }

    pub fn isMaximized(win: *Window) bool {
        return objc.msgSend(objc.BOOL, win.ns_window, "isZoomed", .{}) != objc.NO;
    }

    pub fn setOpacity(win: *Window, opacity: u8) void {
        const FnAlpha = fn (objc.id, objc.SEL, objc.CGFloat) callconv(.c) void;
        const fn_ptr: *const FnAlpha = @ptrCast(&objc.objc_msgSend);
        const alpha: objc.CGFloat = @as(objc.CGFloat, @floatFromInt(opacity)) / 255.0;
        fn_ptr(win.ns_window, objc.sel_registerName("setAlphaValue:"), alpha);
    }

    pub fn focus(win: *Window) void {
        objc.msgSend(void, win.ns_window, "makeKeyAndOrderFront:", .{@as(?objc.id, null)});
    }

    pub fn hide(win: *Window) void {
        objc.msgSend(void, win.ns_window, "orderOut:", .{@as(?objc.id, null)});
        win.is_visible = false;
    }

    pub fn show(win: *Window) void {
        objc.msgSend(void, win.ns_window, "makeKeyAndOrderFront:", .{@as(?objc.id, null)});
        win.is_visible = true;
    }

    pub fn center(win: *Window) void {
        objc.msgSend(void, win.ns_window, "center", .{});
    }

    // ── User pointer ────────────────────────────────────────────────────────

    pub fn setUserPtr(win: *Window, ptr: ?*anyopaque) void {
        win.user_ptr = ptr;
    }

    pub fn getUserPtr(win: *const Window) ?*anyopaque {
        return win.user_ptr;
    }

    // ── Native handles ──────────────────────────────────────────────────────

    pub fn getNativeWindow(win: *const Window) objc.id {
        return win.ns_window;
    }

    pub fn getNativeView(win: *const Window) objc.id {
        return win.ns_view;
    }

    // ── Constraints ─────────────────────────────────────────────────────────

    pub fn setMinSize(win: *Window, w: i32, h: i32) void {
        const FnSize = fn (objc.id, objc.SEL, objc.NSSize) callconv(.c) void;
        const fn_ptr: *const FnSize = @ptrCast(&objc.objc_msgSend);
        fn_ptr(win.ns_window, objc.sel_registerName("setContentMinSize:"), .{
            .width = @floatFromInt(w),
            .height = @floatFromInt(h),
        });
    }

    pub fn setMaxSize(win: *Window, w: i32, h: i32) void {
        const FnSize = fn (objc.id, objc.SEL, objc.NSSize) callconv(.c) void;
        const fn_ptr: *const FnSize = @ptrCast(&objc.objc_msgSend);
        fn_ptr(win.ns_window, objc.sel_registerName("setContentMaxSize:"), .{
            .width = @floatFromInt(w),
            .height = @floatFromInt(h),
        });
    }

    pub fn setAspectRatio(win: *Window, w: i32, h: i32) void {
        const FnSize = fn (objc.id, objc.SEL, objc.NSSize) callconv(.c) void;
        const fn_ptr: *const FnSize = @ptrCast(&objc.objc_msgSend);
        fn_ptr(win.ns_window, objc.sel_registerName("setContentAspectRatio:"), .{
            .width = @floatFromInt(w),
            .height = @floatFromInt(h),
        });
    }

    // ── Attention request ───────────────────────────────────────────────────

    // ── Clipboard ────────────────────────────────────────────────────────

    pub fn clipboardRead(_: *Window) ?[*:0]const u8 {
        const pb = objc.msgSend(objc.id, objc.ns_class("NSPasteboard"), "generalPasteboard", .{});
        const ns_str_type = objc.ns_string("public.utf8-plain-text");
        const ns_str: ?objc.id = objc.msgSend(?objc.id, pb, "stringForType:", .{ns_str_type});
        if (ns_str) |s| {
            return objc.msgSend([*:0]const u8, s, "UTF8String", .{});
        }
        return null;
    }

    pub fn clipboardWrite(_: *Window, text: [*:0]const u8) void {
        const pb = objc.msgSend(objc.id, objc.ns_class("NSPasteboard"), "generalPasteboard", .{});
        objc.msgSend(void, pb, "clearContents", .{});
        const ns_str = objc.ns_string(text);
        const ns_str_type = objc.ns_string("public.utf8-plain-text");
        objc.msgSend(objc.BOOL, pb, "setString:forType:", .{ ns_str, ns_str_type });
    }

    // ── Drag and drop ────────────────────────────────────────────────────

    pub fn setDragAndDrop(win: *Window, enable: bool) void {
        if (enable) {
            // Register view for file URL drags.
            const file_url_type = objc.ns_string("public.file-url");
            const array = objc.msgSend(objc.id, objc.ns_class("NSArray"), "arrayWithObject:", .{file_url_type});
            objc.msgSend(void, win.ns_view, "registerForDraggedTypes:", .{array});
        } else {
            objc.msgSend(void, win.ns_view, "unregisterDraggedTypes", .{});
        }
    }

    pub fn getDroppedFiles(win: *const Window) []const [*:0]const u8 {
        return win.drop_paths[0..win.drop_count];
    }

    // ── Mouse cursor ─────────────────────────────────────────────────────

    pub fn moveMouse(_: *Window, x: i32, y: i32) void {
        _ = objc.CGWarpMouseCursorPosition(.{
            .x = @floatFromInt(x),
            .y = @floatFromInt(y),
        });
    }

    pub fn getMousePos(_: *Window) struct { x: i32, y: i32 } {
        // [NSEvent mouseLocation] returns screen coords (bottom-left origin).
        const loc = objc.msgSend(objc.NSPoint, objc.ns_class("NSEvent"), "mouseLocation", .{});
        // Get main screen height for Y-flip.
        const screen = objc.msgSend(objc.id, objc.ns_class("NSScreen"), "mainScreen", .{});
        const frame = objc.msgSend(objc.NSRect, screen, "frame", .{});
        return .{
            .x = @intFromFloat(loc.x),
            .y = @intFromFloat(frame.size.height - loc.y),
        };
    }

    pub fn setStandardCursor(_: *Window, cursor: @import("../../event.zig").Cursor) void {
        const sel_name: [*:0]const u8 = switch (cursor) {
            .arrow => "arrowCursor",
            .ibeam => "IBeamCursor",
            .crosshair => "crosshairCursor",
            .closed_hand => "closedHandCursor",
            .open_hand => "openHandCursor",
            .pointing_hand => "pointingHandCursor",
            .resize_left_right => "resizeLeftRightCursor",
            .resize_up_down => "resizeUpDownCursor",
            .not_allowed => "operationNotAllowedCursor",
        };
        const ns_cursor = objc.msgSend(objc.id, objc.ns_class("NSCursor"), sel_name, .{});
        objc.msgSend(void, ns_cursor, "set", .{});
    }

    pub fn resetCursor(_: *Window) void {
        const arrow = objc.msgSend(objc.id, objc.ns_class("NSCursor"), "arrowCursor", .{});
        objc.msgSend(void, arrow, "set", .{});
    }

    // ── Attention request ───────────────────────────────────────────────────

    pub fn flash(_: *Window) void {
        // NSInformationalRequest = 10 — bounces dock icon once.
        const app = objc.msgSend(objc.id, objc.objc_getClass("NSApplication"), "sharedApplication", .{});
        const FnAttn = fn (objc.id, objc.SEL, objc.NSUInteger) callconv(.c) void;
        const fn_ptr: *const FnAttn = @ptrCast(&objc.objc_msgSend);
        fn_ptr(app, objc.sel_registerName("requestUserAttention:"), 10);
    }

    // ── Monitor/display ─────────────────────────────────────────────────────

    pub fn getPrimaryMonitor(_: *Window) Monitor {
        const screen = objc.msgSend(objc.id, objc.ns_class("NSScreen"), "mainScreen", .{});
        return monitor_from_screen(screen);
    }

    pub fn getWindowMonitor(win: *Window) Monitor {
        const screen = objc.msgSend(objc.id, win.ns_window, "screen", .{});
        return monitor_from_screen(screen);
    }

    pub fn getMonitors(_: *Window) []const Monitor {
        const screens = objc.msgSend(objc.id, objc.ns_class("NSScreen"), "screens", .{});
        const count = objc.msgSend(objc.NSUInteger, screens, "count", .{});
        const n = @min(count, MAX_MONITORS);

        const S = struct {
            var buf: [MAX_MONITORS]Monitor = undefined;
        };

        var i: objc.NSUInteger = 0;
        while (i < n) : (i += 1) {
            const FnObjAtIdx = fn (objc.id, objc.SEL, objc.NSUInteger) callconv(.c) objc.id;
            const fn_idx: *const FnObjAtIdx = @ptrCast(&objc.objc_msgSend);
            const screen = fn_idx(screens, objc.sel_registerName("objectAtIndex:"), i);
            S.buf[i] = monitor_from_screen(screen);
        }
        return S.buf[0..n];
    }

    pub fn moveToMonitor(win: *Window, mon: Monitor) void {
        const FnRect = fn (objc.id, objc.SEL) callconv(.c) objc.NSRect;
        const fn_rect: *const FnRect = @ptrCast(&objc.objc_msgSend);
        const cur_frame = fn_rect(win.ns_window, objc.sel_registerName("frame"));

        const new_frame = objc.NSRect{
            .origin = .{
                .x = @floatFromInt(mon.x),
                .y = @floatFromInt(mon.y),
            },
            .size = cur_frame.size,
        };
        const FnSetFrame = fn (objc.id, objc.SEL, objc.NSRect, objc.BOOL) callconv(.c) void;
        const fn_set: *const FnSetFrame = @ptrCast(&objc.objc_msgSend);
        fn_set(win.ns_window, objc.sel_registerName("setFrame:display:"), new_frame, objc.YES);
    }
};

// ── init ──────────────────────────────────────────────────────────────────────

pub fn init(title: [:0]const u8, w: i32, h: i32, opts: Options) !*Window {
    if (!g.initialised) try setup_app();

    const win = try std.heap.c_allocator.create(Window);
    win.* = .{
        .ns_window = undefined,
        .ns_view = undefined,
        .ns_delegate = undefined,
        .w = w,
        .h = h,
        .x = 0,
        .y = 0,
    };

    // ── Screen height for Y-flip ──────────────────────────────────────────────
    const screen = objc.msgSend(objc.id, objc.ns_class("NSScreen"), "mainScreen", .{});
    const frame = objc.msgSend(objc.NSRect, screen, "frame", .{});
    const screen_h = frame.size.height;

    // ── Style mask ────────────────────────────────────────────────────────────
    var mask: usize = cocoa.NSWindowStyleMaskTitled |
        cocoa.NSWindowStyleMaskClosable |
        cocoa.NSWindowStyleMaskMiniaturizable;
    if (opts.resizeable) mask |= cocoa.NSWindowStyleMaskResizable;
    if (opts.borderless) mask = cocoa.NSWindowStyleMaskBorderless;

    // ── Compute position ──────────────────────────────────────────────────────
    const cx: f64 = if (opts.centred)
        (frame.size.width - @as(f64, @floatFromInt(w))) / 2.0
    else
        0.0;
    // Cocoa Y: flip from top-left origin
    const cy: f64 = screen_h - @as(f64, @floatFromInt(h)) -
        if (opts.centred)
            (screen_h - @as(f64, @floatFromInt(h))) / 2.0
        else
            0.0;

    win.x = @intFromFloat(cx);
    win.y = @intFromFloat(screen_h - @as(f64, @floatFromInt(h)) - cy);

    const rect = objc.NSRect{
        .origin = .{ .x = cx, .y = cy },
        .size = .{ .width = @floatFromInt(w), .height = @floatFromInt(h) },
    };

    // ── Create NSWindow ───────────────────────────────────────────────────────
    const FnType = fn (objc.id, objc.SEL, objc.NSRect, usize, usize, objc.BOOL) callconv(.c) objc.id;
    const init_sel = objc.sel_registerName("initWithContentRect:styleMask:backing:defer:");
    const fn_ptr: *const FnType = @ptrCast(&objc.objc_msgSend);
    const ns_win_alloc = objc.msgSend(objc.id, objc.ns_class("NSWindow"), "alloc", .{});
    const ns_win = fn_ptr(
        ns_win_alloc,
        init_sel,
        rect,
        mask,
        cocoa.NSBackingStoreBuffered,
        objc.NO,
    );
    win.ns_window = ns_win;
    win.is_borderless = opts.borderless;

    // ── Title ─────────────────────────────────────────────────────────────────
    objc.msgSend(void, ns_win, "setTitle:", .{objc.ns_string(title)});

    // ── Delegate ──────────────────────────────────────────────────────────────
    const delegate = objc.msgSend(objc.id, objc.msgSend(objc.id, g.win_delegate_cls, "alloc", .{}), "init", .{});
    objc.object_setInstanceVariable(delegate, "wndw_win", win);
    objc.msgSend(void, ns_win, "setDelegate:", .{delegate});
    win.ns_delegate = delegate;

    // ── Custom view ───────────────────────────────────────────────────────────
    const FnTypeView = fn (objc.id, objc.SEL, *Window) callconv(.c) objc.id;
    const view_init_sel = objc.sel_registerName("initWithWndwWindow:");
    const fn_ptr_view: *const FnTypeView = @ptrCast(&objc.objc_msgSend);
    const view_alloc = objc.msgSend(objc.id, g.view_cls, "alloc", .{});
    const ns_view = fn_ptr_view(view_alloc, view_init_sel, win);
    win.ns_view = ns_view;
    objc.msgSend(void, ns_win, "setContentView:", .{ns_view});

    // ── Mouse tracking area ───────────────────────────────────────────────────
    objc.msgSend(void, ns_win, "setAcceptsMouseMovedEvents:", .{objc.YES});

    // NSTrackingArea for mouseEntered:/mouseExited: events.
    // Options: MouseEnteredAndExited | ActiveAlways | InVisibleRect
    const tracking_opts: objc.NSUInteger = (0x01 | 0x80 | 0x200);
    const FnTrackInit = fn (objc.id, objc.SEL, objc.NSRect, objc.NSUInteger, ?objc.id, ?*anyopaque) callconv(.c) objc.id;
    const fn_track: *const FnTrackInit = @ptrCast(&objc.objc_msgSend);
    const FnRect = fn (objc.id, objc.SEL) callconv(.c) objc.NSRect;
    const fn_bounds: *const FnRect = @ptrCast(&objc.objc_msgSend);
    const bounds = fn_bounds(ns_view, objc.sel_registerName("bounds"));
    const tracking_area = fn_track(
        objc.msgSend(objc.id, objc.ns_class("NSTrackingArea"), "alloc", .{}),
        objc.sel_registerName("initWithRect:options:owner:userInfo:"),
        bounds,
        tracking_opts,
        ns_view,
        null,
    );
    objc.msgSend(void, ns_view, "addTrackingArea:", .{tracking_area});

    // ── Transparency ──────────────────────────────────────────────────────────
    if (opts.transparent) {
        objc.msgSend(void, ns_win, "setOpaque:", .{objc.NO});
        objc.msgSend(void, ns_win, "setBackgroundColor:", .{objc.msgSend(objc.id, objc.ns_class("NSColor"), "clearColor", .{})});
    }

    // ── Focus ─────────────────────────────────────────────────────────────────
    // Make our view the first responder so key events route correctly.
    objc.msgSend(void, ns_win, "makeFirstResponder:", .{ns_view});

    // ── Show ──────────────────────────────────────────────────────────────────
    objc.msgSend(void, ns_win, "makeKeyAndOrderFront:", .{@as(?objc.id, null)});
    objc.msgSend(void, g.app, "activateIgnoringOtherApps:", .{objc.YES});

    return win;
}

// ── NSApp event drain ─────────────────────────────────────────────────────────

fn drain_ns_events(win: *Window) void {
    const mode = g.run_loop_mode;
    const FnNext = fn (objc.id, objc.SEL, usize, ?objc.id, objc.id, objc.BOOL) callconv(.c) ?objc.id;
    const next_sel = objc.sel_registerName("nextEventMatchingMask:untilDate:inMode:dequeue:");
    const fn_next: *const FnNext = @ptrCast(&objc.objc_msgSend);

    while (true) {
        const ns_ev = fn_next(g.app, next_sel, cocoa.NSEventMaskAny, null, mode, objc.YES) orelse break;

        // Read event data BEFORE sendEvent: — AppKit's default key handling
        // (cancelOperation: for escape, etc.) cannot mutate NSEvent, but reading
        // first avoids any ambiguity.
        const ev_type = objc.msgSend(usize, ns_ev, "type", .{});
        translate_event(win, ns_ev, ev_type);

        // Let AppKit do housekeeping (cursor updates, drawing, etc.)
        objc.msgSend(void, g.app, "sendEvent:", .{ns_ev});
    }
}

fn mods_from_flags(flags: usize) @import("../../event.zig").Modifiers {
    return .{
        .shift = (flags & cocoa.NSEventModifierFlagShift) != 0,
        .ctrl = (flags & cocoa.NSEventModifierFlagControl) != 0,
        .alt = (flags & cocoa.NSEventModifierFlagOption) != 0,
        .super = (flags & cocoa.NSEventModifierFlagCommand) != 0,
        .caps_lock = (flags & cocoa.NSEventModifierFlagCapsLock) != 0,
    };
}

fn translate_event(win: *Window, ns_ev: objc.id, ev_type: usize) void {
    const FnCGFloat = fn (objc.id, objc.SEL) callconv(.c) objc.CGFloat;

    switch (ev_type) {
        // ── Keyboard ─────────────────────────────────────────────────────────
        cocoa.NSEventTypeKeyDown => {
            if (objc.msgSend(objc.BOOL, ns_ev, "isARepeat", .{}) != objc.NO) return;
            const kc = objc.msgSend(u16, ns_ev, "keyCode", .{});
            const flags = objc.msgSend(usize, ns_ev, "modifierFlags", .{});
            win.queue.push(.{ .key_pressed = .{ .key = macos_keycode(kc), .mods = mods_from_flags(flags) } });
        },
        cocoa.NSEventTypeKeyUp => {
            const kc = objc.msgSend(u16, ns_ev, "keyCode", .{});
            const flags = objc.msgSend(usize, ns_ev, "modifierFlags", .{});
            win.queue.push(.{ .key_released = .{ .key = macos_keycode(kc), .mods = mods_from_flags(flags) } });
        },
        cocoa.NSEventTypeFlagsChanged => {
            const flags = objc.msgSend(usize, ns_ev, "modifierFlags", .{});
            const changed = flags ^ win.prev_flags;
            win.prev_flags = flags;
            const kc = objc.msgSend(u16, ns_ev, "keyCode", .{});
            const key = macos_keycode(kc);
            const mods = mods_from_flags(flags);
            if (changed != 0) {
                const pressed = (flags & changed) != 0;
                if (pressed) win.queue.push(.{ .key_pressed = .{ .key = key, .mods = mods } }) else win.queue.push(.{ .key_released = .{ .key = key, .mods = mods } });
            }
        },

        // ── Mouse buttons ─────────────────────────────────────────────────────
        cocoa.NSEventTypeLeftMouseDown => win.queue.push(.{ .mouse_pressed = .left }),
        cocoa.NSEventTypeLeftMouseUp => win.queue.push(.{ .mouse_released = .left }),
        cocoa.NSEventTypeRightMouseDown => win.queue.push(.{ .mouse_pressed = .right }),
        cocoa.NSEventTypeRightMouseUp => win.queue.push(.{ .mouse_released = .right }),
        cocoa.NSEventTypeOtherMouseDown => {
            const btn = other_mouse_button(objc.msgSend(objc.NSInteger, ns_ev, "buttonNumber", .{}));
            win.queue.push(.{ .mouse_pressed = btn });
        },
        cocoa.NSEventTypeOtherMouseUp => {
            const btn = other_mouse_button(objc.msgSend(objc.NSInteger, ns_ev, "buttonNumber", .{}));
            win.queue.push(.{ .mouse_released = btn });
        },

        // ── Mouse movement ────────────────────────────────────────────────────
        cocoa.NSEventTypeMouseMoved,
        cocoa.NSEventTypeLeftMouseDragged,
        cocoa.NSEventTypeRightMouseDragged,
        cocoa.NSEventTypeOtherMouseDragged,
        => {
            const p = mouse_pos(ns_ev, win.h);
            win.queue.push(.{ .mouse_moved = .{ .x = p.x, .y = p.y } });
        },

        // ── Scroll ────────────────────────────────────────────────────────────
        cocoa.NSEventTypeScrollWheel => {
            const fp: *const FnCGFloat = @ptrCast(&objc.objc_msgSend);
            const dx: f32 = @floatCast(fp(ns_ev, objc.sel_registerName("deltaX")));
            const dy: f32 = @floatCast(fp(ns_ev, objc.sel_registerName("deltaY")));
            win.queue.push(.{ .scroll = .{ .dx = dx, .dy = dy } });
        },

        else => {},
    }
}

fn other_mouse_button(btn: objc.NSInteger) event.MouseButton {
    return switch (btn) {
        2 => .middle,
        3 => .x1,
        4 => .x2,
        else => .middle,
    };
}

fn mouse_pos(ns_ev: objc.id, win_h: i32) struct { x: i32, y: i32 } {
    const FnPt = fn (objc.id, objc.SEL) callconv(.c) objc.NSPoint;
    const sel = objc.sel_registerName("locationInWindow");
    const fn_ptr: *const FnPt = @ptrCast(&objc.objc_msgSend);
    const p = fn_ptr(ns_ev, sel);
    return .{
        .x = @intFromFloat(p.x),
        .y = win_h - @as(i32, @intFromFloat(p.y)),
    };
}

// ── App + class setup ─────────────────────────────────────────────────────────

fn setup_app() !void {
    // NSApplication.sharedApplication
    g.app = objc.msgSend(objc.id, objc.ns_class("NSApplication"), "sharedApplication", .{});
    _ = objc.ns_retain(g.app);

    // Set activation policy
    const FnPolicy = fn (objc.id, objc.SEL, objc.NSInteger) callconv(.c) void;
    const policy_sel = objc.sel_registerName("setActivationPolicy:");
    const fp_policy: *const FnPolicy = @ptrCast(&objc.objc_msgSend);
    fp_policy(g.app, policy_sel, cocoa.NSApplicationActivationPolicyRegular);

    // App delegate (for screen-change notifications)
    g.app_delegate_cls = objc.objc_allocateClassPair(objc.objc_getClass("NSObject"), "WndwAppDelegate", 0) orelse
        return error.ClassAllocFailed;
    objc.objc_registerClassPair(g.app_delegate_cls);
    g.app_delegate = objc.msgSend(objc.id, objc.msgSend(objc.id, g.app_delegate_cls, "alloc", .{}), "init", .{});
    objc.msgSend(void, g.app, "setDelegate:", .{g.app_delegate});

    // Finish app launch — required for correct event routing (key focus, menus).
    objc.msgSend(void, g.app, "finishLaunching", .{});

    // Cache the run loop mode string for use in drain_ns_events.
    g.run_loop_mode = objc.ns_retain(objc.ns_string("kCFRunLoopDefaultMode"));

    // Window delegate class
    try setup_window_delegate_class();

    // Custom NSView subclass
    try setup_view_class();

    g.initialised = true;
}

fn setup_window_delegate_class() !void {
    g.win_delegate_cls = objc.objc_allocateClassPair(objc.objc_getClass("NSObject"), "WndwWindowDelegate", 0) orelse
        return error.ClassAllocFailed;

    // Instance variable to hold back-pointer to Window
    _ = objc.class_addIvar(g.win_delegate_cls, "wndw_win", @sizeOf(*anyopaque), @alignOf(*anyopaque), "^v");

    // windowShouldClose: → set should_close, return YES
    _ = objc.class_addMethod(g.win_delegate_cls, objc.sel_registerName("windowShouldClose:"), @ptrCast(&delegate_window_should_close), "B@:@");

    // windowDidResize:
    _ = objc.class_addMethod(g.win_delegate_cls, objc.sel_registerName("windowDidResize:"), @ptrCast(&delegate_window_did_resize), "v@:@");

    // windowDidMove:
    _ = objc.class_addMethod(g.win_delegate_cls, objc.sel_registerName("windowDidMove:"), @ptrCast(&delegate_window_did_move), "v@:@");

    // windowDidBecomeKey:
    _ = objc.class_addMethod(g.win_delegate_cls, objc.sel_registerName("windowDidBecomeKey:"), @ptrCast(&delegate_window_did_become_key), "v@:@");

    // windowDidResignKey:
    _ = objc.class_addMethod(g.win_delegate_cls, objc.sel_registerName("windowDidResignKey:"), @ptrCast(&delegate_window_did_resign_key), "v@:@");

    // windowDidMiniaturize:
    _ = objc.class_addMethod(g.win_delegate_cls, objc.sel_registerName("windowDidMiniaturize:"), @ptrCast(&delegate_window_did_miniaturize), "v@:@");

    // windowDidDeminiaturize:
    _ = objc.class_addMethod(g.win_delegate_cls, objc.sel_registerName("windowDidDeminiaturize:"), @ptrCast(&delegate_window_did_deminiaturize), "v@:@");

    objc.objc_registerClassPair(g.win_delegate_cls);
}

fn setup_view_class() !void {
    g.view_cls = objc.objc_allocateClassPair(objc.objc_getClass("NSView"), "WndwView", 0) orelse
        return error.ClassAllocFailed;

    // Back-pointer ivar
    _ = objc.class_addIvar(g.view_cls, "wndw_win", @sizeOf(*anyopaque), @alignOf(*anyopaque), "^v");

    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("initWithWndwWindow:"), @ptrCast(&view_init_with_window), "@@:^v");

    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("acceptsFirstResponder"), @ptrCast(&view_accepts_first_responder), "B@:");
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("mouseEntered:"), @ptrCast(&view_mouse_entered), "v@:@");
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("mouseExited:"), @ptrCast(&view_mouse_exited), "v@:@");
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("drawRect:"), @ptrCast(&view_draw_rect), "v@:{CGRect={CGPoint=dd}{CGSize=dd}}");
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("viewDidChangeBackingProperties"), @ptrCast(&view_did_change_backing_properties), "v@:");

    // NSDraggingDestination
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("draggingEntered:"), @ptrCast(&view_dragging_entered), "Q@:@");
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("draggingExited:"), @ptrCast(&view_dragging_exited), "v@:@");
    _ = objc.class_addMethod(g.view_cls, objc.sel_registerName("performDragOperation:"), @ptrCast(&view_perform_drag_operation), "B@:@");

    objc.objc_registerClassPair(g.view_cls);
}

// ── Delegate callbacks ────────────────────────────────────────────────────────

fn get_win_from_delegate(delegate: objc.id) ?*Window {
    var ptr: ?*anyopaque = null;
    objc.object_getInstanceVariable(delegate, "wndw_win", &ptr);
    const p = ptr orelse return null;
    return @ptrCast(@alignCast(p));
}

fn delegate_window_should_close(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) objc.BOOL {
    if (get_win_from_delegate(self)) |win| {
        win.should_close = true;
        win.queue.push(.close_requested);
    }
    return objc.YES;
}

fn delegate_window_did_resize(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    const win = get_win_from_delegate(self) orelse return;
    const content_view = objc.msgSend(objc.id, win.ns_window, "contentView", .{});
    const FnRect = fn (objc.id, objc.SEL) callconv(.c) objc.NSRect;
    const fn_ptr: *const FnRect = @ptrCast(&objc.objc_msgSend);
    const frame = fn_ptr(content_view, objc.sel_registerName("frame"));
    win.w = @intFromFloat(frame.size.width);
    win.h = @intFromFloat(frame.size.height);
    win.queue.push(.{ .resized = .{ .w = win.w, .h = win.h } });
    // Detect maximize (zoom) — isZoomed changes after resize completes.
    if (objc.msgSend(objc.BOOL, win.ns_window, "isZoomed", .{}) != objc.NO) {
        win.queue.push(.maximized);
    }
}

fn delegate_window_did_move(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    const win = get_win_from_delegate(self) orelse return;
    const FnRect = fn (objc.id, objc.SEL) callconv(.c) objc.NSRect;
    const fn_ptr: *const FnRect = @ptrCast(&objc.objc_msgSend);
    const frame = fn_ptr(win.ns_window, objc.sel_registerName("frame"));
    win.x = @intFromFloat(frame.origin.x);
    win.y = @intFromFloat(frame.origin.y);
    win.queue.push(.{ .moved = .{ .x = win.x, .y = win.y } });
}

fn delegate_window_did_become_key(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    if (get_win_from_delegate(self)) |win| {
        win.is_focused = true;
        win.queue.push(.focus_gained);
    }
}

fn delegate_window_did_resign_key(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    if (get_win_from_delegate(self)) |win| {
        win.is_focused = false;
        win.queue.push(.focus_lost);
    }
}

fn delegate_window_did_miniaturize(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    if (get_win_from_delegate(self)) |win| {
        win.is_minimized = true;
        win.queue.push(.minimized);
    }
}

fn delegate_window_did_deminiaturize(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    if (get_win_from_delegate(self)) |win| {
        win.is_minimized = false;
        win.queue.push(.restored);
    }
}

// ── View callbacks ────────────────────────────────────────────────────────────

fn get_win_from_view(view: objc.id) ?*Window {
    var ptr: ?*anyopaque = null;
    objc.object_getInstanceVariable(view, "wndw_win", &ptr);
    const p = ptr orelse return null;
    return @ptrCast(@alignCast(p));
}

fn view_init_with_window(self: objc.id, _: objc.SEL, win: *Window) callconv(.c) objc.id {
    // NSView's designated initializer is initWithFrame:.
    // WndwView does not override it, so this dispatches directly to NSView.
    const FnInitFrame = fn (objc.id, objc.SEL, objc.NSRect) callconv(.c) objc.id;
    const fn_ptr: *const FnInitFrame = @ptrCast(&objc.objc_msgSend);
    const zero = objc.NSRect{ .origin = .{ .x = 0, .y = 0 }, .size = .{ .width = 0, .height = 0 } };
    const result = fn_ptr(self, objc.sel_registerName("initWithFrame:"), zero);
    objc.object_setInstanceVariable(result, "wndw_win", win);
    return result;
}

fn view_accepts_first_responder(_: objc.id, _: objc.SEL) callconv(.c) objc.BOOL {
    return objc.YES;
}

fn view_mouse_entered(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    if (get_win_from_view(self)) |win| win.queue.push(.mouse_entered);
}

fn view_mouse_exited(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    if (get_win_from_view(self)) |win| win.queue.push(.mouse_left);
}

fn view_draw_rect(self: objc.id, _: objc.SEL, _: objc.NSRect) callconv(.c) void {
    if (get_win_from_view(self)) |win| win.queue.push(.refresh_requested);
}

fn view_did_change_backing_properties(self: objc.id, _: objc.SEL) callconv(.c) void {
    const win = get_win_from_view(self) orelse return;
    const FnScale = fn (objc.id, objc.SEL) callconv(.c) objc.CGFloat;
    const fn_ptr: *const FnScale = @ptrCast(&objc.objc_msgSend);
    const scale: f32 = @floatCast(fn_ptr(win.ns_window, objc.sel_registerName("backingScaleFactor")));
    win.queue.push(.{ .scale_changed = scale });
}

fn view_dragging_entered(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) objc.NSUInteger {
    if (get_win_from_view(self)) |win| win.queue.push(.file_drop_started);
    return 1; // NSDragOperationCopy
}

fn view_dragging_exited(self: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    if (get_win_from_view(self)) |win| win.queue.push(.file_drop_left);
}

fn view_perform_drag_operation(self: objc.id, _: objc.SEL, sender: objc.id) callconv(.c) objc.BOOL {
    const win = get_win_from_view(self) orelse return objc.NO;
    win.drop_count = 0;

    // Get pasteboard from dragging info.
    const pb = objc.msgSend(objc.id, sender, "draggingPasteboard", .{});

    // Read NSURLs from pasteboard: [pb readObjectsForClasses:options:]
    const url_cls = objc.ns_class("NSURL");
    // Build a single-element NSArray of classes.
    const cls_array = objc.msgSend(objc.id, objc.ns_class("NSArray"), "arrayWithObject:", .{url_cls});
    const urls = objc.msgSend(?objc.id, pb, "readObjectsForClasses:options:", .{ cls_array, @as(?objc.id, null) });
    if (urls) |url_array| {
        const count = objc.msgSend(objc.NSUInteger, url_array, "count", .{});
        var i: objc.NSUInteger = 0;
        while (i < count and win.drop_count < Window.MAX_DROP_FILES) : (i += 1) {
            const FnObjAtIdx = fn (objc.id, objc.SEL, objc.NSUInteger) callconv(.c) objc.id;
            const fn_idx: *const FnObjAtIdx = @ptrCast(&objc.objc_msgSend);
            const url = fn_idx(url_array, objc.sel_registerName("objectAtIndex:"), i);
            const path_str: ?objc.id = objc.msgSend(?objc.id, url, "path", .{});
            if (path_str) |ps| {
                const utf8 = objc.msgSend([*:0]const u8, ps, "UTF8String", .{});
                win.drop_paths[win.drop_count] = utf8;
                win.drop_count += 1;
            }
        }
    }
    win.queue.push(.{ .file_dropped = win.drop_count });
    return objc.YES;
}

// ── macOS hardware keycode → Key ──────────────────────────────────────────────

const macos_keycode = @import("keymap.zig").macos_keycode;
