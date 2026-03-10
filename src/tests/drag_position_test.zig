/// Tests for feature #11: Drag Position During Drag-and-Drop.
///
/// Verifies that the `.file_drag_moved` event variant exists in `Event`
/// and carries a `Position` payload. Runtime behavior (actual drag hover
/// position updates) is tested via the demo — these are compile-time/unit tests.
const std = @import("std");
const event = @import("../event.zig");

// ── Event variant ─────────────────────────────────────────────────────────────

test "Event: has file_drag_moved variant" {
    comptime {
        const info = @typeInfo(event.Event).@"union";
        var found = false;
        for (info.fields) |f| {
            if (std.mem.eql(u8, f.name, "file_drag_moved")) {
                found = true;
                break;
            }
        }
        if (!found) @compileError("missing Event variant: file_drag_moved");
    }
}

test "Event.file_drag_moved: payload is Position" {
    comptime {
        const info = @typeInfo(event.Event).@"union";
        for (info.fields) |f| {
            if (std.mem.eql(u8, f.name, "file_drag_moved")) {
                if (f.type != event.Position) @compileError("file_drag_moved payload must be Position");
                break;
            }
        }
    }
}

// ── Construction ──────────────────────────────────────────────────────────────

test "Event.file_drag_moved: can be constructed with a position" {
    const ev = event.Event{ .file_drag_moved = .{ .x = 100, .y = 200 } };
    switch (ev) {
        .file_drag_moved => |pos| {
            try std.testing.expectEqual(@as(i32, 100), pos.x);
            try std.testing.expectEqual(@as(i32, 200), pos.y);
        },
        else => return error.WrongVariant,
    }
}

test "Event.file_drag_moved: position at origin" {
    const ev = event.Event{ .file_drag_moved = .{ .x = 0, .y = 0 } };
    switch (ev) {
        .file_drag_moved => |pos| {
            try std.testing.expectEqual(@as(i32, 0), pos.x);
            try std.testing.expectEqual(@as(i32, 0), pos.y);
        },
        else => return error.WrongVariant,
    }
}

test "Event.file_drag_moved: position updates are independent values" {
    const ev1 = event.Event{ .file_drag_moved = .{ .x = 10, .y = 20 } };
    const ev2 = event.Event{ .file_drag_moved = .{ .x = 30, .y = 40 } };
    const p1 = ev1.file_drag_moved;
    const p2 = ev2.file_drag_moved;
    try std.testing.expect(p1.x != p2.x);
    try std.testing.expect(p1.y != p2.y);
}
