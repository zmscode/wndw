/// Raw C bindings for RGFW. Prefer using the idiomatic Zig wrappers in this
/// module instead of accessing `rgfw_h` directly.
pub const rgfw_h = @cImport({
    @cInclude("RGFW.h");
});

// ──────────────────────────────────────────────
// Bool helpers
// ──────────────────────────────────────────────

/// Converts an RGFW C boolean to a native Zig `bool`.
pub inline fn toBool(value: rgfw_h.RGFW_bool) bool {
    return value != rgfw_h.RGFW_FALSE;
}

/// Converts a native Zig `bool` to an RGFW C boolean.
pub inline fn fromBool(value: bool) rgfw_h.RGFW_bool {
    return if (value) rgfw_h.RGFW_TRUE else rgfw_h.RGFW_FALSE;
}

// ──────────────────────────────────────────────
// Type aliases
// ──────────────────────────────────────────────

/// Abstract keycode. Use the `key` namespace for named constants (e.g. `key.escape`).
pub const Key = rgfw_h.RGFW_key;
/// Mouse button identifier. Use the `mouse` namespace for named constants (e.g. `mouse.left`).
pub const MouseButton = rgfw_h.RGFW_mouseButton;
/// Tagged union describing a single input or window event.
/// Access the active member by switching on `event.type` (an `EventType`).
pub const Event = rgfw_h.RGFW_event;
/// Common fields shared by all event types (type discriminator + window pointer).
/// Access via `event.common`.
pub const CommonEvent = rgfw_h.RGFW_commonEvent;
/// Event data for mouse button press/release. Access via `event.button`.
pub const MouseButtonEvent = rgfw_h.RGFW_mouseButtonEvent;
/// Event data for mouse scroll. Access via `event.scroll`.
pub const MouseScrollEvent = rgfw_h.RGFW_mouseScrollEvent;
/// Event data for mouse position changes. Access via `event.mouse`.
pub const MousePosEvent = rgfw_h.RGFW_mousePosEvent;
/// Event data for key press/release. Access via `event.key`.
pub const KeyEvent = rgfw_h.RGFW_keyEvent;
/// Event data for Unicode character input. Access via `event.keyChar`.
pub const KeyCharEvent = rgfw_h.RGFW_keyCharEvent;
/// Event data for file drops. Access via `event.drop`.
pub const DataDropEvent = rgfw_h.RGFW_dataDropEvent;
/// Event data for file drags. Access via `event.drag`.
pub const DataDragEvent = rgfw_h.RGFW_dataDragEvent;
/// Event data for DPI/content scale changes. Access via `event.scale`.
pub const ScaleUpdatedEvent = rgfw_h.RGFW_scaleUpdatedEvent;
/// Event data for monitor connect/disconnect. Access via `event.monitor`.
pub const MonitorEvent = rgfw_h.RGFW_monitorEvent;
/// Discriminator for `Event`. Compare against `event_type.*` constants.
pub const EventType = rgfw_h.RGFW_eventType;
/// Bitmask of active key modifiers (shift, ctrl, alt, ...). Check with `keymod.*` constants.
pub const KeyMod = rgfw_h.RGFW_keymod;
/// Standard cursor shapes. Use the `cursor` namespace for named constants.
pub const MouseIcon = rgfw_h.RGFW_mouseIcons;
/// Bitmask of window creation/state flags. Prefer `Window.FlagOptions` for a typed interface.
pub const WindowFlags = rgfw_h.RGFW_windowFlags;
/// Bitmask for enabling/disabling individual event types on a window.
/// Use `event_flag.*` constants and combine with `|`.
pub const EventFlag = rgfw_h.RGFW_eventFlag;
/// Pixel format for image data (icons, cursors, surfaces).
pub const Format = rgfw_h.RGFW_format;
/// Controls how `Window.flashWindow` attracts the user's attention.
pub const FlashRequest = rgfw_h.RGFW_flashRequest;
/// Where to apply a window icon — taskbar, title bar, or both.
pub const IconType = rgfw_h.RGFW_icon;
/// OpenGL profile mode (core, compatibility, ES, ...).
pub const GlProfile = rgfw_h.RGFW_glProfile;
/// OpenGL context release behaviour (flush pipeline or do nothing).
pub const GlReleaseBehavior = rgfw_h.RGFW_glReleaseBehavior;
/// OpenGL renderer hint — hardware-accelerated or software.
pub const GlRenderer = rgfw_h.RGFW_glRenderer;
/// Full set of OpenGL context creation hints (version, profile, buffer sizes, etc.).
/// Pass to `gl.setGlobalHints` before creating a window or context.
pub const GlHints = rgfw_h.RGFW_glHints;
/// Specifies which aspects of a monitor mode to change or compare (resolution, refresh rate, colour depth).
pub const ModeRequest = rgfw_h.RGFW_modeRequest;
/// Describes a display mode — resolution, refresh rate, and colour bit depths.
pub const MonitorMode = rgfw_h.RGFW_monitorMode;
/// Per-channel gamma look-up tables (red, green, blue arrays + count).
/// Obtained from `Monitor.getGammaRamp`; free with `freeGammaRamp` when done.
pub const GammaRamp = rgfw_h.RGFW_gammaRamp;
/// Opaque handle to a renderable pixel buffer for software rendering.
/// Blit to a window with `Window.blitSurface`.
pub const Surface = rgfw_h.RGFW_surface;

// ──────────────────────────────────────────────
// Window flag constants
// ──────────────────────────────────────────────

/// Raw window flag constants for flags not exposed through `Window.FlagOptions`.
/// These can be combined with `|` and applied via the lower-level C API.
///
/// Most users should prefer `Window.FlagOptions`; these are for advanced use
/// cases or composite flags that don't map to a single boolean toggle.
pub const window_flag = struct {
    /// Enable raw (unaccelerated) mouse input on window creation.
    pub const raw_mouse: WindowFlags = rgfw_h.RGFW_windowRawMouse;
    /// Automatically scale the window to match the monitor's content scale.
    pub const scale_to_monitor: WindowFlags = rgfw_h.RGFW_windowScaleToMonitor;
    /// Centre the mouse cursor in the window on creation.
    pub const center_cursor: WindowFlags = rgfw_h.RGFW_windowCenterCursor;
    /// Capture (confine) the mouse to the window on creation.
    pub const capture_mouse: WindowFlags = rgfw_h.RGFW_windowCaptureMouse;
    /// Automatically create an OpenGL context with the window.
    pub const opengl: WindowFlags = rgfw_h.RGFW_windowOpenGL;
    /// Automatically create an EGL context with the window.
    pub const egl: WindowFlags = rgfw_h.RGFW_windowEGL;
    /// Do not auto-deinit RGFW when the last window is closed.
    pub const no_deinit_on_close: WindowFlags = rgfw_h.RGFW_noDeinitOnClose;
    /// Composite: borderless + maximized (windowed fullscreen / borderless fullscreen).
    pub const windowed_fullscreen: WindowFlags = rgfw_h.RGFW_windowedFullscreen;
    /// Composite: capture mouse + raw mouse input.
    pub const capture_raw_mouse: WindowFlags = rgfw_h.RGFW_windowCaptureRawMouse;
};

// ──────────────────────────────────────────────
// Event wait constants
// ──────────────────────────────────────────────

/// Type for `waitForEvent` timeout values.
pub const EventWait = rgfw_h.RGFW_eventWait;

/// Named constants for `waitForEvent`.
pub const event_wait = struct {
    /// Do not wait — return immediately if no events are pending.
    pub const no_wait: EventWait = rgfw_h.RGFW_eventNoWait;
    /// Wait indefinitely until the next event arrives.
    pub const next: EventWait = rgfw_h.RGFW_eventWaitNext;
};

// ──────────────────────────────────────────────
// Debug types
// ──────────────────────────────────────────────

/// Severity level for debug messages emitted by RGFW.
pub const DebugType = rgfw_h.RGFW_debugType;

/// Named constants for `DebugType`.
pub const debug_type = struct {
    /// A fatal or unrecoverable error.
    pub const @"error": DebugType = rgfw_h.RGFW_typeError;
    /// A non-fatal issue that may indicate a problem.
    pub const warning: DebugType = rgfw_h.RGFW_typeWarning;
    /// Informational message (e.g. context created, window freed).
    pub const info: DebugType = rgfw_h.RGFW_typeInfo;
};

// ──────────────────────────────────────────────
// Error codes
// ──────────────────────────────────────────────

/// Machine-readable error/info/warning codes emitted alongside debug messages.
pub const ErrorCode = rgfw_h.RGFW_errorCode;

/// Named constants for `ErrorCode`. Covers errors, informational notices, and warnings.
pub const error_code = struct {
    // Errors
    pub const no_error: ErrorCode = rgfw_h.RGFW_noError;
    pub const out_of_memory: ErrorCode = rgfw_h.RGFW_errOutOfMemory;
    pub const opengl_context: ErrorCode = rgfw_h.RGFW_errOpenGLContext;
    pub const egl_context: ErrorCode = rgfw_h.RGFW_errEGLContext;
    pub const wayland: ErrorCode = rgfw_h.RGFW_errWayland;
    pub const x11: ErrorCode = rgfw_h.RGFW_errX11;
    pub const directx_context: ErrorCode = rgfw_h.RGFW_errDirectXContext;
    pub const iokit: ErrorCode = rgfw_h.RGFW_errIOKit;
    pub const clipboard: ErrorCode = rgfw_h.RGFW_errClipboard;
    pub const failed_func_load: ErrorCode = rgfw_h.RGFW_errFailedFuncLoad;
    pub const buffer: ErrorCode = rgfw_h.RGFW_errBuffer;
    pub const metal: ErrorCode = rgfw_h.RGFW_errMetal;
    pub const platform: ErrorCode = rgfw_h.RGFW_errPlatform;
    pub const event_queue: ErrorCode = rgfw_h.RGFW_errEventQueue;

    // Informational
    pub const info_window: ErrorCode = rgfw_h.RGFW_infoWindow;
    pub const info_buffer: ErrorCode = rgfw_h.RGFW_infoBuffer;
    pub const info_global: ErrorCode = rgfw_h.RGFW_infoGlobal;
    pub const info_opengl: ErrorCode = rgfw_h.RGFW_infoOpenGL;

    // Warnings
    pub const warning_wayland: ErrorCode = rgfw_h.RGFW_warningWayland;
    pub const warning_opengl: ErrorCode = rgfw_h.RGFW_warningOpenGL;
};

// ──────────────────────────────────────────────
// Callback type aliases
// ──────────────────────────────────────────────

/// Callback for debug/error messages. Receives severity, error code, and a human-readable message.
pub const DebugFunc = rgfw_h.RGFW_debugfunc;
/// Callback fired when a window is moved. Receives the window and its new position.
pub const WindowMovedFunc = rgfw_h.RGFW_windowMovedfunc;
/// Callback fired when a window is resized. Receives the window and its new size.
pub const WindowResizedFunc = rgfw_h.RGFW_windowResizedfunc;
/// Callback fired when a window is restored from minimize/maximize. Receives position and size.
pub const WindowRestoredFunc = rgfw_h.RGFW_windowRestoredfunc;
/// Callback fired when a window is maximized. Receives position and size.
pub const WindowMaximizedFunc = rgfw_h.RGFW_windowMaximizedfunc;
/// Callback fired when a window is minimized.
pub const WindowMinimizedFunc = rgfw_h.RGFW_windowMinimizedfunc;
/// Callback fired when a window is requested to close.
pub const WindowQuitFunc = rgfw_h.RGFW_windowQuitfunc;
/// Callback fired when a window gains or loses focus.
pub const FocusFunc = rgfw_h.RGFW_focusfunc;
/// Callback fired when the mouse enters or leaves a window. Receives position and enter/leave status.
pub const MouseNotifyFunc = rgfw_h.RGFW_mouseNotifyfunc;
/// Callback fired when the mouse moves. Receives position and movement delta vector.
pub const MousePosFunc = rgfw_h.RGFW_mousePosfunc;
/// Callback fired when files are dragged over a window. Receives the drag position.
pub const DataDragFunc = rgfw_h.RGFW_dataDragfunc;
/// Callback fired when the window needs repainting.
pub const WindowRefreshFunc = rgfw_h.RGFW_windowRefreshfunc;
/// Callback fired when a Unicode character is typed. Receives the codepoint.
pub const KeyCharFunc = rgfw_h.RGFW_keyCharfunc;
/// Callback fired on key press/release. Receives key, modifiers, repeat flag, and pressed state.
pub const KeyFunc = rgfw_h.RGFW_keyfunc;
/// Callback fired on mouse button press/release. Receives the button and pressed state.
pub const MouseButtonFunc = rgfw_h.RGFW_mouseButtonfunc;
/// Callback fired on mouse scroll. Receives x and y scroll deltas.
pub const MouseScrollFunc = rgfw_h.RGFW_mouseScrollfunc;
/// Callback fired when files are dropped onto a window. Receives the file list and count.
pub const DataDropFunc = rgfw_h.RGFW_dataDropfunc;
/// Callback fired when the content scale factor changes (e.g. moving to a HiDPI display).
pub const ScaleUpdatedFunc = rgfw_h.RGFW_scaleUpdatedfunc;
/// Callback fired when a monitor is connected or disconnected.
pub const MonitorFunc = rgfw_h.RGFW_monitorfunc;

// ──────────────────────────────────────────────
// Callback registration
// ──────────────────────────────────────────────

/// Global callback registration. Set a callback to receive notifications for
/// the corresponding event type across all windows. Each setter returns the
/// previously registered callback (or `null`), allowing callback chaining.
///
/// ```zig
/// const prev = wndw.callbacks.setWindowMoved(struct {
///     fn cb(win: *wndw.rgfw_h.RGFW_window, x: i32, y: i32) callconv(.C) void {
///         _ = win;
///         std.debug.print("moved to {d},{d}\n", .{ x, y });
///     }
/// }.cb);
/// ```
pub const callbacks = struct {
    /// Registers a callback for debug/error messages from RGFW.
    /// Returns the previously registered callback.
    pub fn setDebug(func: DebugFunc) DebugFunc {
        return rgfw_h.RGFW_setDebugCallback(func);
    }

    /// Registers a callback for window move events.
    pub fn setWindowMoved(func: WindowMovedFunc) WindowMovedFunc {
        return rgfw_h.RGFW_setWindowMovedCallback(func);
    }

    /// Registers a callback for window resize events.
    pub fn setWindowResized(func: WindowResizedFunc) WindowResizedFunc {
        return rgfw_h.RGFW_setWindowResizedCallback(func);
    }

    /// Registers a callback for window quit (close request) events.
    pub fn setWindowQuit(func: WindowQuitFunc) WindowQuitFunc {
        return rgfw_h.RGFW_setWindowQuitCallback(func);
    }

    /// Registers a callback for mouse position change events.
    pub fn setMousePos(func: MousePosFunc) MousePosFunc {
        return rgfw_h.RGFW_setMousePosCallback(func);
    }

    /// Registers a callback for window refresh (repaint needed) events.
    pub fn setWindowRefresh(func: WindowRefreshFunc) WindowRefreshFunc {
        return rgfw_h.RGFW_setWindowRefreshCallback(func);
    }

    /// Registers a callback for focus change events.
    pub fn setFocus(func: FocusFunc) FocusFunc {
        return rgfw_h.RGFW_setFocusCallback(func);
    }

    /// Registers a callback for mouse enter/leave events.
    pub fn setMouseNotify(func: MouseNotifyFunc) MouseNotifyFunc {
        return rgfw_h.RGFW_setMouseNotifyCallback(func);
    }

    /// Registers a callback for file drop events.
    pub fn setDataDrop(func: DataDropFunc) DataDropFunc {
        return rgfw_h.RGFW_setDataDropCallback(func);
    }

    /// Registers a callback for file drag events.
    pub fn setDataDrag(func: DataDragFunc) DataDragFunc {
        return rgfw_h.RGFW_setDataDragCallback(func);
    }

    /// Registers a callback for key press/release events.
    pub fn setKey(func: KeyFunc) KeyFunc {
        return rgfw_h.RGFW_setKeyCallback(func);
    }

    /// Registers a callback for Unicode character input events.
    pub fn setKeyChar(func: KeyCharFunc) KeyCharFunc {
        return rgfw_h.RGFW_setKeyCharCallback(func);
    }

    /// Registers a callback for mouse button press/release events.
    pub fn setMouseButton(func: MouseButtonFunc) MouseButtonFunc {
        return rgfw_h.RGFW_setMouseButtonCallback(func);
    }

    /// Registers a callback for mouse scroll events.
    pub fn setMouseScroll(func: MouseScrollFunc) MouseScrollFunc {
        return rgfw_h.RGFW_setMouseScrollCallback(func);
    }

    /// Registers a callback for window maximized events.
    pub fn setWindowMaximized(func: WindowMaximizedFunc) WindowMaximizedFunc {
        return rgfw_h.RGFW_setWindowMaximizedCallback(func);
    }

    /// Registers a callback for window minimized events.
    pub fn setWindowMinimized(func: WindowMinimizedFunc) WindowMinimizedFunc {
        return rgfw_h.RGFW_setWindowMinimizedCallback(func);
    }

    /// Registers a callback for window restored events.
    pub fn setWindowRestored(func: WindowRestoredFunc) WindowRestoredFunc {
        return rgfw_h.RGFW_setWindowRestoredCallback(func);
    }

    /// Registers a callback for content scale change events.
    pub fn setScaleUpdated(func: ScaleUpdatedFunc) ScaleUpdatedFunc {
        return rgfw_h.RGFW_setScaleUpdatedCallback(func);
    }

    /// Registers a callback for monitor connect/disconnect events.
    pub fn setMonitor(func: MonitorFunc) MonitorFunc {
        return rgfw_h.RGFW_setMonitorCallback(func);
    }
};

// ──────────────────────────────────────────────
// Debug messaging
// ──────────────────────────────────────────────

/// Sends a debug message through RGFW's debug callback system.
/// If a debug callback has been registered via `callbacks.setDebug`, it will
/// be invoked with the given severity, error code, and message.
///
/// ```zig
/// wndw.sendDebugInfo(wndw.debug_type.info, wndw.error_code.no_error, "App initialized");
/// ```
pub fn sendDebugInfo(dtype: DebugType, err: ErrorCode, msg: [*:0]const u8) void {
    rgfw_h.RGFW_sendDebugInfo(dtype, err, msg);
}

// ──────────────────────────────────────────────
// Format constants
// ──────────────────────────────────────────────

/// Pixel format constants for image data passed to `setIcon`, `Mouse.load`, etc.
pub const format = struct {
    /// 8-bit RGB, 3 bytes per pixel.
    pub const rgb8: Format = rgfw_h.RGFW_formatRGB8;
    /// 8-bit BGR, 3 bytes per pixel.
    pub const bgr8: Format = rgfw_h.RGFW_formatBGR8;
    /// 8-bit RGBA, 4 bytes per pixel.
    pub const rgba8: Format = rgfw_h.RGFW_formatRGBA8;
    /// 8-bit ARGB, 4 bytes per pixel.
    pub const argb8: Format = rgfw_h.RGFW_formatARGB8;
    /// 8-bit BGRA, 4 bytes per pixel.
    pub const bgra8: Format = rgfw_h.RGFW_formatBGRA8;
    /// 8-bit ABGR, 4 bytes per pixel.
    pub const abgr8: Format = rgfw_h.RGFW_formatABGR8;
};

// ──────────────────────────────────────────────
// Flash request constants
// ──────────────────────────────────────────────

/// Options for `Window.flashWindow` controlling how the taskbar/dock entry flashes.
pub const flash_request = struct {
    /// Cancel any active flash.
    pub const cancel: FlashRequest = rgfw_h.RGFW_flashCancel;
    /// Flash once briefly.
    pub const briefly: FlashRequest = rgfw_h.RGFW_flashBriefly;
    /// Flash continuously until the window receives focus.
    pub const until_focused: FlashRequest = rgfw_h.RGFW_flashUntilFocused;
};

// ──────────────────────────────────────────────
// Icon type constants
// ──────────────────────────────────────────────

/// Where to apply a window icon via `Window.setIconEx`.
pub const icon_type = struct {
    /// Taskbar / dock icon only.
    pub const taskbar: IconType = rgfw_h.RGFW_iconTaskbar;
    /// Title-bar icon only.
    pub const window: IconType = rgfw_h.RGFW_iconWindow;
    /// Both taskbar and title bar.
    pub const both: IconType = rgfw_h.RGFW_iconBoth;
};

// ──────────────────────────────────────────────
// Event flag constants
// ──────────────────────────────────────────────

/// Bitmask flags for enabling/disabling event types on a window.
/// Combine with `|` and pass to `Window.setEnabledEvents` or `Window.setDisabledEvents`.
///
/// ```zig
/// // Only receive keyboard and quit events:
/// win.setEnabledEvents(event_flag.key_events | event_flag.quit_flag);
/// ```
pub const event_flag = struct {
    pub const key_pressed: EventFlag = rgfw_h.RGFW_keyPressedFlag;
    pub const key_released: EventFlag = rgfw_h.RGFW_keyReleasedFlag;
    pub const key_char: EventFlag = rgfw_h.RGFW_keyCharFlag;
    pub const mouse_scroll: EventFlag = rgfw_h.RGFW_mouseScrollFlag;
    pub const mouse_button_pressed: EventFlag = rgfw_h.RGFW_mouseButtonPressedFlag;
    pub const mouse_button_released: EventFlag = rgfw_h.RGFW_mouseButtonReleasedFlag;
    pub const mouse_pos_changed: EventFlag = rgfw_h.RGFW_mousePosChangedFlag;
    pub const mouse_enter: EventFlag = rgfw_h.RGFW_mouseEnterFlag;
    pub const mouse_leave: EventFlag = rgfw_h.RGFW_mouseLeaveFlag;
    pub const window_moved: EventFlag = rgfw_h.RGFW_windowMovedFlag;
    pub const window_resized: EventFlag = rgfw_h.RGFW_windowResizedFlag;
    pub const focus_in: EventFlag = rgfw_h.RGFW_focusInFlag;
    pub const focus_out: EventFlag = rgfw_h.RGFW_focusOutFlag;
    pub const window_refresh: EventFlag = rgfw_h.RGFW_windowRefreshFlag;
    pub const window_maximized: EventFlag = rgfw_h.RGFW_windowMaximizedFlag;
    pub const window_minimized: EventFlag = rgfw_h.RGFW_windowMinimizedFlag;
    pub const window_restored: EventFlag = rgfw_h.RGFW_windowRestoredFlag;
    pub const scale_updated: EventFlag = rgfw_h.RGFW_scaleUpdatedFlag;
    pub const quit_flag: EventFlag = rgfw_h.RGFW_quitFlag;
    pub const data_drop: EventFlag = rgfw_h.RGFW_dataDropFlag;
    pub const data_drag: EventFlag = rgfw_h.RGFW_dataDragFlag;
    pub const monitor_connected: EventFlag = rgfw_h.RGFW_monitorConnectedFlag;
    pub const monitor_disconnected: EventFlag = rgfw_h.RGFW_monitorDisconnectedFlag;

    /// All key-related events (pressed, released, char).
    pub const key_events: EventFlag = rgfw_h.RGFW_keyEventsFlag;
    /// All mouse-related events (buttons, scroll, position, enter/leave).
    pub const mouse_events: EventFlag = rgfw_h.RGFW_mouseEventsFlag;
    /// All window state events (move, resize, refresh, maximize, minimize, restore, scale).
    pub const window_events: EventFlag = rgfw_h.RGFW_windowEventsFlag;
    /// Focus-in and focus-out events.
    pub const focus_events: EventFlag = rgfw_h.RGFW_focusEventsFlag;
    /// Drag-and-drop events (drag and drop).
    pub const data_drop_events: EventFlag = rgfw_h.RGFW_dataDropEventsFlag;
    /// Monitor connect/disconnect events.
    pub const monitor_events: EventFlag = rgfw_h.RGFW_monitorEventsFlag;
    /// Every event type.
    pub const all: EventFlag = rgfw_h.RGFW_allEventFlags;
};

// ──────────────────────────────────────────────
// GL profile / renderer constants
// ──────────────────────────────────────────────

/// OpenGL profile values for `GlHints.profile`.
pub const gl_profile = struct {
    /// Core profile — only the requested version's API.
    pub const core: GlProfile = rgfw_h.RGFW_glCore;
    /// Forward-compatible — deprecated functions removed.
    pub const forward_compatibility: GlProfile = rgfw_h.RGFW_glForwardCompatibility;
    /// Compatibility profile — includes older API versions.
    pub const compatibility: GlProfile = rgfw_h.RGFW_glCompatibility;
    /// OpenGL ES.
    pub const es: GlProfile = rgfw_h.RGFW_glES;
};

/// OpenGL renderer values for `GlHints.renderer`.
pub const gl_renderer = struct {
    /// Hardware-accelerated (GPU).
    pub const accelerated: GlRenderer = rgfw_h.RGFW_glAccelerated;
    /// Software-rendered (CPU).
    pub const software: GlRenderer = rgfw_h.RGFW_glSoftware;
};

/// OpenGL release behaviour values for `GlHints.releaseBehavior`.
pub const gl_release = struct {
    /// Flush the pipeline when the context is released.
    pub const flush: GlReleaseBehavior = rgfw_h.RGFW_glReleaseFlush;
    /// Do nothing on release.
    pub const none: GlReleaseBehavior = rgfw_h.RGFW_glReleaseNone;
};

// ──────────────────────────────────────────────
// Monitor mode request constants
// ──────────────────────────────────────────────

/// Flags for `Monitor.requestMode` specifying which mode properties to change.
pub const mode_request = struct {
    /// Change the resolution (scale).
    pub const scale: ModeRequest = rgfw_h.RGFW_monitorScale;
    /// Change the refresh rate.
    pub const refresh: ModeRequest = rgfw_h.RGFW_monitorRefresh;
    /// Change the colour bit depth.
    pub const rgb: ModeRequest = rgfw_h.RGFW_monitorRGB;
    /// Change everything (resolution + refresh + colour).
    pub const all: ModeRequest = rgfw_h.RGFW_monitorAll;
};

// ──────────────────────────────────────────────
// Event type constants
// ──────────────────────────────────────────────

/// Named constants for `Event.type`. Switch on these to handle events:
///
/// ```zig
/// var ev: wndw.Event = undefined;
/// while (win.pollEvent(&ev)) {
///     switch (ev.type) {
///         wndw.event_type.key_pressed => { /* ... */ },
///         wndw.event_type.quit => break,
///         else => {},
///     }
/// }
/// ```
pub const event_type = struct {
    pub const none: EventType = rgfw_h.RGFW_eventNone;
    pub const key_pressed: EventType = rgfw_h.RGFW_keyPressed;
    pub const key_released: EventType = rgfw_h.RGFW_keyReleased;
    /// A Unicode character was typed (for text input, distinct from key_pressed).
    pub const key_char: EventType = rgfw_h.RGFW_keyChar;
    pub const mouse_button_pressed: EventType = rgfw_h.RGFW_mouseButtonPressed;
    pub const mouse_button_released: EventType = rgfw_h.RGFW_mouseButtonReleased;
    pub const mouse_scroll: EventType = rgfw_h.RGFW_mouseScroll;
    pub const mouse_pos_changed: EventType = rgfw_h.RGFW_mousePosChanged;
    pub const window_moved: EventType = rgfw_h.RGFW_windowMoved;
    pub const window_resized: EventType = rgfw_h.RGFW_windowResized;
    pub const focus_in: EventType = rgfw_h.RGFW_focusIn;
    pub const focus_out: EventType = rgfw_h.RGFW_focusOut;
    pub const mouse_enter: EventType = rgfw_h.RGFW_mouseEnter;
    pub const mouse_leave: EventType = rgfw_h.RGFW_mouseLeave;
    /// The window contents need repainting (e.g. after being un-occluded).
    pub const window_refresh: EventType = rgfw_h.RGFW_windowRefresh;
    /// The window was requested to close (e.g. user clicked the X button).
    pub const quit: EventType = rgfw_h.RGFW_quit;
    /// Files were dropped onto the window. Retrieve with `Window.getDataDrop`.
    pub const data_drop: EventType = rgfw_h.RGFW_dataDrop;
    /// Files are being dragged over the window. Get position with `Window.dataDragPosition`.
    pub const data_drag: EventType = rgfw_h.RGFW_dataDrag;
    pub const window_maximized: EventType = rgfw_h.RGFW_windowMaximized;
    pub const window_minimized: EventType = rgfw_h.RGFW_windowMinimized;
    pub const window_restored: EventType = rgfw_h.RGFW_windowRestored;
    /// The monitor's content scale factor changed (e.g. window moved to a HiDPI display).
    pub const scale_updated: EventType = rgfw_h.RGFW_scaleUpdated;
    pub const monitor_connected: EventType = rgfw_h.RGFW_monitorConnected;
    pub const monitor_disconnected: EventType = rgfw_h.RGFW_monitorDisconnected;
};

/// Back-compat alias for `event_type.quit`.
pub const quit: EventType = event_type.quit;

// ──────────────────────────────────────────────
// Key constants
// ──────────────────────────────────────────────

/// Named key constants for use with `Window.isKeyPressed`, `Window.isKeyDown`, etc.
///
/// ```zig
/// if (win.isKeyPressed(wndw.key.escape)) win.setShouldClose(true);
/// ```
pub const key = struct {
    pub const null_key: Key = rgfw_h.RGFW_keyNULL;
    pub const escape: Key = rgfw_h.RGFW_escape;
    pub const backtick: Key = rgfw_h.RGFW_backtick;
    pub const space: Key = rgfw_h.RGFW_space;
    pub const tab: Key = rgfw_h.RGFW_tab;
    pub const back_space: Key = rgfw_h.RGFW_backSpace;
    pub const @"return": Key = rgfw_h.RGFW_return;
    pub const delete: Key = rgfw_h.RGFW_delete;

    // Letters
    pub const a: Key = rgfw_h.RGFW_a;
    pub const b: Key = rgfw_h.RGFW_b;
    pub const c: Key = rgfw_h.RGFW_c;
    pub const d: Key = rgfw_h.RGFW_d;
    pub const e: Key = rgfw_h.RGFW_e;
    pub const f: Key = rgfw_h.RGFW_f;
    pub const g: Key = rgfw_h.RGFW_g;
    pub const h: Key = rgfw_h.RGFW_h;
    pub const i: Key = rgfw_h.RGFW_i;
    pub const j: Key = rgfw_h.RGFW_j;
    pub const k: Key = rgfw_h.RGFW_k;
    pub const l: Key = rgfw_h.RGFW_l;
    pub const m: Key = rgfw_h.RGFW_m;
    pub const n: Key = rgfw_h.RGFW_n;
    pub const o: Key = rgfw_h.RGFW_o;
    pub const p: Key = rgfw_h.RGFW_p;
    pub const q: Key = rgfw_h.RGFW_q;
    pub const r: Key = rgfw_h.RGFW_r;
    pub const s: Key = rgfw_h.RGFW_s;
    pub const t: Key = rgfw_h.RGFW_t;
    pub const u: Key = rgfw_h.RGFW_u;
    pub const v: Key = rgfw_h.RGFW_v;
    pub const w: Key = rgfw_h.RGFW_w;
    pub const x: Key = rgfw_h.RGFW_x;
    pub const y: Key = rgfw_h.RGFW_y;
    pub const z: Key = rgfw_h.RGFW_z;

    // Numbers
    pub const @"0": Key = rgfw_h.RGFW_0;
    pub const @"1": Key = rgfw_h.RGFW_1;
    pub const @"2": Key = rgfw_h.RGFW_2;
    pub const @"3": Key = rgfw_h.RGFW_3;
    pub const @"4": Key = rgfw_h.RGFW_4;
    pub const @"5": Key = rgfw_h.RGFW_5;
    pub const @"6": Key = rgfw_h.RGFW_6;
    pub const @"7": Key = rgfw_h.RGFW_7;
    pub const @"8": Key = rgfw_h.RGFW_8;
    pub const @"9": Key = rgfw_h.RGFW_9;

    // Punctuation
    pub const minus: Key = rgfw_h.RGFW_minus;
    pub const equal: Key = rgfw_h.RGFW_equal;
    pub const period: Key = rgfw_h.RGFW_period;
    pub const comma: Key = rgfw_h.RGFW_comma;
    pub const slash: Key = rgfw_h.RGFW_slash;
    pub const bracket: Key = rgfw_h.RGFW_bracket;
    pub const close_bracket: Key = rgfw_h.RGFW_closeBracket;
    pub const semicolon: Key = rgfw_h.RGFW_semicolon;
    pub const apostrophe: Key = rgfw_h.RGFW_apostrophe;
    pub const back_slash: Key = rgfw_h.RGFW_backSlash;

    // Arrow keys
    pub const up: Key = rgfw_h.RGFW_up;
    pub const down: Key = rgfw_h.RGFW_down;
    pub const left: Key = rgfw_h.RGFW_left;
    pub const right: Key = rgfw_h.RGFW_right;

    // Navigation
    pub const insert: Key = rgfw_h.RGFW_insert;
    pub const end: Key = rgfw_h.RGFW_end;
    pub const home: Key = rgfw_h.RGFW_home;
    pub const page_up: Key = rgfw_h.RGFW_pageUp;
    pub const page_down: Key = rgfw_h.RGFW_pageDown;
    pub const menu: Key = rgfw_h.RGFW_menu;

    // Function keys
    pub const f1: Key = rgfw_h.RGFW_F1;
    pub const f2: Key = rgfw_h.RGFW_F2;
    pub const f3: Key = rgfw_h.RGFW_F3;
    pub const f4: Key = rgfw_h.RGFW_F4;
    pub const f5: Key = rgfw_h.RGFW_F5;
    pub const f6: Key = rgfw_h.RGFW_F6;
    pub const f7: Key = rgfw_h.RGFW_F7;
    pub const f8: Key = rgfw_h.RGFW_F8;
    pub const f9: Key = rgfw_h.RGFW_F9;
    pub const f10: Key = rgfw_h.RGFW_F10;
    pub const f11: Key = rgfw_h.RGFW_F11;
    pub const f12: Key = rgfw_h.RGFW_F12;
    pub const f13: Key = rgfw_h.RGFW_F13;
    pub const f14: Key = rgfw_h.RGFW_F14;
    pub const f15: Key = rgfw_h.RGFW_F15;
    pub const @"f16": Key = rgfw_h.RGFW_F16;
    pub const f17: Key = rgfw_h.RGFW_F17;
    pub const f18: Key = rgfw_h.RGFW_F18;
    pub const f19: Key = rgfw_h.RGFW_F19;
    pub const f20: Key = rgfw_h.RGFW_F20;
    pub const f21: Key = rgfw_h.RGFW_F21;
    pub const f22: Key = rgfw_h.RGFW_F22;
    pub const f23: Key = rgfw_h.RGFW_F23;
    pub const f24: Key = rgfw_h.RGFW_F24;
    pub const f25: Key = rgfw_h.RGFW_F25;

    // Modifiers
    pub const caps_lock: Key = rgfw_h.RGFW_capsLock;
    pub const shift_l: Key = rgfw_h.RGFW_shiftL;
    pub const control_l: Key = rgfw_h.RGFW_controlL;
    pub const alt_l: Key = rgfw_h.RGFW_altL;
    pub const super_l: Key = rgfw_h.RGFW_superL;
    pub const shift_r: Key = rgfw_h.RGFW_shiftR;
    pub const control_r: Key = rgfw_h.RGFW_controlR;
    pub const alt_r: Key = rgfw_h.RGFW_altR;
    pub const super_r: Key = rgfw_h.RGFW_superR;

    // Lock keys
    pub const num_lock: Key = rgfw_h.RGFW_numLock;
    pub const scroll_lock: Key = rgfw_h.RGFW_scrollLock;
    pub const print_screen: Key = rgfw_h.RGFW_printScreen;
    pub const pause: Key = rgfw_h.RGFW_pause;

    // Keypad
    pub const kp_slash: Key = rgfw_h.RGFW_kpSlash;
    pub const kp_multiply: Key = rgfw_h.RGFW_kpMultiply;
    pub const kp_plus: Key = rgfw_h.RGFW_kpPlus;
    pub const kp_minus: Key = rgfw_h.RGFW_kpMinus;
    pub const kp_equal: Key = rgfw_h.RGFW_kpEqual;
    pub const kp_return: Key = rgfw_h.RGFW_kpReturn;
    pub const kp_period: Key = rgfw_h.RGFW_kpPeriod;
    pub const kp_0: Key = rgfw_h.RGFW_kp0;
    pub const kp_1: Key = rgfw_h.RGFW_kp1;
    pub const kp_2: Key = rgfw_h.RGFW_kp2;
    pub const kp_3: Key = rgfw_h.RGFW_kp3;
    pub const kp_4: Key = rgfw_h.RGFW_kp4;
    pub const kp_5: Key = rgfw_h.RGFW_kp5;
    pub const kp_6: Key = rgfw_h.RGFW_kp6;
    pub const kp_7: Key = rgfw_h.RGFW_kp7;
    pub const kp_8: Key = rgfw_h.RGFW_kp8;
    pub const kp_9: Key = rgfw_h.RGFW_kp9;

    // International
    /// Non-US key #1.
    pub const world1: Key = rgfw_h.RGFW_world1;
    /// Non-US key #2.
    pub const world2: Key = rgfw_h.RGFW_world2;

    // Sentinel
    /// Upper bound / padding value for key arrays. Not a real key.
    pub const last: Key = rgfw_h.RGFW_keyLast;

    // Convenience aliases
    /// Alias for `@"return"` — avoids the need for `@""` quoting.
    pub const enter: Key = rgfw_h.RGFW_return;
    /// Alias for `equal`.
    pub const equals: Key = rgfw_h.RGFW_equal;
    /// Alias for `kp_equal`.
    pub const kp_equals: Key = rgfw_h.RGFW_kpEqual;
};

// ──────────────────────────────────────────────
// Key modifier constants
// ──────────────────────────────────────────────

/// Bitmask constants for checking modifier key state from `KeyMod` fields on key events.
/// These are bit flags — test with `&`:
///
/// ```zig
/// if (ev.key.mod & wndw.keymod.control != 0) { /* Ctrl held */ }
/// ```
pub const keymod = struct {
    pub const caps_lock: KeyMod = rgfw_h.RGFW_modCapsLock;
    pub const num_lock: KeyMod = rgfw_h.RGFW_modNumLock;
    pub const control: KeyMod = rgfw_h.RGFW_modControl;
    pub const alt: KeyMod = rgfw_h.RGFW_modAlt;
    pub const shift: KeyMod = rgfw_h.RGFW_modShift;
    pub const super: KeyMod = rgfw_h.RGFW_modSuper;
    pub const scroll_lock: KeyMod = rgfw_h.RGFW_modScrollLock;
};

// ──────────────────────────────────────────────
// Mouse button constants
// ──────────────────────────────────────────────

/// Named mouse button constants for use with `Window.isMousePressed`, etc.
pub const mouse = struct {
    pub const left: MouseButton = rgfw_h.RGFW_mouseLeft;
    pub const middle: MouseButton = rgfw_h.RGFW_mouseMiddle;
    pub const right: MouseButton = rgfw_h.RGFW_mouseRight;
    pub const misc1: MouseButton = rgfw_h.RGFW_mouseMisc1;
    pub const misc2: MouseButton = rgfw_h.RGFW_mouseMisc2;
    pub const misc3: MouseButton = rgfw_h.RGFW_mouseMisc3;
    pub const misc4: MouseButton = rgfw_h.RGFW_mouseMisc4;
    pub const misc5: MouseButton = rgfw_h.RGFW_mouseMisc5;
};

// ──────────────────────────────────────────────
// Mouse cursor icon constants
// ──────────────────────────────────────────────

/// Standard cursor shapes for `Window.setMouseCursor`.
///
/// ```zig
/// _ = win.setMouseCursor(wndw.cursor.pointing_hand);
/// ```
pub const cursor = struct {
    pub const normal: MouseIcon = rgfw_h.RGFW_mouseNormal;
    pub const arrow: MouseIcon = rgfw_h.RGFW_mouseArrow;
    /// Text selection / I-beam cursor.
    pub const ibeam: MouseIcon = rgfw_h.RGFW_mouseIbeam;
    pub const crosshair: MouseIcon = rgfw_h.RGFW_mouseCrosshair;
    /// Hand cursor, typically used for clickable links.
    pub const pointing_hand: MouseIcon = rgfw_h.RGFW_mousePointingHand;
    /// Horizontal resize (east-west).
    pub const resize_ew: MouseIcon = rgfw_h.RGFW_mouseResizeEW;
    /// Vertical resize (north-south).
    pub const resize_ns: MouseIcon = rgfw_h.RGFW_mouseResizeNS;
    pub const resize_nwse: MouseIcon = rgfw_h.RGFW_mouseResizeNWSE;
    pub const resize_nesw: MouseIcon = rgfw_h.RGFW_mouseResizeNESW;
    /// Omnidirectional resize / move cursor.
    pub const resize_all: MouseIcon = rgfw_h.RGFW_mouseResizeAll;
    /// "Forbidden" / circle-with-slash cursor.
    pub const not_allowed: MouseIcon = rgfw_h.RGFW_mouseNotAllowed;
    /// Busy / hourglass cursor.
    pub const wait: MouseIcon = rgfw_h.RGFW_mouseWait;
    /// Background activity cursor (arrow + spinner).
    pub const progress: MouseIcon = rgfw_h.RGFW_mouseProgress;

    // Directional resize cursors
    /// North-west resize cursor.
    pub const resize_nw: MouseIcon = rgfw_h.RGFW_mouseResizeNW;
    /// North resize cursor.
    pub const resize_n: MouseIcon = rgfw_h.RGFW_mouseResizeN;
    /// North-east resize cursor.
    pub const resize_ne: MouseIcon = rgfw_h.RGFW_mouseResizeNE;
    /// East resize cursor.
    pub const resize_e: MouseIcon = rgfw_h.RGFW_mouseResizeE;
    /// South-east resize cursor.
    pub const resize_se: MouseIcon = rgfw_h.RGFW_mouseResizeSE;
    /// South resize cursor.
    pub const resize_s: MouseIcon = rgfw_h.RGFW_mouseResizeS;
    /// South-west resize cursor.
    pub const resize_sw: MouseIcon = rgfw_h.RGFW_mouseResizeSW;
    /// West resize cursor.
    pub const resize_w: MouseIcon = rgfw_h.RGFW_mouseResizeW;
};

// ──────────────────────────────────────────────
// Errors
// ──────────────────────────────────────────────

pub const Error = error{
    CreateWindowFailed,
};

// ──────────────────────────────────────────────
// Point / Size helpers
// ──────────────────────────────────────────────

/// A 2D point in screen coordinates. Returned by position queries.
pub const Point = struct { x: i32, y: i32 };
/// A 2D size in pixels or screen units. Returned by size queries.
pub const Size = struct { w: i32, h: i32 };

// ──────────────────────────────────────────────
// Custom mouse cursor
// ──────────────────────────────────────────────

/// A custom mouse cursor loaded from pixel data. Create with `Mouse.load`,
/// apply to a window with `Window.setCustomMouse`, and release with `free`.
///
/// ```zig
/// const cursor_data: [*]u8 = /* 32x32 RGBA pixels */;
/// if (Mouse.load(cursor_data, 32, 32, wndw.format.rgba8)) |custom| {
///     defer custom.free();
///     win.setCustomMouse(custom);
/// }
/// ```
pub const Mouse = struct {
    handle: *rgfw_h.RGFW_mouse,

    /// Creates a cursor from raw pixel data. Returns `null` if the platform
    /// failed to create the cursor.
    pub fn load(data: [*]u8, w: i32, h: i32, fmt: Format) ?Mouse {
        const m = rgfw_h.RGFW_loadMouse(data, w, h, fmt) orelse return null;
        return .{ .handle = m };
    }

    /// Releases the platform cursor resources. Do not use the `Mouse` after this.
    pub fn free(self: Mouse) void {
        rgfw_h.RGFW_freeMouse(self.handle);
    }
};

// ──────────────────────────────────────────────
// Monitor
// ──────────────────────────────────────────────

/// Represents a physical display. Obtain via `getPrimaryMonitor`, `getMonitors`,
/// or `Window.getMonitor`.
pub const Monitor = struct {
    handle: *rgfw_h.RGFW_monitor,

    /// Returns the human-readable monitor name as a Zig slice (no allocation).
    pub fn name(self: Monitor) []const u8 {
        const raw: [*]const u8 = @ptrCast(rgfw_h.RGFW_monitor_getName(self.handle));
        const len = blk: {
            var idx: usize = 0;
            while (idx < 128 and raw[idx] != 0) : (idx += 1) {}
            break :blk idx;
        };
        return raw[0..len];
    }

    /// Returns the top-left corner of the monitor's workarea in screen coordinates.
    pub fn position(self: Monitor) Point {
        var x: i32 = 0;
        var y: i32 = 0;
        _ = rgfw_h.RGFW_monitor_getPosition(self.handle, &x, &y);
        return .{ .x = x, .y = y };
    }

    /// Returns the content scale factors. 1.0 = standard, 2.0 = HiDPI/Retina.
    pub fn scale(self: Monitor) struct { x: f32, y: f32 } {
        var x: f32 = 0;
        var y: f32 = 0;
        _ = rgfw_h.RGFW_monitor_getScale(self.handle, &x, &y);
        return .{ .x = x, .y = y };
    }

    /// Returns the pixel ratio (1.0 for standard displays, 2.0 for HiDPI).
    pub fn pixelRatio(self: Monitor) f32 {
        return self.handle.*.pixelRatio;
    }

    /// Returns the physical display size in inches.
    pub fn physicalSize(self: Monitor) struct { w: f32, h: f32 } {
        var w: f32 = 0;
        var h: f32 = 0;
        _ = rgfw_h.RGFW_monitor_getPhysicalSize(self.handle, &w, &h);
        return .{ .w = w, .h = h };
    }

    /// Returns the current display mode (resolution and refresh rate).
    pub fn mode(self: Monitor) struct { w: i32, h: i32, refresh_rate: f32 } {
        const m = self.handle.*.mode;
        return .{ .w = m.w, .h = m.h, .refresh_rate = m.refreshRate };
    }

        /// Retrieves the current display mode into `out`. Returns `true` on success.
    /// This is the live mode; use `mode()` for the cached value from the struct.
    pub fn getMode(self: Monitor, out: *MonitorMode) bool {
        return toBool(rgfw_h.RGFW_monitor_getMode(self.handle, out));
    }

    /// Finds the closest supported display mode to `target` and writes it into `closest`.
    /// Returns `true` if a match was found.
    ///
    /// ```zig
    /// var target = MonitorMode{ .w = 1920, .h = 1080, .refreshRate = 60.0, ... };
    /// var closest: MonitorMode = undefined;
    /// if (mon.findClosestMode(&target, &closest)) {
    ///     _ = mon.setMode(&closest);
    /// }
    /// ```
    pub fn findClosestMode(self: Monitor, target: *MonitorMode, closest: *MonitorMode) bool {
        return toBool(rgfw_h.RGFW_monitor_findClosestMode(self.handle, target, closest));
    }

    /// Scales this monitor's content to fit the given window.
    /// Returns `true` on success.
    pub fn scaleToWindow(self: Monitor, win: Window) bool {
        return toBool(rgfw_h.RGFW_monitor_scaleToWindow(self.handle, win.handle));
    }

    /// Returns the usable desktop area (excluding taskbar/dock), as position + size.
    pub fn workarea(self: Monitor) struct { x: i32, y: i32, w: i32, h: i32 } {
        var x: i32 = 0;
        var y: i32 = 0;
        var w: i32 = 0;
        var h: i32 = 0;
        _ = rgfw_h.RGFW_monitor_getWorkarea(self.handle, &x, &y, &w, &h);
        return .{ .x = x, .y = y, .w = w, .h = h };
    }

    /// Sets the monitor's gamma to a single value. 1.0 is normal.
    /// Returns `true` on success.
    pub fn setGamma(self: Monitor, gamma: f32) bool {
        return toBool(rgfw_h.RGFW_monitor_setGamma(self.handle, gamma));
    }

    /// Returns the monitor's gamma ramp, or `null` on failure.
    /// Free the result with `freeGammaRamp` when done.
    pub fn getGammaRamp(self: Monitor) ?*GammaRamp {
        return rgfw_h.RGFW_monitor_getGammaRamp(self.handle);
    }

    /// Applies a custom gamma ramp to the monitor. Returns `true` on success.
    pub fn setGammaRamp(self: Monitor, ramp: *GammaRamp) bool {
        return toBool(rgfw_h.RGFW_monitor_setGammaRamp(self.handle, ramp));
    }

    /// Requests a display mode change. `request` controls which properties to change
    /// (resolution, refresh rate, colour depth). Returns `true` on success.
    pub fn requestMode(self: Monitor, target_mode: *MonitorMode, request: ModeRequest) bool {
        return toBool(rgfw_h.RGFW_monitor_requestMode(self.handle, target_mode, request));
    }

    /// Directly sets the monitor to the given display mode. Returns `true` on success.
    pub fn setMode(self: Monitor, target_mode: *MonitorMode) bool {
        return toBool(rgfw_h.RGFW_monitor_setMode(self.handle, target_mode));
    }

    /// Attaches arbitrary user data to this monitor.
    pub fn setUserPtr(self: Monitor, ptr: ?*anyopaque) void {
        rgfw_h.RGFW_monitor_setUserPtr(self.handle, ptr);
    }

    /// Retrieves previously attached user data, cast to `*T`.
    /// Returns `null` if no data was set.
    pub fn getUserPtr(self: Monitor, comptime T: type) ?*T {
        const raw = rgfw_h.RGFW_monitor_getUserPtr(self.handle) orelse return null;
        return @ptrCast(@alignCast(raw));
    }

    /// Fills a pre-allocated `GammaRamp` with this monitor's gamma ramp data.
    /// Returns the ramp entry count. Pass a `null`-data ramp to query the count first.
    pub fn getGammaRampPtr(self: Monitor, ramp: *GammaRamp) usize {
        return rgfw_h.RGFW_monitor_getGammaRampPtr(self.handle, ramp);
    }

    /// Sets the monitor's gamma using a pre-allocated channel array.
    /// `gamma` is the exponent, `ptr` is the LUT data, and `count` is the array length.
    /// Returns `true` on success.
    pub fn setGammaPtr(self: Monitor, gamma: f32, ptr: [*]u16, count: usize) bool {
        return toBool(rgfw_h.RGFW_monitor_setGammaPtr(self.handle, gamma, ptr, count));
    }

    /// Fills a pre-allocated mode array with this monitor's supported modes.
    /// Returns the number of modes written. If `modes` is `null`, returns the
    /// estimated count without writing.
    pub fn getModesPtr(self: Monitor, modes: *[*]MonitorMode) usize {
        return rgfw_h.RGFW_monitor_getModesPtr(self.handle, modes);
    }
};

/// Returns the primary (main) monitor, or `null` if none is available.
pub fn getPrimaryMonitor() ?Monitor {
    const m = rgfw_h.RGFW_getPrimaryMonitor() orelse return null;
    return .{ .handle = m };
}

/// Fills `buf` with connected monitors and returns the populated slice.
/// The returned slice length is `@min(connected_count, buf.len)`.
///
/// ```zig
/// var buf: [8]wndw.Monitor = undefined;
/// for (wndw.getMonitors(&buf)) |mon| {
///     std.debug.print("monitor: {s}\n", .{mon.name()});
/// }
/// ```
pub fn getMonitors(buf: []Monitor) []Monitor {
    var len: usize = 0;
    const ptrs = rgfw_h.RGFW_getMonitors(&len) orelse return buf[0..0];
    const count = @min(len, buf.len);
    for (0..count) |idx| {
        buf[idx] = .{ .handle = ptrs[idx] };
    }
    return buf[0..count];
}

/// Re-scans for connected/disconnected monitors. Call periodically if you need
/// hot-plug detection.
pub fn pollMonitors() void {
    rgfw_h.RGFW_pollMonitors();
}

/// Frees a `GammaRamp` previously obtained from `Monitor.getGammaRamp`.
pub fn freeGammaRamp(ramp: *GammaRamp) void {
    rgfw_h.RGFW_freeGammaRamp(ramp);
}

// ──────────────────────────────────────────────
// Global input queries
// ──────────────────────────────────────────────

/// Window-independent (global) input state queries.
/// These reflect the state across all windows, unlike `Window.isKeyPressed` etc.
/// which are scoped to a single window.
pub const input = struct {
    /// Returns `true` if the key was just pressed this frame (edge-triggered).
    pub fn isKeyPressed(k: Key) bool {
        return toBool(rgfw_h.RGFW_isKeyPressed(k));
    }
    /// Returns `true` while the key is held down (level-triggered).
    pub fn isKeyDown(k: Key) bool {
        return toBool(rgfw_h.RGFW_isKeyDown(k));
    }
    /// Returns `true` if the key was just released this frame (edge-triggered).
    pub fn isKeyReleased(k: Key) bool {
        return toBool(rgfw_h.RGFW_isKeyReleased(k));
    }

    /// Returns `true` if the button was just pressed this frame.
    pub fn isMousePressed(button: MouseButton) bool {
        return toBool(rgfw_h.RGFW_isMousePressed(button));
    }
    /// Returns `true` while the button is held down.
    pub fn isMouseDown(button: MouseButton) bool {
        return toBool(rgfw_h.RGFW_isMouseDown(button));
    }
    /// Returns `true` if the button was just released this frame.
    pub fn isMouseReleased(button: MouseButton) bool {
        return toBool(rgfw_h.RGFW_isMouseReleased(button));
    }

    /// Returns the scroll wheel delta since the last poll. Positive y = scroll up.
    pub fn mouseScroll() struct { x: f32, y: f32 } {
        var x: f32 = 0;
        var y: f32 = 0;
        rgfw_h.RGFW_getMouseScroll(&x, &y);
        return .{ .x = x, .y = y };
    }

    /// Returns the mouse movement delta since the last poll.
    pub fn mouseVector() struct { x: f32, y: f32 } {
        var x: f32 = 0;
        var y: f32 = 0;
        rgfw_h.RGFW_getMouseVector(&x, &y);
        return .{ .x = x, .y = y };
    }

    /// Returns the mouse position in screen coordinates, or `null` on failure.
    pub fn globalMouse() ?Point {
        var x: i32 = 0;
        var y: i32 = 0;
        if (!toBool(rgfw_h.RGFW_getGlobalMouse(&x, &y))) return null;
        return .{ .x = x, .y = y };
    }
};

// ──────────────────────────────────────────────
// Key conversion
// ──────────────────────────────────────────────

/// Converts a platform-native (OS API) keycode to a wndw `Key`.
/// Useful when integrating with external input systems.
pub fn apiKeyToKey(keycode: u32) Key {
    return rgfw_h.RGFW_apiKeyToRGFW(keycode);
}

/// Converts a wndw `Key` back to the platform-native keycode.
pub fn keyToApiKey(k: Key) u32 {
    return rgfw_h.RGFW_rgfwToApiKey(k);
}

/// Maps a physical key (scan code) to the logical key for the current keyboard layout.
/// For example, on an AZERTY keyboard `physicalToMappedKey(key.a)` returns `key.q`.
pub fn physicalToMappedKey(k: Key) Key {
    return rgfw_h.RGFW_physicalToMappedKey(k);
}

// ──────────────────────────────────────────────
// Clipboard
// ──────────────────────────────────────────────

/// System clipboard access for text data.
pub const clipboard = struct {
    /// Returns the clipboard contents as a borrowed slice, or `null` if empty/unavailable.
    /// The returned memory is owned by RGFW and valid until the next clipboard operation.
    pub fn read() ?[]const u8 {
        var len: usize = 0;
        const ptr = rgfw_h.RGFW_readClipboard(&len) orelse return null;
        return ptr[0..len];
    }

    /// Reads clipboard text into a caller-provided buffer, avoiding internal allocation.
    /// Returns the populated slice, or `null` on failure.
    pub fn readInto(buf: []u8) ?[]const u8 {
        const result = rgfw_h.RGFW_readClipboardPtr(buf.ptr, buf.len);
        if (result < 0) return null;
        return buf[0..@intCast(result)];
    }

    /// Writes text to the system clipboard.
    pub fn write(text: []const u8) void {
        rgfw_h.RGFW_writeClipboard(text.ptr, @intCast(text.len));
    }
};

// ──────────────────────────────────────────────
// Global event helpers
// ──────────────────────────────────────────────

/// Processes all pending platform events across all windows.
/// Call once per frame before polling individual window events.
pub fn pollEvents() void {
    rgfw_h.RGFW_pollEvents();
}

/// Enables or disables event queuing. When enabled (`true`), events are buffered
/// and consumed via `pollEvent`/`checkQueuedEvent`. When disabled, events are
/// processed immediately as they arrive.
pub fn setQueueEvents(queue: bool) void {
    rgfw_h.RGFW_setQueueEvents(fromBool(queue));
}

/// Blocks until an event arrives or `wait_ms` milliseconds elapse.
/// Pass `-1` to wait indefinitely.
pub fn waitForEvent(wait_ms: i32) void {
    rgfw_h.RGFW_waitForEvent(wait_ms);
}

/// Signals the event loop to stop checking events, unblocking `waitForEvent`
/// from another thread.
pub fn stopCheckEvents() void {
    rgfw_h.RGFW_stopCheckEvents();
}

/// Checks for the next event across all windows (non-queued mode).
/// Returns `true` and fills `out` if an event was available.
pub fn checkEvent(out: *Event) bool {
    return toBool(rgfw_h.RGFW_checkEvent(out));
}

/// Pops the next event from the global queue (queued mode).
/// Returns `true` and fills `out` if an event was available.
pub fn checkQueuedEvent(out: *Event) bool {
    return toBool(rgfw_h.RGFW_checkQueuedEvent(out));
}

/// Discards all events currently in the global queue.
pub fn eventQueueFlush() void {
    rgfw_h.RGFW_eventQueueFlush();
}

// ──────────────────────────────────────────────
// Root window
// ──────────────────────────────────────────────

/// Designates a window as the "root" window. RGFW uses this for certain
/// platform operations that require a primary window reference.
pub fn setRootWindow(win: Window) void {
    rgfw_h.RGFW_setRootWindow(win.handle);
}

/// Returns the current root window, or `null` if none has been set.
pub fn getRootWindow() ?Window {
    const w = rgfw_h.RGFW_getRootWindow() orelse return null;
    return .{ .handle = w };
}

// ──────────────────────────────────────────────
// Global raw mouse mode
// ──────────────────────────────────────────────

/// Enables or disables raw (unaccelerated) mouse input globally.
/// For per-window control, use `Window.setRawMouseMode` instead.
pub fn setRawMouseMode(raw: bool) void {
    rgfw_h.RGFW_setRawMouseMode(fromBool(raw));
}

// ──────────────────────────────────────────────
// Native format
// ──────────────────────────────────────────────

/// Returns the pixel format native to the current platform (e.g. `format.bgra8` on Windows,
/// `format.rgba8` on most others). Useful when creating surfaces or icons to avoid conversion.
pub fn nativeFormat() Format {
    return rgfw_h.RGFW_nativeFormat();
}

// ──────────────────────────────────────────────
// Class / instance name (X11)
// ──────────────────────────────────────────────

/// Sets the X11 window class name. Has no effect on other platforms.
/// Call before `init` for the class to take effect on all new windows.
pub fn setClassName(name_str: [:0]const u8) void {
    rgfw_h.RGFW_setClassName(name_str.ptr);
}

/// Sets the X11 instance name. Has no effect on other platforms.
pub fn setXInstName(name_str: [:0]const u8) void {
    rgfw_h.RGFW_setXInstName(name_str.ptr);
}

// ──────────────────────────────────────────────
// OpenGL types
// ──────────────────────────────────────────────

/// Opaque handle to an OpenGL rendering context.
pub const GlContext = rgfw_h.RGFW_glContext;

// ──────────────────────────────────────────────
// EGL types
// ──────────────────────────────────────────────

/// Opaque handle to an EGL rendering context.
pub const EglContext = rgfw_h.RGFW_eglContext;

// ──────────────────────────────────────────────
// OpenGL global functions
// ──────────────────────────────────────────────

/// Global OpenGL utilities. Requires the `rgfw_opengl` build option to be meaningful
/// at runtime, but these symbols are always present so the module compiles unconditionally.
pub const gl = struct {
    /// Sets the global OpenGL context hints used when creating new windows/contexts.
    /// Call before `init` or `Window.makeContextCurrent`.
    pub fn setGlobalHints(hints: *GlHints) void {
        rgfw_h.RGFW_setGlobalHints_OpenGL(hints);
    }

    /// Returns the current global GL hints, or `null` if not yet configured.
    pub fn getGlobalHints() ?*GlHints {
        return rgfw_h.RGFW_getGlobalHints_OpenGL();
    }

    /// Resets global GL hints to RGFW defaults (OpenGL 1.0, core, double-buffered, 8-bit RGBA, 24-bit depth).
    pub fn resetGlobalHints() void {
        rgfw_h.RGFW_resetGlobalHints_OpenGL();
    }

    /// Looks up an OpenGL function by name. Cast the result to the appropriate function pointer.
    /// Returns `null` if the function is not available.
    ///
    /// ```zig
    /// const glClear = @as(?*const fn (u32) callconv(.C) void,
    ///     @ptrCast(wndw.gl.getProcAddress("glClear")));
    /// ```
    pub fn getProcAddress(procname: [:0]const u8) ?*const anyopaque {
        const addr = rgfw_h.RGFW_getProcAddress_OpenGL(procname.ptr);
        return @ptrCast(addr);
    }

    /// Returns `true` if the named OpenGL extension is supported.
    pub fn extensionSupported(extension: [:0]const u8) bool {
        return toBool(rgfw_h.RGFW_extensionSupported_OpenGL(extension.ptr, extension.len));
    }

    /// Returns the window whose OpenGL context is currently active, or `null`.
    pub fn getCurrentWindow() ?Window {
        const w = rgfw_h.RGFW_getCurrentWindow_OpenGL() orelse return null;
        return .{ .handle = w };
    }

    /// Returns the native platform context handle from an `GlContext`, or `null`.
    /// Useful for interop with platform-specific OpenGL APIs.
    pub fn getSourceContext(ctx: *GlContext) ?*anyopaque {
        return rgfw_h.RGFW_glContext_getSourceContext(ctx);
    }

    /// Returns the raw native OpenGL context currently active on the calling thread, or `null`.
    /// Unlike `getCurrentWindow`, this returns the platform context handle directly.
    pub fn getCurrentContext() ?*anyopaque {
        return rgfw_h.RGFW_getCurrentContext_OpenGL();
    }

    /// Returns `true` if the named OpenGL extension is supported by the platform
    /// (e.g. WGL, GLX, or EGL), as opposed to the GL implementation itself.
    pub fn extensionSupportedPlatform(extension: [:0]const u8) bool {
        return toBool(rgfw_h.RGFW_extensionSupportedPlatform_OpenGL(extension.ptr, extension.len));
    }
};

// ──────────────────────────────────────────────
// EGL global functions
// ──────────────────────────────────────────────

/// Global EGL utilities for platforms using EGL (Linux/Wayland, Android, embedded).
/// These symbols are always present so the module compiles unconditionally.
pub const egl = struct {
    /// Returns the EGL display connection, or `null` if unavailable.
    pub fn getDisplay() ?*anyopaque {
        return rgfw_h.RGFW_getDisplay_EGL();
    }

    /// Returns the native EGL context handle from an `EglContext`, or `null`.
    pub fn getSourceContext(ctx: *EglContext) ?*anyopaque {
        return rgfw_h.RGFW_eglContext_getSourceContext(ctx);
    }

    /// Returns the EGL surface handle from an `EglContext`, or `null`.
    pub fn getSurface(ctx: *EglContext) ?*anyopaque {
        return rgfw_h.RGFW_eglContext_getSurface(ctx);
    }

    /// Returns the Wayland EGL window handle from an `EglContext`, or `null`.
    /// Only meaningful on Wayland.
    pub fn wlEGLWindow(ctx: *EglContext) ?*anyopaque {
        const ptr = rgfw_h.RGFW_eglContext_wlEGLWindow(ctx);
        return @ptrCast(ptr);
    }

    /// Returns the raw EGL context currently active on the calling thread, or `null`.
    pub fn getCurrentContext() ?*anyopaque {
        return rgfw_h.RGFW_getCurrentContext_EGL();
    }

    /// Returns the window whose EGL context is currently active, or `null`.
    pub fn getCurrentWindow() ?Window {
        const w = rgfw_h.RGFW_getCurrentWindow_EGL() orelse return null;
        return .{ .handle = w };
    }

    /// Looks up an EGL function by name. Cast the result to the appropriate function pointer.
    /// Returns `null` if the function is not available.
    pub fn getProcAddress(procname: [:0]const u8) ?*const anyopaque {
        const addr = rgfw_h.RGFW_getProcAddress_EGL(procname.ptr);
        return @ptrCast(addr);
    }

    /// Returns `true` if the named EGL extension is supported by the GL implementation.
    pub fn extensionSupported(extension: [:0]const u8) bool {
        return toBool(rgfw_h.RGFW_extensionSupported_EGL(extension.ptr, extension.len));
    }

    /// Returns `true` if the named EGL extension is supported by the platform.
    pub fn extensionSupportedPlatform(extension: [:0]const u8) bool {
        return toBool(rgfw_h.RGFW_extensionSupportedPlatform_EGL(extension.ptr, extension.len));
    }
};

// ──────────────────────────────────────────────
// Vulkan (requires rgfw_vulkan build option)
// ──────────────────────────────────────────────

/// Vulkan interop utilities. Only available when the `rgfw_vulkan` build option is enabled.
/// When disabled, this is an empty struct.
///
/// ```zig
/// // Build with: zig build -Drgfw_vulkan=true
/// const extensions = wndw.vulkan.getRequiredInstanceExtensions();
/// ```
pub const vulkan = if (@hasDecl(rgfw_h, "RGFW_getRequiredInstanceExtensions_Vulkan")) struct {
    pub const VkResult = rgfw_h.VkResult;
    pub const VkInstance = rgfw_h.VkInstance;
    pub const VkSurfaceKHR = rgfw_h.VkSurfaceKHR;
    pub const VkPhysicalDevice = rgfw_h.VkPhysicalDevice;

    /// Returns the Vulkan instance extensions required by RGFW (typically `VK_KHR_surface`
    /// and a platform-specific surface extension).
    pub fn getRequiredInstanceExtensions() struct { extensions: [*]const [*:0]const u8, count: usize } {
        var count: usize = 0;
        const exts = rgfw_h.RGFW_getRequiredInstanceExtensions_Vulkan(&count);
        return .{ .extensions = @ptrCast(exts), .count = count };
    }

    /// Checks whether the given physical device and queue family support presentation.
    pub fn getPresentationSupport(physical_device: VkPhysicalDevice, queue_family_index: u32) bool {
        return toBool(rgfw_h.RGFW_getPresentationSupport_Vulkan(physical_device, queue_family_index));
    }
} else struct {};

// ──────────────────────────────────────────────
// DirectX (requires rgfw_directx build option, Windows only)
// ──────────────────────────────────────────────

/// DirectX interop utilities. Only available when the `rgfw_directx` build option is
/// enabled on Windows. When disabled or on non-Windows platforms, this is an empty struct.
pub const directx = if (@hasDecl(rgfw_h, "RGFW_window_createSwapChain_DirectX")) struct {
    pub const IDXGIFactory = rgfw_h.IDXGIFactory;
    pub const IUnknown = rgfw_h.IUnknown;
    pub const IDXGISwapChain = rgfw_h.IDXGISwapChain;
} else struct {};

// ──────────────────────────────────────────────
// WebGPU (requires rgfw_webgpu build option)
// ──────────────────────────────────────────────

/// WebGPU interop utilities. Only available when the `rgfw_webgpu` build option is enabled.
/// When disabled, this is an empty struct.
pub const webgpu = if (@hasDecl(rgfw_h, "RGFW_window_createSurface_WebGPU")) struct {
    pub const WGPUSurface = rgfw_h.WGPUSurface;
    pub const WGPUInstance = rgfw_h.WGPUInstance;
} else struct {};

// ──────────────────────────────────────────────
// Window
// ──────────────────────────────────────────────

/// A cross-platform window. Created with `init` or `initAt`, destroyed with `close`.
///
/// Basic usage:
/// ```zig
/// const wndw = @import("wndw");
///
/// var win = try wndw.init("My App", 800, 600, .{});
/// defer win.close();
///
/// while (!win.shouldClose()) {
///     var ev: wndw.Event = undefined;
///     while (win.pollEvent(&ev)) {
///         // handle events ...
///     }
/// }
/// ```
pub const Window = struct {
    handle: *rgfw_h.RGFW_window,

    /// Declarative window configuration. All fields default to `null` (unchanged).
    /// Set a field to `true` to enable or `false` to disable.
    ///
    /// Used both at creation time (passed to `init`/`initAt`) and at runtime
    /// (passed to `setFlags` to modify an existing window).
    ///
    /// Note: `border` and `resizable` have inverted semantics internally
    /// (RGFW uses "NoBorder"/"NoResize" flags), but this struct lets you
    /// write `border: true` naturally.
    pub const FlagOptions = struct {
        /// Centre the window on screen.
        centered: ?bool = null,
        /// Alias for `centered` (British spelling).
        centred: ?bool = null,
        /// Allow the user to resize the window.
        resizable: ?bool = null,
        /// Show window decorations (title bar, border).
        border: ?bool = null,
        /// Enter exclusive fullscreen mode.
        fullscreen: ?bool = null,
        /// Keep the window above other windows.
        floating: ?bool = null,
        /// Create the window hidden (call `show` later).
        hidden: ?bool = null,
        /// Start maximized.
        maximize: ?bool = null,
        /// Start minimized.
        minimize: ?bool = null,
        /// Hide the mouse cursor when over this window.
        hide_mouse: ?bool = null,
        /// Automatically focus the window when shown.
        focus_on_show: ?bool = null,
        /// Request input focus immediately.
        focus: ?bool = null,
        /// Enable per-pixel transparency (compositing WM required).
        transparent: ?bool = null,
        /// Accept drag-and-drop file events.
        allow_dnd: ?bool = null,

        fn toFlags(opts: FlagOptions, current: rgfw_h.RGFW_windowFlags) rgfw_h.RGFW_windowFlags {
            var flags = current;
            const set = struct {
                fn apply(f: *rgfw_h.RGFW_windowFlags, bit: rgfw_h.RGFW_windowFlags, val: ?bool) void {
                    if (val) |v| {
                        if (v) f.* |= bit else f.* &= ~bit;
                    }
                }
            };
            if (opts.border) |b| set.apply(&flags, rgfw_h.RGFW_windowNoBorder, !b);
            if (opts.resizable) |r| set.apply(&flags, rgfw_h.RGFW_windowNoResize, !r);

            set.apply(&flags, rgfw_h.RGFW_windowFullscreen, opts.fullscreen);
            set.apply(&flags, rgfw_h.RGFW_windowFloating, opts.floating);
            set.apply(&flags, rgfw_h.RGFW_windowHide, opts.hidden);
            set.apply(&flags, rgfw_h.RGFW_windowMaximize, opts.maximize);
            set.apply(&flags, rgfw_h.RGFW_windowMinimize, opts.minimize);
            set.apply(&flags, rgfw_h.RGFW_windowHideMouse, opts.hide_mouse);
            set.apply(&flags, rgfw_h.RGFW_windowFocusOnShow, opts.focus_on_show);
            set.apply(&flags, rgfw_h.RGFW_windowFocus, opts.focus);
            set.apply(&flags, rgfw_h.RGFW_windowTransparent, opts.transparent);
            set.apply(&flags, rgfw_h.RGFW_windowAllowDND, opts.allow_dnd);

            const centered_val = opts.centered orelse opts.centred;
            set.apply(&flags, rgfw_h.RGFW_windowCenter, centered_val);

            return flags;
        }
    };

    // ── Lifecycle ────────────────────────────

    /// Destroys the window and releases all associated resources.
    /// The `Window` value must not be used after calling this.
    pub fn close(self: Window) void {
        rgfw_h.RGFW_window_close(self.handle);
    }

    /// Closes the window without freeing the underlying memory.
    /// Use this when the `RGFW_window` was allocated externally (e.g. via `initPtr`)
    /// and you want to manage the memory yourself.
    pub fn closePtr(self: Window) void {
        rgfw_h.RGFW_window_closePtr(self.handle);
    }

    // ── State queries ────────────────────────

    /// Returns `true` if the window has been requested to close (e.g. the user
    /// clicked the X button or `setShouldClose(true)` was called).
    pub fn shouldClose(self: Window) bool {
        return toBool(rgfw_h.RGFW_window_shouldClose(self.handle));
    }

    /// Returns `true` if the window is currently in fullscreen mode.
    pub fn isFullscreen(self: Window) bool {
        return toBool(rgfw_h.RGFW_window_isFullscreen(self.handle));
    }

    /// Returns `true` if the window is currently hidden (not visible).
    pub fn isHidden(self: Window) bool {
        return toBool(rgfw_h.RGFW_window_isHidden(self.handle));
    }

    /// Returns `true` if the window is currently minimized to the taskbar/dock.
    pub fn isMinimized(self: Window) bool {
        return toBool(rgfw_h.RGFW_window_isMinimized(self.handle));
    }

    /// Returns `true` if the window is currently maximized.
    pub fn isMaximized(self: Window) bool {
        return toBool(rgfw_h.RGFW_window_isMaximized(self.handle));
    }

    /// Returns `true` if the window has no decorations (borderless).
    pub fn isBorderless(self: Window) bool {
        return toBool(rgfw_h.RGFW_window_borderless(self.handle));
    }

    /// Returns `true` if the window is set to stay above other windows.
    pub fn isFloating(self: Window) bool {
        return toBool(rgfw_h.RGFW_window_isFloating(self.handle));
    }

    /// Returns `true` if the window currently has input focus.
    pub fn isInFocus(self: Window) bool {
        return toBool(rgfw_h.RGFW_window_isInFocus(self.handle));
    }

    /// Returns `true` if the mouse is currently captured (confined to this window).
    pub fn isCaptured(self: Window) bool {
        return toBool(rgfw_h.RGFW_window_isCaptured(self.handle));
    }

    /// Returns `true` if drag-and-drop is enabled for this window.
    pub fn allowsDND(self: Window) bool {
        return toBool(rgfw_h.RGFW_window_allowsDND(self.handle));
    }

    // ── State control ────────────────────────

    /// Marks the window as wanting to close. The window is not actually destroyed
    /// until you call `close`; this just causes `shouldClose` to return `true`.
    pub fn setShouldClose(self: Window, should_close: bool) void {
        rgfw_h.RGFW_window_setShouldClose(self.handle, fromBool(should_close));
    }

    /// Applies multiple window flags at once using the declarative `FlagOptions` struct.
    /// Only fields set to non-`null` are changed; others are left as-is.
    pub fn setFlags(self: Window, options: FlagOptions) void {
        rgfw_h.RGFW_window_setFlags(self.handle, options.toFlags(self.handle.*.internal.flags));
    }

    /// Returns the raw window flags bitmask.
    pub fn getFlags(self: Window) u32 {
        return rgfw_h.RGFW_window_getFlags(self.handle);
    }

    // ── Window operations ────────────────────

    /// Moves the window to the given screen coordinates.
    pub fn move(self: Window, x: i32, y: i32) void {
        rgfw_h.RGFW_window_move(self.handle, x, y);
    }

    /// Resizes the window's client area to the given dimensions.
    pub fn resize(self: Window, w: i32, h: i32) void {
        rgfw_h.RGFW_window_resize(self.handle, w, h);
    }

    /// Returns the window's current position in screen coordinates.
    pub fn position(self: Window) Point {
        var x: i32 = 0;
        var y: i32 = 0;
        _ = rgfw_h.RGFW_window_getPosition(self.handle, &x, &y);
        return .{ .x = x, .y = y };
    }

    /// Returns the window's client area size in screen units.
    pub fn size(self: Window) Size {
        var w: i32 = 0;
        var h: i32 = 0;
        _ = rgfw_h.RGFW_window_getSize(self.handle, &w, &h);
        return .{ .w = w, .h = h };
    }

    /// Returns the window's client area size in actual pixels.
    /// This differs from `size` on HiDPI displays where 1 screen unit > 1 pixel.
    pub fn sizeInPixels(self: Window) Size {
        var w: i32 = 0;
        var h: i32 = 0;
        _ = rgfw_h.RGFW_window_getSizeInPixels(self.handle, &w, &h);
        return .{ .w = w, .h = h };
    }

    /// Centres the window on its current monitor.
    pub fn center(self: Window) void {
        rgfw_h.RGFW_window_center(self.handle);
    }

    /// Requests input focus for this window.
    pub fn focus(self: Window) void {
        rgfw_h.RGFW_window_focus(self.handle);
    }

    /// Raises the window to the top of the stacking order without necessarily focusing it.
    pub fn raise(self: Window) void {
        rgfw_h.RGFW_window_raise(self.handle);
    }

    /// Maximizes the window to fill the available screen area.
    pub fn maximize(self: Window) void {
        rgfw_h.RGFW_window_maximize(self.handle);
    }

    /// Minimizes (iconifies) the window to the taskbar/dock.
    pub fn minimize(self: Window) void {
        rgfw_h.RGFW_window_minimize(self.handle);
    }

    /// Restores the window from a maximized or minimized state to its previous size.
    pub fn restore(self: Window) void {
        rgfw_h.RGFW_window_restore(self.handle);
    }

    /// Makes a hidden window visible.
    pub fn show(self: Window) void {
        rgfw_h.RGFW_window_show(self.handle);
    }

    /// Hides the window (it remains alive but is not visible).
    pub fn hide(self: Window) void {
        rgfw_h.RGFW_window_hide(self.handle);
    }

    /// Enters or exits fullscreen mode.
    pub fn setFullscreen(self: Window, fullscreen: bool) void {
        rgfw_h.RGFW_window_setFullscreen(self.handle, fromBool(fullscreen));
    }

    /// Sets the window opacity. `0` = fully transparent, `255` = fully opaque.
    pub fn setOpacity(self: Window, opacity: u8) void {
        rgfw_h.RGFW_window_setOpacity(self.handle, opacity);
    }

    /// Changes the window's title bar text.
    pub fn setName(self: Window, name_str: [:0]const u8) void {
        rgfw_h.RGFW_window_setName(self.handle, name_str.ptr);
    }

    /// Shows or hides window decorations (title bar, border).
    pub fn setBorder(self: Window, border: bool) void {
        rgfw_h.RGFW_window_setBorder(self.handle, fromBool(border));
    }

    /// Sets whether the window stays above other windows.
    pub fn setFloating(self: Window, floating: bool) void {
        rgfw_h.RGFW_window_setFloating(self.handle, fromBool(floating));
    }

    /// Enables or disables drag-and-drop for this window.
    pub fn setDND(self: Window, allow: bool) void {
        rgfw_h.RGFW_window_setDND(self.handle, fromBool(allow));
    }

    /// When enabled, mouse events pass through this window to whatever is behind it.
    pub fn setMousePassthrough(self: Window, passthrough: bool) void {
        rgfw_h.RGFW_window_setMousePassthrough(self.handle, fromBool(passthrough));
    }

    /// Flashes the window's taskbar/dock entry to attract attention.
    /// See `flash_request` for options.
    pub fn flashWindow(self: Window, request: FlashRequest) void {
        rgfw_h.RGFW_window_flash(self.handle, request);
    }

    // ── Icon ─────────────────────────────────

    /// Sets the window icon (both taskbar and title bar) from raw pixel data.
    /// Returns `true` on success.
    pub fn setIcon(self: Window, data: [*]u8, w: i32, h: i32, fmt: Format) bool {
        return toBool(rgfw_h.RGFW_window_setIcon(self.handle, data, w, h, fmt));
    }

    /// Sets the window icon for a specific target (taskbar, title bar, or both).
    /// Returns `true` on success. See `icon_type` for target values.
    pub fn setIconEx(self: Window, data: [*]u8, w: i32, h: i32, fmt: Format, icon: IconType) bool {
        return toBool(rgfw_h.RGFW_window_setIconEx(self.handle, data, w, h, fmt, icon));
    }

    // ── Size constraints ─────────────────────

    /// Locks the window's aspect ratio. The window manager will enforce this
    /// ratio when the user resizes. Pass `0, 0` to remove the constraint.
    pub fn setAspectRatio(self: Window, w: i32, h: i32) void {
        rgfw_h.RGFW_window_setAspectRatio(self.handle, w, h);
    }

    /// Sets the minimum allowed client area size. Pass `0, 0` to remove.
    pub fn setMinSize(self: Window, w: i32, h: i32) void {
        rgfw_h.RGFW_window_setMinSize(self.handle, w, h);
    }

    /// Sets the maximum allowed client area size. Pass `0, 0` to remove.
    pub fn setMaxSize(self: Window, w: i32, h: i32) void {
        rgfw_h.RGFW_window_setMaxSize(self.handle, w, h);
    }

    // ── Event polling ────────────────────────

    /// Convenience: enables event queuing and processes all pending platform events.
    /// Equivalent to calling `setQueueEvents(true)` then `pollEvents()`.
    pub fn poll(self: Window) void {
        _ = self;
        rgfw_h.RGFW_setQueueEvents(rgfw_h.RGFW_TRUE);
        rgfw_h.RGFW_pollEvents();
    }

    /// Pops the next queued event for this window into `out`.
    /// Returns `true` if an event was available. Call in a loop:
    ///
    /// ```zig
    /// var ev: wndw.Event = undefined;
    /// while (win.pollEvent(&ev)) {
    ///     switch (ev.type) { ... }
    /// }
    /// ```
    pub fn pollEvent(self: Window, out: *Event) bool {
        rgfw_h.RGFW_setQueueEvents(rgfw_h.RGFW_TRUE);
        return toBool(rgfw_h.RGFW_window_checkQueuedEvent(self.handle, out));
    }

    /// Non-queued event check: directly polls the OS for the next event on this window.
    /// Returns `true` and fills `out` if an event was available.
    pub fn checkEvent(self: Window, out: *Event) bool {
        return toBool(rgfw_h.RGFW_window_checkEvent(self.handle, out));
    }

    /// Pops and returns the next event from this window's queue, or `null` if empty.
    /// The returned pointer is valid until the next pop or flush.
    pub fn eventQueuePop(self: Window) ?*Event {
        return rgfw_h.RGFW_window_eventQueuePop(self.handle);
    }

    // ── Event filtering ──────────────────────

    /// Sets which event types this window will receive. Events not in the mask are silently discarded.
    /// Pass `event_flag.all` to receive everything (default).
    pub fn setEnabledEvents(self: Window, events: EventFlag) void {
        rgfw_h.RGFW_window_setEnabledEvents(self.handle, events);
    }

    /// Returns the current enabled-events bitmask.
    pub fn getEnabledEvents(self: Window) EventFlag {
        return rgfw_h.RGFW_window_getEnabledEvents(self.handle);
    }

    /// Disables the specified event types (removes them from the enabled set).
    pub fn setDisabledEvents(self: Window, events: EventFlag) void {
        rgfw_h.RGFW_window_setDisabledEvents(self.handle, events);
    }

    /// Enables or disables a single event type.
    pub fn setEventState(self: Window, event: EventFlag, enabled: bool) void {
        rgfw_h.RGFW_window_setEventState(self.handle, event, fromBool(enabled));
    }

    // ── Keyboard input ───────────────────────

    /// Returns `true` if the key was just pressed this frame (edge-triggered, window-scoped).
    pub fn isKeyPressed(self: Window, k: Key) bool {
        return toBool(rgfw_h.RGFW_window_isKeyPressed(self.handle, k));
    }

    /// Returns `true` while the key is held down (level-triggered, window-scoped).
    pub fn isKeyDown(self: Window, k: Key) bool {
        return toBool(rgfw_h.RGFW_window_isKeyDown(self.handle, k));
    }

    /// Returns `true` if the key was just released this frame (edge-triggered, window-scoped).
    pub fn isKeyReleased(self: Window, k: Key) bool {
        return toBool(rgfw_h.RGFW_window_isKeyReleased(self.handle, k));
    }

    /// Sets a key that will automatically trigger `shouldClose` when pressed.
    /// Pass `key.null_key` to disable.
    pub fn setExitKey(self: Window, k: Key) void {
        rgfw_h.RGFW_window_setExitKey(self.handle, k);
    }

    /// Returns the current exit key, or `key.null_key` if none is set.
    pub fn getExitKey(self: Window) Key {
        return rgfw_h.RGFW_window_getExitKey(self.handle);
    }

    // ── Mouse input ──────────────────────────

    /// Returns `true` if the button was just pressed this frame (window-scoped).
    pub fn isMousePressed(self: Window, button: MouseButton) bool {
        return toBool(rgfw_h.RGFW_window_isMousePressed(self.handle, button));
    }

    /// Returns `true` while the button is held down (window-scoped).
    pub fn isMouseDown(self: Window, button: MouseButton) bool {
        return toBool(rgfw_h.RGFW_window_isMouseDown(self.handle, button));
    }

    /// Returns `true` if the button was just released this frame (window-scoped).
    pub fn isMouseReleased(self: Window, button: MouseButton) bool {
        return toBool(rgfw_h.RGFW_window_isMouseReleased(self.handle, button));
    }

    /// Returns the mouse cursor position relative to the window's client area.
    pub fn mousePosition(self: Window) Point {
        var x: i32 = 0;
        var y: i32 = 0;
        _ = rgfw_h.RGFW_window_getMouse(self.handle, &x, &y);
        return .{ .x = x, .y = y };
    }

    /// Returns `true` if the mouse cursor is currently within the window's client area.
    pub fn isMouseInside(self: Window) bool {
        return toBool(rgfw_h.RGFW_window_isMouseInside(self.handle));
    }

    /// Returns `true` if the mouse just entered the window this frame.
    pub fn didMouseEnter(self: Window) bool {
        return toBool(rgfw_h.RGFW_window_didMouseEnter(self.handle));
    }

    /// Returns `true` if the mouse just left the window this frame.
    pub fn didMouseLeave(self: Window) bool {
        return toBool(rgfw_h.RGFW_window_didMouseLeave(self.handle));
    }

    // ── Mouse / cursor control ───────────────

    /// Shows or hides the mouse cursor when it is over this window.
    pub fn showMouse(self: Window, visible: bool) void {
        rgfw_h.RGFW_window_showMouse(self.handle, fromBool(visible));
    }

    /// Warps the mouse cursor to the given position relative to the window.
    pub fn moveMouse(self: Window, x: i32, y: i32) void {
        rgfw_h.RGFW_window_moveMouse(self.handle, x, y);
    }

    /// Sets the mouse cursor to a standard system shape.
    /// Returns `true` on success. See `cursor.*` for shapes.
    pub fn setMouseCursor(self: Window, icon: MouseIcon) bool {
        return toBool(rgfw_h.RGFW_window_setMouseStandard(self.handle, icon));
    }

    /// Resets the cursor to the platform default (usually an arrow).
    /// Returns `true` on success.
    pub fn resetMouseCursor(self: Window) bool {
        return toBool(rgfw_h.RGFW_window_setMouseDefault(self.handle));
    }

    /// Sets a custom cursor from a `Mouse` handle created with `Mouse.load`.
    pub fn setCustomMouse(self: Window, custom_mouse: Mouse) void {
        rgfw_h.RGFW_window_setMouse(self.handle, custom_mouse.handle);
    }

    /// Confines the mouse cursor to this window's bounds. Pass `false` to release.
    pub fn captureMouse(self: Window, capture: bool) void {
        rgfw_h.RGFW_window_captureMouse(self.handle, fromBool(capture));
    }

    /// Captures the mouse AND enables raw (unaccelerated) input in one call.
    /// Equivalent to `captureMouse(true)` + `setRawMouseMode(true)`.
    pub fn captureRawMouse(self: Window, capture: bool) void {
        rgfw_h.RGFW_window_captureRawMouse(self.handle, fromBool(capture));
    }

    /// Enables or disables raw (unaccelerated) mouse input for this window.
    /// Raw mode reports relative deltas instead of absolute screen positions;
    /// useful for FPS camera controls.
    pub fn setRawMouseMode(self: Window, raw: bool) void {
        rgfw_h.RGFW_window_setRawMouseMode(self.handle, fromBool(raw));
    }

    /// Returns `true` if raw mouse mode is active for this window.
    pub fn isRawMouseMode(self: Window) bool {
        return toBool(rgfw_h.RGFW_window_isRawMouseMode(self.handle));
    }

    /// Returns `true` if the mouse cursor is currently hidden for this window.
    pub fn isMouseHidden(self: Window) bool {
        return toBool(rgfw_h.RGFW_window_isMouseHidden(self.handle));
    }

    // ── Drag & drop ─────────────────────────

    /// Returns `true` if files are currently being dragged over this window.
    pub fn isDataDragging(self: Window) bool {
        return toBool(rgfw_h.RGFW_window_isDataDragging(self.handle));
    }

    /// Returns the position of the drag cursor while files are being dragged
    /// over the window, or `null` if no drag is in progress.
    pub fn dataDragPosition(self: Window) ?Point {
        var x: i32 = 0;
        var y: i32 = 0;
        if (!toBool(rgfw_h.RGFW_window_getDataDrag(self.handle, &x, &y))) return null;
        return .{ .x = x, .y = y };
    }

    /// Returns `true` if files were just dropped onto this window this frame.
    /// Retrieve the file list with `getDataDrop`.
    pub fn didDataDrop(self: Window) bool {
        return toBool(rgfw_h.RGFW_window_didDataDrop(self.handle));
    }

    /// Returns the list of files that were dropped onto this window, or `null`
    /// if no drop occurred. The returned pointers are valid until the next event poll.
    ///
    /// ```zig
    /// if (win.getDataDrop()) |drop| {
    ///     for (drop.files[0..drop.count]) |file| {
    ///         std.debug.print("dropped: {s}\n", .{std.mem.span(file)});
    ///     }
    /// }
    /// ```
    pub fn getDataDrop(self: Window) ?struct { files: [*]const [*:0]const u8, count: usize } {
        var files: [*c]const [*c]const u8 = undefined;
        var count: usize = 0;
        if (!toBool(rgfw_h.RGFW_window_getDataDrop(self.handle, @ptrCast(&files), &count))) return null;
        return .{ .files = @ptrCast(files), .count = count };
    }

    // ── Monitor ──────────────────────────────

    /// Returns the monitor this window is currently on, or `null` if it cannot be determined.
    pub fn getMonitor(self: Window) ?Monitor {
        const m = rgfw_h.RGFW_window_getMonitor(self.handle) orelse return null;
        return .{ .handle = m };
    }

    /// Moves the window to the given monitor (centred on it).
    pub fn moveToMonitor(self: Window, mon: Monitor) void {
        rgfw_h.RGFW_window_moveToMonitor(self.handle, mon.handle);
    }

    /// Scales the window to match the monitor's content scale factor.
    /// Useful when moving between standard and HiDPI displays.
    pub fn scaleToMonitor(self: Window) void {
        rgfw_h.RGFW_window_scaleToMonitor(self.handle);
    }

    // ── Surface / software rendering ─────────

    /// Creates a renderable surface tied to this window from raw pixel data.
    /// Returns `null` on failure. Free with `freeSurface` when done.
    ///
    /// ```zig
    /// var pixels: [800 * 600 * 4]u8 = undefined;
    /// if (win.createSurface(&pixels, 800, 600, wndw.format.rgba8)) |surf| {
    ///     defer wndw.freeSurface(surf);
    ///     // draw into pixels...
    ///     win.blitSurface(surf);
    /// }
    /// ```
    pub fn createSurface(self: Window, data: [*]u8, w: i32, h: i32, fmt: Format) ?*Surface {
        return rgfw_h.RGFW_window_createSurface(self.handle, data, w, h, fmt);
    }

    /// Presents a software-rendered `Surface` to the window. The surface's pixel data
    /// is copied to the window's framebuffer and displayed.
    pub fn blitSurface(self: Window, surface: *Surface) void {
        rgfw_h.RGFW_window_blitSurface(self.handle, surface);
    }

    /// Creates a surface into a pre-allocated `Surface` struct, using this window's
    /// visual (important on X11 where visuals may differ between windows).
    /// Returns `true` on success.
    pub fn createSurfacePtr(self: Window, data: [*]u8, w: i32, h: i32, fmt: Format, surface: *Surface) bool {
        return toBool(rgfw_h.RGFW_window_createSurfacePtr(self.handle, data, w, h, fmt, surface));
    }

    // ── OpenGL (requires rgfw_opengl build option) ──

    /// Presents the OpenGL back buffer (equivalent to `glSwapBuffers`).
    pub fn swapBuffers(self: Window) void {
        rgfw_h.RGFW_window_swapBuffers_OpenGL(self.handle);
    }

    /// Sets the swap interval (VSync). `0` = no VSync, `1` = VSync,
    /// `-1` = adaptive VSync (if supported).
    pub fn swapInterval(self: Window, interval: i32) void {
        rgfw_h.RGFW_window_swapInterval_OpenGL(self.handle, interval);
    }

    /// Makes this window's OpenGL context current on the calling thread.
    pub fn makeContextCurrent(self: Window) void {
        rgfw_h.RGFW_window_makeContextCurrent_OpenGL(self.handle);
    }

    /// Destroys the OpenGL context associated with this window.
    /// After this call, OpenGL operations on this window are invalid.
    pub fn deleteContext(self: Window) void {
        const ctx = rgfw_h.RGFW_window_getContext_OpenGL(self.handle) orelse return;
        rgfw_h.RGFW_window_deleteContext_OpenGL(self.handle, ctx);
    }

    /// Creates a new OpenGL context for this window using the given hints.
    /// Returns the context, or `null` on failure. The caller owns the returned context
    /// and must free it with `deleteContextPtrOpenGL`.
    pub fn createOpenGLContext(self: Window, hints: *GlHints) ?*GlContext {
        return rgfw_h.RGFW_window_createContext_OpenGL(self.handle, hints);
    }

    /// Creates an OpenGL context into a pre-allocated `GlContext`.
    /// Returns `true` on success.
    pub fn createOpenGLContextPtr(self: Window, ctx: *GlContext, hints: *GlHints) bool {
        return toBool(rgfw_h.RGFW_window_createContextPtr_OpenGL(self.handle, ctx, hints));
    }

    /// Makes this window current using the platform OpenGL API directly.
    /// Unlike `makeContextCurrent`, this bypasses any RGFW tracking.
    pub fn makeCurrentWindowOpenGL(self: Window) void {
        rgfw_h.RGFW_window_makeCurrentWindow_OpenGL(self.handle);
    }

    /// Destroys a specific OpenGL context without freeing the `GlContext` memory.
    /// Use this for contexts created with `createOpenGLContextPtr`.
    pub fn deleteContextPtrOpenGL(self: Window, ctx: *GlContext) void {
        rgfw_h.RGFW_window_deleteContextPtr_OpenGL(self.handle, ctx);
    }

    // ── EGL (requires rgfw_egl build option) ──

    /// Creates a new EGL context for this window using the given hints.
    /// Returns the context, or `null` on failure.
    pub fn createEGLContext(self: Window, hints: *GlHints) ?*EglContext {
        return rgfw_h.RGFW_window_createContext_EGL(self.handle, hints);
    }

    /// Creates an EGL context into a pre-allocated `EglContext`.
    /// Returns `true` on success.
    pub fn createEGLContextPtr(self: Window, ctx: *EglContext, hints: *GlHints) bool {
        return toBool(rgfw_h.RGFW_window_createContextPtr_EGL(self.handle, ctx, hints));
    }

    /// Destroys an EGL context and frees its memory.
    pub fn deleteEGLContext(self: Window, ctx: *EglContext) void {
        rgfw_h.RGFW_window_deleteContext_EGL(self.handle, ctx);
    }

    /// Destroys an EGL context without freeing the `EglContext` memory.
    /// Use this for contexts created with `createEGLContextPtr`.
    pub fn deleteEGLContextPtr(self: Window, ctx: *EglContext) void {
        rgfw_h.RGFW_window_deleteContextPtr_EGL(self.handle, ctx);
    }

    /// Returns the EGL context associated with this window, or `null`.
    pub fn getEGLContext(self: Window) ?*EglContext {
        return rgfw_h.RGFW_window_getContext_EGL(self.handle);
    }

    /// Presents the EGL back buffer for this window.
    pub fn swapBuffersEGL(self: Window) void {
        rgfw_h.RGFW_window_swapBuffers_EGL(self.handle);
    }

    /// Makes this window's EGL context current using the platform API directly.
    pub fn makeCurrentWindowEGL(self: Window) void {
        rgfw_h.RGFW_window_makeCurrentWindow_EGL(self.handle);
    }

    /// Makes this window's EGL context current via RGFW tracking.
    /// Pass `null` to release the context from the current thread
    /// (useful when moving a context between threads).
    pub fn makeCurrentContextEGL(self: Window) void {
        rgfw_h.RGFW_window_makeCurrentContext_EGL(self.handle);
    }

    /// Sets the EGL swap interval for this window. `0` = no VSync, `1` = VSync.
    pub fn swapIntervalEGL(self: Window, interval: i32) void {
        rgfw_h.RGFW_window_swapInterval_EGL(self.handle, interval);
    }

    // ── Vulkan (requires rgfw_vulkan build option) ──

    /// Creates a Vulkan surface for this window.
    /// Returns `VK_SUCCESS` on success; writes the surface handle to `surface`.
    /// Only available when `rgfw_vulkan` build option is enabled.
    pub const createVulkanSurface = if (@hasDecl(rgfw_h, "RGFW_window_createSurface_Vulkan"))
        struct {
            fn call(self: Window, instance: vulkan.VkInstance, surface: *vulkan.VkSurfaceKHR) vulkan.VkResult {
                return rgfw_h.RGFW_window_createSurface_Vulkan(self.handle, instance, surface);
            }
        }.call
    else
        @as(?void, null);

    // ── DirectX (requires rgfw_directx build option, Windows only) ──

    /// Creates a DirectX swap chain for this window.
    /// Returns `0` on success; writes the swap chain to `swapchain`.
    /// Only available when `rgfw_directx` build option is enabled on Windows.
    pub const createDirectXSwapChain = if (@hasDecl(rgfw_h, "RGFW_window_createSwapChain_DirectX"))
        struct {
            fn call(self: Window, factory: *directx.IDXGIFactory, device: *directx.IUnknown, swapchain: **directx.IDXGISwapChain) i32 {
                return rgfw_h.RGFW_window_createSwapChain_DirectX(self.handle, factory, device, swapchain);
            }
        }.call
    else
        @as(?void, null);

    // ── WebGPU (requires rgfw_webgpu build option) ──

    /// Creates a WebGPU surface for this window.
    /// Returns the `WGPUSurface` handle.
    /// Only available when `rgfw_webgpu` build option is enabled.
    pub const createWebGPUSurface = if (@hasDecl(rgfw_h, "RGFW_window_createSurface_WebGPU"))
        struct {
            fn call(self: Window, instance: webgpu.WGPUInstance) webgpu.WGPUSurface {
                return rgfw_h.RGFW_window_createSurface_WebGPU(self.handle, instance);
            }
        }.call
    else
        @as(?void, null);

    // ── Platform-native handles ───────────────

    /// Returns a pointer to the internal platform source struct.
    /// The layout is platform-specific and opaque unless the `rgfw_native` build option is set.
    pub fn getSrc(self: Window) *rgfw_h.RGFW_window_src {
        return rgfw_h.RGFW_window_getSrc(self.handle);
    }

    /// Returns the macOS `NSView*` for this window, or `null` on other platforms.
    pub fn getViewOSX(self: Window) ?*anyopaque {
        return rgfw_h.RGFW_window_getView_OSX(self.handle);
    }

    /// Returns the macOS `NSWindow*` for this window, or `null` on other platforms.
    pub fn getWindowOSX(self: Window) ?*anyopaque {
        return rgfw_h.RGFW_window_getWindow_OSX(self.handle);
    }

    /// Sets the Core Animation layer for this window (macOS only). No-op on other platforms.
    pub fn setLayerOSX(self: Window, layer: ?*anyopaque) void {
        rgfw_h.RGFW_window_setLayer_OSX(self.handle, layer);
    }

    /// Returns the Win32 `HWND` for this window, or `null` on other platforms.
    pub fn getHWND(self: Window) ?*anyopaque {
        return rgfw_h.RGFW_window_getHWND(self.handle);
    }

    /// Returns the Win32 `HDC` (device context) for this window, or `null` on other platforms.
    pub fn getHDC(self: Window) ?*anyopaque {
        return rgfw_h.RGFW_window_getHDC(self.handle);
    }

    /// Returns the X11 window handle for this window, or `0` on other platforms.
    pub fn getWindowX11(self: Window) u64 {
        return rgfw_h.RGFW_window_getWindow_X11(self.handle);
    }

    /// Returns the Wayland `wl_surface*` for this window, or `null` on other platforms.
    pub fn getWindowWayland(self: Window) ?*anyopaque {
        const ptr = rgfw_h.RGFW_window_getWindow_Wayland(self.handle);
        return @ptrCast(ptr);
    }

    // ── User data ────────────────────────────

    /// Attaches an arbitrary pointer to this window for later retrieval.
    /// Useful for associating application state with a window.
    pub fn setUserPtr(self: Window, ptr: ?*anyopaque) void {
        rgfw_h.RGFW_window_setUserPtr(self.handle, ptr);
    }

    /// Retrieves the user pointer previously set with `setUserPtr`, cast to `*T`.
    /// Returns `null` if no pointer was set.
    ///
    /// ```zig
    /// win.setUserPtr(&my_app_state);
    /// // later:
    /// if (win.getUserPtr(AppState)) |state| { ... }
    /// ```
    pub fn getUserPtr(self: Window, comptime T: type) ?*T {
        const raw = rgfw_h.RGFW_window_getUserPtr(self.handle) orelse return null;
        return @ptrCast(@alignCast(raw));
    }
};

// ──────────────────────────────────────────────
// Window creation
// ──────────────────────────────────────────────

/// Creates a new window centred at the default position (0, 0) with the given title and size.
/// Configure initial state via `options` (all default to `null` / unchanged).
///
/// ```zig
/// var win = try wndw.init("Hello", 800, 600, .{ .resizable = true });
/// defer win.close();
/// ```
pub fn init(title: [:0]const u8, width: i32, height: i32, options: Window.FlagOptions) Error!Window {
    const window = rgfw_h.RGFW_createWindow(
        title.ptr,
        0,
        0,
        width,
        height,
        options.toFlags(0),
    ) orelse return error.CreateWindowFailed;

    return .{ .handle = window };
}

/// Creates a new window at a specific screen position.
///
/// ```zig
/// var win = try wndw.initAt("Hello", 100, 200, 800, 600, .{});
/// ```
pub fn initAt(title: [:0]const u8, x: i32, y: i32, width: i32, height: i32, options: Window.FlagOptions) Error!Window {
    const window = rgfw_h.RGFW_createWindow(
        title.ptr,
        x,
        y,
        width,
        height,
        options.toFlags(0),
    ) orelse return error.CreateWindowFailed;

    return .{ .handle = window };
}

/// Creates a window into a pre-allocated `RGFW_window` buffer.
/// Use this when you manage window memory yourself (e.g. via `alloc` / `sizeofWindow`).
///
/// ```zig
/// const buf: *rgfw_h.RGFW_window = @ptrCast(@alignCast(wndw.alloc(wndw.sizeofWindow())));
/// var win = try wndw.createWindowPtr("Hello", 0, 0, 800, 600, .{}, buf);
/// defer win.closePtr();
/// ```
pub fn createWindowPtr(title: [:0]const u8, x: i32, y: i32, width: i32, height: i32, options: Window.FlagOptions, win: *rgfw_h.RGFW_window) Error!Window {
    const window = rgfw_h.RGFW_createWindowPtr(
        title.ptr,
        x,
        y,
        width,
        height,
        options.toFlags(0),
        win,
    ) orelse return error.CreateWindowFailed;

    return .{ .handle = window };
}

// ──────────────────────────────────────────────
// Library init / deinit
// ──────────────────────────────────────────────

/// Explicitly initialises the RGFW backend. This is called automatically by `init`/`initAt`,
/// so you only need it if you want to set up global state (monitors, keycodes) before
/// creating any windows. Returns `0` on success.
pub fn initBackend() i32 {
    return rgfw_h.RGFW_init();
}

/// Tears down the RGFW backend and releases all global resources.
/// Call after all windows have been closed.
pub fn deinitBackend() void {
    rgfw_h.RGFW_deinit();
}

// ──────────────────────────────────────────────
// RGFW_info lifecycle
// ──────────────────────────────────────────────

/// Opaque handle to the global RGFW library state.
pub const Info = rgfw_h.RGFW_info;

/// Returns the size in bytes of the `Info` struct.
/// Useful for pre-allocating memory before calling `initPtr`.
pub fn sizeofInfo() usize {
    return rgfw_h.RGFW_sizeofInfo();
}

/// Initialises RGFW using a caller-provided `Info` struct.
/// This avoids RGFW's internal allocation and gives you full control over the
/// library state's lifetime. Returns `0` on success.
pub fn initPtr(info: *Info) i32 {
    return rgfw_h.RGFW_init_ptr(info);
}

/// Tears down a specific RGFW instance stored in the provided `Info` pointer.
pub fn deinitPtr(info: *Info) void {
    rgfw_h.RGFW_deinit_ptr(info);
}

/// Replaces the global `Info` pointer used by RGFW.
/// All subsequent RGFW operations will use this instance.
pub fn setInfo(info: *Info) void {
    rgfw_h.RGFW_setInfo(info);
}

/// Returns the current global `Info` pointer, or `null` if RGFW has not been initialised.
pub fn getInfo() ?*Info {
    return rgfw_h.RGFW_getInfo();
}

// ──────────────────────────────────────────────
// Allocator API
// ──────────────────────────────────────────────

/// Allocates `size` bytes using RGFW's internal allocator (defaults to `malloc`).
/// Useful when you need memory compatible with `rgfwFree`.
pub fn alloc(size: usize) ?*anyopaque {
    return rgfw_h.RGFW_alloc(size);
}

/// Frees memory previously allocated with `alloc`.
pub fn free(ptr: *anyopaque) void {
    rgfw_h.RGFW_free(ptr);
}

// ──────────────────────────────────────────────
// Sizeof helpers
// ──────────────────────────────────────────────

/// Returns the size in bytes of the `RGFW_window` struct.
pub fn sizeofWindow() usize {
    return rgfw_h.RGFW_sizeofWindow();
}

/// Returns the size in bytes of the platform-specific `RGFW_window_src` struct.
pub fn sizeofWindowSrc() usize {
    return rgfw_h.RGFW_sizeofWindowSrc();
}

/// Returns the size in bytes of the `RGFW_nativeImage` struct.
pub fn sizeofNativeImage() usize {
    return rgfw_h.RGFW_sizeofNativeImage();
}

/// Returns the size in bytes of the `RGFW_surface` struct.
pub fn sizeofSurface() usize {
    return rgfw_h.RGFW_sizeofSurface();
}

// ──────────────────────────────────────────────
// Surface creation (standalone)
// ──────────────────────────────────────────────

/// Creates a standalone renderable surface from raw pixel data (not tied to a window).
/// Returns `null` on failure. Free with `freeSurface` when done.
pub fn createSurface(data: [*]u8, w: i32, h: i32, fmt: Format) ?*Surface {
    return rgfw_h.RGFW_createSurface(data, w, h, fmt);
}

/// Frees a `Surface` previously created with `createSurface` or `Window.createSurface`.
pub fn freeSurface(surface: *Surface) void {
    rgfw_h.RGFW_surface_free(surface);
}

// ──────────────────────────────────────────────
// Surface ptr-variants
// ──────────────────────────────────────────────

/// Creates a standalone surface into a pre-allocated `Surface` struct.
/// Returns `true` on success.
///
/// Note: on X11, this uses the root window's visual. Use `Window.createSurfacePtr`
/// if the surface must match a specific window's visual.
pub fn createSurfacePtr(data: [*]u8, w: i32, h: i32, fmt: Format, surface: *Surface) bool {
    return toBool(rgfw_h.RGFW_createSurfacePtr(data, w, h, fmt, surface));
}

/// Frees only the internal buffers of a surface, leaving the `Surface` struct itself intact.
/// Use this for surfaces created with `createSurfacePtr` or `Window.createSurfacePtr`.
pub fn freeSurfacePtr(surface: *Surface) void {
    rgfw_h.RGFW_surface_freePtr(surface);
}

// ──────────────────────────────────────────────
// Image data conversion
// ──────────────────────────────────────────────

/// Describes a pixel colour channel layout (offsets and channel count).
pub const ColorLayout = rgfw_h.RGFW_colorLayout;

/// Callback for custom pixel format conversion. Receives dest/src buffers,
/// their layouts, and the pixel count.
pub const ConvertImageDataFunc = rgfw_h.RGFW_convertImageDataFunc;

/// Opaque handle to a platform-native image (used internally by surfaces).
pub const NativeImage = rgfw_h.RGFW_nativeImage;

/// Converts pixel data between formats. If `func` is `null`, the built-in converter is used.
///
/// ```zig
/// wndw.copyImageData(dest.ptr, 800, 600, wndw.format.rgba8, src.ptr, wndw.format.bgra8, null);
/// ```
pub fn copyImageData(
    dest_data: [*]u8,
    w: i32,
    h: i32,
    dest_format: Format,
    src_data: [*]u8,
    src_format: Format,
    func: ?ConvertImageDataFunc,
) void {
    rgfw_h.RGFW_copyImageData(dest_data, w, h, dest_format, src_data, src_format, func);
}

/// Sets the function used for converting surface pixel data between formats.
/// Pass `null` to restore the default converter.
pub fn surfaceSetConvertFunc(surface: *Surface, func: ?ConvertImageDataFunc) void {
    rgfw_h.RGFW_surface_setConvertFunc(surface, func);
}

/// Returns the platform-native image backing a surface, or `null`.
pub fn surfaceGetNativeImage(surface: *Surface) ?*NativeImage {
    return rgfw_h.RGFW_surface_getNativeImage(surface);
}

// ──────────────────────────────────────────────
// Monitor mode enumeration
// ──────────────────────────────────────────────

/// Returns all supported display modes for a monitor. The returned slice is
/// heap-allocated by RGFW; free it with `freeModes` when done.
/// Returns `null` on failure.
///
/// ```zig
/// if (mon.getModes()) |result| {
///     defer wndw.freeModes(result.modes);
///     for (result.modes[0..result.count]) |m| {
///         std.debug.print("{d}x{d} @ {d}Hz\n", .{ m.w, m.h, m.refreshRate });
///     }
/// }
/// ```
pub fn getMonitorModes(mon: Monitor) ?struct { modes: [*]MonitorMode, count: usize } {
    var count: usize = 0;
    const modes = rgfw_h.RGFW_monitor_getModes(mon.handle, &count) orelse return null;
    return .{ .modes = modes, .count = count };
}

/// Frees a mode list previously returned by `getMonitorModes`.
pub fn freeModes(modes: [*]MonitorMode) void {
    rgfw_h.RGFW_freeModes(modes);
}

/// Compares two monitor modes according to the given request flags.
/// Returns `true` if the modes match on the requested properties.
pub fn monitorModeCompare(a: *MonitorMode, b: *MonitorMode, request: ModeRequest) bool {
    return toBool(rgfw_h.RGFW_monitorModeCompare(a, b, request));
}

// ──────────────────────────────────────────────
// Event queue (advanced)
// ──────────────────────────────────────────────

/// Pushes a synthetic event onto the global event queue.
/// Useful for injecting custom events from application code.
pub fn eventQueuePush(event: *const Event) void {
    rgfw_h.RGFW_eventQueuePush(event);
}

/// Pops and returns the next event from the global queue, or `null` if empty.
/// The returned pointer is valid until the next pop or flush.
/// For window-specific pops, use `Window.eventQueuePop`.
pub fn eventQueuePop() ?*Event {
    return rgfw_h.RGFW_eventQueuePop();
}

// ──────────────────────────────────────────────
// Input state reset
// ──────────────────────────────────────────────

/// Resets all key states (pressed/down/released) to their default.
/// Useful when regaining focus or switching input contexts.
pub fn resetKey() void {
    rgfw_h.RGFW_resetKey();
}

/// Resets the "previous frame" input state snapshot. Call at the start of a
/// new frame if you need manual control over edge-triggered input detection.
pub fn resetPrevState() void {
    rgfw_h.RGFW_resetPrevState();
}

// ──────────────────────────────────────────────
// Platform helpers
// ──────────────────────────────────────────────

/// On macOS, changes the working directory to the app bundle's Resources folder.
/// This is necessary to find bundled assets when running as a `.app`. No-op on other platforms.
pub fn moveToMacOSResourceDir() void {
    rgfw_h.RGFW_moveToMacOSResourceDir();
}

/// On Linux, forces RGFW to use (or not use) Wayland instead of X11.
/// Must be called before `init` or `initBackend` to take effect.
pub fn useWayland(wayland: bool) void {
    rgfw_h.RGFW_useWayland(fromBool(wayland));
}

/// Returns `true` if RGFW is currently using the Wayland backend (Linux only).
/// Always returns `false` on non-Linux platforms.
pub fn usingWayland() bool {
    return toBool(rgfw_h.RGFW_usingWayland());
}

// ──────────────────────────────────────────────
// Platform-native global accessors
// ──────────────────────────────────────────────

/// Returns the macOS Core Animation layer, or `null` on other platforms.
pub fn getLayerOSX() ?*anyopaque {
    return rgfw_h.RGFW_getLayer_OSX();
}

/// Returns the X11 `Display*`, or `null` on other platforms.
pub fn getDisplayX11() ?*anyopaque {
    return rgfw_h.RGFW_getDisplay_X11();
}

/// Returns the Wayland `wl_display*`, or `null` on other platforms.
pub fn getDisplayWayland() ?*anyopaque {
    const ptr = rgfw_h.RGFW_getDisplay_Wayland();
    return @ptrCast(ptr);
}

/// Type alias for the platform-specific internal window source struct.
pub const WindowSrc = rgfw_h.RGFW_window_src;

// ──────────────────────────────────────────────
// UTF-8 utilities
// ──────────────────────────────────────────────

/// Decodes a single UTF-8 codepoint from `string` starting at `index.*`.
/// Advances `index.*` past the decoded bytes. Returns the Unicode codepoint.
///
/// ```zig
/// var idx: usize = 0;
/// while (idx < text.len) {
///     const cp = wndw.decodeUTF8(text.ptr, &idx);
///     // use codepoint...
/// }
/// ```
pub fn decodeUTF8(string: [*]const u8, index: *usize) u32 {
    return rgfw_h.RGFW_decodeUTF8(string, index);
}

/// Returns `true` if the string contains only Latin-1 (ISO 8859-1) characters.
pub fn isLatin(string: []const u8) bool {
    return toBool(rgfw_h.RGFW_isLatin(string.ptr, string.len));
}
