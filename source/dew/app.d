/// Application host: rebuild → layout → paint → present.
module dew.app;

import dew.dsl;
import dew.node;
import dew.layout;
import dew.display_list;
import dew.paint_pass;
import dew.event;
import dew.backend.iface;

/// Owns the retained tree and drives a frame.
struct App
{
    UiBuilder ui;
    NodeId root;
    DisplayList list;
    float width = 800;
    float height = 600;
    RenderBackend backend;
    string title = "dew";
    string versionLabel = import("VERSION");
    /// Captures contacts across frames (multi-touch + drag).
    PointerRouter pointers;

    void setRoot(Widget w) @safe @nogc
    {
        root = w.id;
    }

    void frame() @safe
    {
        layoutTree(ui.store, root, width, height);
        list.clear();
        paintTree(ui.store, root, list);
        if (backend !is null)
            backend.present(list, cast(uint) width, cast(uint) height);
    }

    bool pointer(PointerEvent ev) @safe
    {
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

    void resize(float w, float h) @safe
    {
        width = w;
        height = h;
        if (backend !is null)
            backend.resize(cast(uint) w, cast(uint) h);
    }
}
