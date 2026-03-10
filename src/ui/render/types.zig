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
