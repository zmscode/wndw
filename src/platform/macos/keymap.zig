/// macOS hardware keycode → Key mapping.
///
/// Table indexed by macOS hardware keycode (0x00–0x7F, 128 entries).
/// Out-of-range keycodes return .unknown.
///
/// Sources: Apple HIToolbox/Events.h, RGFW RGFW_init_keycodes
const event = @import("../../event.zig");
pub const Key = event.Key;

pub fn macos_keycode(kc: u16) Key {
    if (kc >= keycodes.len) return .unknown;
    return keycodes[kc];
}

// 128-entry table. Index = macOS hardware keycode (0x00–0x7F).
const keycodes = [128]Key{
    .a, // 0x00
    .s, // 0x01
    .d, // 0x02
    .f, // 0x03
    .h, // 0x04
    .g, // 0x05
    .z, // 0x06
    .x, // 0x07
    .c, // 0x08
    .v, // 0x09
    .unknown, // 0x0A (ISO extra key)
    .b, // 0x0B
    .q, // 0x0C
    .w, // 0x0D
    .e, // 0x0E
    .r, // 0x0F
    .y, // 0x10
    .t, // 0x11
    .@"1", // 0x12
    .@"2", // 0x13
    .@"3", // 0x14
    .@"4", // 0x15
    .@"6", // 0x16
    .@"5", // 0x17
    .equal, // 0x18  =
    .@"9", // 0x19
    .@"7", // 0x1A
    .minus, // 0x1B  -
    .@"8", // 0x1C
    .@"0", // 0x1D
    .right_bracket, // 0x1E  ]
    .o, // 0x1F
    .u, // 0x20
    .left_bracket, // 0x21  [
    .i, // 0x22
    .p, // 0x23
    .enter, // 0x24
    .l, // 0x25
    .j, // 0x26
    .apostrophe, // 0x27  '
    .k, // 0x28
    .semicolon, // 0x29  ;
    .backslash, // 0x2A  \
    .comma, // 0x2B  ,
    .slash, // 0x2C  /
    .n, // 0x2D
    .m, // 0x2E
    .period, // 0x2F  .
    .tab, // 0x30
    .space, // 0x31
    .grave, // 0x32  `
    .backspace, // 0x33
    .unknown, // 0x34
    .escape, // 0x35
    .right_super, // 0x36
    .left_super, // 0x37
    .left_shift, // 0x38
    .caps_lock, // 0x39
    .left_alt, // 0x3A
    .left_ctrl, // 0x3B
    .right_shift, // 0x3C
    .right_alt, // 0x3D
    .right_ctrl, // 0x3E
    .unknown, // 0x3F  (fn key)
    .unknown, // 0x40
    .kp_decimal, // 0x41
    .unknown, // 0x42
    .kp_multiply, // 0x43
    .unknown, // 0x44
    .kp_add, // 0x45
    .unknown, // 0x46
    .num_lock, // 0x47  (kp clear on Mac)
    .unknown, // 0x48
    .unknown, // 0x49
    .unknown, // 0x4A
    .kp_divide, // 0x4B
    .kp_enter, // 0x4C
    .unknown, // 0x4D
    .kp_subtract, // 0x4E
    .unknown, // 0x4F
    .unknown, // 0x50
    .kp_equal, // 0x51
    .kp_0, // 0x52
    .kp_1, // 0x53
    .kp_2, // 0x54
    .kp_3, // 0x55
    .kp_4, // 0x56
    .kp_5, // 0x57
    .kp_6, // 0x58
    .kp_7, // 0x59
    .unknown, // 0x5A
    .kp_8, // 0x5B
    .kp_9, // 0x5C
    .unknown, // 0x5D
    .unknown, // 0x5E
    .unknown, // 0x5F
    .f5, // 0x60
    .f6, // 0x61
    .f7, // 0x62
    .f3, // 0x63
    .f8, // 0x64
    .f9, // 0x65
    .unknown, // 0x66
    .f11, // 0x67
    .unknown, // 0x68
    .print_screen, // 0x69
    .unknown, // 0x6A
    .scroll_lock, // 0x6B
    .unknown, // 0x6C
    .f10, // 0x6D
    .menu, // 0x6E
    .f12, // 0x6F
    .unknown, // 0x70
    .pause, // 0x71
    .insert, // 0x72  (help on Mac)
    .home, // 0x73
    .page_up, // 0x74
    .delete, // 0x75
    .f4, // 0x76
    .end, // 0x77
    .f2, // 0x78
    .page_down, // 0x79
    .f1, // 0x7A
    .left, // 0x7B
    .right, // 0x7C
    .down, // 0x7D
    .up, // 0x7E
    .unknown, // 0x7F
};
