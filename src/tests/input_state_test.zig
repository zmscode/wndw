/// Tests for global input state tracking (Phase 10).
///
/// Pure logic tests — no ObjC needed. Input state is tracked via bitsets
/// updated during poll(). Tests exercise the InputState struct directly.
const std = @import("std");
const Window = @import("../platform/macos/window.zig").Window;
const ev = @import("../event.zig");
const Key = ev.Key;
const MouseButton = ev.MouseButton;

// ── Key state ───────────────────────────────────────────────────────────────

test "Window has isKeyDown" {
    try std.testing.expect(@hasDecl(Window, "isKeyDown"));
}

test "Window has isKeyPressed" {
    try std.testing.expect(@hasDecl(Window, "isKeyPressed"));
}

test "Window has isKeyReleased" {
    try std.testing.expect(@hasDecl(Window, "isKeyReleased"));
}

// ── Mouse state ─────────────────────────────────────────────────────────────

test "Window has isMouseDown" {
    try std.testing.expect(@hasDecl(Window, "isMouseDown"));
}

test "Window has isMousePressed" {
    try std.testing.expect(@hasDecl(Window, "isMousePressed"));
}

test "Window has isMouseReleased" {
    try std.testing.expect(@hasDecl(Window, "isMouseReleased"));
}

// ── InputState struct ───────────────────────────────────────────────────────

test "Window has InputState" {
    try std.testing.expect(@hasDecl(Window, "InputState"));
}

test "Window: input_state field exists" {
    comptime if (!@hasField(Window, "input_state")) @compileError("missing field: input_state");
}

// ── InputState logic tests ──────────────────────────────────────────────────

test "InputState: key not pressed by default" {
    const IS = Window.InputState;
    var state = IS{};
    try std.testing.expect(!state.isKeyDown(.a));
    try std.testing.expect(!state.isKeyPressed(.a));
    try std.testing.expect(!state.isKeyReleased(.a));
}

test "InputState: keyDown after press" {
    const IS = Window.InputState;
    var state = IS{};
    state.handleKeyPress(.a);
    try std.testing.expect(state.isKeyDown(.a));
    try std.testing.expect(state.isKeyPressed(.a));
    try std.testing.expect(!state.isKeyReleased(.a));
}

test "InputState: key still down after frame advance, but not pressed" {
    const IS = Window.InputState;
    var state = IS{};
    state.handleKeyPress(.a);
    state.nextFrame();
    try std.testing.expect(state.isKeyDown(.a));
    try std.testing.expect(!state.isKeyPressed(.a));
    try std.testing.expect(!state.isKeyReleased(.a));
}

test "InputState: key released after release event" {
    const IS = Window.InputState;
    var state = IS{};
    state.handleKeyPress(.a);
    state.nextFrame();
    state.handleKeyRelease(.a);
    try std.testing.expect(!state.isKeyDown(.a));
    try std.testing.expect(state.isKeyReleased(.a));
}

test "InputState: isKeyReleased true on frame after release" {
    const IS = Window.InputState;
    var state = IS{};
    state.handleKeyPress(.a);
    state.nextFrame();
    state.handleKeyRelease(.a);
    // After release, key is up. isKeyReleased = was down last frame, up now
    // Actually, released means: was down prev frame, up this frame.
    // handleKeyRelease clears current. nextFrame swaps. So:
    //   - handleKeyRelease sets current down=false
    //   - Before nextFrame: prev still has down=true, current has down=false
    //   - isKeyReleased = prev.down AND !current.down
    try std.testing.expect(state.isKeyReleased(.a));
}

test "InputState: released clears after next frame" {
    const IS = Window.InputState;
    var state = IS{};
    state.handleKeyPress(.a);
    state.nextFrame();
    state.handleKeyRelease(.a);
    state.nextFrame();
    try std.testing.expect(!state.isKeyDown(.a));
    try std.testing.expect(!state.isKeyReleased(.a));
}

test "InputState: multiple keys independent" {
    const IS = Window.InputState;
    var state = IS{};
    state.handleKeyPress(.a);
    state.handleKeyPress(.space);
    try std.testing.expect(state.isKeyDown(.a));
    try std.testing.expect(state.isKeyDown(.space));
    try std.testing.expect(!state.isKeyDown(.escape));
}

// ── Mouse state logic ───────────────────────────────────────────────────────

test "InputState: mouse not pressed by default" {
    const IS = Window.InputState;
    var state = IS{};
    try std.testing.expect(!state.isMouseBtnDown(.left));
    try std.testing.expect(!state.isMouseBtnPressed(.left));
    try std.testing.expect(!state.isMouseBtnReleased(.left));
}

test "InputState: mouse down after press" {
    const IS = Window.InputState;
    var state = IS{};
    state.handleMousePress(.left);
    try std.testing.expect(state.isMouseBtnDown(.left));
    try std.testing.expect(state.isMouseBtnPressed(.left));
}

test "InputState: mouse still down after frame, not pressed" {
    const IS = Window.InputState;
    var state = IS{};
    state.handleMousePress(.left);
    state.nextFrame();
    try std.testing.expect(state.isMouseBtnDown(.left));
    try std.testing.expect(!state.isMouseBtnPressed(.left));
}

test "InputState: mouse released" {
    const IS = Window.InputState;
    var state = IS{};
    state.handleMousePress(.right);
    state.nextFrame();
    state.handleMouseRelease(.right);
    try std.testing.expect(state.isMouseBtnReleased(.right));
    state.nextFrame();
    try std.testing.expect(!state.isMouseBtnReleased(.right));
}
