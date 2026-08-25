/// Input / focus event model.
module rmgui.event;

import rmgui.node;

enum PointerButton : ubyte
{
    Left = 1,
    Right = 2,
    Middle = 4,
}

struct PointerEvent
{
    float x, y;
    PointerButton button;
    bool pressed;
}

/// Hit-test and dispatch click handlers for the laid-out tree.
bool dispatchPointer(ref NodeStore store, NodeId root, PointerEvent ev) @safe
{
    if (!root.valid || !ev.pressed || ev.button != PointerButton.Left)
        return false;
    return hitClick(store, root, ev.x, ev.y);
}

private bool hitClick(ref NodeStore store, NodeId id, float x, float y) @safe
{
    ref Node n = store[id];
    // Children first (top-most)
    for (auto c = n.firstChild; c.valid; c = store[c].nextSibling)
        if (hitClick(store, c, x, y))
            return true;

    if (x >= n.x && x < n.x + n.w && y >= n.y && y < n.y + n.h)
    {
        if (n.kind == NodeKind.Button && n.onClick !is null)
        {
            n.onClick();
            return true;
        }
    }
    return false;
}
