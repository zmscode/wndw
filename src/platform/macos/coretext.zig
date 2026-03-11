// ── CoreText extern fn declarations ──────────────────────────────────
//
// Minimal set of CoreText/CoreGraphics functions needed for text
// shaping, measurement, and glyph rasterization. No SDK headers
// required — these are resolved by linking CoreText.framework.

const objc = @import("objc.zig");

// ── Opaque types ────────────────────────────────────────────────────

pub const CTFontRef = *anyopaque;
pub const CFStringRef = *anyopaque;
pub const CGGlyph = u16;
pub const UniChar = u16;
pub const CGContextRef = *anyopaque;
pub const CGImageRef = *anyopaque;
pub const CGColorSpaceRef = *anyopaque;

pub const CGPoint = extern struct { x: f64, y: f64 };
pub const CGSize = extern struct { width: f64, height: f64 };
pub const CGRect = extern struct { x: f64, y: f64, w: f64, h: f64 };

// ── Font creation ───────────────────────────────────────────────────

pub extern "c" fn CTFontCreateWithName(name: CFStringRef, size: f64, matrix: ?*const anyopaque) CTFontRef;

// ── Glyph mapping ───────────────────────────────────────────────────

pub extern "c" fn CTFontGetGlyphsForCharacters(font: CTFontRef, characters: [*]const UniChar, glyphs: [*]CGGlyph, count: isize) bool;

// ── Font metrics ────────────────────────────────────────────────────

pub extern "c" fn CTFontGetAscent(font: CTFontRef) f64;
pub extern "c" fn CTFontGetDescent(font: CTFontRef) f64;
pub extern "c" fn CTFontGetLeading(font: CTFontRef) f64;

// ── Per-glyph metrics ───────────────────────────────────────────────

/// orientation: 0 = kCTFontOrientationDefault
pub extern "c" fn CTFontGetAdvancesForGlyphs(font: CTFontRef, orientation: i32, glyphs: [*]const CGGlyph, advances: ?[*]CGSize, count: isize) f64;
pub extern "c" fn CTFontGetBoundingRectsForGlyphs(font: CTFontRef, orientation: i32, glyphs: [*]const CGGlyph, bounding_rects: ?[*]CGRect, count: isize) CGRect;

// ── Glyph drawing ───────────────────────────────────────────────────

pub extern "c" fn CTFontDrawGlyphs(font: CTFontRef, glyphs: [*]const CGGlyph, positions: [*]const CGPoint, count: usize, context: CGContextRef) void;

// ── Bitmap context for rasterization ────────────────────────────────

pub extern "c" fn CGBitmapContextCreate(data: ?[*]u8, width: usize, height: usize, bits_per_component: usize, bytes_per_row: usize, colorspace: ?CGColorSpaceRef, bitmap_info: u32) ?CGContextRef;
pub extern "c" fn CGBitmapContextCreateImage(ctx: CGContextRef) ?CGImageRef;
pub extern "c" fn CGColorSpaceCreateDeviceGray() CGColorSpaceRef;
pub extern "c" fn CGColorSpaceRelease(cs: CGColorSpaceRef) void;

// ── Drawing into CG context ─────────────────────────────────────────

pub extern "c" fn CGContextSetRGBFillColor(ctx: CGContextRef, r: f64, g: f64, b: f64, a: f64) void;
pub extern "c" fn CGContextFillRect(ctx: CGContextRef, rect: CGRect) void;
pub extern "c" fn CGContextClipToMask(ctx: CGContextRef, rect: CGRect, mask: CGImageRef) void;
pub extern "c" fn CGContextSaveGState(ctx: CGContextRef) void;
pub extern "c" fn CGContextRestoreGState(ctx: CGContextRef) void;
pub extern "c" fn CGContextTranslateCTM(ctx: CGContextRef, tx: f64, ty: f64) void;
pub extern "c" fn CGContextScaleCTM(ctx: CGContextRef, sx: f64, sy: f64) void;

// ── Image ───────────────────────────────────────────────────────────

pub extern "c" fn CGImageRelease(image: CGImageRef) void;
pub extern "c" fn CGImageCreateWithImageInRect(image: CGImageRef, rect: CGRect) ?CGImageRef;

// ── CoreFoundation ──────────────────────────────────────────────────

pub extern "c" fn CFRelease(cf: *anyopaque) void;

// ── Helpers ─────────────────────────────────────────────────────────

/// Create a CTFont for the system UI font at the given size.
/// Uses toll-free bridging: NSString* == CFStringRef.
pub fn createSystemFont(size: f64) CTFontRef {
    // ".AppleSystemUIFont" is the private name for the system font
    const name = objc.ns_string(".AppleSystemUIFont");
    return CTFontCreateWithName(@ptrCast(name), size, null);
}

/// Map a single Unicode codepoint to a glyph ID.
pub fn getGlyph(font: CTFontRef, codepoint: u21) CGGlyph {
    if (codepoint <= 0xFFFF) {
        // BMP — single UTF-16 code unit
        var ch: [1]UniChar = .{@intCast(codepoint)};
        var glyph: [1]CGGlyph = .{0};
        _ = CTFontGetGlyphsForCharacters(font, &ch, &glyph, 1);
        return glyph[0];
    } else {
        // Supplementary plane — surrogate pair
        const cp = codepoint - 0x10000;
        var ch: [2]UniChar = .{
            @intCast(0xD800 + (cp >> 10)),
            @intCast(0xDC00 + (cp & 0x3FF)),
        };
        var glyph: [1]CGGlyph = .{0};
        _ = CTFontGetGlyphsForCharacters(font, &ch, &glyph, 2);
        return glyph[0];
    }
}

/// Get the horizontal advance for a single glyph.
pub fn getAdvance(font: CTFontRef, glyph_id: CGGlyph) f64 {
    var glyphs = [1]CGGlyph{glyph_id};
    var advances = [1]CGSize{.{ .width = 0, .height = 0 }};
    _ = CTFontGetAdvancesForGlyphs(font, 0, &glyphs, &advances, 1);
    return advances[0].width;
}

/// Get the bounding rect for a single glyph.
pub fn getBoundingRect(font: CTFontRef, glyph_id: CGGlyph) CGRect {
    var glyphs = [1]CGGlyph{glyph_id};
    var rects = [1]CGRect{.{ .x = 0, .y = 0, .w = 0, .h = 0 }};
    _ = CTFontGetBoundingRectsForGlyphs(font, 0, &glyphs, &rects, 1);
    return rects[0];
}
