// Test runner — imports every test suite in src/tests/.
//
// Having this file at src/ makes the module root src/, so test files can
// use relative imports like `@import("../event_queue.zig")` without escaping
// the module boundary.
//
// Run with: `zig build test`
comptime {
    _ = @import("tests/event_queue_test.zig");
    _ = @import("tests/keymap_test.zig");
    _ = @import("tests/api_test.zig");
    _ = @import("tests/event_types_test.zig");
    _ = @import("tests/window_methods_test.zig");
    _ = @import("tests/input_state_test.zig");
    _ = @import("tests/event_callbacks_test.zig");
    _ = @import("tests/opengl_test.zig");
    _ = @import("tests/zgl_compat_test.zig");
    _ = @import("tests/appearance_test.zig");
}
