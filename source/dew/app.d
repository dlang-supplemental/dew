/// Application host: rebuild → layout → paint → present.
module dew.app;

import dew.dsl;
import dew.node;
import dew.layout;
import dew.display_list;
import dew.paint_pass;
import dew.event;
import dew.scale;
import dew.backend.iface;

/// Owns the retained tree and drives a frame.
///
/// `width` / `height` are the **logical** layout viewport. Widget `.px` sizes
/// and pointer coordinates are logical. `contentScale` maps logical → physical
/// for the display list and backend framebuffer. Default scale is 1× (no-op).
struct App
{
    UiBuilder ui;
    NodeId root;
    DisplayList list;
    /// Logical layout viewport (DIPs).
    float width = 800;
    float height = 600;
    /// Whole-UI content scale (GLFW content scale / Win32 DPI÷96). Default 1×.
    ScaleFactor contentScale; // default 1x1
    /// Optional live probe; when non-null, `frame()` refreshes `contentScale`.
    ContentScaleSource scaleSource;
    RenderBackend backend;
    string title = "dew";
    string versionLabel = import("VERSION");
    /// Captures contacts across frames (multi-touch + drag).
    PointerRouter pointers;

    void setRoot(Widget w) @safe @nogc
    {
        root = w.id;
    }

    /// Set content scale explicitly (also clears `scaleSource` unless keepSource).
    void setContentScale(ScaleFactor scale, bool keepSource = false) @safe @nogc nothrow
    {
        contentScale = scale;
        if (!keepSource)
            scaleSource = null;
    }

    /// Logical viewport size.
    @property float logicalWidth() const @safe @nogc pure nothrow
    {
        return width;
    }

    @property float logicalHeight() const @safe @nogc pure nothrow
    {
        return height;
    }

    /// Physical framebuffer size derived from logical viewport × content scale.
    @property float physicalWidth() const @safe @nogc pure nothrow
    {
        return contentScale.logicalToPhysicalX(width);
    }

    @property float physicalHeight() const @safe @nogc pure nothrow
    {
        return contentScale.logicalToPhysicalY(height);
    }

    /**
     * Sync from a window host: framebuffer size + content scale.
     *
     * Sets logical `width`/`height` to `framebuffer / scale` and resizes the
     * backend to the physical framebuffer. Typical GLFW loop:
     *
     * ---
     * float sx, sy;
     * glfwGetWindowContentScale(win, &sx, &sy);
     * int fbW, fbH;
     * glfwGetFramebufferSize(win, &fbW, &fbH);
     * app.syncFromFramebuffer(fbW, fbH, ScaleFactor(sx, sy));
     * ---
     *
     * Or pass `contentScaleFromGlfw(win, cast(GlfwContentScaleFn)&glfwGetWindowContentScale)`.
     */
    void syncFromFramebuffer(float framebufferW, float framebufferH, ScaleFactor scale) @safe
    {
        if (scale.x <= 0)
            scale.x = 1;
        if (scale.y <= 0)
            scale.y = 1;
        contentScale = scale;
        width = scale.physicalToLogicalX(framebufferW);
        height = scale.physicalToLogicalY(framebufferH);
        if (backend !is null)
            backend.resize(cast(uint) framebufferW, cast(uint) framebufferH);
    }

    void frame() @safe
    {
        if (scaleSource !is null)
            contentScale = scaleSource.contentScale();
        layoutTree(ui.store, root, width, height);
        list.clear();
        paintTree(ui.store, root, list);
        list.applyContentScale(contentScale);
        if (backend !is null)
            backend.present(list, cast(uint) physicalWidth, cast(uint) physicalHeight);
    }

    bool pointer(PointerEvent ev) @safe
    {
        // Pointer samples are logical (same space as layout / GLFW cursor pos).
        return pointers.dispatch(ui.store, root, ev);
    }

    bool key(KeyEvent ev) @safe
    {
        return pointers.dispatchKey(ui.store, root, ev);
    }

    @property NodeId focused() const @safe @nogc pure nothrow
    {
        return pointers.focused;
    }

    void focus(NodeId id) @safe @nogc nothrow
    {
        pointers.focused = id;
    }

    /// Resize the **logical** viewport; backend gets physical pixels.
    void resize(float w, float h) @safe
    {
        width = w;
        height = h;
        if (backend !is null)
            backend.resize(cast(uint) physicalWidth, cast(uint) physicalHeight);
    }
}

unittest
{
    // 100% vs 150% content scale: logical widget width 100 → physical 100 vs 150.
    import dew.units : Length;

    App app;
    beginUi(app.ui);
    scope (exit)
        endUi();

    Node box;
    box.kind = NodeKind.Button;
    box.text = "X";
    box.fontSize = 14;
    box.width = Length.px(100);
    box.height = Length.px(40);
    auto id = app.ui.store.alloc(box);
    app.setRoot(Widget(id));
    app.resize(200, 100);

    float buttonPhysicalW(ScaleFactor s)
    {
        app.setContentScale(s);
        app.frame();
        foreach (ref cmd; app.list.cmds)
        {
            if (cmd.op == DrawOp.FillRoundedRect)
                return cmd.w;
        }
        return float.nan;
    }

    const w100 = buttonPhysicalW(ScaleFactor.uniform(1.0f));
    const w150 = buttonPhysicalW(ScaleFactor.uniform(1.5f));
    assert(w100 > 99 && w100 < 101);
    assert(w150 > 149 && w150 < 151);
    // Layout geometry stays logical (node bounds not mutated by paint scale).
    assert(app.ui.store[id].w > 99 && app.ui.store[id].w < 101);

    app.syncFromFramebuffer(1200, 900, ScaleFactor.uniform(1.5f));
    assert(app.width > 799 && app.width < 801);
    assert(app.height > 599 && app.height < 601);
    assert(app.physicalWidth > 1199 && app.physicalWidth < 1201);
}
