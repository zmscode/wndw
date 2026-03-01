const std = @import("std");
const keymap = @import("../platform/macos/keymap.zig");
const Key = keymap.Key;

test "letter keys" {
    try std.testing.expectEqual(Key.a, keymap.macos_keycode(0x00));
    try std.testing.expectEqual(Key.s, keymap.macos_keycode(0x01));
    try std.testing.expectEqual(Key.d, keymap.macos_keycode(0x02));
    try std.testing.expectEqual(Key.k, keymap.macos_keycode(0x28));
    try std.testing.expectEqual(Key.z, keymap.macos_keycode(0x06));
    try std.testing.expectEqual(Key.q, keymap.macos_keycode(0x0C));
    try std.testing.expectEqual(Key.w, keymap.macos_keycode(0x0D));
}

test "digit keys" {
    try std.testing.expectEqual(Key.@"1", keymap.macos_keycode(0x12));
    try std.testing.expectEqual(Key.@"2", keymap.macos_keycode(0x13));
    try std.testing.expectEqual(Key.@"3", keymap.macos_keycode(0x14));
    try std.testing.expectEqual(Key.@"4", keymap.macos_keycode(0x15));
    try std.testing.expectEqual(Key.@"5", keymap.macos_keycode(0x17));
    try std.testing.expectEqual(Key.@"6", keymap.macos_keycode(0x16));
    try std.testing.expectEqual(Key.@"7", keymap.macos_keycode(0x1A));
    try std.testing.expectEqual(Key.@"8", keymap.macos_keycode(0x1C));
    try std.testing.expectEqual(Key.@"9", keymap.macos_keycode(0x19));
    try std.testing.expectEqual(Key.@"0", keymap.macos_keycode(0x1D));
}

test "escape key" {
    try std.testing.expectEqual(Key.escape, keymap.macos_keycode(0x35));
}

test "enter space tab backspace delete" {
    try std.testing.expectEqual(Key.enter, keymap.macos_keycode(0x24));
    try std.testing.expectEqual(Key.space, keymap.macos_keycode(0x31));
    try std.testing.expectEqual(Key.tab, keymap.macos_keycode(0x30));
    try std.testing.expectEqual(Key.backspace, keymap.macos_keycode(0x33));
    try std.testing.expectEqual(Key.delete, keymap.macos_keycode(0x75));
}

test "arrow keys" {
    try std.testing.expectEqual(Key.left, keymap.macos_keycode(0x7B));
    try std.testing.expectEqual(Key.right, keymap.macos_keycode(0x7C));
    try std.testing.expectEqual(Key.down, keymap.macos_keycode(0x7D));
    try std.testing.expectEqual(Key.up, keymap.macos_keycode(0x7E));
}

test "navigation keys" {
    try std.testing.expectEqual(Key.home, keymap.macos_keycode(0x73));
    try std.testing.expectEqual(Key.end, keymap.macos_keycode(0x77));
    try std.testing.expectEqual(Key.page_up, keymap.macos_keycode(0x74));
    try std.testing.expectEqual(Key.page_down, keymap.macos_keycode(0x79));
    try std.testing.expectEqual(Key.insert, keymap.macos_keycode(0x72)); // help on Mac
}

test "function keys" {
    try std.testing.expectEqual(Key.f1, keymap.macos_keycode(0x7A));
    try std.testing.expectEqual(Key.f2, keymap.macos_keycode(0x78));
    try std.testing.expectEqual(Key.f3, keymap.macos_keycode(0x63));
    try std.testing.expectEqual(Key.f4, keymap.macos_keycode(0x76));
    try std.testing.expectEqual(Key.f5, keymap.macos_keycode(0x60));
    try std.testing.expectEqual(Key.f6, keymap.macos_keycode(0x61));
    try std.testing.expectEqual(Key.f7, keymap.macos_keycode(0x62));
    try std.testing.expectEqual(Key.f8, keymap.macos_keycode(0x64));
    try std.testing.expectEqual(Key.f9, keymap.macos_keycode(0x65));
    try std.testing.expectEqual(Key.f10, keymap.macos_keycode(0x6D));
    try std.testing.expectEqual(Key.f11, keymap.macos_keycode(0x67));
    try std.testing.expectEqual(Key.f12, keymap.macos_keycode(0x6F));
}

test "modifier keys" {
    try std.testing.expectEqual(Key.left_shift, keymap.macos_keycode(0x38));
    try std.testing.expectEqual(Key.right_shift, keymap.macos_keycode(0x3C));
    try std.testing.expectEqual(Key.left_ctrl, keymap.macos_keycode(0x3B));
    try std.testing.expectEqual(Key.right_ctrl, keymap.macos_keycode(0x3E));
    try std.testing.expectEqual(Key.left_alt, keymap.macos_keycode(0x3A));
    try std.testing.expectEqual(Key.right_alt, keymap.macos_keycode(0x3D));
    try std.testing.expectEqual(Key.left_super, keymap.macos_keycode(0x37));
    try std.testing.expectEqual(Key.right_super, keymap.macos_keycode(0x36));
    try std.testing.expectEqual(Key.caps_lock, keymap.macos_keycode(0x39));
}

test "numpad keys" {
    try std.testing.expectEqual(Key.kp_0, keymap.macos_keycode(0x52));
    try std.testing.expectEqual(Key.kp_1, keymap.macos_keycode(0x53));
    try std.testing.expectEqual(Key.kp_9, keymap.macos_keycode(0x5C));
    try std.testing.expectEqual(Key.kp_decimal, keymap.macos_keycode(0x41));
    try std.testing.expectEqual(Key.kp_multiply, keymap.macos_keycode(0x43));
    try std.testing.expectEqual(Key.kp_add, keymap.macos_keycode(0x45));
    try std.testing.expectEqual(Key.kp_subtract, keymap.macos_keycode(0x4E));
    try std.testing.expectEqual(Key.kp_divide, keymap.macos_keycode(0x4B));
    try std.testing.expectEqual(Key.kp_enter, keymap.macos_keycode(0x4C));
    try std.testing.expectEqual(Key.kp_equal, keymap.macos_keycode(0x51));
    try std.testing.expectEqual(Key.num_lock, keymap.macos_keycode(0x47)); // kp clear on Mac
}

test "punctuation keys" {
    try std.testing.expectEqual(Key.minus, keymap.macos_keycode(0x1B));
    try std.testing.expectEqual(Key.equal, keymap.macos_keycode(0x18));
    try std.testing.expectEqual(Key.left_bracket, keymap.macos_keycode(0x21));
    try std.testing.expectEqual(Key.right_bracket, keymap.macos_keycode(0x1E));
    try std.testing.expectEqual(Key.backslash, keymap.macos_keycode(0x2A));
    try std.testing.expectEqual(Key.semicolon, keymap.macos_keycode(0x29));
    try std.testing.expectEqual(Key.apostrophe, keymap.macos_keycode(0x27));
    try std.testing.expectEqual(Key.grave, keymap.macos_keycode(0x32));
    try std.testing.expectEqual(Key.comma, keymap.macos_keycode(0x2B));
    try std.testing.expectEqual(Key.period, keymap.macos_keycode(0x2F));
    try std.testing.expectEqual(Key.slash, keymap.macos_keycode(0x2C));
}

test "known .unknown slots" {
    // ISO extra key (JIS layout)
    try std.testing.expectEqual(Key.unknown, keymap.macos_keycode(0x0A));
    // Reserved slot
    try std.testing.expectEqual(Key.unknown, keymap.macos_keycode(0x34));
    // fn key (no direct mapping)
    try std.testing.expectEqual(Key.unknown, keymap.macos_keycode(0x3F));
    // Last slot in table
    try std.testing.expectEqual(Key.unknown, keymap.macos_keycode(0x7F));
}

test "out of range returns .unknown" {
    try std.testing.expectEqual(Key.unknown, keymap.macos_keycode(0x80));
    try std.testing.expectEqual(Key.unknown, keymap.macos_keycode(0xFF));
    try std.testing.expectEqual(Key.unknown, keymap.macos_keycode(std.math.maxInt(u16)));
}
