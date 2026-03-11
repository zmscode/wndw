// ── Shared render types ─────────────────────────────────────────────
//
// Types shared between the platform-agnostic UI layer and the
// platform-specific renderer. This file is a standalone module
// ("render_types") to avoid circular dependencies.

/// A rounded rectangle with background, border, and shadow.
pub const QuadCmd = struct {
    bounds: [4]f32, // x, y, w, h
    bg: [4]f32 = .{ 0, 0, 0, 0 }, // r, g, b, a (normalized)
    border_color: [4]f32 = .{ 0, 0, 0, 0 },
    border_width: f32 = 0,
    corner_radii: [4]f32 = .{ 0, 0, 0, 0 }, // TL, TR, BR, BL
    shadow_color: [4]f32 = .{ 0, 0, 0, 0 },
    shadow_blur: f32 = 0,
    shadow_offset: [2]f32 = .{ 0, 0 },
    clip_index: i32 = -1,
};

pub const ClipCmd = struct {
    bounds: [4]f32, // x, y, w, h
};

/// A text run to be drawn by the renderer.
pub const TextCmd = struct {
    text: []const u8, // UTF-8 string (valid for frame lifetime)
    bounds: [4]f32, // x, y, w, h
    color: [4]f32, // r, g, b, a (normalized)
    font_size: f32,
    weight: u8, // FontWeight ordinal
    clip_index: i32 = -1,
};

/// Metrics returned by text measurement.
pub const TextMetrics = struct {
    width: f32,
    height: f32,
    ascent: f32,
    descent: f32,
};

/// Platform-provided text measurement interface.
pub const TextMeasurer = struct {
    ctx: *anyopaque,
    measure_fn: *const fn (ctx: *anyopaque, text: []const u8, font_size: f32, weight: u8, max_width: f32) TextMetrics,

    pub fn measure(self: TextMeasurer, text: []const u8, font_size: f32, weight: u8, max_width: f32) TextMetrics {
        return self.measure_fn(self.ctx, text, font_size, weight, max_width);
    }
};

/// Cached glyph location within the atlas bitmap.
pub const GlyphInfo = struct {
    atlas_x: u16,
    atlas_y: u16,
    width: u16,
    height: u16,
    bearing_x: f32,
    bearing_y: f32,
    advance: f32,
};
