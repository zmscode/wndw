// ── Style types for the UI framework ─────────────────────────────────
//
// Color, Edges, Len, Style — the data model for visual properties.
// Consumed by Div elements during layout and paint.

pub const Color = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 255,

    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn hex(comptime h: u32) Color {
        return .{
            .r = @truncate(h >> 16),
            .g = @truncate(h >> 8),
            .b = @truncate(h),
            .a = 255,
        };
    }

    /// Normalized [0,1] floats for draw commands.
    pub fn toVec4(self: Color) [4]f32 {
        return .{
            @as(f32, @floatFromInt(self.r)) / 255.0,
            @as(f32, @floatFromInt(self.g)) / 255.0,
            @as(f32, @floatFromInt(self.b)) / 255.0,
            @as(f32, @floatFromInt(self.a)) / 255.0,
        };
    }

    pub fn eql(a: Color, b: Color) bool {
        return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a;
    }
};

pub const Edges = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,

    pub fn all(v: f32) Edges {
        return .{ .top = v, .right = v, .bottom = v, .left = v };
    }

    pub fn xy(x: f32, y: f32) Edges {
        return .{ .top = y, .right = x, .bottom = y, .left = x };
    }

    pub fn horizontal(self: Edges) f32 {
        return self.left + self.right;
    }

    pub fn vertical(self: Edges) f32 {
        return self.top + self.bottom;
    }
};

pub const Len = union(enum) {
    auto,
    px: f32,
    percent: f32,
};

pub const FlexDirection = enum { row, column, row_reverse, column_reverse };
pub const FlexWrap = enum { no_wrap, wrap };
pub const Align = enum { start, end, center, stretch };
pub const Justify = enum { start, end, center, space_between, space_around, space_evenly };
pub const Overflow = enum { visible, hidden, scroll };
pub const Position = enum { relative, absolute };

pub const Style = struct {
    // ── Layout ───────────────────────────────────────────────────────
    direction: FlexDirection = .column,
    align_items: Align = .stretch,
    align_self: ?Align = null,
    justify_content: Justify = .start,
    gap: f32 = 0,

    width: Len = .auto,
    height: Len = .auto,
    min_width: Len = .auto,
    min_height: Len = .auto,
    max_width: Len = .auto,
    max_height: Len = .auto,

    flex_grow: f32 = 0,
    flex_shrink: f32 = 1,

    padding: Edges = .{},
    margin: Edges = .{},

    overflow: Overflow = .visible,
    position: Position = .relative,

    // ── Visual ───────────────────────────────────────────────────────
    background: ?Color = null,
    border_color: ?Color = null,
    border_width: f32 = 0,
    corner_radius: [4]f32 = .{ 0, 0, 0, 0 },
    shadow_color: ?Color = null,
    shadow_blur: f32 = 0,
    shadow_offset: [2]f32 = .{ 0, 0 },
    opacity: f32 = 1.0,
};
