/// Input / focus / touch dispatch (engine-owned; OS only supplies raw pointers).
module dew.event;

import dew.node;
import dew.input;

public import dew.input;

/// Hit-test and dispatch click / tap handlers for the laid-out tree.
bool dispatchPointer(ref NodeStore store, NodeId root, PointerEvent ev) @safe
{
    if (!root.valid)
        return false;

    if (ev.kind == PointerKind.Mouse && ev.pressed && ev.phase == PointerPhase.Down
        && ev.button == PointerButton.Left)
        return hitClick(store, root, ev.x, ev.y, false);

    if (ev.kind == PointerKind.Touch || ev.kind == PointerKind.Pen)
    {
        if (ev.phase == PointerPhase.Down && ev.primary)
            return hitClick(store, root, ev.x, ev.y, true);
        return false;
    }

    if (ev.pressed && ev.button == PointerButton.Left)
        return hitClick(store, root, ev.x, ev.y, false);
    return false;
}

private bool hitClick(ref NodeStore store, NodeId id, float x, float y, bool touch) @safe
{
    ref Node n = store[id];
    for (auto c = n.firstChild; c.valid; c = store[c].nextSibling)
        if (hitClick(store, c, x, y, touch))
            return true;

    float slop = 0;
    if (touch && (n.touchCaps & TouchCapability.TouchTarget) != 0)
        slop = defaultTouchSlop;

    if (x >= n.x - slop && x < n.x + n.w + slop && y >= n.y - slop && y < n.y + n.h + slop)
    {
        const wantsTap = (n.touchCaps == TouchCapability.None)
            || (n.touchCaps & TouchCapability.Tap) != 0;
        if (!wantsTap)
            return false;

        if (n.kind == NodeKind.Button && n.onClick !is null)
        {
            n.onClick();
            return true;
        }
        if (n.onPointer !is null)
        {
            PointerEvent pe = touchDown(x, y);
            if (!touch)
            {
                pe.kind = PointerKind.Mouse;
                pe.button = PointerButton.Left;
                pe.id = 0;
            }
            n.onPointer(pe);
            return true;
        }
    }
    return false;
}
