// ── macOS Native Renderer (CoreGraphics) ────────────────────────────
//
// Platform-specific rendering backend. Draws QuadCmd list from the
// UI framework's draw list using CoreGraphics APIs.
//
// This file lives in platform/macos/ because it uses CG extern fns.
// The UI layer accesses it via comptime platform dispatch in
// ui/render/backend.zig, keeping everything above platform/ agnostic.

const std = @import("std");
const objc = @import("objc.zig");
const types = @import("render_types");

// ── CoreGraphics extern fns ─────────────────────────────────────────

const CGContextRef = *anyopaque;
const CGColorRef = *anyopaque;
const CGPathRef = *const anyopaque;

const CGRect = extern struct { x: f64, y: f64, w: f64, h: f64 };
const CGSize = extern struct { w: f64, h: f64 };

extern "c" fn CGContextSaveGState(ctx: CGContextRef) void;
extern "c" fn CGContextRestoreGState(ctx: CGContextRef) void;
extern "c" fn CGContextSetRGBFillColor(ctx: CGContextRef, r: f64, g: f64, b: f64, a: f64) void;
extern "c" fn CGContextSetRGBStrokeColor(ctx: CGContextRef, r: f64, g: f64, b: f64, a: f64) void;
extern "c" fn CGContextSetLineWidth(ctx: CGContextRef, width: f64) void;
extern "c" fn CGContextFillPath(ctx: CGContextRef) void;
extern "c" fn CGContextStrokePath(ctx: CGContextRef) void;
extern "c" fn CGContextClipToRect(ctx: CGContextRef, rect: CGRect) void;
extern "c" fn CGContextTranslateCTM(ctx: CGContextRef, tx: f64, ty: f64) void;
extern "c" fn CGContextScaleCTM(ctx: CGContextRef, sx: f64, sy: f64) void;
extern "c" fn CGContextSetShadowWithColor(ctx: CGContextRef, offset: CGSize, blur: f64, color: ?CGColorRef) void;
extern "c" fn CGColorCreateGenericRGB(r: f64, g: f64, b: f64, a: f64) CGColorRef;
extern "c" fn CGColorRelease(color: CGColorRef) void;
extern "c" fn CGPathCreateWithRoundedRect(rect: CGRect, corner_w: f64, corner_h: f64, transform: ?*const anyopaque) CGPathRef;
extern "c" fn CGContextAddPath(ctx: CGContextRef, path: CGPathRef) void;
extern "c" fn CGPathRelease(path: CGPathRef) void;

// ── Renderer ────────────────────────────────────────────────────────

pub const Renderer = struct {
    gpa: std.mem.Allocator,

    pub fn init(gpa: std.mem.Allocator) Renderer {
        return .{ .gpa = gpa };
    }

    /// Draw all quads into the current NSGraphicsContext.
    /// Must be called from within drawRect: (i.e. a valid CG context exists).
    pub fn flush(
        self: *Renderer,
        quads: []const types.QuadCmd,
        clips: []const types.ClipCmd,
        view_height: f64,
    ) void {
        _ = self;

        // Get current CGContext from NSGraphicsContext
        const ns_gfx_class = objc.objc_getClass("NSGraphicsContext") orelse return;
        const ns_gfx_ctx = objc.msgSend(objc.id, ns_gfx_class, "currentContext", .{});
        const cg_ctx: CGContextRef = objc.msgSend(CGContextRef, ns_gfx_ctx, "CGContext", .{});

        // Flip coordinate system: CG is bottom-left, we use top-left
        CGContextSaveGState(cg_ctx);
        CGContextTranslateCTM(cg_ctx, 0, view_height);
        CGContextScaleCTM(cg_ctx, 1, -1);

        for (quads) |quad| {
            drawQuad(cg_ctx, quad, clips);
        }

        CGContextRestoreGState(cg_ctx);
    }

    fn drawQuad(ctx: CGContextRef, q: types.QuadCmd, clips: []const types.ClipCmd) void {
        CGContextSaveGState(ctx);

        // Clip
        if (q.clip_index >= 0) {
            const clip = clips[@intCast(q.clip_index)];
            CGContextClipToRect(ctx, .{
                .x = @floatCast(clip.bounds[0]),
                .y = @floatCast(clip.bounds[1]),
                .w = @floatCast(clip.bounds[2]),
                .h = @floatCast(clip.bounds[3]),
            });
        }

        const rect = CGRect{
            .x = @floatCast(q.bounds[0]),
            .y = @floatCast(q.bounds[1]),
            .w = @floatCast(q.bounds[2]),
            .h = @floatCast(q.bounds[3]),
        };

        // Average corner radius
        const radius: f64 = @floatCast((q.corner_radii[0] + q.corner_radii[1] +
            q.corner_radii[2] + q.corner_radii[3]) / 4.0);

        // Shadow
        if (q.shadow_blur > 0) {
            const shadow_cg = CGColorCreateGenericRGB(
                @floatCast(q.shadow_color[0]),
                @floatCast(q.shadow_color[1]),
                @floatCast(q.shadow_color[2]),
                @floatCast(q.shadow_color[3]),
            );
            defer CGColorRelease(shadow_cg);
            CGContextSetShadowWithColor(ctx, .{
                .w = @floatCast(q.shadow_offset[0]),
                .h = @floatCast(q.shadow_offset[1]),
            }, @floatCast(q.shadow_blur), shadow_cg);
        }

        // Background fill
        if (q.bg[3] > 0) {
            const path = CGPathCreateWithRoundedRect(rect, radius, radius, null);
            defer CGPathRelease(path);
            CGContextAddPath(ctx, path);
            CGContextSetRGBFillColor(ctx, q.bg[0], q.bg[1], q.bg[2], q.bg[3]);
            CGContextFillPath(ctx);
        }

        // Border stroke
        if (q.border_width > 0) {
            const path = CGPathCreateWithRoundedRect(rect, radius, radius, null);
            defer CGPathRelease(path);
            CGContextAddPath(ctx, path);
            CGContextSetRGBStrokeColor(
                ctx,
                q.border_color[0],
                q.border_color[1],
                q.border_color[2],
                q.border_color[3],
            );
            CGContextSetLineWidth(ctx, @floatCast(q.border_width));
            CGContextStrokePath(ctx);
        }

        CGContextRestoreGState(ctx);
    }

    pub fn deinit(self: *Renderer) void {
        _ = self;
    }
};
