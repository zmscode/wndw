// ── Native Renderer — imported from wndw ────────────────────────────
//
// The platform-specific renderer lives in the wndw module (alongside
// Window, events, etc.) at platform/<os>/renderer.zig. The UI layer
// imports it from wndw, keeping all platform-specific code in one place.
//
// Adding a new platform means implementing Renderer in that platform's
// directory and adding a branch in src/root.zig.

pub const Renderer = @import("wndw").Renderer;
