# Architecting a Zig GPUI Clone on top of `wndw`

A comprehensive architectural plan for building a GPUI-style UI framework in
Zig 0.16, using `wndw` as the platform layer. Zero external dependencies —
no Rust, no C files, no SDK headers.

GPUI (from Zed) achieves extreme performance through a hybrid of retained state
and immediate-mode UI, with GPU-rendered text via a glyph atlas. This document
translates those Rust concepts into idiomatic, high-performance Zig, grounded
in what `wndw` actually provides today.

**Rendering strategy**: Native CoreGraphics for shapes (default) with GPUI-style
glyph atlas for text. OpenGL backend available as an opt-in for GPU-heavy UIs.

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  Application Code                                       │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                │
│  │ Model A │  │ Model B │  │ Model C │  (Retained)     │
│  └────┬────┘  └────┬────┘  └────┬────┘                │
│       │            │            │                       │
│  ┌────▼────────────▼────────────▼────┐                 │
│  │         View Layer                │  (Retained)     │
│  │   render() → Element tree         │                 │
│  └────────────────┬──────────────────┘                 │
│                   │ rebuilt every frame                  │
│  ┌────────────────▼──────────────────┐                 │
│  │     Element Tree (Immediate)      │  (Frame Arena)  │
│  │   Div → Div → Text               │                 │
│  │         └→ Div → Text             │                 │
│  └────────────────┬──────────────────┘                 │
│                   │                                     │
│  ┌────────────────▼──────────────────┐                 │
│  │     Layout Engine (Flexbox)       │  (Zig-native)   │
│  │   constraints in → sizes out      │                 │
│  └────────────────┬──────────────────┘                 │
│                   │                                     │
│  ┌────────────────▼──────────────────┐                 │
│  │     Paint → Draw Command Buffer   │                 │
│  │   QuadCmd, GlyphCmd, ClipCmd      │                 │
│  └────────────────┬──────────────────┘                 │
│                   │                                     │
│  ┌────────────────▼──────────────────┐                 │
│  │     Renderer (swappable backend)  │                 │
│  │   ┌──────────┐  ┌─────────────┐  │                 │
│  │   │ Native   │  │ OpenGL 3.2  │  │                 │
│  │   │ CoreGfx  │  │ SDF shaders │  │                 │
│  │   │(default) │  │  (opt-in)   │  │                 │
│  │   └──────────┘  └─────────────┘  │                 │
│  │   Glyph atlas (shared, GPUI-style)│                 │
│  └────────────────┬──────────────────┘                 │
│                   │                                     │
│  ┌────────────────▼──────────────────┐                 │
│  │     wndw (Platform Layer)         │                 │
│  │   Window, GL context, events,     │                 │
│  │   CVDisplayLink, clipboard        │                 │
│  └───────────────────────────────────┘                 │
└─────────────────────────────────────────────────────────┘
```

Three strict layers:

1. **Retained State** — Models and Views persist across frames. Owned by the
   entity pool, accessed via generational `Handle(T)`.
2. **Immediate Elements** — The visual tree is rebuilt every frame into a
   frame-scoped arena. Elements are lightweight structs that describe *what*
   to draw, not *how*.
3. **Renderer** — Collects draw commands from the paint phase and dispatches
   to the active backend. Native CoreGraphics is the default — draws rounded
   rects, borders, and shadows via CG path APIs. Text always uses a GPUI-style
   glyph atlas (rasterized once via CoreGraphics, cached, blitted per-glyph).
   OpenGL backend available for GPU-accelerated SDF rendering when elected.

---

## 2. Integration with `wndw`

The framework builds directly on `wndw`'s existing capabilities. No forking,
no patching — just importing the module.

### What `wndw` provides (used directly)

| Capability | wndw API | Used by |
|---|---|---|
| Window creation | `wndw.init(title, w, h, opts)` | `App.run()` |
| Event polling | `win.poll() -> ?Event` | `WindowContext.processEvents()` |
| Input state | `win.isKeyDown()`, `win.getMousePos()` | Hit testing, shortcuts |
| Window geometry | `win.getSize()`, `win.getPos()` | Root layout constraints |
| Cursor control | `win.setStandardCursor(cursor)` | Hover styles |
| Clipboard | `win.clipboardRead()` / `win.clipboardWrite()` | Text editing |
| Scale factor | `.scale_changed` event | DPI-aware rendering |
| Appearance | `win.getAppearance()` / `.appearance_changed` | Theme system |
| NSView handle | `win.getNativeView()` | Native renderer (drawRect) |
| Vsync frame sync | `win.createDisplayLink()` / `win.waitForFrame()` | Main loop |
| OpenGL (opt-in) | `win.createGLContext(.{})` / `win.getProcAddress()` | GL backend |
| Buffer swap | `win.swapBuffers()` | GL backend |

### The main loop

```zig
pub const RenderBackend = enum { native, opengl };

pub fn run(app: *App) !void {
    var win = try wndw.init(app.title, app.width, app.height, .{
        .centred = true,
        .resizable = true,
    });
    defer win.close();

    // GL context only created when explicitly requested
    if (app.backend == .opengl) {
        try win.createGLContext(.{ .samples = 4, .srgb = true });
        win.setSwapInterval(1);
    }
    defer if (app.backend == .opengl) win.deleteContext();

    try win.createDisplayLink();
    defer win.destroyDisplayLink();

    var cx = try WindowContext.init(app.allocator, win, app.backend);
    defer cx.deinit();

    // Mount root view
    cx.setRootView(app.root_view_fn);

    while (!win.shouldClose()) {
        // 1. Process platform events → hit test → dispatch
        cx.processEvents();

        // 2. Run pending effects (model subscriptions, timers, animations)
        cx.flushEffects();

        // 3. If anything is dirty, rebuild element tree + layout + paint
        if (cx.needs_render) {
            cx.render();
        }

        // 4. Submit draw commands to the active backend
        cx.renderer.flush(&cx);

        // 5. Present and wait for vsync
        switch (cx.backend) {
            .native => {
                // Native backend: setNeedsDisplay triggers drawRect
                // (flush already called drawRect-compatible CG drawing)
            },
            .opengl => {
                win.swapBuffers();
            },
        }
        win.waitForFrame();

        // 6. Reset frame arena for next frame
        cx.resetFrame();
    }
}
```

---

## 3. Memory Management

### A. Frame Arena (zero-cost immediate mode)

The element tree is rebuilt every frame. To avoid per-element heap allocations,
everything ephemeral lives in an `ArenaAllocator` that resets each frame.

```zig
const WindowContext = struct {
    /// Persistent allocator for entities, renderer buffers, font cache.
    gpa: std.mem.Allocator,
    /// Per-frame arena — reset at the end of each frame.
    frame_arena: std.heap.ArenaAllocator,

    pub fn frameAlloc(self: *WindowContext) std.mem.Allocator {
        return self.frame_arena.allocator();
    }

    pub fn resetFrame(self: *WindowContext) void {
        _ = self.frame_arena.reset(.retain_capacity);
    }
};
```

**What goes where:**

| Arena (per-frame) | GPA (persistent) |
|---|---|
| Element tree nodes | Entity pool storage |
| Style structs | Font / glyph atlas |
| Children slices | Renderer GPU buffers |
| Hit box array | Subscription table |
| Layout node scratch | Animation state |
| Draw command buffer | Clipboard strings |

### B. Entity Pool (generational slab)

Rust GPUI uses `Arc<Mutex<T>>`. We use a generational slab — O(1) access with
dangling-handle detection via generation counters.

```zig
pub const EntityId = struct {
    index: u32,
    generation: u32,
};

pub fn Handle(comptime T: type) type {
    return struct {
        id: EntityId,

        /// Read the entity. Asserts the handle is still valid (generation matches).
        pub fn read(self: @This(), cx: *WindowContext) *const T {
            return cx.entities.get(T, self.id);
        }

        /// Write the entity. Automatically marks it dirty so subscribers fire.
        pub fn update(self: @This(), cx: *WindowContext, f: *const fn (*T, *WindowContext) void) void {
            const ptr = cx.entities.getMut(T, self.id);
            f(ptr, cx);
            cx.notifySubscribers(self.id);
        }

        /// Subscribe to changes. Callback fires after any `update()` call.
        pub fn observe(self: @This(), cx: *WindowContext, callback: *const fn (*WindowContext) void) void {
            cx.addSubscription(self.id, callback);
        }
    };
}
```

The pool itself stores type-erased slots:

```zig
pub const EntityPool = struct {
    const Slot = struct {
        data: [*]u8,         // raw bytes, cast back via @alignCast/@ptrCast
        generation: u32,
        type_id: usize,      // @intFromPtr(@typeName(T)) for debug safety
        alive: bool,
    };

    slots: std.ArrayList(Slot),
    free_list: std.ArrayList(u32),

    pub fn create(self: *EntityPool, comptime T: type, gpa: std.mem.Allocator, value: T) !Handle(T) {
        const idx = if (self.free_list.popOrNull()) |i| i else blk: {
            try self.slots.append(.{ .data = undefined, .generation = 0, .type_id = 0, .alive = false });
            break :blk @as(u32, @intCast(self.slots.items.len - 1));
        };
        var slot = &self.slots.items[idx];
        const ptr = try gpa.create(T);
        ptr.* = value;
        slot.data = @ptrCast(ptr);
        slot.generation +%= 1;
        slot.type_id = @intFromPtr(@typeName(T).ptr);
        slot.alive = true;
        return .{ .id = .{ .index = idx, .generation = slot.generation } };
    }

    pub fn get(self: *EntityPool, comptime T: type, id: EntityId) *const T {
        const slot = self.slots.items[id.index];
        std.debug.assert(slot.alive and slot.generation == id.generation);
        return @ptrCast(@alignCast(slot.data));
    }

    pub fn getMut(self: *EntityPool, comptime T: type, id: EntityId) *T {
        const slot = self.slots.items[id.index];
        std.debug.assert(slot.alive and slot.generation == id.generation);
        return @ptrCast(@alignCast(slot.data));
    }

    pub fn destroy(self: *EntityPool, gpa: std.mem.Allocator, id: EntityId) void {
        var slot = &self.slots.items[id.index];
        std.debug.assert(slot.alive and slot.generation == id.generation);
        gpa.destroy(@as(*align(1) u8, @ptrCast(slot.data)));
        slot.alive = false;
        self.free_list.append(id.index) catch {};
    }
};
```

---

## 4. The View System

A **View** is a retained component that knows how to render itself into an
element tree. This is GPUI's core abstraction.

```zig
/// The View interface — any type that implements `render`.
pub fn View(comptime T: type) type {
    return struct {
        handle: Handle(T),

        /// Called once per dirty frame. Returns the root element for this view.
        /// The returned element (and its children) live in the frame arena.
        pub fn render(self: @This(), cx: *WindowContext) Element {
            const model = self.handle.read(cx);
            return model.render(cx);
        }
    };
}
```

A concrete view is any struct with a `render` method:

```zig
const Counter = struct {
    count: i32 = 0,

    pub fn render(self: *const Counter, cx: *WindowContext) Element {
        return div(cx)
            .flex_row()
            .gap(8)
            .padding_all(16)
            .bg(cx.theme.surface)
            .children(&.{
                // Decrement button
                div(cx)
                    .padding_xy(12, 8)
                    .bg(cx.theme.primary)
                    .corner_radius(6)
                    .cursor(.pointing_hand)
                    .on_click(struct {
                        fn handler(counter: *Counter, _: *WindowContext) void {
                            counter.count -= 1;
                        }
                    }.handler, self)
                    .child(text(cx, "-").color(cx.theme.on_primary)),

                // Display
                text(cx, "{d}", .{self.count})
                    .font_size(24)
                    .color(cx.theme.on_surface),

                // Increment button
                div(cx)
                    .padding_xy(12, 8)
                    .bg(cx.theme.primary)
                    .corner_radius(6)
                    .cursor(.pointing_hand)
                    .on_click(struct {
                        fn handler(counter: *Counter, _: *WindowContext) void {
                            counter.count += 1;
                        }
                    }.handler, self)
                    .child(text(cx, "+").color(cx.theme.on_primary)),
            })
            .into_element();
    }
};
```

### Mounting views

```zig
// In app setup:
var cx = try WindowContext.init(allocator, win);
const counter_handle = try cx.entities.create(Counter, allocator, .{});
cx.setRootView(View(Counter){ .handle = counter_handle });
```

### The `AnyView` type-erased wrapper

For heterogeneous children (e.g. a sidebar that holds different view types),
we need a type-erased view:

```zig
pub const AnyView = struct {
    id: EntityId,
    render_fn: *const fn (EntityId, *WindowContext) Element,

    pub fn render(self: AnyView, cx: *WindowContext) Element {
        return self.render_fn(self.id, cx);
    }
};

/// Erase a typed View into an AnyView.
pub fn any_view(comptime T: type, handle: Handle(T)) AnyView {
    return .{
        .id = handle.id,
        .render_fn = struct {
            fn render(id: EntityId, cx: *WindowContext) Element {
                const model = cx.entities.get(T, id);
                return model.render(cx);
            }
        }.render,
    };
}
```

---

## 5. The Element Tree

Elements are the immediate-mode primitives. They're rebuilt every frame into
the frame arena. Two core elements cover 95% of UI: `Div` and `Text`.

### A. The Element interface

```zig
pub const Element = struct {
    vtable: *const VTable,
    data: *anyopaque,

    pub const VTable = struct {
        layout: *const fn (*anyopaque, *LayoutContext, Constraints) Size,
        paint: *const fn (*anyopaque, *PaintContext, Rect) void,
    };

    pub fn layout(self: Element, lx: *LayoutContext, constraints: Constraints) Size {
        return self.vtable.layout(self.data, lx, constraints);
    }

    pub fn paint(self: Element, px: *PaintContext, bounds: Rect) void {
        self.vtable.paint(self.data, px, bounds);
    }
};
```

This vtable approach (vs. a tagged union) allows user code to define custom
elements without modifying the framework.

### B. Div — the universal container

`Div` is the `<div>` of this framework. It holds style, children, and
optional event handlers. Built using a fluent API that returns `*Div`
(pointer into frame arena) for chaining.

```zig
pub const Div = struct {
    style: Style = .{},
    children: []Element = &.{},
    children_buf: std.ArrayListUnmanaged(Element) = .{},
    on_click_handler: ?ClickHandler = null,
    on_hover_handler: ?HoverHandler = null,
    cursor_style: ?event.Cursor = null,

    const ClickHandler = struct {
        callback: *const fn (*anyopaque, *WindowContext) void,
        target: *anyopaque,
    };

    const HoverHandler = struct {
        callback: *const fn (*anyopaque, *WindowContext, bool) void,
        target: *anyopaque,
    };

    // ── Fluent style methods ──────────────────────────────────────────

    pub fn bg(self: *Div, color: Color) *Div {
        self.style.background = color;
        return self;
    }

    pub fn corner_radius(self: *Div, r: f32) *Div {
        self.style.corner_radius = .{ r, r, r, r };
        return self;
    }

    pub fn padding_all(self: *Div, p: f32) *Div {
        self.style.padding = .{ .top = p, .right = p, .bottom = p, .left = p };
        return self;
    }

    pub fn padding_xy(self: *Div, x: f32, y: f32) *Div {
        self.style.padding = .{ .top = y, .right = x, .bottom = y, .left = x };
        return self;
    }

    pub fn flex_row(self: *Div) *Div {
        self.style.direction = .row;
        return self;
    }

    pub fn flex_col(self: *Div) *Div {
        self.style.direction = .column;
        return self;
    }

    pub fn gap(self: *Div, g: f32) *Div {
        self.style.gap = g;
        return self;
    }

    pub fn align_center(self: *Div) *Div {
        self.style.align_items = .center;
        return self;
    }

    pub fn justify_center(self: *Div) *Div {
        self.style.justify_content = .center;
        return self;
    }

    pub fn size(self: *Div, w: Len, h: Len) *Div {
        self.style.width = w;
        self.style.height = h;
        return self;
    }

    pub fn flex(self: *Div, f: f32) *Div {
        self.style.flex_grow = f;
        return self;
    }

    pub fn overflow_scroll(self: *Div) *Div {
        self.style.overflow = .scroll;
        return self;
    }

    pub fn border(self: *Div, width: f32, color: Color) *Div {
        self.style.border_width = width;
        self.style.border_color = color;
        return self;
    }

    pub fn shadow(self: *Div, blur: f32, color: Color) *Div {
        self.style.shadow_blur = blur;
        self.style.shadow_color = color;
        return self;
    }

    // ── Children ──────────────────────────────────────────────────────

    pub fn child(self: *Div, el: Element) *Div {
        self.children_buf.append(self.arena, el) catch unreachable;
        return self;
    }

    pub fn children(self: *Div, els: []const Element) *Div {
        self.children_buf.appendSlice(self.arena, els) catch unreachable;
        return self;
    }

    // ── Events ────────────────────────────────────────────────────────

    pub fn on_click(self: *Div, comptime callback: anytype, target: anytype) *Div {
        self.on_click_handler = .{
            .callback = @ptrCast(&callback),
            .target = @ptrCast(@constCast(target)),
        };
        return self;
    }

    pub fn cursor(self: *Div, c: event.Cursor) *Div {
        self.cursor_style = c;
        return self;
    }

    // ── Convert to Element ────────────────────────────────────────────

    pub fn into_element(self: *Div) Element {
        self.children = self.children_buf.items;
        return .{ .vtable = &div_vtable, .data = @ptrCast(self) };
    }

    arena: std.mem.Allocator = undefined, // set by div() constructor
};

/// Top-level constructor. Allocates a Div in the frame arena.
pub fn div(cx: *WindowContext) *Div {
    const d = cx.frameAlloc().create(Div) catch unreachable;
    d.* = .{ .arena = cx.frameAlloc() };
    return d;
}

const div_vtable: Element.VTable = .{
    .layout = &Div.doLayout,
    .paint = &Div.doPaint,
};
```

### C. Text element

```zig
pub const Text = struct {
    string: []const u8,
    style: TextStyle = .{},

    pub fn color(self: *Text, c: Color) *Text {
        self.style.color = c;
        return self;
    }

    pub fn font_size(self: *Text, s: f32) *Text {
        self.style.font_size = s;
        return self;
    }

    pub fn font_weight(self: *Text, w: FontWeight) *Text {
        self.style.weight = w;
        return self;
    }

    pub fn into_element(self: *Text) Element {
        return .{ .vtable = &text_vtable, .data = @ptrCast(self) };
    }
};

/// Create a text element. Accepts `fmt` + args, formatted into the frame arena.
pub fn text(cx: *WindowContext, comptime fmt: []const u8, args: anytype) *Text {
    const alloc = cx.frameAlloc();
    const t = alloc.create(Text) catch unreachable;
    t.* = .{
        .string = std.fmt.allocPrint(alloc, fmt, args) catch unreachable,
    };
    return t;
}
```

---

## 6. Style System

The `Style` struct is the Zig equivalent of GPUI's `StyleRefinement`. Every
visual property a `Div` can have lives here.

```zig
pub const Style = struct {
    // ── Layout (consumed by the flexbox engine) ───────────────────────
    direction: FlexDirection = .column,
    wrap: FlexWrap = .no_wrap,
    align_items: Align = .stretch,
    align_self: ?Align = null,
    justify_content: Justify = .start,
    gap: f32 = 0,

    width: Len = .auto,
    height: Len = .auto,
    min_width: Len = .auto,
    min_height: Len = .auto,
    max_width: Len = .auto,
    max_height: Len = .auto,

    flex_grow: f32 = 0,
    flex_shrink: f32 = 1,

    padding: Edges = .{},
    margin: Edges = .{},

    overflow: Overflow = .visible,
    position: Position = .relative,

    // ── Visual (consumed by the paint phase) ──────────────────────────
    background: ?Color = null,
    border_color: ?Color = null,
    border_width: f32 = 0,
    corner_radius: [4]f32 = .{ 0, 0, 0, 0 }, // TL, TR, BR, BL
    shadow_color: ?Color = null,
    shadow_blur: f32 = 0,
    shadow_offset: [2]f32 = .{ 0, 0 },
    opacity: f32 = 1.0,

    // ── Interaction ───────────────────────────────────────────────────
    cursor: ?event.Cursor = null,
    pointer_events: bool = true,
};

pub const Len = union(enum) {
    auto,
    px: f32,
    percent: f32, // 0.0–1.0
    fr: f32,      // flex fraction (for grid-like layouts)
};

pub const Edges = struct {
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
    left: f32 = 0,
};

pub const FlexDirection = enum { row, column, row_reverse, column_reverse };
pub const FlexWrap = enum { no_wrap, wrap };
pub const Align = enum { start, end, center, stretch, baseline };
pub const Justify = enum { start, end, center, space_between, space_around, space_evenly };
pub const Overflow = enum { visible, hidden, scroll };
pub const Position = enum { relative, absolute };

pub const Color = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 255,

    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn hex(comptime h: u32) Color {
        return .{
            .r = @truncate(h >> 16),
            .g = @truncate(h >> 8),
            .b = @truncate(h),
            .a = 255,
        };
    }

    /// Normalized [0,1] floats for passing to shaders.
    pub fn toVec4(self: Color) [4]f32 {
        return .{
            @as(f32, @floatFromInt(self.r)) / 255.0,
            @as(f32, @floatFromInt(self.g)) / 255.0,
            @as(f32, @floatFromInt(self.b)) / 255.0,
            @as(f32, @floatFromInt(self.a)) / 255.0,
        };
    }
};

pub const TextStyle = struct {
    font_size: f32 = 14.0,
    color: Color = Color.hex(0xE0E0E0),
    weight: FontWeight = .regular,
    family: ?[]const u8 = null, // null = system default
    line_height: ?f32 = null,   // null = 1.3 × font_size
};

pub const FontWeight = enum(u16) {
    thin = 100,
    light = 300,
    regular = 400,
    medium = 500,
    semi_bold = 600,
    bold = 700,
    black = 900,
};
```

---

## 7. Layout Engine (Zig-native Flexbox)

Instead of linking Taffy via Rust FFI (which contradicts `wndw`'s zero-dependency
philosophy), we implement a focused flexbox subset directly in Zig. This covers
the layouts GPUI actually uses — flex row/column with gaps, padding, alignment,
and flex grow/shrink.

### Layout algorithm

The layout is a two-pass tree walk, matching CSS flexbox semantics:

```
Pass 1 (measure): bottom-up — each node computes its intrinsic size
Pass 2 (arrange): top-down — each node assigns positions to children
```

```zig
pub const Constraints = struct {
    min_w: f32 = 0,
    min_h: f32 = 0,
    max_w: f32 = std.math.inf(f32),
    max_h: f32 = std.math.inf(f32),

    pub fn tight(w: f32, h: f32) Constraints {
        return .{ .min_w = w, .min_h = h, .max_w = w, .max_h = h };
    }
};

pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    pub fn contains(self: Rect, px: f32, py: f32) bool {
        return px >= self.x and px < self.x + self.w and
               py >= self.y and py < self.y + self.h;
    }

    pub fn inset(self: Rect, edges: Edges) Rect {
        return .{
            .x = self.x + edges.left,
            .y = self.y + edges.top,
            .w = self.w - edges.left - edges.right,
            .h = self.h - edges.top - edges.bottom,
        };
    }
};

pub const LayoutContext = struct {
    frame_alloc: std.mem.Allocator,
    text_measurer: *TextMeasurer,

    /// Lay out a flex container (Div with children).
    pub fn layoutFlex(
        self: *LayoutContext,
        style: *const Style,
        children_elements: []Element,
        constraints: Constraints,
    ) Size {
        const is_row = style.direction == .row or style.direction == .row_reverse;
        const content = constraints.insetPadding(style.padding);

        // Phase 1: Measure each child with unbounded cross-axis
        var child_sizes = self.frame_alloc.alloc(Size, children_elements.len) catch unreachable;
        var total_main: f32 = 0;
        var total_grow: f32 = 0;

        for (children_elements, 0..) |child, i| {
            const child_constraint = if (is_row)
                Constraints{ .max_w = std.math.inf(f32), .max_h = content.max_h }
            else
                Constraints{ .max_w = content.max_w, .max_h = std.math.inf(f32) };

            child_sizes[i] = child.layout(self, child_constraint);
            total_main += if (is_row) child_sizes[i].w else child_sizes[i].h;
            // accumulate flex_grow from child styles (looked up via vtable)
        }

        // Phase 2: Distribute remaining space per flex_grow
        const gap_total = style.gap * @as(f32, @floatFromInt(@max(children_elements.len, 1) - 1));
        const available = (if (is_row) content.max_w else content.max_h) - total_main - gap_total;
        // ... distribute `available` among flex_grow children ...

        // Phase 3: Position children along main axis + align on cross axis
        // ... assign Rect to each child ...

        return .{ .w = constraints.clampW(total_w), .h = constraints.clampH(total_h) };
    }
};
```

### Why not Taffy?

| | Taffy via Rust FFI | Zig-native flexbox |
|---|---|---|
| Dependencies | Requires Rust toolchain + cargo | Zero |
| Build complexity | Cross-compile Rust → .a → link | Just Zig |
| Debug experience | Opaque across FFI boundary | Full Zig stack traces |
| Scope | Full CSS Grid + Flexbox | Flexbox subset (what GPUI uses) |
| Maintenance | Track upstream Taffy semver | We own it |

GPUI itself only uses a subset of flexbox (no grid, no `float`, no `position: absolute`
in most cases). A ~400-line Zig implementation covers this completely.

---

## 8. Event Routing & Hit Testing

`wndw` provides a flat event queue. GPUI uses hierarchical dispatch. We bridge
this with a **hit box stack** built during the paint phase.

### Hit box registration

During `paint()`, every element that handles interaction pushes a hit box:

```zig
pub const HitBox = struct {
    bounds: Rect,
    z_index: u16,
    cursor: ?event.Cursor,
    on_click: ?Div.ClickHandler,
    on_hover: ?Div.HoverHandler,
    on_scroll: ?ScrollHandler,
};

pub const PaintContext = struct {
    hit_boxes: std.ArrayListUnmanaged(HitBox),
    draw_list: DrawList,
    clip_stack: std.ArrayListUnmanaged(Rect),
    z_index: u16 = 0,

    pub fn pushHitBox(self: *PaintContext, box: HitBox) void {
        var b = box;
        b.z_index = self.z_index;
        self.hit_boxes.append(self.alloc, b) catch unreachable;
    }

    pub fn pushClip(self: *PaintContext, rect: Rect) void {
        self.clip_stack.append(self.alloc, rect) catch unreachable;
        self.z_index += 1;
    }

    pub fn popClip(self: *PaintContext) void {
        _ = self.clip_stack.pop();
    }
};
```

### Event dispatch

After painting, the `WindowContext` processes `wndw` events against the hit
box stack (reverse iteration = front-to-back Z order):

```zig
pub fn processEvents(cx: *WindowContext) void {
    while (cx.window.poll()) |ev| {
        switch (ev) {
            .mouse_pressed => |btn| {
                const pos = cx.window.getMousePos();
                const px: f32 = @floatFromInt(pos.x);
                const py: f32 = @floatFromInt(pos.y);

                // Reverse iterate: topmost element first
                var i = cx.paint_cx.hit_boxes.items.len;
                while (i > 0) {
                    i -= 1;
                    const hb = cx.paint_cx.hit_boxes.items[i];
                    if (hb.bounds.contains(px, py)) {
                        if (hb.on_click) |handler| {
                            if (btn == .left) {
                                handler.callback(handler.target, cx);
                                cx.needs_render = true;
                                break;
                            }
                        }
                    }
                }
            },

            .mouse_moved => |_| {
                // Update cursor based on topmost hovered hit box
                const pos = cx.window.getMousePos();
                const px: f32 = @floatFromInt(pos.x);
                const py: f32 = @floatFromInt(pos.y);
                var found_cursor: event.Cursor = .arrow;

                var i = cx.paint_cx.hit_boxes.items.len;
                while (i > 0) {
                    i -= 1;
                    const hb = cx.paint_cx.hit_boxes.items[i];
                    if (hb.bounds.contains(px, py)) {
                        if (hb.cursor) |c| {
                            found_cursor = c;
                            break;
                        }
                    }
                }
                cx.window.setStandardCursor(found_cursor);
            },

            .scroll => |delta| {
                // Dispatch to deepest scrollable container under cursor
                cx.dispatchScroll(delta);
            },

            .key_pressed => |kp| {
                // Check keybindings → actions first, then focused element
                if (cx.keybindings.match(kp)) |action| {
                    cx.dispatchAction(action);
                } else if (kp.mods.super) {
                    // System shortcuts (Cmd+C, Cmd+V, etc.)
                    cx.handleSystemShortcut(kp);
                }
                cx.needs_render = true;
            },

            .resized => |_| {
                cx.needs_render = true;
            },

            .appearance_changed => |appearance| {
                cx.theme = if (appearance == .dark) Theme.dark() else Theme.light();
                cx.needs_render = true;
            },

            .close_requested => cx.window.quit(),

            else => {},
        }
    }
}
```

### Focus management

Focus tracks which element receives keyboard input:

```zig
pub const FocusHandle = struct {
    id: u32,

    pub fn isFocused(self: FocusHandle, cx: *WindowContext) bool {
        return cx.focused_element == self.id;
    }
};

// Elements request focus via the WindowContext:
pub fn requestFocus(cx: *WindowContext, handle: FocusHandle) void {
    if (cx.focused_element != handle.id) {
        // Fire blur on old, focus on new
        cx.focused_element = handle.id;
        cx.needs_render = true;
    }
}
```

---

## 9. Scroll Containers

Scrollable content is essential for lists, text editors, and panels.
A `Div` with `overflow_scroll()` becomes a scroll container.

```zig
/// Scroll state — lives in the entity pool (persistent across frames).
pub const ScrollState = struct {
    offset_x: f32 = 0,
    offset_y: f32 = 0,
    content_size: Size = .{ .w = 0, .h = 0 },
    viewport_size: Size = .{ .w = 0, .h = 0 },

    pub fn scrollBy(self: *ScrollState, dx: f32, dy: f32) void {
        self.offset_x = std.math.clamp(
            self.offset_x + dx,
            0,
            @max(self.content_size.w - self.viewport_size.w, 0),
        );
        self.offset_y = std.math.clamp(
            self.offset_y + dy,
            0,
            @max(self.content_size.h - self.viewport_size.h, 0),
        );
    }

    pub fn scrollProgress(self: *const ScrollState) f32 {
        const max = self.content_size.h - self.viewport_size.h;
        return if (max <= 0) 0 else self.offset_y / max;
    }
};
```

During paint, a scroll container:
1. Pushes a clip rect matching its viewport bounds
2. Translates child positions by `(-offset_x, -offset_y)`
3. Registers a scroll hit box so `dispatchScroll` targets it
4. Optionally paints a scrollbar thumb (a thin `QuadCmd`)

---

## 10. Renderer (Dual Backend)

Both backends consume the same `DrawList`. The element tree's `paint()` phase
pushes backend-agnostic draw commands; the renderer translates them to native
CG calls or GL draw calls depending on which backend is active.

### A. Draw command types (shared)

```zig
pub const DrawList = struct {
    quads: std.ArrayListUnmanaged(QuadCmd) = .{},
    glyphs: std.ArrayListUnmanaged(GlyphCmd) = .{},
    clips: std.ArrayListUnmanaged(ClipCmd) = .{},

    pub fn pushQuad(self: *DrawList, alloc: std.mem.Allocator, q: QuadCmd) void {
        self.quads.append(alloc, q) catch unreachable;
    }

    pub fn pushGlyph(self: *DrawList, alloc: std.mem.Allocator, g: GlyphCmd) void {
        self.glyphs.append(alloc, g) catch unreachable;
    }

    pub fn clear(self: *DrawList) void {
        self.quads.clearRetainingCapacity();
        self.glyphs.clearRetainingCapacity();
        self.clips.clearRetainingCapacity();
    }
};

/// A rounded rectangle with background, border, and shadow.
pub const QuadCmd = struct {
    bounds: [4]f32,          // x, y, w, h
    bg: [4]f32,              // r, g, b, a (normalized)
    border_color: [4]f32,
    border_width: f32,
    corner_radii: [4]f32,    // TL, TR, BR, BL
    shadow_color: [4]f32,
    shadow_blur: f32,
    shadow_offset: [2]f32,
    clip_index: i32,         // -1 = no clip
};

/// A single glyph — positioned sub-rect of the glyph atlas.
pub const GlyphCmd = struct {
    bounds: [4]f32,     // x, y, w, h (screen px)
    uv: [4]f32,        // u0, v0, u1, v1 (atlas coordinates)
    color: [4]f32,
    clip_index: i32,
};

pub const ClipCmd = struct {
    rect: Rect,
};
```

### B. Renderer interface

```zig
pub const Renderer = union(RenderBackend) {
    native: NativeRenderer,
    opengl: GlRenderer,

    pub fn init(win: *wndw.Window, backend: RenderBackend, gpa: std.mem.Allocator) !Renderer {
        return switch (backend) {
            .native => .{ .native = try NativeRenderer.init(win, gpa) },
            .opengl => .{ .opengl = try GlRenderer.init(win, gpa) },
        };
    }

    pub fn flush(self: *Renderer, cx: *WindowContext) void {
        switch (self.*) {
            .native => |*n| n.flush(cx),
            .opengl => |*g| g.flush(cx),
        }
    }

    pub fn deinit(self: *Renderer) void {
        switch (self.*) {
            .native => |*n| n.deinit(),
            .opengl => |*g| g.deinit(),
        }
    }
};
```

### C. Native renderer (CoreGraphics) — default

The native backend draws directly into the NSView's backing store using
CoreGraphics. This is the default — no GL context, no shaders, no deprecated
API warnings. Shapes use CG path APIs; text uses the shared glyph atlas
blitted via `CGContextDrawImage`.

```zig
// ── CoreGraphics extern fns (pure Zig, no SDK headers) ──────────────

// Context
extern fn CGContextSaveGState(ctx: CGContextRef) void;
extern fn CGContextRestoreGState(ctx: CGContextRef) void;
extern fn CGContextSetRGBFillColor(ctx: CGContextRef, r: f64, g: f64, b: f64, a: f64) void;
extern fn CGContextSetRGBStrokeColor(ctx: CGContextRef, r: f64, g: f64, b: f64, a: f64) void;
extern fn CGContextSetLineWidth(ctx: CGContextRef, width: f64) void;
extern fn CGContextFillPath(ctx: CGContextRef) void;
extern fn CGContextStrokePath(ctx: CGContextRef) void;
extern fn CGContextClipToRect(ctx: CGContextRef, rect: CGRect) void;
extern fn CGContextTranslateCTM(ctx: CGContextRef, tx: f64, ty: f64) void;
extern fn CGContextScaleCTM(ctx: CGContextRef, sx: f64, sy: f64) void;
extern fn CGContextSetAlpha(ctx: CGContextRef, alpha: f64) void;

// Shadows
extern fn CGContextSetShadowWithColor(
    ctx: CGContextRef, offset: CGSize, blur: f64, color: ?CGColorRef,
) void;
extern fn CGColorCreateGenericRGB(r: f64, g: f64, b: f64, a: f64) CGColorRef;
extern fn CGColorRelease(color: CGColorRef) void;

// Paths (rounded rects)
extern fn CGPathCreateWithRoundedRect(
    rect: CGRect, corner_w: f64, corner_h: f64, transform: ?*const anyopaque,
) CGPathRef;
extern fn CGPathCreateMutable() CGMutablePathRef;
extern fn CGPathAddRoundedRect(
    path: CGMutablePathRef, transform: ?*const anyopaque,
    rect: CGRect, corner_w: f64, corner_h: f64,
) void;
extern fn CGContextAddPath(ctx: CGContextRef, path: CGPathRef) void;
extern fn CGPathRelease(path: CGPathRef) void;

// Images (for glyph atlas blitting)
extern fn CGContextDrawImage(ctx: CGContextRef, rect: CGRect, image: CGImageRef) void;
extern fn CGBitmapContextCreate(
    data: ?*anyopaque, width: usize, height: usize,
    bits_per_component: usize, bytes_per_row: usize,
    colorspace: CGColorSpaceRef, bitmap_info: u32,
) ?CGContextRef;
extern fn CGBitmapContextCreateImage(ctx: CGContextRef) ?CGImageRef;
extern fn CGImageRelease(image: CGImageRef) void;
extern fn CGColorSpaceCreateDeviceGray() CGColorSpaceRef;
extern fn CGColorSpaceCreateDeviceRGB() CGColorSpaceRef;
extern fn CGColorSpaceRelease(cs: CGColorSpaceRef) void;
extern fn CGImageCreateWithImageInRect(image: CGImageRef, rect: CGRect) ?CGImageRef;

// Types
const CGContextRef = *anyopaque;
const CGColorRef = *anyopaque;
const CGPathRef = *const anyopaque;
const CGMutablePathRef = *anyopaque;
const CGImageRef = *anyopaque;
const CGColorSpaceRef = *anyopaque;
const CGRect = extern struct { x: f64, y: f64, w: f64, h: f64 };
const CGSize = extern struct { w: f64, h: f64 };
const CGPoint = extern struct { x: f64, y: f64 };
```

The `NativeRenderer` acquires the current `CGContextRef` via
`[[NSGraphicsContext currentContext] CGContext]` (called through `objc.msgSend`),
then iterates the draw list:

```zig
pub const NativeRenderer = struct {
    glyph_atlas: GlyphAtlas,
    /// Cached CGImage of the atlas bitmap, rebuilt on atlas changes.
    atlas_image: ?CGImageRef = null,
    /// Raw pixel buffer backing the atlas (grayscale, 1 byte/px).
    atlas_pixels: []u8,
    atlas_size: u32 = 1024,
    atlas_dirty: bool = false,
    gpa: std.mem.Allocator,

    pub fn init(_: *wndw.Window, gpa: std.mem.Allocator) !NativeRenderer {
        const size: u32 = 1024;
        const pixels = try gpa.alloc(u8, size * size);
        @memset(pixels, 0);
        return .{
            .glyph_atlas = GlyphAtlas.init(gpa),
            .atlas_pixels = pixels,
            .gpa = gpa,
        };
    }

    pub fn flush(self: *NativeRenderer, cx: *WindowContext) void {
        // Get current CGContext from NSGraphicsContext
        const ns_gfx_ctx = objc.msgSend(
            objc.getClass("NSGraphicsContext"), .{},
            objc.id, objc.sel("currentContext"),
        );
        const cg_ctx: CGContextRef = objc.msgSend(
            ns_gfx_ctx, .{}, CGContextRef, objc.sel("CGContext"),
        );

        const scale = cx.scale_factor;

        // Flip coordinate system: CG is bottom-left, we use top-left
        const h: f64 = @floatFromInt(cx.window.getSize().h);
        CGContextTranslateCTM(cg_ctx, 0, h);
        CGContextScaleCTM(cg_ctx, 1, -1);

        // Draw quads
        for (cx.paint_cx.draw_list.quads.items) |quad| {
            self.drawQuad(cg_ctx, quad, cx);
        }

        // Draw glyphs (from atlas)
        if (self.atlas_dirty) self.rebuildAtlasImage();
        for (cx.paint_cx.draw_list.glyphs.items) |glyph| {
            self.drawGlyph(cg_ctx, glyph);
        }

        cx.paint_cx.draw_list.clear();
    }

    fn drawQuad(self: *NativeRenderer, ctx: CGContextRef, q: QuadCmd, cx: *WindowContext) void {
        _ = self;
        CGContextSaveGState(ctx);

        // Clip
        if (q.clip_index >= 0) {
            const clip = cx.paint_cx.draw_list.clips.items[@intCast(q.clip_index)];
            CGContextClipToRect(ctx, .{
                .x = @floatCast(clip.rect.x), .y = @floatCast(clip.rect.y),
                .w = @floatCast(clip.rect.w), .h = @floatCast(clip.rect.h),
            });
        }

        const rect = CGRect{
            .x = @floatCast(q.bounds[0]), .y = @floatCast(q.bounds[1]),
            .w = @floatCast(q.bounds[2]), .h = @floatCast(q.bounds[3]),
        };
        // Average corner radius (CG's rounded rect uses uniform radius;
        // for per-corner, build a CGMutablePath with arcs instead)
        const radius: f64 = @floatCast((q.corner_radii[0] + q.corner_radii[1] +
            q.corner_radii[2] + q.corner_radii[3]) / 4.0);

        // Shadow
        if (q.shadow_blur > 0) {
            const shadow_cg = CGColorCreateGenericRGB(
                @floatCast(q.shadow_color[0]), @floatCast(q.shadow_color[1]),
                @floatCast(q.shadow_color[2]), @floatCast(q.shadow_color[3]),
            );
            defer CGColorRelease(shadow_cg);
            CGContextSetShadowWithColor(ctx, .{
                .w = @floatCast(q.shadow_offset[0]),
                .h = @floatCast(q.shadow_offset[1]),
            }, @floatCast(q.shadow_blur), shadow_cg);
        }

        // Background fill
        const path = CGPathCreateWithRoundedRect(rect, radius, radius, null);
        defer CGPathRelease(path);
        CGContextAddPath(ctx, path);
        CGContextSetRGBFillColor(ctx, q.bg[0], q.bg[1], q.bg[2], q.bg[3]);
        CGContextFillPath(ctx);

        // Border stroke
        if (q.border_width > 0) {
            CGContextAddPath(ctx, path);
            CGContextSetRGBStrokeColor(ctx,
                q.border_color[0], q.border_color[1],
                q.border_color[2], q.border_color[3],
            );
            CGContextSetLineWidth(ctx, @floatCast(q.border_width));
            CGContextStrokePath(ctx);
        }

        CGContextRestoreGState(ctx);
    }

    fn drawGlyph(self: *NativeRenderer, ctx: CGContextRef, g: GlyphCmd) void {
        const atlas_img = self.atlas_image orelse return;

        // Extract the glyph sub-image from atlas using UV coordinates
        const ax: f64 = @floatCast(g.uv[0] * @as(f32, @floatFromInt(self.atlas_size)));
        const ay: f64 = @floatCast(g.uv[1] * @as(f32, @floatFromInt(self.atlas_size)));
        const aw: f64 = @floatCast((g.uv[2] - g.uv[0]) * @as(f32, @floatFromInt(self.atlas_size)));
        const ah: f64 = @floatCast((g.uv[3] - g.uv[1]) * @as(f32, @floatFromInt(self.atlas_size)));

        const sub_img = CGImageCreateWithImageInRect(atlas_img, .{
            .x = ax, .y = ay, .w = aw, .h = ah,
        }) orelse return;
        defer CGImageRelease(sub_img);

        // Tint: set fill color, then draw in kCGBlendModeMultiply
        // (the atlas is grayscale alpha; we colorize by compositing)
        CGContextSaveGState(ctx);
        CGContextSetRGBFillColor(ctx, g.color[0], g.color[1], g.color[2], g.color[3]);

        const dest = CGRect{
            .x = @floatCast(g.bounds[0]), .y = @floatCast(g.bounds[1]),
            .w = @floatCast(g.bounds[2]), .h = @floatCast(g.bounds[3]),
        };
        CGContextDrawImage(ctx, dest, sub_img);
        CGContextRestoreGState(ctx);
    }

    fn rebuildAtlasImage(self: *NativeRenderer) void {
        if (self.atlas_image) |old| CGImageRelease(old);
        const cs = CGColorSpaceCreateDeviceGray();
        defer CGColorSpaceRelease(cs);
        const bmp_ctx = CGBitmapContextCreate(
            @ptrCast(self.atlas_pixels.ptr),
            self.atlas_size, self.atlas_size,
            8, self.atlas_size, cs, 0,
        ) orelse return;
        self.atlas_image = CGBitmapContextCreateImage(bmp_ctx);
        self.atlas_dirty = false;
    }

    pub fn deinit(self: *NativeRenderer) void {
        if (self.atlas_image) |img| CGImageRelease(img);
        self.gpa.free(self.atlas_pixels);
        self.glyph_atlas.deinit();
    }
};
```

**Why native by default:**

| | Native (CoreGraphics) | OpenGL 3.2 |
|---|---|---|
| Dependencies | Zero (CG is always present) | GL context setup |
| macOS deprecation | Fully supported | Deprecated since 10.14 |
| Subpixel text | Free via CG compositing | Manual in shader |
| Debug tools | Instruments → Core Animation | GPU debugger needed |
| Rounded rects | `CGPathCreateWithRoundedRect` | SDF shader |
| Shadow/blur | `CGContextSetShadow` (native gaussian) | Manual in fragment shader |
| Color management | Automatic (system profile) | Manual sRGB |
| Perf ceiling | ~1000s of elements | ~100,000+ elements |

### D. OpenGL renderer (opt-in)

Activated via `App{ .backend = .opengl }`. Uses SDF shaders for shapes and
instanced rendering for text. Better for GPU-heavy UIs with many thousands
of elements, animations, or custom visual effects.

```zig
pub const GlRenderer = struct {
    gl: GlFunctions,

    // Quad pipeline
    quad_program: u32,
    quad_vao: u32,
    quad_vbo: u32,
    quad_ibo: u32,

    // Glyph pipeline
    glyph_program: u32,
    glyph_vao: u32,
    glyph_vbo: u32,
    glyph_ibo: u32,

    // Glyph atlas (GL texture version)
    atlas_texture: u32,
    atlas: GlyphAtlas,

    viewport_w: f32,
    viewport_h: f32,

    pub fn init(win: *wndw.Window, gpa: std.mem.Allocator) !GlRenderer {
        var self: GlRenderer = undefined;

        // Load all GL functions via wndw's getProcAddress
        inline for (@typeInfo(GlFunctions).@"struct".fields) |field| {
            const name = field.name;
            @field(self.gl, name) = @ptrCast(@alignCast(
                win.getProcAddress(name) orelse return error.GLFunctionNotFound,
            ));
        }

        // Compile SDF quad + glyph shaders
        self.quad_program = try self.compileProgram(quad_vert_src, quad_frag_src);
        self.glyph_program = try self.compileProgram(glyph_vert_src, glyph_frag_src);

        // Setup VAOs, VBOs, unit quad geometry for instanced rendering
        self.gl.glGenVertexArrays(1, &self.quad_vao);
        // ... setup per-instance vertex attributes ...

        // Create atlas texture (1024×1024 R8)
        self.gl.glGenTextures(1, &self.atlas_texture);
        self.gl.glBindTexture(GL_TEXTURE_2D, self.atlas_texture);
        self.gl.glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, 1024, 1024, 0,
            GL_RED, GL_UNSIGNED_BYTE, null);

        self.atlas = GlyphAtlas.init(gpa);
        return self;
    }

    pub fn flush(self: *GlRenderer, cx: *WindowContext) void {
        const size = cx.window.getSize();
        self.viewport_w = @floatFromInt(size.w);
        self.viewport_h = @floatFromInt(size.h);

        self.gl.glViewport(0, 0, size.w, size.h);
        self.gl.glClear(GL_COLOR_BUFFER_BIT);
        self.gl.glEnable(GL_BLEND);
        self.gl.glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        // Instanced quad draw
        const quads = cx.paint_cx.draw_list.quads.items;
        if (quads.len > 0) {
            self.gl.glUseProgram(self.quad_program);
            self.gl.glUniform2f(
                self.gl.glGetUniformLocation(self.quad_program, "u_viewport"),
                self.viewport_w, self.viewport_h,
            );
            self.gl.glBindBuffer(GL_ARRAY_BUFFER, self.quad_ibo);
            self.gl.glBufferData(GL_ARRAY_BUFFER,
                @intCast(quads.len * @sizeOf(QuadCmd)),
                @ptrCast(quads.ptr), GL_STREAM_DRAW);
            self.gl.glBindVertexArray(self.quad_vao);
            self.gl.glDrawArraysInstanced(GL_TRIANGLES, 0, 6, @intCast(quads.len));
        }

        // Instanced glyph draw
        const glyphs = cx.paint_cx.draw_list.glyphs.items;
        if (glyphs.len > 0) {
            self.gl.glUseProgram(self.glyph_program);
            self.gl.glBindTexture(GL_TEXTURE_2D, self.atlas_texture);
            self.gl.glBindBuffer(GL_ARRAY_BUFFER, self.glyph_ibo);
            self.gl.glBufferData(GL_ARRAY_BUFFER,
                @intCast(glyphs.len * @sizeOf(GlyphCmd)),
                @ptrCast(glyphs.ptr), GL_STREAM_DRAW);
            self.gl.glBindVertexArray(self.glyph_vao);
            self.gl.glDrawArraysInstanced(GL_TRIANGLES, 0, 6, @intCast(glyphs.len));
        }

        cx.paint_cx.draw_list.clear();
    }

    pub fn deinit(self: *GlRenderer) void {
        self.atlas.deinit();
        self.gl.glDeleteProgram(self.quad_program);
        self.gl.glDeleteProgram(self.glyph_program);
        // ... delete VAOs, VBOs, texture ...
    }
};
```

### E. SDF shaders (OpenGL backend only)

The fragment shader renders rounded rectangles with borders and shadows
using signed distance functions — no textures needed for UI primitives.

```glsl
// quad.vert
#version 330 core

const vec2 quad_verts[6] = vec2[6](
    vec2(0, 0), vec2(1, 0), vec2(1, 1),
    vec2(0, 0), vec2(1, 1), vec2(0, 1)
);

// Per-instance attributes (matches QuadCmd layout)
layout(location = 1) in vec4 a_bounds;
layout(location = 2) in vec4 a_bg;
layout(location = 3) in vec4 a_border_color;
layout(location = 4) in float a_border_width;
layout(location = 5) in vec4 a_corner_radii;
layout(location = 6) in vec4 a_shadow_color;
layout(location = 7) in float a_shadow_blur;
layout(location = 8) in vec2 a_shadow_offset;

uniform vec2 u_viewport;

out vec2 v_local;
out vec4 v_bg;
out vec4 v_border_color;
out float v_border_width;
out vec4 v_corner_radii;
out vec4 v_shadow_color;
out float v_shadow_blur;
out vec2 v_size;

void main() {
    vec2 vert = quad_verts[gl_VertexID];
    float expand = a_shadow_blur * 2.0;
    vec2 pos = a_bounds.xy - expand + vert * (a_bounds.zw + expand * 2.0);
    vec2 ndc = (pos / u_viewport) * 2.0 - 1.0;
    ndc.y = -ndc.y;
    gl_Position = vec4(ndc, 0.0, 1.0);

    v_local = vert * (a_bounds.zw + expand * 2.0) - expand;
    v_size = a_bounds.zw;
    v_bg = a_bg;
    v_border_color = a_border_color;
    v_border_width = a_border_width;
    v_corner_radii = a_corner_radii;
    v_shadow_color = a_shadow_color;
    v_shadow_blur = a_shadow_blur;
}
```

```glsl
// quad.frag
#version 330 core

in vec2 v_local;
in vec4 v_bg;
in vec4 v_border_color;
in float v_border_width;
in vec4 v_corner_radii;
in vec4 v_shadow_color;
in float v_shadow_blur;
in vec2 v_size;

out vec4 frag_color;

float roundedBoxSDF(vec2 p, vec2 b, vec4 r) {
    vec2 rr = (p.x > 0.0)
        ? ((p.y > 0.0) ? r.zw : r.yz)
        : ((p.y > 0.0) ? r.wx : r.xy);
    float radius = rr.x;
    vec2 q = abs(p) - b + radius;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

void main() {
    vec2 half_size = v_size * 0.5;
    vec2 p = v_local - half_size;

    if (v_shadow_blur > 0.0) {
        float sd = roundedBoxSDF(p, half_size, v_corner_radii);
        float sa = 1.0 - smoothstep(-v_shadow_blur, v_shadow_blur, sd);
        frag_color = vec4(v_shadow_color.rgb, v_shadow_color.a * sa);
    }

    float dist = roundedBoxSDF(p, half_size, v_corner_radii);
    float body_alpha = 1.0 - smoothstep(-0.5, 0.5, dist);

    if (v_border_width > 0.0) {
        float inner = roundedBoxSDF(p, half_size - v_border_width, v_corner_radii);
        float ba = 1.0 - smoothstep(-0.5, 0.5, inner);
        vec4 fill = mix(v_bg, v_border_color, ba - body_alpha);
        frag_color = vec4(fill.rgb, fill.a * body_alpha);
    } else {
        frag_color = vec4(v_bg.rgb, v_bg.a * body_alpha);
    }
}
```

```glsl
// glyph.vert
#version 330 core

const vec2 quad_verts[6] = vec2[6](
    vec2(0, 0), vec2(1, 0), vec2(1, 1),
    vec2(0, 0), vec2(1, 1), vec2(0, 1)
);

layout(location = 1) in vec4 a_bounds;
layout(location = 2) in vec4 a_uv;
layout(location = 3) in vec4 a_color;

uniform vec2 u_viewport;
out vec2 v_uv;
out vec4 v_color;

void main() {
    vec2 vert = quad_verts[gl_VertexID];
    vec2 pos = a_bounds.xy + vert * a_bounds.zw;
    vec2 ndc = (pos / u_viewport) * 2.0 - 1.0;
    ndc.y = -ndc.y;
    gl_Position = vec4(ndc, 0.0, 1.0);
    v_uv = mix(a_uv.xy, a_uv.zw, vert);
    v_color = a_color;
}
```

```glsl
// glyph.frag
#version 330 core

in vec2 v_uv;
in vec4 v_color;
uniform sampler2D u_atlas;
out vec4 frag_color;

void main() {
    float alpha = texture(u_atlas, v_uv).r;
    frag_color = vec4(v_color.rgb, v_color.a * alpha);
}
```

---

## 11. Text Engine — GPUI-style Glyph Atlas (CoreText via `extern fn`)

This is the heart of text rendering, mirroring GPUI's approach: **shape text
with CoreText, rasterize individual glyphs into a cached atlas, then blit them
as positioned quads**. Both the native CG and OpenGL backends share the same
`GlyphAtlas` — the only difference is whether glyphs are drawn via
`CGContextDrawImage` or as GL textured quads.

Following `wndw`'s pattern, all CoreText and CoreGraphics APIs are called
through `extern fn` declarations — no SDK headers, no `@cImport`.

### A. Text measurement (for layout)

```zig
// Pure Zig externs — linked via -framework CoreText -framework CoreFoundation
extern fn CFStringCreateWithBytes(
    alloc: ?*anyopaque, bytes: [*]const u8, len: i64,
    encoding: u32, is_external: bool,
) ?*anyopaque;
extern fn CFAttributedStringCreate(
    alloc: ?*anyopaque, str: *anyopaque, attrs: *anyopaque,
) ?*anyopaque;
extern fn CTFontCreateWithName(
    name: *anyopaque, size: f64, matrix: ?*anyopaque,
) *anyopaque;
extern fn CTLineCreateWithAttributedString(attrStr: *anyopaque) *anyopaque;
extern fn CTLineGetTypographicBounds(
    line: *anyopaque, ascent: ?*f64, descent: ?*f64, leading: ?*f64,
) f64;
extern fn CFRelease(cf: *anyopaque) void;

const kCFStringEncodingUTF8: u32 = 0x08000100;

pub const TextMeasurer = struct {
    default_font: *anyopaque, // CTFontRef

    pub fn init(font_name: [:0]const u8, size: f32) TextMeasurer {
        const name_cf = CFStringCreateWithBytes(
            null, font_name.ptr, @intCast(font_name.len),
            kCFStringEncodingUTF8, false,
        ) orelse unreachable;
        defer CFRelease(name_cf);

        return .{
            .default_font = CTFontCreateWithName(name_cf, @floatCast(size), null),
        };
    }

    /// Measure text width + height using CoreText line metrics.
    pub fn measure(self: *TextMeasurer, str: []const u8, font_size: f32) struct { w: f32, h: f32 } {
        _ = font_size; // TODO: create font at requested size, or cache per-size
        const cf_str = CFStringCreateWithBytes(
            null, str.ptr, @intCast(str.len), kCFStringEncodingUTF8, false,
        ) orelse return .{ .w = 0, .h = 0 };
        defer CFRelease(cf_str);

        // Create attributed string with font
        // ... (create CFDictionary with kCTFontAttributeName → self.default_font)
        // ... create CTLine, measure, release ...

        var ascent: f64 = 0;
        var descent: f64 = 0;
        var leading: f64 = 0;
        const width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
        CFRelease(line);

        return .{
            .w = @floatCast(width),
            .h = @floatCast(ascent + descent + leading),
        };
    }
};
```

### B. Glyph atlas

Individual glyphs are rasterized into an R8 texture atlas on first use.
Subsequent frames just look up the cached UV coordinates.

```zig
pub const GlyphAtlas = struct {
    const GlyphKey = struct {
        codepoint: u21,
        font_size_x10: u16, // font size × 10 for sub-pixel sizing
    };

    const GlyphEntry = struct {
        uv: [4]f32,         // u0, v0, u1, v1
        size: [2]f32,       // pixel width, height
        bearing: [2]f32,    // x/y offset from baseline
        advance: f32,       // horizontal advance
    };

    cache: std.AutoHashMap(GlyphKey, GlyphEntry),
    atlas_x: u32 = 0,      // current packing cursor
    atlas_y: u32 = 0,
    row_height: u32 = 0,
    atlas_size: u32 = 1024,

    /// Rasterize a glyph via CoreGraphics if not cached.
    pub fn getOrInsert(
        self: *GlyphAtlas,
        key: GlyphKey,
        gl: *GlFunctions,
        atlas_tex: u32,
    ) GlyphEntry {
        if (self.cache.get(key)) |entry| return entry;

        // 1. Create CGBitmapContext (grayscale, 1 byte/pixel)
        // 2. Draw the glyph with CTFontDrawGlyphs
        // 3. Upload pixel data to atlas_tex at (atlas_x, atlas_y) via glTexSubImage2D
        // 4. Compute UV coordinates and cache them

        const entry = GlyphEntry{
            .uv = .{
                @as(f32, @floatFromInt(self.atlas_x)) / @as(f32, @floatFromInt(self.atlas_size)),
                @as(f32, @floatFromInt(self.atlas_y)) / @as(f32, @floatFromInt(self.atlas_size)),
                @as(f32, @floatFromInt(self.atlas_x + glyph_w)) / @as(f32, @floatFromInt(self.atlas_size)),
                @as(f32, @floatFromInt(self.atlas_y + glyph_h)) / @as(f32, @floatFromInt(self.atlas_size)),
            },
            .size = .{ @floatFromInt(glyph_w), @floatFromInt(glyph_h) },
            .bearing = .{ x_bearing, y_bearing },
            .advance = advance,
        };

        self.cache.put(key, entry) catch {};

        // Advance packing cursor
        self.atlas_x += glyph_w + 1; // 1px padding
        if (self.atlas_x + glyph_w >= self.atlas_size) {
            self.atlas_x = 0;
            self.atlas_y += self.row_height + 1;
            self.row_height = 0;
        }
        self.row_height = @max(self.row_height, glyph_h);

        return entry;
    }
};
```

### C. The GPUI text rendering pipeline

This mirrors Zed's approach precisely:

1. **Shaping** (CoreText): Convert a UTF-8 string into a sequence of
   glyph IDs + advances using `CTLineCreateWithAttributedString`. This
   handles kerning, ligatures, complex scripts, and bidi.

2. **Measurement** (layout phase): `TextMeasurer.measure()` returns the
   bounding box → feeds into the flexbox engine as a leaf node's intrinsic
   size.

3. **Rasterization** (on cache miss): For each unique (glyph_id, font_size)
   pair not yet in the atlas, rasterize the glyph into a temporary
   `CGBitmapContext` (grayscale, 1 byte/pixel), then copy the pixels into
   the atlas bitmap at the next available slot.

4. **Paint phase**: Iterate shaped glyphs, look up each in `GlyphAtlas`,
   push a `GlyphCmd` per glyph with screen position + atlas UVs + color.

5. **Draw phase** (backend-specific):
   - **Native**: `CGContextDrawImage` per glyph from the atlas CGImage,
     with color tinting via CG compositing modes.
   - **OpenGL**: All `GlyphCmd`s uploaded as instance data, drawn in a
     single `glDrawArraysInstanced` call against the atlas GL texture.

This architecture means glyph rasterization (the expensive part) only
happens once per unique glyph/size combination. Subsequent frames just
emit positioned quads — the same trick that gives Zed 120fps text rendering.

---

## 12. Theme System

Responds to `wndw`'s `.appearance_changed` event to toggle light/dark themes.

```zig
pub const Theme = struct {
    // Surfaces
    background: Color,
    surface: Color,
    surface_hover: Color,
    surface_active: Color,

    // Content
    on_background: Color,
    on_surface: Color,
    on_surface_secondary: Color,

    // Accent
    primary: Color,
    on_primary: Color,
    primary_hover: Color,

    // Semantic
    error_color: Color,
    warning: Color,
    success: Color,

    // Borders & dividers
    border: Color,
    divider: Color,

    // Shadows
    shadow: Color,

    pub fn dark() Theme {
        return .{
            .background = Color.hex(0x1E1E2E),
            .surface = Color.hex(0x313244),
            .surface_hover = Color.hex(0x45475A),
            .surface_active = Color.hex(0x585B70),
            .on_background = Color.hex(0xCDD6F4),
            .on_surface = Color.hex(0xCDD6F4),
            .on_surface_secondary = Color.hex(0xA6ADC8),
            .primary = Color.hex(0x89B4FA),
            .on_primary = Color.hex(0x1E1E2E),
            .primary_hover = Color.hex(0xB4D0FB),
            .error_color = Color.hex(0xF38BA8),
            .warning = Color.hex(0xFAB387),
            .success = Color.hex(0xA6E3A1),
            .border = Color.hex(0x45475A),
            .divider = Color.hex(0x313244),
            .shadow = Color.rgba(0, 0, 0, 80),
        };
    }

    pub fn light() Theme {
        return .{
            .background = Color.hex(0xEFF1F5),
            .surface = Color.hex(0xE6E9EF),
            .surface_hover = Color.hex(0xDCE0E8),
            .surface_active = Color.hex(0xBCC0CC),
            .on_background = Color.hex(0x4C4F69),
            .on_surface = Color.hex(0x4C4F69),
            .on_surface_secondary = Color.hex(0x7C7F93),
            .primary = Color.hex(0x1E66F5),
            .on_primary = Color.hex(0xEFF1F5),
            .primary_hover = Color.hex(0x4B83F7),
            .error_color = Color.hex(0xD20F39),
            .warning = Color.hex(0xFE640B),
            .success = Color.hex(0x40A02B),
            .border = Color.hex(0xBCC0CC),
            .divider = Color.hex(0xDCE0E8),
            .shadow = Color.rgba(0, 0, 0, 30),
        };
    }
};
```

---

## 13. Action System & Keybindings

GPUI maps keystrokes to semantic actions. In Zig, we use a comptime-generated
union and a simple binding table.

```zig
pub const Action = union(enum) {
    copy,
    paste,
    cut,
    select_all,
    undo,
    redo,
    delete_backward,
    delete_forward,
    move_left,
    move_right,
    move_up,
    move_down,
    move_to_line_start,
    move_to_line_end,
    // App-defined actions extend via composition (wrap in a larger union)
};

pub const KeyBinding = struct {
    key: event.Key,
    mods: event.Modifiers,
    action: Action,
};

pub const KeybindingTable = struct {
    bindings: []const KeyBinding,

    pub fn match(self: *const KeybindingTable, kp: event.KeyEvent) ?Action {
        for (self.bindings) |b| {
            if (b.key == kp.key and
                b.mods.super == kp.mods.super and
                b.mods.ctrl == kp.mods.ctrl and
                b.mods.alt == kp.mods.alt and
                b.mods.shift == kp.mods.shift)
            {
                return b.action;
            }
        }
        return null;
    }
};

/// Default macOS keybindings.
pub const default_bindings: []const KeyBinding = &.{
    .{ .key = .c, .mods = .{ .super = true }, .action = .copy },
    .{ .key = .v, .mods = .{ .super = true }, .action = .paste },
    .{ .key = .x, .mods = .{ .super = true }, .action = .cut },
    .{ .key = .a, .mods = .{ .super = true }, .action = .select_all },
    .{ .key = .z, .mods = .{ .super = true }, .action = .undo },
    .{ .key = .z, .mods = .{ .super = true, .shift = true }, .action = .redo },
    .{ .key = .backspace, .mods = .{}, .action = .delete_backward },
    .{ .key = .delete, .mods = .{}, .action = .delete_forward },
    .{ .key = .left, .mods = .{}, .action = .move_left },
    .{ .key = .right, .mods = .{}, .action = .move_right },
    .{ .key = .up, .mods = .{}, .action = .move_up },
    .{ .key = .down, .mods = .{}, .action = .move_down },
    .{ .key = .left, .mods = .{ .super = true }, .action = .move_to_line_start },
    .{ .key = .right, .mods = .{ .super = true }, .action = .move_to_line_end },
};
```

Actions are dispatched to the focused element first, then bubble up the view
hierarchy. Any view can register an action handler:

```zig
fn handleAction(self: *MyView, action: Action, cx: *WindowContext) bool {
    switch (action) {
        .copy => { self.copySelection(cx); return true; },
        .paste => { self.pasteFromClipboard(cx); return true; },
        else => return false, // not handled, bubble up
    }
}
```

---

## 14. Animation System

Smooth transitions for style properties (opacity, color, position).
Animations are persistent state — they live in the entity pool, not the
frame arena.

```zig
pub const Animation = struct {
    pub const Easing = enum {
        linear,
        ease_in,
        ease_out,
        ease_in_out,
    };

    start_value: f32,
    end_value: f32,
    duration_ms: u32,
    elapsed_ms: u32 = 0,
    easing: Easing = .ease_in_out,
    done: bool = false,

    pub fn tick(self: *Animation, dt_ms: u32) f32 {
        self.elapsed_ms += dt_ms;
        if (self.elapsed_ms >= self.duration_ms) {
            self.done = true;
            return self.end_value;
        }
        const t = @as(f32, @floatFromInt(self.elapsed_ms)) /
                  @as(f32, @floatFromInt(self.duration_ms));
        const eased = switch (self.easing) {
            .linear => t,
            .ease_in => t * t,
            .ease_out => 1.0 - (1.0 - t) * (1.0 - t),
            .ease_in_out => if (t < 0.5) 2.0 * t * t else 1.0 - std.math.pow(f32, -2.0 * t + 2.0, 2) / 2.0,
        };
        return self.start_value + (self.end_value - self.start_value) * eased;
    }
};
```

Usage in a view:

```zig
const FadeIn = struct {
    opacity_anim: Animation,
    child: AnyView,

    pub fn render(self: *const FadeIn, cx: *WindowContext) Element {
        return div(cx)
            .opacity(self.opacity_anim.current())
            .child(self.child.render(cx))
            .into_element();
    }
};
```

The `WindowContext` maintains an animation tick based on frame delta time.
Any running animation marks the context dirty so rendering continues even
without user input.

---

## 15. The `WindowContext` (full definition)

The central coordinator — owns everything, passed to all UI code.

```zig
pub const WindowContext = struct {
    // ── Platform ──────────────────────────────────────────────────────
    window: *wndw.Window,
    gpa: std.mem.Allocator,
    frame_arena: std.heap.ArenaAllocator,

    // ── State ─────────────────────────────────────────────────────────
    entities: EntityPool,
    subscriptions: SubscriptionTable,
    root_view: ?AnyView = null,
    needs_render: bool = true,
    focused_element: ?u32 = null,

    // ── Rendering ─────────────────────────────────────────────────────
    backend: RenderBackend,
    renderer: Renderer,
    paint_cx: PaintContext,
    text_measurer: TextMeasurer,
    scale_factor: f32 = 1.0,

    // ── Input ─────────────────────────────────────────────────────────
    keybindings: KeybindingTable,

    // ── Theming ───────────────────────────────────────────────────────
    theme: Theme,

    // ── Time ──────────────────────────────────────────────────────────
    last_frame_time: i64,
    frame_dt_ms: u32 = 16,

    pub fn init(gpa: std.mem.Allocator, win: *wndw.Window, backend: RenderBackend) !WindowContext {
        return .{
            .window = win,
            .gpa = gpa,
            .frame_arena = std.heap.ArenaAllocator.init(gpa),
            .entities = EntityPool.init(gpa),
            .subscriptions = SubscriptionTable.init(gpa),
            .backend = backend,
            .renderer = try Renderer.init(win, backend, gpa),
            .paint_cx = PaintContext.init(gpa),
            .text_measurer = TextMeasurer.init(".AppleSystemUIFont", 14),
            .keybindings = .{ .bindings = default_bindings },
            .theme = if (win.getAppearance() == .dark) Theme.dark() else Theme.light(),
            .last_frame_time = std.time.milliTimestamp(),
        };
    }

    pub fn deinit(self: *WindowContext) void {
        self.frame_arena.deinit();
        self.entities.deinit();
        self.renderer.deinit();
    }

    pub fn frameAlloc(self: *WindowContext) std.mem.Allocator {
        return self.frame_arena.allocator();
    }

    pub fn resetFrame(self: *WindowContext) void {
        _ = self.frame_arena.reset(.retain_capacity);
        self.paint_cx.hit_boxes.clearRetainingCapacity();
        // Update frame timing
        const now = std.time.milliTimestamp();
        self.frame_dt_ms = @intCast(@min(now - self.last_frame_time, 100));
        self.last_frame_time = now;
    }

    pub fn render(self: *WindowContext) void {
        if (self.root_view) |view| {
            const root_element = view.render(self);

            // Layout pass
            const win_size = self.window.getSize();
            var lx = LayoutContext{
                .frame_alloc = self.frameAlloc(),
                .text_measurer = &self.text_measurer,
            };
            const constraints = Constraints.tight(
                @floatFromInt(win_size.w),
                @floatFromInt(win_size.h),
            );
            _ = root_element.layout(&lx, constraints);

            // Paint pass
            self.paint_cx.z_index = 0;
            root_element.paint(&self.paint_cx, .{
                .x = 0, .y = 0,
                .w = @floatFromInt(win_size.w),
                .h = @floatFromInt(win_size.h),
            });
        }
        self.needs_render = false;
    }

    pub fn setRootView(self: *WindowContext, view: AnyView) void {
        self.root_view = view;
        self.needs_render = true;
    }
};
```

---

## 16. Implementation Roadmap

Build incrementally. Each phase produces a working demo.

### Phase 1: Colored rectangles ✅ DONE

- `WindowContext` wrapping `wndw.Window` with frame arena
- `Div` element with `bg()`, `padding_all()`, `size()`, hardcoded absolute positions
- `NativeRenderer` drawing `QuadCmd` list via CoreGraphics
- `DrawList` and `PaintContext` (no hit testing yet)
- Hook into NSView's `drawRect:` for native rendering
- **Demo**: `ui_demo.zig` — nested colored rounded rectangles on screen

**Architecture decisions (learned during implementation):**

1. **Platform renderer lives in `wndw` module**, not in `src/ui/`. The CG extern fns
   and ObjC runtime calls belong alongside the rest of the macOS platform code in
   `src/platform/macos/renderer.zig`. The UI layer imports `Renderer` from `wndw`
   via `@import("wndw").Renderer`, keeping `src/ui/` fully platform-agnostic.

2. **Shared render types module** (`render_types`). `QuadCmd` and `ClipCmd` are defined
   in `src/ui/render/types.zig` as a standalone build module — the leaf of the
   dependency graph. Both the `wndw` module (platform renderer) and the `ui` module
   (draw list) import from it, avoiding circular deps and Zig's "file in two modules"
   error.

3. **`drawRect:` callback hook**. Added `Window.setDrawCallback()` and
   `Window.requestRedraw()` to the wndw API. The callback fires synchronously inside
   `drawRect:` while a valid CG context exists. The UI framework calls
   `win.requestRedraw()` after building its draw list, and the renderer flushes
   quads in the callback.

4. **`[4]f32` bounds in ClipCmd** (not a Rect struct). Keeps ClipCmd self-contained
   in the shared types module without depending on layout.zig's Rect.

**Suggested improvements for Phase 3:**
- Consider whether `RenderFn = *const fn (Allocator) Element` should take a
  `*WindowContext` instead, so views can access window state (size, theme, etc.)
  during render.
- `flex_shrink` is stored but not yet applied during overflow (Phase 2 only
  distributes positive remaining space via `flex_grow`).

### Phase 2: Flexbox layout ✅ DONE

- Proper flexbox algorithm in `Div.doLayout`:
  - Two-pass: measure children → distribute space → position
  - `flex_grow` distributes remaining main-axis space proportionally
  - `gap` accounts for spacing in both layout and flex_grow distribution
  - `justify_content`: start, end, center, space_between, space_around, space_evenly
  - `align_items`: start, end, center, stretch (default)
  - `align_self` per-element override via Element struct field
  - Auto-sized containers shrink-wrap to children (unbounded cross-axis pass)
- `ChildLayout` struct replaces `child_sizes` — stores computed x/y/w/h per child
- `Element` now carries `flex_grow`, `flex_shrink`, `align_self` fields (copied
  from Style in `into_element()`) so parent can read child layout hints without vtable
- New fluent API: `.grow(f32)`, `.shrink(f32)`, `.align_items(Align)`, `.align_self(Align)`,
  `.justify(Justify)`
- 17 new tests (46 total): flex row/col positioning, gap, flex_grow equal and
  proportional, align_items center/stretch, align_self override, justify_content
  all 6 modes, auto-sized shrink-wrap row/col, flex_grow+gap, padding+flex, nested flex
- **Demo**: `flex_demo.zig` — 5-section layout showcasing toolbar, flex_grow,
  space_between, sidebar+content split, centered card

**Architecture decisions (Phase 2):**

1. **Layout hints on Element struct** (not vtable). `flex_grow`, `flex_shrink`, and
   `align_self` live directly on Element, copied from Style in `into_element()`. This
   avoids adding a `get_style` vtable method and keeps the parent's flexbox algorithm
   simple — it reads child layout hints directly without dynamic dispatch.

2. **ChildLayout replaces child_sizes**. Layout now computes full x/y/w/h positions
   relative to the content area. Paint just offsets by content origin — no position
   computation in the paint pass.

3. **Unbounded cross-axis for auto-sized containers**. When a dimension is `.auto` and
   constraints are unbounded, children are measured with `inf` on the cross axis so
   explicit child sizes are preserved. After measurement, the container shrink-wraps
   to `max(child_cross)`.

4. **`align` is a reserved word in Zig**. Variable named `alignment` instead.

### Phase 3: Text rendering ✅ DONE

- CoreText `extern fn` declarations (`coretext.zig`) for font creation, glyph mapping, metrics
- `GlyphAtlas` with shelf-packing for measurement/advance caching (`text.zig`)
- `Text` element with fluent API: `font_size()`, `color()`, `font_weight()` (`ui/text.zig`)
- `TextCmd` draw command, `TextMeasurer` interface in shared `render_types`
- Rendering via `CTFontDrawGlyphs` — batch glyph drawing with CG context unflip
- `FontWeight` enum (ultralight through black), `MacTextBackend` with font cache
- 6 new tests (59 total): fluent API, layout measurement, paint emit, constraints, text-in-div, DrawList
- **Demo**: `text_demo.zig` — titles, labeled buttons, font size showcase, user card, status bar
- Live resize support via `requestRedraw()` from `windowDidResize:` delegate

**Architecture decisions:**

1. **Platform-agnostic Text element** with `TextMeasurer` function pointer interface.
   The measurer is provided by the platform renderer, passed at construction time.
   No vtable changes needed — keeps Element interface stable.

2. **CTFontDrawGlyphs for rendering** instead of atlas bitmap blitting. CoreText
   handles glyph positioning, hinting, and subpixel rendering natively. The atlas
   still caches advance widths for fast measurement.

3. **Local context unflip for text drawing.** The flush() context is flipped (top-down).
   `CTFontDrawGlyphs` expects CG's native bottom-up system. Solution: `CGContextScaleCTM(1, -1)`
   with negated y positions for the draw call.

4. **`FontWeight` as platform-agnostic enum** in style.zig, converted to ordinal for
   the measurer/renderer. System font (`.AppleSystemUIFont`) via toll-free bridged NSString.

### Phase 4: Interaction ✅ DONE

- Hit box registration during paint (painter's order, back-to-front hit testing)
- `on_click` dispatch — press+release on same element fires callback
- `on_mouse_enter` / `on_mouse_leave` callbacks with hover tracking
- Cursor changes on hover via `wndw.setStandardCursor()` / `resetCursor()`
- `Callback` type: type-erased `fn(?*anyopaque) void` + context pointer
- `HitTestList` in `PaintContext` — accumulated during paint, queried on mouse events
- `WindowContext.handleMouseMove/Press/Release()` dispatches to hit test system
- Fluent API: `.on_click(ctx, fn)`, `.set_cursor(.pointing_hand)`
- **Demo**: `counter_demo` — increment/decrement/reset buttons with cursor changes

**Architecture decisions:**

1. **Hit boxes in PaintContext, not a separate tree**: Hit boxes are registered during
   the paint phase alongside draw commands. This means the hit test list is always
   consistent with what's rendered — no sync issues between layout and interaction.

2. **Callback = ctx + fn pointer**: Rather than storing closures or vtables, callbacks
   are a simple `{ ctx: ?*anyopaque, func: ?*const fn(?*anyopaque) void }`. This is
   zero-cost when unused and trivially composable from Zig code.

3. **Press+release click model**: `on_click` only fires when press and release hit the
   same element. This matches native platform behavior — users can "cancel" a click
   by dragging off the element before releasing.

### Phase 5: Reactivity ✅ DONE

- `EntityPool`: generational slab with type-erased slots, free list recycling
- `Handle(T)`: typed wrapper with `read()` and `update()` (auto-notifies observers)
- `View(T)`: wraps Handle, delegates `render()` to model, `subscribe()` sets dirty flag
- Observer pattern: `pool.observe(id, ctx, fn)` — callbacks fire on `handle.update()`
- Generation checks: stale handles caught by generation mismatch assertions
- **Demo**: `observer_demo` — counter with stats panel, status bar, all observing shared state

**Architecture decisions:**

1. **Comptime-generated destroy fn per type**: Each slot stores a `DestroyFn` created via
   `makeDestroyFn(T)` at comptime. This avoids storing size/alignment and lets us use
   `gpa.destroy(ptr)` with correct type alignment — clean deallocation for any `T`.

2. **Subscriptions as flat list**: Simple `ArrayList(Subscription)` rather than a per-entity
   hash map. For typical UI entity counts (<100), linear scan is faster than hashing.
   Subscriptions are cleaned up on `destroy()` via swap-remove.

3. **View.subscribe() wires dirty flag**: Rather than coupling View to WindowContext, the
   view just sets a `*bool` to true when its entity changes. The demo wires this to
   `cx.needs_render`. This keeps View testable without the platform renderer.

### Phase 6: Scroll & polish (2–3 days)

- Scroll containers with clip rects (`CGContextClipToRect` / `glScissor`)
- `ScrollState` in entity pool, dispatched from `wndw.scroll`
- Theme system responding to `wndw.appearance_changed`
- Animation system with easing
- Action/keybinding system
- **Demo**: Scrollable list with theme toggle and keyboard shortcuts

### Phase 7: Component Library — Foundation (3–4 days)

Build-out of reusable, styled components on top of the element primitives.
Each component is a Zig struct with a fluent API that returns an `Element`.
Inspired by [gpui-component](https://github.com/longbridge/gpui-component) (60+ components for GPUI/Rust).

**Inputs & Controls:**
- `Button` — primary/secondary/ghost/danger variants, disabled state, icon slot, loading spinner
- `IconButton` — compact square button with just an icon
- `Checkbox` — checked/unchecked/indeterminate, label, on_change callback
- `Radio` — radio group with mutual exclusion, on_change
- `Switch` — toggle switch with on/off state, animated thumb
- `Slider` — horizontal/vertical, range, step, on_change
- `TextInput` — single-line input, placeholder, selection, cursor, on_submit
- `TextArea` — multi-line input with scroll
- `Select` — dropdown menu with options, search/filter, on_select
- `ColorPicker` — hue/saturation/lightness picker, hex input

**Display & Typography:**
- `Label` — styled text with size variants (xs/sm/md/lg), truncation, wrapping
- `Icon` — SVG/glyph icon with size and color
- `Badge` — notification count or status dot
- `Tag` — colored label chip, removable variant
- `Tooltip` — hover-triggered floating text
- `Kbd` — keyboard shortcut display (e.g. `⌘S`)
- `Skeleton` — loading placeholder with pulse animation
- `Spinner` — circular loading indicator
- `Rating` — star rating (read-only or interactive)

**Layout & Structure:**
- `Divider` — horizontal/vertical line with optional label
- `Accordion` — collapsible sections with header + content
- `Collapsible` — single collapsible panel
- `GroupBox` — bordered group with title
- `Breadcrumb` — navigation breadcrumb trail
- `Stepper` — numbered step indicator (wizard flow)
- `Tabs` — tabbed content panels, on_select

**Overlays & Feedback:**
- `Popover` — anchored floating panel (click to toggle)
- `HoverCard` — floating card on hover (preview)
- `Dialog` — modal dialog with title, body, actions
- `Sheet` — slide-in panel from edge (side sheet)
- `Alert` — inline alert banner (info/warning/error/success)
- `Notification` — toast-style notification, auto-dismiss
- `Progress` — linear progress bar, determinate/indeterminate

**Data & Lists:**
- `List` — virtualized list with dynamic row heights
- `VirtualList` — high-performance list for 100K+ items
- `Table` — columns, sorting, row selection, virtualized
- `DescriptionList` — key-value pair display
- `Tree` — expandable/collapsible tree view
- `Pagination` — page controls for paginated data
- `Menu` — context menu / dropdown menu with items, dividers, submenus

**Navigation:**
- `Sidebar` — collapsible sidebar with sections and items
- `TitleBar` — custom window title bar (integrates with `wndw` inset titlebar)
- `Link` — clickable text link with hover underline

**Demo**: Component showcase app — tabbed gallery showing every component
with live interactive examples.

### Phase 8: Component Library — Advanced (3–4 days)

- `Resizable` — resizable panels with drag handles
- `Dock` — dockable/undockable panel layout (IDE-style)
- `Form` — form container with validation, field layout, submit
- `Clipboard` — copy/paste integration via `wndw` clipboard API
- `FocusTrap` — keyboard focus containment for modals/dialogs
- `Animation` — declarative spring/ease/tween animations on any property
- `Theme` — light/dark mode, custom color tokens, responds to `wndw.appearance_changed`
- `ActionSystem` — keybinding table, command palette dispatch

**Demo**: IDE-style layout with dock panels, resizable splits, command palette

### Phase 9: OpenGL backend (optional, 2–3 days)

- `GlRenderer` with SDF quad + glyph shaders
- GL atlas texture (upload same rasterized glyph data to GL texture)
- Instanced draw calls for quads and glyphs
- Backend selector: `App{ .backend = .opengl }`
- **Demo**: Same UI running on both backends, switchable at startup

---

## Appendix A: File structure

```
src/
├── ui/                            ← UI framework (platform-agnostic)
│   ├── root.zig                   ← public API re-exports [Phase 1 ✅]
│   ├── context.zig                ← WindowContext [Phase 1 ✅]
│   ├── element.zig                ← Element vtable, Div [Phase 1 ✅]
│   ├── style.zig                  ← Style, Color, Len, Edges [Phase 1 ✅]
│   ├── layout.zig                 ← Constraints, Rect, Size [Phase 1 ✅]
│   ├── text.zig                   ← Text element, fluent API [Phase 3 ✅]
│   ├── interaction.zig            ← HitTestList, HitBox, Callback [Phase 4 ✅]
│   ├── entity.zig                 ← EntityPool, Handle(T), EntityId [Phase 5 ✅]
│   ├── view.zig                   ← View(T), subscribe/dirty [Phase 5 ✅]
│   ├── tests.zig                  ← UI unit tests (83 tests) [Phase 1-5 ✅]
│   ├── theme.zig                  ← Theme, dark/light presets
│   ├── action.zig                 ← Action union, KeybindingTable
│   ├── animation.zig              ← Animation, Easing
│   └── render/
│       ├── types.zig              ← QuadCmd, ClipCmd, TextCmd, TextMeasurer [Phase 1+3 ✅]
│       ├── draw_list.zig          ← DrawList (quad/clip/text accumulator) [Phase 1+3 ✅]
│       ├── paint.zig              ← PaintContext [Phase 1+3 ✅]
│       ├── native.zig             ← Renderer import from wndw [Phase 1 ✅]
│       └── opengl.zig             ← GlRenderer (SDF shaders, opt-in)
├── platform/
│   └── macos/
│       ├── window.zig             ← Window, events, drawRect callback
│       ├── objc.zig               ← ObjC runtime extern fns
│       ├── cocoa.zig              ← AppKit numeric constants
│       ├── keymap.zig             ← hardware keycode mapping
│       ├── coretext.zig           ← CoreText extern fns + helpers [Phase 3 ✅]
│       ├── text.zig               ← GlyphAtlas, MacTextBackend [Phase 3 ✅]
│       └── renderer.zig           ← CG quad + text renderer [Phase 1+3 ✅]
├── event.zig                      ← platform-agnostic event types
├── event_queue.zig                ← lock-free circular buffer
└── root.zig                       ← wndw public API + Renderer export
```

## Appendix B: Rendering backend rationale

**Native CoreGraphics is the default** because:

- Zero setup — no GL context, no shaders, no deprecated API warnings
- Automatic subpixel text, color management, and Retina scaling
- `CGPathCreateWithRoundedRect` + `CGContextSetShadow` cover all UI primitives
- Matches `wndw`'s philosophy: pure platform APIs via `extern fn`
- Sufficient for typical app UIs (toolbars, lists, forms, panels)

**OpenGL 3.2 is the opt-in** for when you need:

- Instanced rendering for 10,000+ elements (data tables, node graphs)
- Custom fragment shaders (SDF text effects, blurs, gradients)
- Consistent rendering across platforms (when Linux/Windows backends land)
- `wndw` already exposes full GL context management and proc loading

**Metal** can be added later as a third backend behind the same `DrawList`
interface — the element/layout/event layers don't change

## Appendix C: Comparison with GPUI

| GPUI (Rust) | This framework (Zig) |
|---|---|
| `Arc<Mutex<T>>` | `Handle(T)` + generational slab |
| `impl Render for T` | `T` has `pub fn render(*const T, *WindowContext) Element` |
| `div().child(...)` returns owned | `div(cx).child(...)` returns `*Div` (frame arena) |
| Taffy for layout | Zig-native flexbox (~400 lines) |
| Metal + Blade | Native CG (default) / OpenGL 3.2 (opt-in) |
| `cx.notify()` | `handle.update(cx, fn)` auto-notifies |
| proc macros for Actions | `comptime` union + binding table |
| `SharedString` (Arc) | `[]const u8` in frame arena or entity pool |
| Platform via objc crate | `wndw` (pure Zig ObjC runtime) |
