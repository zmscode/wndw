/// Tests for feature #13: Window Ordering / Stacking.
///
/// Verifies that `Window.getWindowOrder()` exists and returns a slice of
/// Window pointers. Ordering is determined at runtime by `[NSApp orderedWindows]`
/// and cannot be unit-tested here — use the demo for live ordering checks.
const std = @import("std");
const Window = @import("../platform/macos/window.zig").Window;

// ── Method presence ──────────────────────────────────────────────────────────

test "Window: has getWindowOrder method" {
    comptime if (!@hasDecl(Window, "getWindowOrder")) @compileError("missing method: getWindowOrder");
}

// ── Return type ──────────────────────────────────────────────────────────────

test "Window.getWindowOrder: return type is a slice of Window pointers" {
    // Inspect the return type at compile time without calling the method
    // (calling it would require a live NSApp).
    const fn_type = @typeInfo(@TypeOf(Window.getWindowOrder));
    comptime {
        const ret = fn_type.@"fn".return_type orelse
            @compileError("getWindowOrder has no return type");
        const info = @typeInfo(ret);
        if (info != .pointer) @compileError("getWindowOrder must return a slice");
        if (info.pointer.size != .slice) @compileError("getWindowOrder must return a slice");
        if (info.pointer.child != *Window) @compileError("getWindowOrder slice element must be *Window");
    }
}
