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
const ct = @import("coretext.zig");
const text_backend = @import("text.zig");

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
extern "c" fn CGContextFillRect(ctx: CGContextRef, rect: CGRect) void;

// ── Renderer ────────────────────────────────────────────────────────

pub const Renderer = struct {
    gpa: std.mem.Allocator,
    text: text_backend.MacTextBackend,

    pub fn init(gpa: std.mem.Allocator) Renderer {
        return .{
            .gpa = gpa,
            .text = text_backend.MacTextBackend.init(gpa),
        };
    }

    /// Get the text measurer interface for the UI layer.
    pub fn textMeasurer(self: *Renderer) types.TextMeasurer {
        return self.text.measurer();
    }

    /// Draw all quads and text into the current NSGraphicsContext.
    /// Must be called from within drawRect: (i.e. a valid CG context exists).
    pub fn flush(
        self: *Renderer,
        quads: []const types.QuadCmd,
        clips: []const types.ClipCmd,
        texts: []const types.TextCmd,
        view_height: f64,
    ) void {
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

        for (texts) |txt| {
            self.drawText(cg_ctx, txt, clips);
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

    fn drawText(self: *Renderer, ctx: CGContextRef, t: types.TextCmd, clips: []const types.ClipCmd) void {
        CGContextSaveGState(ctx);

        // Clip
        if (t.clip_index >= 0) {
            const clip = clips[@intCast(t.clip_index)];
            CGContextClipToRect(ctx, .{
                .x = @floatCast(clip.bounds[0]),
                .y = @floatCast(clip.bounds[1]),
                .w = @floatCast(clip.bounds[2]),
                .h = @floatCast(clip.bounds[3]),
            });
        }

        const font = self.text.atlas.getFont(t.font_size, t.weight);
        const ascent: f64 = ct.CTFontGetAscent(font);
        const size_x10: u16 = @intFromFloat(t.font_size * 10);

        // Baseline position in our top-down coordinate system
        var pen_x: f64 = @floatCast(t.bounds[0]);
        const baseline_y: f64 = @as(f64, @floatCast(t.bounds[1])) + ascent;
        const max_x: f64 = @floatCast(t.bounds[0] + t.bounds[2]);

        // Set text color
        CGContextSetRGBFillColor(ctx, t.color[0], t.color[1], t.color[2], t.color[3]);

        // Collect glyphs and positions, then batch-draw with CTFontDrawGlyphs.
        // CTFontDrawGlyphs uses CG's native bottom-up coordinate system, so
        // we locally unflip the context for the draw call.
        var glyphs: [512]ct.CGGlyph = undefined;
        var positions: [512]ct.CGPoint = undefined;
        var count: usize = 0;

        var iter = std.unicode.Utf8View.initUnchecked(t.text).iterator();
        while (iter.nextCodepoint()) |cp| {
            if (count >= 512) break;
            const glyph_id = ct.getGlyph(font, cp);
            glyphs[count] = glyph_id;

            // In the locally-unflipped sub-context (see below), y is negated.
            // Position: (pen_x, -baseline_y) in the unflipped space.
            positions[count] = .{ .x = pen_x, .y = -baseline_y };

            // Get advance from measurement cache
            const key = text_backend.GlyphKey{
                .glyph_id = glyph_id,
                .font_size_x10 = size_x10,
                .weight = t.weight,
            };
            const info = self.text.atlas.getOrRasterize(key, font);
            pen_x += @floatCast(info.advance);
            count += 1;

            if (pen_x > max_x) break;
        }

        if (count > 0) {
            // The flush() context is flipped (top-down). CTFontDrawGlyphs
            // draws in CG's native bottom-up system, so glyphs would render
            // upside-down. Locally unflip with scale(1, -1) — positions
            // have their y values negated to compensate.
            CGContextScaleCTM(ctx, 1, -1);
            ct.CTFontDrawGlyphs(font, &glyphs, &positions, count, ctx);
        }

        CGContextRestoreGState(ctx);
    }

    pub fn deinit(self: *Renderer) void {
        self.text.deinit();
    }
};
