/// Numeric Cocoa / AppKit / OpenGL constants — no headers needed.
///
/// These are stable ABI values from Apple's frameworks that have not
/// changed across macOS SDK versions. Using numeric constants instead
/// of `@cImport` means we don't need the macOS SDK headers at compile
/// time, which avoids the `libDER/DERItem.h` error and keeps the build
/// pure Zig.
///
/// Sources: Apple HIToolbox headers, AppKit headers, NSOpenGL headers.

// ── NSWindowStyleMask ─────────────────────────────────────────────────────────
/// Bitmask values for `[NSWindow styleMask]`. Combine with `|`.
pub const NSWindowStyleMaskBorderless: usize = 0;
pub const NSWindowStyleMaskTitled: usize = 1 << 0; // 0x0001
pub const NSWindowStyleMaskClosable: usize = 1 << 1; // 0x0002
pub const NSWindowStyleMaskMiniaturizable: usize = 1 << 2; // 0x0004
pub const NSWindowStyleMaskResizable: usize = 1 << 3; // 0x0008
pub const NSWindowStyleMaskFullScreen: usize = 1 << 14; // 0x4000
pub const NSWindowStyleMaskFullSizeContentView: usize = 1 << 15; // 0x8000

// ── NSBackingStoreType ────────────────────────────────────────────────────────

/// The standard backing store type — always use this for modern macOS.
pub const NSBackingStoreBuffered: usize = 2;

// ── NSApplicationActivationPolicy ────────────────────────────────────────────

/// Regular app — appears in dock and command-tab switcher.
pub const NSApplicationActivationPolicyRegular: isize = 0;
/// Accessory app — no dock icon, no menu bar.
pub const NSApplicationActivationPolicyAccessory: isize = 1;
/// Prohibited — cannot be activated.
pub const NSApplicationActivationPolicyProhibited: isize = 2;

// ── NSEventMask ───────────────────────────────────────────────────────────────

/// Pass to `nextEventMatchingMask:` to receive all event types.
pub const NSEventMaskAny: usize = ~@as(usize, 0);

// ── NSEventType ───────────────────────────────────────────────────────────────
/// Numeric values for `[NSEvent type]`.
pub const NSEventTypeLeftMouseDown: usize = 1;
pub const NSEventTypeLeftMouseUp: usize = 2;
pub const NSEventTypeRightMouseDown: usize = 3;
pub const NSEventTypeRightMouseUp: usize = 4;
pub const NSEventTypeMouseMoved: usize = 5;
pub const NSEventTypeLeftMouseDragged: usize = 6;
pub const NSEventTypeRightMouseDragged: usize = 7;
pub const NSEventTypeKeyDown: usize = 10;
pub const NSEventTypeKeyUp: usize = 11;
pub const NSEventTypeFlagsChanged: usize = 12;
pub const NSEventTypeScrollWheel: usize = 22;
pub const NSEventTypeOtherMouseDown: usize = 25;
pub const NSEventTypeOtherMouseUp: usize = 26;
pub const NSEventTypeOtherMouseDragged: usize = 27;

// ── NSEventModifierFlags ──────────────────────────────────────────────────────
/// Bitmask values from `[NSEvent modifierFlags]`.
pub const NSEventModifierFlagCapsLock: usize = 1 << 16; // 0x010000
pub const NSEventModifierFlagShift: usize = 1 << 17; // 0x020000
pub const NSEventModifierFlagControl: usize = 1 << 18; // 0x040000
pub const NSEventModifierFlagOption: usize = 1 << 19; // 0x080000
pub const NSEventModifierFlagCommand: usize = 1 << 20; // 0x100000
pub const NSEventModifierFlagNumericPad: usize = 1 << 21; // 0x200000

// ── NSWindowLevel ─────────────────────────────────────────────────────────────

/// Default window level.
pub const NSNormalWindowLevel: isize = 0;
/// Always-on-top (floating) window level.
pub const NSFloatingWindowLevel: isize = 3;

// ── NSWindowCollectionBehavior ────────────────────────────────────────────────

/// Allow the window to enter fullscreen via the green title bar button.
pub const NSWindowCollectionBehaviorFullScreenPrimary: usize = 1 << 7; // 0x80

// ── NSOpenGLContextParameter ──────────────────────────────────────────────────
/// Parameters for `[NSOpenGLContext setValues:forParameter:]`.
/// Controls vsync (0 = off, 1 = on).
pub const NSOpenGLContextParameterSwapInterval: i32 = 222;
/// Controls surface opacity (0 = transparent, 1 = opaque).
pub const NSOpenGLContextParameterSurfaceOpacity: i32 = 236;

// ── NSOpenGLPFA (pixel format attributes) ─────────────────────────────────────
/// Attributes for `[NSOpenGLPixelFormat initWithAttributes:]`.
/// These are key-value pairs in a null-terminated u32 array.
/// Some are flags (just the key, no value); others are key-then-value.
pub const NSOpenGLPFADoubleBuffer: u32 = 5; // flag
pub const NSOpenGLPFAColorSize: u32 = 8; // key-value
pub const NSOpenGLPFAAlphaSize: u32 = 11; // key-value
pub const NSOpenGLPFADepthSize: u32 = 12; // key-value
pub const NSOpenGLPFAStencilSize: u32 = 13; // key-value
pub const NSOpenGLPFASampleBuffers: u32 = 55; // key-value
pub const NSOpenGLPFASamples: u32 = 56; // key-value
pub const NSOpenGLPFAAccelerated: u32 = 73; // flag — prefer hardware-accelerated
pub const NSOpenGLPFAClosestPolicy: u32 = 74; // flag — choose closest match
pub const NSOpenGLPFAOpenGLProfile: u32 = 99; // key-value — profile version below

/// OpenGL profile version constants for `NSOpenGLPFAOpenGLProfile`.
pub const NSOpenGLProfileVersionLegacy: u32 = 0x1000; // OpenGL 2.1
pub const NSOpenGLProfileVersion3_2Core: u32 = 0x3200; // OpenGL 3.2 Core
/// Note: RGFW had a bug where this was set to 0x3200 (same as 3.2 Core).
/// The correct value is 0x4100.
pub const NSOpenGLProfileVersion4_1Core: u32 = 0x4100; // OpenGL 4.1 Core
