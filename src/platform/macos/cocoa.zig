/// Numeric Cocoa / AppKit / OpenGL constants.
///
/// No headers needed — these are stable ABI values that haven't changed
/// across macOS SDK versions.

// ── NSWindowStyleMask ─────────────────────────────────────────────────────────

pub const NSWindowStyleMaskBorderless: usize = 0;
pub const NSWindowStyleMaskTitled: usize = 1 << 0; // 0x0001
pub const NSWindowStyleMaskClosable: usize = 1 << 1; // 0x0002
pub const NSWindowStyleMaskMiniaturizable: usize = 1 << 2; // 0x0004
pub const NSWindowStyleMaskResizable: usize = 1 << 3; // 0x0008
pub const NSWindowStyleMaskFullScreen: usize = 1 << 14; // 0x4000
pub const NSWindowStyleMaskFullSizeContentView: usize = 1 << 15; // 0x8000

// ── NSBackingStoreType ────────────────────────────────────────────────────────

pub const NSBackingStoreBuffered: usize = 2;

// ── NSApplicationActivationPolicy ────────────────────────────────────────────

pub const NSApplicationActivationPolicyRegular: isize = 0;
pub const NSApplicationActivationPolicyAccessory: isize = 1;
pub const NSApplicationActivationPolicyProhibited: isize = 2;

// ── NSEventMask ───────────────────────────────────────────────────────────────

/// Pass to nextEventMatchingMask: to receive all event types.
pub const NSEventMaskAny: usize = ~@as(usize, 0);

// ── NSEventType ───────────────────────────────────────────────────────────────

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

pub const NSEventModifierFlagCapsLock: usize = 1 << 16; // 0x010000
pub const NSEventModifierFlagShift: usize = 1 << 17; // 0x020000
pub const NSEventModifierFlagControl: usize = 1 << 18; // 0x040000
pub const NSEventModifierFlagOption: usize = 1 << 19; // 0x080000
pub const NSEventModifierFlagCommand: usize = 1 << 20; // 0x100000
pub const NSEventModifierFlagNumericPad: usize = 1 << 21; // 0x200000

// ── NSWindowLevel ─────────────────────────────────────────────────────────────

pub const NSNormalWindowLevel: isize = 0;
pub const NSFloatingWindowLevel: isize = 3; // always-on-top

// ── NSWindowCollectionBehavior ────────────────────────────────────────────────

pub const NSWindowCollectionBehaviorFullScreenPrimary: usize = 1 << 7; // 0x80

// ── NSOpenGLContextParameter ──────────────────────────────────────────────────

pub const NSOpenGLContextParameterSwapInterval: i32 = 222;
pub const NSOpenGLContextParameterSurfaceOpacity: i32 = 236;

// ── NSOpenGLPFA (pixel format attributes) ─────────────────────────────────────

pub const NSOpenGLPFADoubleBuffer: u32 = 5;
pub const NSOpenGLPFAColorSize: u32 = 8;
pub const NSOpenGLPFAAlphaSize: u32 = 11;
pub const NSOpenGLPFADepthSize: u32 = 12;
pub const NSOpenGLPFAStencilSize: u32 = 13;
pub const NSOpenGLPFASampleBuffers: u32 = 55;
pub const NSOpenGLPFASamples: u32 = 56;
pub const NSOpenGLPFAOpenGLProfile: u32 = 99;
pub const NSOpenGLProfileVersion3_2Core: u32 = 0x3200;
pub const NSOpenGLProfileVersion4_1Core: u32 = 0x4100;
