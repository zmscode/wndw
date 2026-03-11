// ── Scroll State ─────────────────────────────────────────────────────
//
// Tracks scroll offset for scroll containers. Can be stored in an
// EntityPool for retained scroll position across frames.
//
// ScrollState is purely logical — the element tree applies the offset
// during layout/paint by translating child positions.

pub const ScrollState = struct {
    offset_x: f32 = 0,
    offset_y: f32 = 0,

    /// Add a delta to the current scroll offset.
    pub fn scrollBy(self: *ScrollState, dx: f32, dy: f32) void {
        self.offset_x += dx;
        self.offset_y += dy;
    }

    /// Clamp scroll offset so content stays within bounds.
    /// content_h is the total height of scrollable content.
    /// viewport_h is the visible area height.
    pub fn clamp(self: *ScrollState, content_h: f32, viewport_h: f32) void {
        const max_y = @max(content_h - viewport_h, 0);
        self.offset_y = @max(@min(self.offset_y, max_y), 0);
    }

    /// Reset scroll to top.
    pub fn scrollToTop(self: *ScrollState) void {
        self.offset_y = 0;
    }
};
