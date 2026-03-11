// ── Theme ────────────────────────────────────────────────────────────
//
// Semantic color tokens for consistent styling across components.
// Provides dark and light presets. Components reference theme colors
// instead of hardcoded hex values.

const style = @import("style.zig");
pub const Color = style.Color;

pub const Theme = struct {
    bg: Color,
    surface: Color,
    text: Color,
    muted: Color,
    border: Color,
    primary: Color,
    danger: Color,
    success: Color,
    warning: Color,

    pub const dark = Theme{
        .bg = Color.hex(0x1E1E2E),
        .surface = Color.hex(0x313244),
        .text = Color.hex(0xCDD6F4),
        .muted = Color.hex(0xA6ADC8),
        .border = Color.hex(0x45475A),
        .primary = Color.hex(0x89B4FA),
        .danger = Color.hex(0xF38BA8),
        .success = Color.hex(0xA6E3A1),
        .warning = Color.hex(0xF9E2AF),
    };

    pub const light = Theme{
        .bg = Color.hex(0xEFF1F5),
        .surface = Color.hex(0xCCD0DA),
        .text = Color.hex(0x4C4F69),
        .muted = Color.hex(0x6C6F85),
        .border = Color.hex(0xBCC0CC),
        .primary = Color.hex(0x1E66F5),
        .danger = Color.hex(0xD20F39),
        .success = Color.hex(0x40A02B),
        .warning = Color.hex(0xDF8E1D),
    };
};
