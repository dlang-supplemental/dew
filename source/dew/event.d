/// Input / focus / touch dispatch (engine-owned; OS only supplies raw pointers).
module dew.event;

import dew.node;
import dew.input;
import std.math : sqrt;

public import dew.input;

enum size_t maxActivePointers = 16;

/// One captured contact / mouse button tracked across Move / Up / Cancel.
struct ActivePointer
{
    uint id;
    NodeId target;
    float startX, startY;
    float lastX, lastY;
    bool dragging;
    bool primary;
    PointerKind kind;
    bool occupied;
}

/**
 * Routes pointer samples with capture, multi-touch move, and drag-vs-tap.
 *
 * Down hits the deepest interactive node and captures that `id`. Move/Up/Cancel
 * deliver to the capture target (even if the contact leaves its bounds).
 * Buttons with Tap fire `onClick` on Up when the contact stayed within slop and
 * never entered a drag. Drag capability (or any Move past slop) sets `dragging`.
 */
struct PointerRouter
{
    ActivePointer[maxActivePointers] slots;
    /// Keyboard focus target (Tab cycle); `NodeId` invalid = none.
    NodeId focused;
    KeyHandler onKey;

    void clear() @safe @nogc nothrow
    {
        foreach (ref s; slots)
            s = ActivePointer.init;
        focused = NodeId.init;
    }

    bool dispatch(ref NodeStore store, NodeId root, PointerEvent ev) @safe
    {
        if (!root.valid)
            return false;

        final switch (ev.phase)
        {
        case PointerPhase.Down:
            return onDown(store, root, ev);
        case PointerPhase.Move:
            return onMove(store, ev);
        case PointerPhase.Up:
            return onUp(store, ev);
        case PointerPhase.Cancel:
            return onCancel(store, ev);
        }
    }

    /// Tab / Shift+Tab focus cycle; Enter activates focused Button.
    bool dispatchKey(ref NodeStore store, NodeId root, KeyEvent ev) @safe
    {
        if (onKey !is null)
            onKey(ev);
        if (!root.valid || ev.phase != KeyPhase.Down)
            return false;

        if (ev.key == "Tab")
        {
            focused = nextFocusable(store, root, focused, !ev.shift);
            return focused.valid;
        }
        if (ev.key == "Enter" || ev.key == " ")
        {
            if (!focused.valid)
                return false;
            ref Node n = store[focused];
            if (n.kind == NodeKind.Button && n.onClick !is null)
            {
                n.onClick();
                return true;
            }
            if (n.onKey !is null)
            {
                n.onKey(ev);
                return true;
            }
        }
        if (focused.valid && store[focused].onKey !is null)
        {
            store[focused].onKey(ev);
            return true;
        }
        return false;
    }

private:
    bool onDown(ref NodeStore store, NodeId root, PointerEvent ev) @safe
    {
        // Non-primary contacts require MultiTouch on the hit target (or none).
        auto hit = hitInteractive(store, root, ev.x, ev.y, ev);
        if (!hit.valid)
            return false;

        ref Node n = store[hit];
        if (!ev.primary && (n.touchCaps & TouchCapability.MultiTouch) == 0
            && n.touchCaps != TouchCapability.None)
            return false;

        if (!capture(ev, hit))
            return false;

        if (n.focusable || n.kind == NodeKind.Button || n.kind == NodeKind.TextField
            || n.kind == NodeKind.CheckBox)
            focused = hit;

        deliverPointer(store, hit, ev);
        return true;
    }

    bool onMove(ref NodeStore store, PointerEvent ev) @safe
    {
        auto idx = findSlot(ev.id);
        if (idx < 0)
            return false;
        ref ActivePointer ap = slots[idx];
        ap.lastX = ev.x;
        ap.lastY = ev.y;

        ref Node n = store[ap.target];
        const dx = ev.x - ap.startX;
        const dy = ev.y - ap.startY;
        const dist = sqrt(dx * dx + dy * dy);
        if (!ap.dragging && dist >= defaultTouchSlop)
        {
            const wantsDrag = (n.touchCaps & TouchCapability.Drag) != 0
                || n.onPointer !is null;
            if (wantsDrag)
                ap.dragging = true;
        }

        deliverPointer(store, ap.target, ev);
        return true;
    }

    bool onUp(ref NodeStore store, PointerEvent ev) @safe
    {
        auto idx = findSlot(ev.id);
        if (idx < 0)
            return false;
        ref ActivePointer ap = slots[idx];
        const target = ap.target;
        const wasDragging = ap.dragging;
        const startX = ap.startX;
        const startY = ap.startY;
        releaseSlot(idx);

        deliverPointer(store, target, ev);

        ref Node n = store[target];
        const dx = ev.x - startX;
        const dy = ev.y - startY;
        const withinSlop = sqrt(dx * dx + dy * dy) < defaultTouchSlop;
        const wantsTap = (n.touchCaps == TouchCapability.None)
            || (n.touchCaps & TouchCapability.Tap) != 0;

        if (!wasDragging && withinSlop && wantsTap)
        {
            if (n.kind == NodeKind.Button && n.onClick !is null)
            {
                n.onClick();
                return true;
            }
            if (n.kind == NodeKind.CheckBox && n.onClick !is null)
            {
                n.onClick();
                return true;
            }
        }
        return true;
    }

    bool onCancel(ref NodeStore store, PointerEvent ev) @safe
    {
        auto idx = findSlot(ev.id);
        if (idx < 0)
            return false;
        const target = slots[idx].target;
        releaseSlot(idx);
        deliverPointer(store, target, ev);
        return true;
    }

    bool capture(PointerEvent ev, NodeId target) @safe @nogc nothrow
    {
        auto existing = findSlot(ev.id);
        if (existing >= 0)
        {
            slots[existing].target = target;
            slots[existing].startX = ev.x;
            slots[existing].startY = ev.y;
            slots[existing].lastX = ev.x;
            slots[existing].lastY = ev.y;
            slots[existing].dragging = false;
            slots[existing].primary = ev.primary;
            slots[existing].kind = ev.kind;
            return true;
        }
        foreach (ref s; slots)
        {
            if (!s.occupied)
            {
                s.occupied = true;
                s.id = ev.id;
                s.target = target;
                s.startX = ev.x;
                s.startY = ev.y;
                s.lastX = ev.x;
                s.lastY = ev.y;
                s.dragging = false;
                s.primary = ev.primary;
                s.kind = ev.kind;
                return true;
            }
        }
        return false;
    }

    int findSlot(uint id) @safe @nogc pure nothrow
    {
        foreach (i, ref s; slots)
            if (s.occupied && s.id == id)
                return cast(int) i;
        return -1;
    }

    void releaseSlot(int idx) @safe @nogc nothrow
    {
        if (idx >= 0 && idx < cast(int) slots.length)
            slots[idx] = ActivePointer.init;
    }
}

private void deliverPointer(ref NodeStore store, NodeId id, PointerEvent ev) @safe
{
    if (!id.valid)
        return;
    ref Node n = store[id];
    if (n.onPointer !is null)
        n.onPointer(ev);
}

/// Depth-first hit of the deepest node that wants pointer / click input.
NodeId hitInteractive(ref NodeStore store, NodeId id, float x, float y, PointerEvent ev) @safe
{
    ref Node n = store[id];
    for (auto c = n.firstChild; c.valid; c = store[c].nextSibling)
    {
        auto hit = hitInteractive(store, c, x, y, ev);
        if (hit.valid)
            return hit;
    }

    float slop = 0;
    const touchLike = ev.kind == PointerKind.Touch || ev.kind == PointerKind.Pen;
    if (touchLike && (n.touchCaps & TouchCapability.TouchTarget) != 0)
        slop = defaultTouchSlop;

    if (x < n.x - slop || x >= n.x + n.w + slop || y < n.y - slop || y >= n.y + n.h + slop)
        return NodeId.init;

    const interactive = n.onPointer !is null
        || n.onClick !is null
        || n.kind == NodeKind.Button
        || n.kind == NodeKind.TextField
        || n.kind == NodeKind.CheckBox
        || n.focusable;
    return interactive ? id : NodeId.init;
}

/// Legacy entry: uses a temporary router (no capture across calls). Prefer `App.pointer`.
bool dispatchPointer(ref NodeStore store, NodeId root, PointerEvent ev) @safe
{
    PointerRouter router;
    return router.dispatch(store, root, ev);
}

NodeId nextFocusable(ref NodeStore store, NodeId root, NodeId current, bool forward) @safe
{
    NodeId[128] order;
    size_t count;
    collectFocusable(store, root, order, count);
    if (!count)
        return NodeId.init;

    if (!current.valid)
        return forward ? order[0] : order[count - 1];

    sizediff_t idx = -1;
    foreach (i; 0 .. count)
        if (order[i].index == current.index)
        {
            idx = cast(sizediff_t) i;
            break;
        }
    if (idx < 0)
        return forward ? order[0] : order[count - 1];

    if (forward)
        return order[(idx + 1) % count];
    return order[(idx - 1 + count) % count];
}

private void collectFocusable(ref NodeStore store, NodeId id, ref NodeId[128] outBuf, ref size_t count) @safe
{
    if (!id.valid || count >= outBuf.length)
        return;
    ref Node n = store[id];
    if (n.focusable || n.kind == NodeKind.Button || n.kind == NodeKind.TextField
        || n.kind == NodeKind.CheckBox)
        outBuf[count++] = id;
    for (auto c = n.firstChild; c.valid; c = store[c].nextSibling)
        collectFocusable(store, c, outBuf, count);
}

unittest
{
    import dew.dsl;
    import dew.layout : layoutTree;

    UiBuilder b;
    beginUi(b);
    scope (exit)
        endUi();

    int clicks;
    int moves;
    auto root = VStack(
        Button("Go").touchFriendly().onClick(() { clicks++; }),
        Button("Drag").touchCaps(TouchCapability.Drag | TouchCapability.Tap)
            .onPointer((PointerEvent ev) {
                if (ev.phase == PointerPhase.Move)
                    moves++;
            })
    ).spacing(8).padding(4).width(200).height(120);

    layoutTree(b.store, root.id, 200, 120);
    PointerRouter router;

    // Tap → click on Up
    float bx, by, bw, bh;
    bool found;
    foreach (ref n; b.store.nodes)
        if (n.kind == NodeKind.Button && n.text == "Go")
        {
            bx = n.x;
            by = n.y;
            bw = n.w;
            bh = n.h;
            found = true;
            break;
        }
    assert(found);
    assert(router.dispatch(b.store, root.id, touchDown(bx + bw / 2, by + bh / 2)));
    assert(clicks == 0); // click deferred to Up
    assert(router.dispatch(b.store, root.id, touchUp(bx + bw / 2, by + bh / 2)));
    assert(clicks == 1);

    // Drag: move past slop, no click
    found = false;
    foreach (ref n; b.store.nodes)
        if (n.kind == NodeKind.Button && n.text == "Drag")
        {
            bx = n.x;
            by = n.y;
            bw = n.w;
            bh = n.h;
            found = true;
            break;
        }
    assert(found);
    const cx = bx + bw / 2;
    const cy = by + bh / 2;
    assert(router.dispatch(b.store, root.id, touchDown(cx, cy, 2)));
    assert(router.dispatch(b.store, root.id, touchMove(cx + 20, cy + 20, 2)));
    assert(moves >= 1);
    assert(router.dispatch(b.store, root.id, touchUp(cx + 20, cy + 20, 2)));
    // Drag button has no onClick — clicks unchanged
    assert(clicks == 1);
}
