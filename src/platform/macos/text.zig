// ── macOS Text Backend ───────────────────────────────────────────────
//
// Platform-specific text measurement and glyph rasterization using
// CoreText. Provides the TextMeasurer interface consumed by the
// platform-agnostic UI layer.

const std = @import("std");
const ct = @import("coretext.zig");
const render_types = @import("render_types");

pub const TextMeasurer = render_types.TextMeasurer;
pub const TextMetrics = render_types.TextMetrics;
pub const GlyphInfo = render_types.GlyphInfo;

// ── GlyphKey ────────────────────────────────────────────────────────

pub const GlyphKey = struct {
    glyph_id: u16,
    /// Font size quantized to tenths of a point (size * 10).
    font_size_x10: u16,
    weight: u8,
};

// ── FontCache ───────────────────────────────────────────────────────

/// Caches CTFont objects by (size_x10, weight) to avoid repeated creation.
const FontKey = struct { size_x10: u16, weight: u8 };

// ── GlyphAtlas ──────────────────────────────────────────────────────

pub const GlyphAtlas = struct {
    pixels: []u8,
    atlas_width: u32,
    atlas_height: u32,
    cursor_x: u32 = 0,
    cursor_y: u32 = 0,
    shelf_height: u32 = 0,
    cache: std.AutoHashMap(GlyphKey, GlyphInfo),
    font_cache: std.AutoHashMap(FontKey, ct.CTFontRef),
    gpa: std.mem.Allocator,

    pub fn init(gpa: std.mem.Allocator) GlyphAtlas {
        const w: u32 = 1024;
        const h: u32 = 1024;
        const pixels = gpa.alloc(u8, w * h) catch unreachable;
        @memset(pixels, 0);
        return .{
            .pixels = pixels,
            .atlas_width = w,
            .atlas_height = h,
            .cache = std.AutoHashMap(GlyphKey, GlyphInfo).init(gpa),
            .font_cache = std.AutoHashMap(FontKey, ct.CTFontRef).init(gpa),
            .gpa = gpa,
        };
    }

    pub fn deinit(self: *GlyphAtlas) void {
        var font_it = self.font_cache.valueIterator();
        while (font_it.next()) |font_ptr| {
            ct.CFRelease(font_ptr.*);
        }
        self.font_cache.deinit();
        self.cache.deinit();
        self.gpa.free(self.pixels);
    }

    /// Get or create a CTFont for the given size and weight.
    pub fn getFont(self: *GlyphAtlas, size: f32, weight: u8) ct.CTFontRef {
        const key = FontKey{ .size_x10 = @intFromFloat(size * 10), .weight = weight };
        if (self.font_cache.get(key)) |font| return font;

        // Create system font at the requested size
        const font = ct.createSystemFont(@floatCast(size));
        self.font_cache.put(key, font) catch unreachable;
        return font;
    }

    /// Look up a cached glyph or rasterize it into the atlas.
    pub fn getOrRasterize(self: *GlyphAtlas, key: GlyphKey, font: ct.CTFontRef) GlyphInfo {
        if (self.cache.get(key)) |info| return info;

        // Get glyph bounding rect
        const rect = ct.getBoundingRect(font, key.glyph_id);
        const advance = ct.getAdvance(font, key.glyph_id);

        // Bitmap dimensions (add 2px padding for antialiasing)
        const gw: u32 = @intFromFloat(@ceil(@abs(rect.w)) + 2);
        const gh: u32 = @intFromFloat(@ceil(@abs(rect.h)) + 2);

        if (gw == 0 or gh == 0) {
            // Whitespace glyph — no bitmap needed
            const info = GlyphInfo{
                .atlas_x = 0,
                .atlas_y = 0,
                .width = 0,
                .height = 0,
                .bearing_x = @floatCast(rect.x),
                .bearing_y = @floatCast(rect.y + rect.h),
                .advance = @floatCast(advance),
            };
            self.cache.put(key, info) catch unreachable;
            return info;
        }

        // Ensure atlas has room
        if (self.cursor_x + gw > self.atlas_width) {
            // Next shelf
            self.cursor_x = 0;
            self.cursor_y += self.shelf_height;
            self.shelf_height = 0;
        }
        if (self.cursor_y + gh > self.atlas_height) {
            self.growAtlas();
        }

        // Rasterize into a temporary buffer
        const colorspace = ct.CGColorSpaceCreateDeviceGray();
        defer ct.CGColorSpaceRelease(colorspace);

        const tmp_buf = self.gpa.alloc(u8, gw * gh) catch unreachable;
        defer self.gpa.free(tmp_buf);
        @memset(tmp_buf, 0);

        const tmp_ctx = ct.CGBitmapContextCreate(
            tmp_buf.ptr,
            gw,
            gh,
            8,
            gw,
            colorspace,
            0, // kCGImageAlphaOnly is not valid for grayscale; 0 = kCGImageAlphaNone
        ) orelse {
            // Fallback: return empty glyph
            const info = GlyphInfo{
                .atlas_x = 0,
                .atlas_y = 0,
                .width = 0,
                .height = 0,
                .bearing_x = @floatCast(rect.x),
                .bearing_y = @floatCast(rect.y + rect.h),
                .advance = @floatCast(advance),
            };
            self.cache.put(key, info) catch unreachable;
            return info;
        };

        // White fill color so the glyph renders as white on black
        ct.CGContextSetRGBFillColor(tmp_ctx, 1, 1, 1, 1);

        // Position: the bounding rect origin is relative to the glyph origin.
        // We need to offset so the glyph draws within our buffer.
        const pos = [1]ct.CGPoint{.{
            .x = -rect.x + 1, // +1 for padding
            .y = -rect.y + 1,
        }};
        var glyphs = [1]ct.CGGlyph{key.glyph_id};
        ct.CTFontDrawGlyphs(font, &glyphs, &pos, 1, tmp_ctx);

        // Copy to atlas
        const ax = self.cursor_x;
        const ay = self.cursor_y;
        for (0..gh) |row| {
            const src_start = row * gw;
            const dst_start = (ay + @as(u32, @intCast(row))) * self.atlas_width + ax;
            @memcpy(
                self.pixels[dst_start..][0..gw],
                tmp_buf[src_start..][0..gw],
            );
        }

        // Advance cursor
        self.cursor_x += gw;
        self.shelf_height = @max(self.shelf_height, gh);

        const info = GlyphInfo{
            .atlas_x = @intCast(ax),
            .atlas_y = @intCast(ay),
            .width = @intCast(gw),
            .height = @intCast(gh),
            .bearing_x = @floatCast(rect.x - 1), // account for padding
            .bearing_y = @floatCast(rect.y + rect.h + 1),
            .advance = @floatCast(advance),
        };
        self.cache.put(key, info) catch unreachable;
        return info;
    }

    fn growAtlas(self: *GlyphAtlas) void {
        const new_h = self.atlas_height * 2;
        const new_pixels = self.gpa.alloc(u8, self.atlas_width * new_h) catch unreachable;
        @memset(new_pixels, 0);
        @memcpy(new_pixels[0..self.pixels.len], self.pixels);
        self.gpa.free(self.pixels);
        self.pixels = new_pixels;
        self.atlas_height = new_h;
    }
};

// ── TextMeasurer implementation ─────────────────────────────────────

pub const MacTextBackend = struct {
    atlas: GlyphAtlas,

    pub fn init(gpa: std.mem.Allocator) MacTextBackend {
        return .{ .atlas = GlyphAtlas.init(gpa) };
    }

    pub fn deinit(self: *MacTextBackend) void {
        self.atlas.deinit();
    }

    pub fn measurer(self: *MacTextBackend) TextMeasurer {
        return .{
            .ctx = @ptrCast(self),
            .measure_fn = &measureText,
        };
    }

    fn measureText(ctx: *anyopaque, txt: []const u8, font_size: f32, weight: u8, max_width: f32) TextMetrics {
        const self: *MacTextBackend = @ptrCast(@alignCast(ctx));
        const font = self.atlas.getFont(font_size, weight);

        const ascent: f32 = @floatCast(ct.CTFontGetAscent(font));
        const descent: f32 = @floatCast(ct.CTFontGetDescent(font));
        const line_height = ascent + descent;

        // Measure width by summing glyph advances
        var width: f32 = 0;
        const size_x10: u16 = @intFromFloat(font_size * 10);
        var iter = std.unicode.Utf8View.initUnchecked(txt).iterator();
        while (iter.nextCodepoint()) |cp| {
            const glyph_id = ct.getGlyph(font, cp);
            const key = GlyphKey{ .glyph_id = glyph_id, .font_size_x10 = size_x10, .weight = weight };
            const info = self.atlas.getOrRasterize(key, font);
            width += info.advance;
            if (width > max_width) {
                width = max_width;
                break;
            }
        }

        return .{
            .width = width,
            .height = line_height,
            .ascent = ascent,
            .descent = descent,
        };
    }
};
