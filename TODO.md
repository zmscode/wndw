# wndw — Remaining RGFW Coverage

Tracked gaps between the RGFW C API and the `wndw` Zig wrapper, organized into implementation phases.

---

## Phase 1: Callbacks & Debug System

The entire callback registration system and debug/error type infrastructure. This is the largest missing surface area and is essential for event-driven architectures.

### Callback type aliases
- [x] `RGFW_debugfunc`
- [x] `RGFW_windowMovedfunc`
- [x] `RGFW_windowResizedfunc`
- [x] `RGFW_windowRestoredfunc`
- [x] `RGFW_windowMaximizedfunc`
- [x] `RGFW_windowMinimizedfunc`
- [x] `RGFW_windowQuitfunc`
- [x] `RGFW_focusfunc`
- [x] `RGFW_mouseNotifyfunc`
- [x] `RGFW_mousePosfunc`
- [x] `RGFW_dataDragfunc`
- [x] `RGFW_windowRefreshfunc`
- [x] `RGFW_keyCharfunc`
- [x] `RGFW_keyfunc`
- [x] `RGFW_mouseButtonfunc`
- [x] `RGFW_mouseScrollfunc`
- [x] `RGFW_dataDropfunc`
- [x] `RGFW_scaleUpdatedfunc`
- [x] `RGFW_monitorfunc`

### Callback registration functions
- [x] `RGFW_setDebugCallback`
- [x] `RGFW_setWindowMovedCallback`
- [x] `RGFW_setWindowResizedCallback`
- [x] `RGFW_setWindowQuitCallback`
- [x] `RGFW_setMousePosCallback`
- [x] `RGFW_setWindowRefreshCallback`
- [x] `RGFW_setFocusCallback`
- [x] `RGFW_setMouseNotifyCallback`
- [x] `RGFW_setDataDropCallback`
- [x] `RGFW_setDataDragCallback`
- [x] `RGFW_setKeyCallback`
- [x] `RGFW_setKeyCharCallback`
- [x] `RGFW_setMouseButtonCallback`
- [x] `RGFW_setMouseScrollCallback`
- [x] `RGFW_setWindowMaximizedCallback`
- [x] `RGFW_setWindowMinimizedCallback`
- [x] `RGFW_setWindowRestoredCallback`
- [x] `RGFW_setScaleUpdatedCallback`
- [x] `RGFW_setMonitorCallback`

### Debug & error types
- [x] `RGFW_debugType` enum alias (`typeError`, `typeWarning`, `typeInfo`)
- [x] `RGFW_errorCode` enum alias (all error/info/warning codes)
- [x] `RGFW_sendDebugInfo` function

---

## Phase 2: Missing Constants & Type Aliases

Fill in remaining enum values, key constants, cursor shapes, and event sub-types.

### Window flags not in `FlagOptions`
- [x] `RGFW_windowRawMouse` (start with raw mouse)
- [x] `RGFW_windowScaleToMonitor`
- [x] `RGFW_windowCenterCursor`
- [x] `RGFW_windowCaptureMouse`
- [x] `RGFW_windowOpenGL` (auto-create GL context)
- [x] `RGFW_windowEGL` (auto-create EGL context)
- [x] `RGFW_noDeinitOnClose`
- [x] `RGFW_windowedFullscreen` (composite)
- [x] `RGFW_windowCaptureRawMouse` (composite)

### Key constants (in `key` namespace)
- [x] `key.enter` (alias for `key.@"return"`)
- [x] `key.equals` (alias for `key.equal`)
- [x] `key.kp_equals` (alias for `key.kp_equal`)
- [x] `key.f13` through `key.f25`
- [x] `key.world1`, `key.world2`
- [x] `key.last` (sentinel value = 256)

### Cursor shapes (in `cursor` namespace)
- [x] `cursor.resize_nw`
- [x] `cursor.resize_n`
- [x] `cursor.resize_ne`
- [x] `cursor.resize_e`
- [x] `cursor.resize_se`
- [x] `cursor.resize_s`
- [x] `cursor.resize_sw`
- [x] `cursor.resize_w`

### Event wait constants
- [x] `event_wait.no_wait` (= 0)
- [x] `event_wait.next` (= -1)

### Event sub-struct type aliases
- [x] `CommonEvent`
- [x] `MouseButtonEvent`
- [x] `MouseScrollEvent`
- [x] `MousePosEvent`
- [x] `KeyEvent`
- [x] `KeyCharEvent`
- [x] `DataDropEvent`
- [x] `DataDragEvent`
- [x] `ScaleUpdatedEvent`
- [x] `MonitorEvent`

---

## Phase 3: OpenGL Context Management

Complete the OpenGL context API beyond the basic swap/current operations.

- [x] `RGFW_glContext` type alias
- [x] `Window.createOpenGLContext(hints)` — `RGFW_window_createContext_OpenGL`
- [x] `Window.createOpenGLContextPtr(ctx, hints)` — `RGFW_window_createContextPtr_OpenGL`
- [x] `Window.makeCurrentWindowOpenGL()` — `RGFW_window_makeCurrentWindow_OpenGL`
- [x] `Window.deleteContextPtrOpenGL(ctx)` — `RGFW_window_deleteContextPtr_OpenGL`
- [x] `gl.getSourceContext(ctx)` — `RGFW_glContext_getSourceContext`
- [x] `gl.getCurrentContext()` — `RGFW_getCurrentContext_OpenGL`
- [x] `gl.extensionSupportedPlatform(ext)` — `RGFW_extensionSupportedPlatform_OpenGL`

---

## Phase 4: EGL Context API

Full EGL context lifecycle for platforms using EGL (Linux/Wayland, Android, embedded).

- [x] `RGFW_eglContext` type alias
- [x] `Window.createEGLContext(hints)` — `RGFW_window_createContext_EGL`
- [x] `Window.createEGLContextPtr(ctx, hints)` — `RGFW_window_createContextPtr_EGL`
- [x] `Window.deleteEGLContext(ctx)` — `RGFW_window_deleteContext_EGL`
- [x] `Window.deleteEGLContextPtr(ctx)` — `RGFW_window_deleteContextPtr_EGL`
- [x] `Window.getEGLContext()` — `RGFW_window_getContext_EGL`
- [x] `Window.swapBuffersEGL()` — `RGFW_window_swapBuffers_EGL`
- [x] `Window.makeCurrentWindowEGL()` — `RGFW_window_makeCurrentWindow_EGL`
- [x] `Window.makeCurrentContextEGL()` — `RGFW_window_makeCurrentContext_EGL`
- [x] `Window.swapIntervalEGL(interval)` — `RGFW_window_swapInterval_EGL`
- [x] `egl.getDisplay()` — `RGFW_getDisplay_EGL`
- [x] `egl.getSourceContext(ctx)` — `RGFW_eglContext_getSourceContext`
- [x] `egl.getSurface(ctx)` — `RGFW_eglContext_getSurface`
- [x] `egl.wlEGLWindow(ctx)` — `RGFW_eglContext_wlEGLWindow`
- [x] `egl.getCurrentContext()` — `RGFW_getCurrentContext_EGL`
- [x] `egl.getCurrentWindow()` — `RGFW_getCurrentWindow_EGL`
- [x] `egl.getProcAddress(name)` — `RGFW_getProcAddress_EGL`
- [x] `egl.extensionSupported(ext)` — `RGFW_extensionSupported_EGL`
- [x] `egl.extensionSupportedPlatform(ext)` — `RGFW_extensionSupportedPlatform_EGL`

---

## Phase 5: Vulkan & DirectX

Graphics API interop for non-OpenGL backends. Conditionally compiled — enable with `-Drgfw_vulkan=true` or `-Drgfw_directx=true`. When disabled, `vulkan` / `directx` resolve to empty structs and `Window.createVulkanSurface` / `Window.createDirectXSwapChain` resolve to `null`.

### Vulkan
- [x] `vulkan.getRequiredInstanceExtensions()` — `RGFW_getRequiredInstanceExtensions_Vulkan`
- [x] `Window.createVulkanSurface(instance)` — `RGFW_window_createSurface_Vulkan`
- [x] `vulkan.getPresentationSupport(device, queueFamily)` — `RGFW_getPresentationSupport_Vulkan`

### DirectX
- [x] `Window.createDirectXSwapChain(factory, device)` — `RGFW_window_createSwapChain_DirectX`

---

## Phase 6: Platform-Native Handle Accessors

Expose underlying OS window/display handles for interop with platform-specific or third-party libraries.

### macOS
- [x] `Window.getViewOSX()` — `RGFW_window_getView_OSX`
- [x] `Window.getWindowOSX()` — `RGFW_window_getWindow_OSX`
- [x] `Window.setLayerOSX(layer)` — `RGFW_window_setLayer_OSX`
- [x] `getLayerOSX()` — `RGFW_getLayer_OSX`

### Windows
- [x] `Window.getHWND()` — `RGFW_window_getHWND`
- [x] `Window.getHDC()` — `RGFW_window_getHDC`

### X11
- [x] `Window.getWindowX11()` — `RGFW_window_getWindow_X11`
- [x] `getDisplayX11()` — `RGFW_getDisplay_X11`

### Wayland
- [x] `Window.getWindowWayland()` — `RGFW_window_getWindow_Wayland`
- [x] `getDisplayWayland()` — `RGFW_getDisplay_Wayland`

### General
- [x] `Window.getSrc()` — `RGFW_window_getSrc`
- [x] `RGFW_window_src` type alias
- [x] `usingWayland()` — `RGFW_usingWayland`

---

## Phase 7: Library Lifecycle & Memory

Advanced library state management, allocator hooks, and sizeof helpers.

### RGFW_info lifecycle
- [x] `RGFW_info` type alias
- [x] `sizeofInfo()` — `RGFW_sizeofInfo`
- [x] `initPtr(info)` — `RGFW_init_ptr`
- [x] `deinitPtr(info)` — `RGFW_deinit_ptr`
- [x] `setInfo(info)` — `RGFW_setInfo`
- [x] `getInfo()` — `RGFW_getInfo`

### Allocator API
- [x] `alloc(size)` — `RGFW_alloc`
- [x] `free(ptr)` — `RGFW_free`

### Sizeof helpers
- [x] `sizeofWindow()` — `RGFW_sizeofWindow`
- [x] `sizeofWindowSrc()` — `RGFW_sizeofWindowSrc`
- [x] `sizeofNativeImage()` — `RGFW_sizeofNativeImage`
- [x] `sizeofSurface()` — `RGFW_sizeofSurface`

---

## Phase 8: Surface & Image Data (Advanced)

Pre-allocated buffer variants and pixel format conversion for software rendering.

### Ptr-variant surface creation
- [x] `createSurfacePtr(data, w, h, format, surface)` — `RGFW_createSurfacePtr`
- [x] `Window.createSurfacePtr(data, w, h, format, surface)` — `RGFW_window_createSurfacePtr`
- [x] `Surface.freePtr(surface)` — `RGFW_surface_freePtr`

### Image data conversion
- [x] `RGFW_colorLayout` type alias
- [x] `RGFW_convertImageDataFunc` callback type alias
- [x] `RGFW_nativeImage` type alias
- [x] `copyImageData(dest, w, h, dest_fmt, src, src_fmt, func)` — `RGFW_copyImageData`
- [x] `Surface.setConvertFunc(func)` — `RGFW_surface_setConvertFunc`
- [x] `Surface.getNativeImage()` — `RGFW_surface_getNativeImage`

### Monitor ptr-variants
- [x] `Monitor.getGammaRampPtr(ramp)` — `RGFW_monitor_getGammaRampPtr`
- [x] `Monitor.setGammaPtr(gamma, ptr, count)` — `RGFW_monitor_setGammaPtr`
- [x] `Monitor.getModesPtr(modes)` — `RGFW_monitor_getModesPtr`

---

## Phase 9: Miscellaneous

Small remaining items.

- [x] `Window.closePtr()` — `RGFW_window_closePtr` (close without freeing memory)

---

## Phase 10: Remaining Gaps

Small items found during a full audit of RGFW.h against the wrapper.

### Missing functions
- [x] `createWindowPtr(name, x, y, w, h, flags, win)` — `RGFW_createWindowPtr` (create window into pre-allocated memory)

### WebGPU support
- [x] Add `rgfw_webgpu` build option (mirrors `rgfw_vulkan` / `rgfw_directx` pattern)
- [x] `Window.createWebGPUSurface(instance)` — `RGFW_window_createSurface_WebGPU` (conditional, behind `#ifdef RGFW_WEBGPU`)

### Monitor accessor robustness
Refactored `Monitor` accessors to delegate to the official C API getter functions instead of direct struct field access:
- [x] `Monitor.position()` — delegates to `RGFW_monitor_getPosition`
- [x] `Monitor.name()` — delegates to `RGFW_monitor_getName`
- [x] `Monitor.scale()` — delegates to `RGFW_monitor_getScale`
- [x] `Monitor.physicalSize()` — delegates to `RGFW_monitor_getPhysicalSize`
