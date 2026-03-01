# wndw — Remaining RGFW Coverage

Tracked gaps between the RGFW C API and the `wndw` Zig wrapper, organized into implementation phases.

---

## Phase 1: Callbacks & Debug System

The entire callback registration system and debug/error type infrastructure. This is the largest missing surface area and is essential for event-driven architectures.

### Callback type aliases
- [ ] `RGFW_debugfunc`
- [ ] `RGFW_windowMovedfunc`
- [ ] `RGFW_windowResizedfunc`
- [ ] `RGFW_windowRestoredfunc`
- [ ] `RGFW_windowMaximizedfunc`
- [ ] `RGFW_windowMinimizedfunc`
- [ ] `RGFW_windowQuitfunc`
- [ ] `RGFW_focusfunc`
- [ ] `RGFW_mouseNotifyfunc`
- [ ] `RGFW_mousePosfunc`
- [ ] `RGFW_dataDragfunc`
- [ ] `RGFW_windowRefreshfunc`
- [ ] `RGFW_keyCharfunc`
- [ ] `RGFW_keyfunc`
- [ ] `RGFW_mouseButtonfunc`
- [ ] `RGFW_mouseScrollfunc`
- [ ] `RGFW_dataDropfunc`
- [ ] `RGFW_scaleUpdatedfunc`
- [ ] `RGFW_monitorfunc`

### Callback registration functions
- [ ] `RGFW_setDebugCallback`
- [ ] `RGFW_setWindowMovedCallback`
- [ ] `RGFW_setWindowResizedCallback`
- [ ] `RGFW_setWindowQuitCallback`
- [ ] `RGFW_setMousePosCallback`
- [ ] `RGFW_setWindowRefreshCallback`
- [ ] `RGFW_setFocusCallback`
- [ ] `RGFW_setMouseNotifyCallback`
- [ ] `RGFW_setDataDropCallback`
- [ ] `RGFW_setDataDragCallback`
- [ ] `RGFW_setKeyCallback`
- [ ] `RGFW_setKeyCharCallback`
- [ ] `RGFW_setMouseButtonCallback`
- [ ] `RGFW_setMouseScrollCallback`
- [ ] `RGFW_setWindowMaximizedCallback`
- [ ] `RGFW_setWindowMinimizedCallback`
- [ ] `RGFW_setWindowRestoredCallback`
- [ ] `RGFW_setScaleUpdatedCallback`
- [ ] `RGFW_setMonitorCallback`

### Debug & error types
- [ ] `RGFW_debugType` enum alias (`typeError`, `typeWarning`, `typeInfo`)
- [ ] `RGFW_errorCode` enum alias (all error/info/warning codes)
- [ ] `RGFW_sendDebugInfo` function

---

## Phase 2: Missing Constants & Type Aliases

Fill in remaining enum values, key constants, cursor shapes, and event sub-types.

### Window flags not in `FlagOptions`
- [ ] `RGFW_windowRawMouse` (start with raw mouse)
- [ ] `RGFW_windowScaleToMonitor`
- [ ] `RGFW_windowCenterCursor`
- [ ] `RGFW_windowCaptureMouse`
- [ ] `RGFW_windowOpenGL` (auto-create GL context)
- [ ] `RGFW_windowEGL` (auto-create EGL context)
- [ ] `RGFW_noDeinitOnClose`
- [ ] `RGFW_windowedFullscreen` (composite)
- [ ] `RGFW_windowCaptureRawMouse` (composite)

### Key constants (in `key` namespace)
- [ ] `key.enter` (alias for `key.@"return"`)
- [ ] `key.equals` (alias for `key.equal`)
- [ ] `key.kp_equals` (alias for `key.kp_equal`)
- [ ] `key.f13` through `key.f25`
- [ ] `key.world1`, `key.world2`
- [ ] `key.last` (sentinel value = 256)

### Cursor shapes (in `cursor` namespace)
- [ ] `cursor.resize_nw`
- [ ] `cursor.resize_n`
- [ ] `cursor.resize_ne`
- [ ] `cursor.resize_e`
- [ ] `cursor.resize_se`
- [ ] `cursor.resize_s`
- [ ] `cursor.resize_sw`
- [ ] `cursor.resize_w`

### Event wait constants
- [ ] `event_wait.no_wait` (= 0)
- [ ] `event_wait.next` (= -1)

### Event sub-struct type aliases
- [ ] `CommonEvent`
- [ ] `MouseButtonEvent`
- [ ] `MouseScrollEvent`
- [ ] `MousePosEvent`
- [ ] `KeyEvent`
- [ ] `KeyCharEvent`
- [ ] `DataDropEvent`
- [ ] `DataDragEvent`
- [ ] `ScaleUpdatedEvent`
- [ ] `MonitorEvent`

---

## Phase 3: OpenGL Context Management

Complete the OpenGL context API beyond the basic swap/current operations.

- [ ] `RGFW_glContext` type alias
- [ ] `Window.createOpenGLContext(hints)` — `RGFW_window_createContext_OpenGL`
- [ ] `Window.createOpenGLContextPtr(ctx, hints)` — `RGFW_window_createContextPtr_OpenGL`
- [ ] `Window.makeCurrentWindowOpenGL()` — `RGFW_window_makeCurrentWindow_OpenGL`
- [ ] `Window.deleteContextPtrOpenGL(ctx)` — `RGFW_window_deleteContextPtr_OpenGL`
- [ ] `gl.getSourceContext(ctx)` — `RGFW_glContext_getSourceContext`
- [ ] `gl.getCurrentContext()` — `RGFW_getCurrentContext_OpenGL`
- [ ] `gl.extensionSupportedPlatform(ext)` — `RGFW_extensionSupportedPlatform_OpenGL`

---

## Phase 4: EGL Context API

Full EGL context lifecycle for platforms using EGL (Linux/Wayland, Android, embedded).

- [ ] `RGFW_eglContext` type alias
- [ ] `Window.createEGLContext(hints)` — `RGFW_window_createContext_EGL`
- [ ] `Window.createEGLContextPtr(ctx, hints)` — `RGFW_window_createContextPtr_EGL`
- [ ] `Window.deleteEGLContext(ctx)` — `RGFW_window_deleteContext_EGL`
- [ ] `Window.deleteEGLContextPtr(ctx)` — `RGFW_window_deleteContextPtr_EGL`
- [ ] `Window.getEGLContext()` — `RGFW_window_getContext_EGL`
- [ ] `Window.swapBuffersEGL()` — `RGFW_window_swapBuffers_EGL`
- [ ] `Window.makeCurrentWindowEGL()` — `RGFW_window_makeCurrentWindow_EGL`
- [ ] `Window.makeCurrentContextEGL()` — `RGFW_window_makeCurrentContext_EGL`
- [ ] `Window.swapIntervalEGL(interval)` — `RGFW_window_swapInterval_EGL`
- [ ] `egl.getDisplay()` — `RGFW_getDisplay_EGL`
- [ ] `egl.getSourceContext(ctx)` — `RGFW_eglContext_getSourceContext`
- [ ] `egl.getSurface(ctx)` — `RGFW_eglContext_getSurface`
- [ ] `egl.wlEGLWindow(ctx)` — `RGFW_eglContext_wlEGLWindow`
- [ ] `egl.getCurrentContext()` — `RGFW_getCurrentContext_EGL`
- [ ] `egl.getCurrentWindow()` — `RGFW_getCurrentWindow_EGL`
- [ ] `egl.getProcAddress(name)` — `RGFW_getProcAddress_EGL`
- [ ] `egl.extensionSupported(ext)` — `RGFW_extensionSupported_EGL`
- [ ] `egl.extensionSupportedPlatform(ext)` — `RGFW_extensionSupportedPlatform_EGL`

---

## Phase 5: Vulkan & DirectX

Graphics API interop for non-OpenGL backends.

### Vulkan
- [ ] `vulkan.getRequiredInstanceExtensions()` — `RGFW_getRequiredInstanceExtensions_Vulkan`
- [ ] `Window.createVulkanSurface(instance)` — `RGFW_window_createSurface_Vulkan`
- [ ] `vulkan.getPresentationSupport(device, queueFamily)` — `RGFW_getPresentationSupport_Vulkan`

### DirectX
- [ ] `Window.createDirectXSwapChain(factory, device)` — `RGFW_window_createSwapChain_DirectX`

---

## Phase 6: Platform-Native Handle Accessors

Expose underlying OS window/display handles for interop with platform-specific or third-party libraries.

### macOS
- [ ] `Window.getViewOSX()` — `RGFW_window_getView_OSX`
- [ ] `Window.getWindowOSX()` — `RGFW_window_getWindow_OSX`
- [ ] `Window.setLayerOSX(layer)` — `RGFW_window_setLayer_OSX`
- [ ] `getLayerOSX()` — `RGFW_getLayer_OSX`

### Windows
- [ ] `Window.getHWND()` — `RGFW_window_getHWND`
- [ ] `Window.getHDC()` — `RGFW_window_getHDC`

### X11
- [ ] `Window.getWindowX11()` — `RGFW_window_getWindow_X11`
- [ ] `getDisplayX11()` — `RGFW_getDisplay_X11`

### Wayland
- [ ] `Window.getWindowWayland()` — `RGFW_window_getWindow_Wayland`
- [ ] `getDisplayWayland()` — `RGFW_getDisplay_Wayland`

### General
- [ ] `Window.getSrc()` — `RGFW_window_getSrc`
- [ ] `RGFW_window_src` type alias
- [ ] `usingWayland()` — `RGFW_usingWayland`

---

## Phase 7: Library Lifecycle & Memory

Advanced library state management, allocator hooks, and sizeof helpers.

### RGFW_info lifecycle
- [ ] `RGFW_info` type alias
- [ ] `sizeofInfo()` — `RGFW_sizeofInfo`
- [ ] `initPtr(info)` — `RGFW_init_ptr`
- [ ] `deinitPtr(info)` — `RGFW_deinit_ptr`
- [ ] `setInfo(info)` — `RGFW_setInfo`
- [ ] `getInfo()` — `RGFW_getInfo`

### Allocator API
- [ ] `alloc(size)` — `RGFW_alloc`
- [ ] `free(ptr)` — `RGFW_free`

### Sizeof helpers
- [ ] `sizeofWindow()` — `RGFW_sizeofWindow`
- [ ] `sizeofWindowSrc()` — `RGFW_sizeofWindowSrc`
- [ ] `sizeofNativeImage()` — `RGFW_sizeofNativeImage`
- [ ] `sizeofSurface()` — `RGFW_sizeofSurface`

---

## Phase 8: Surface & Image Data (Advanced)

Pre-allocated buffer variants and pixel format conversion for software rendering.

### Ptr-variant surface creation
- [ ] `createSurfacePtr(data, w, h, format, surface)` — `RGFW_createSurfacePtr`
- [ ] `Window.createSurfacePtr(data, w, h, format, surface)` — `RGFW_window_createSurfacePtr`
- [ ] `Surface.freePtr(surface)` — `RGFW_surface_freePtr`

### Image data conversion
- [ ] `RGFW_colorLayout` type alias
- [ ] `RGFW_convertImageDataFunc` callback type alias
- [ ] `RGFW_nativeImage` type alias
- [ ] `copyImageData(dest, w, h, dest_fmt, src, src_fmt, func)` — `RGFW_copyImageData`
- [ ] `Surface.setConvertFunc(func)` — `RGFW_surface_setConvertFunc`
- [ ] `Surface.getNativeImage()` — `RGFW_surface_getNativeImage`

### Monitor ptr-variants
- [ ] `Monitor.getGammaRampPtr(ramp)` — `RGFW_monitor_getGammaRampPtr`
- [ ] `Monitor.setGammaPtr(gamma, ptr, count)` — `RGFW_monitor_setGammaPtr`
- [ ] `Monitor.getModesPtr(modes)` — `RGFW_monitor_getModesPtr`

---

## Phase 9: Miscellaneous

Small remaining items.

- [ ] `Window.closePtr()` — `RGFW_window_closePtr` (close without freeing memory)
