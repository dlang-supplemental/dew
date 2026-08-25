/// Application host: rebuild → layout → paint → present.
module rmgui.app;

import rmgui.dsl;
import rmgui.node;
import rmgui.layout;
import rmgui.display_list;
import rmgui.paint_pass;
import rmgui.event;
import rmgui.backend.iface;

/// Owns the retained tree and drives a frame.
struct App
{
    UiBuilder ui;
    NodeId root;
    DisplayList list;
    float width = 800;
    float height = 600;
    RenderBackend backend;
    string title = "rmgui";
    string versionLabel = import("VERSION");

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
        return dispatchPointer(ui.store, root, ev);
    }

    void resize(float w, float h) @safe
    {
        width = w;
        height = h;
        if (backend !is null)
            backend.resize(cast(uint) w, cast(uint) h);
    }
}
