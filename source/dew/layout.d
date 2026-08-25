/// Single-pass flexbox / box-constraint layout over contiguous nodes.
module dew.layout;

import dew.node;
import dew.units;
import std.algorithm : max;
import std.math : isNaN;

/// Layout `root` into the given viewport.
void layoutTree(ref NodeStore store, NodeId root, float viewportW, float viewportH) @safe
{
    if (!root.valid)
        return;
    layoutNode(store, root, 0, 0, viewportW, viewportH);
}

private void layoutNode(ref NodeStore store, NodeId id, float x, float y, float availW, float availH) @safe
{
    ref Node n = store[id];
    float w = n.width.resolve(availW);
    float h = n.height.resolve(availH);

    if (isNaN(w))
        w = availW;
    if (isNaN(h))
        h = measureIntrinsicHeight(store, id, w);

    n.x = x;
    n.y = y;
    n.w = w;
    n.h = h;
    n.dirty = false;

    if (n.kind == NodeKind.VStack || n.kind == NodeKind.HStack || n.kind == NodeKind.Container)
        layoutChildren(store, id);
}

private float measureIntrinsicHeight(ref NodeStore store, NodeId id, float width) @safe
{
    ref Node n = store[id];
    final switch (n.kind)
    {
    case NodeKind.Text:
    case NodeKind.Button:
        return n.fontSize * (n.bold ? 1.4f : 1.25f) + n.padding * 2;
    case NodeKind.Spacer:
        return 0;
    case NodeKind.Custom:
        return n.fontSize + n.padding * 2;
    case NodeKind.VStack:
    case NodeKind.HStack:
    case NodeKind.Container:
        // provisional — refined in layoutChildren
        return n.padding * 2;
    }
}

private void layoutChildren(ref NodeStore store, NodeId parent) @safe
{
    ref Node p = store[parent];
    const axis = p.kind == NodeKind.HStack ? Axis.Horizontal : Axis.Vertical;
    const innerX = p.x + p.padding;
    const innerY = p.y + p.padding;
    const innerW = max(0.0f, p.w - p.padding * 2);
    const innerH = max(0.0f, p.h - p.padding * 2);

    // Collect children
    NodeId[64] buf;
    size_t count;
    for (auto c = p.firstChild; c.valid && count < buf.length; c = store[c].nextSibling)
        buf[count++] = c;
    if (!count)
        return;

    float totalFixed = 0;
    float totalGrow = 0;
    float[64] base;
    foreach (i; 0 .. count)
    {
        ref Node ch = store[buf[i]];
        float main = axis == Axis.Horizontal
            ? ch.width.resolve(innerW)
            : ch.height.resolve(innerH);
        if (isNaN(main))
        {
            if (ch.kind == NodeKind.Text || ch.kind == NodeKind.Button)
                main = estimateTextWidth(ch) + ch.padding * 2;
            else if (ch.kind == NodeKind.Spacer)
                main = 0;
            else
                main = 0;
        }
        base[i] = main;
        totalFixed += main;
        totalGrow += ch.flexGrow;
    }

    const gaps = count > 1 ? p.spacing * (count - 1) : 0;
    const mainSize = axis == Axis.Horizontal ? innerW : innerH;
    float free = mainSize - totalFixed - gaps;
    if (free < 0)
        free = 0;

    float cursor = 0;
    foreach (i; 0 .. count)
    {
        ref Node ch = store[buf[i]];
        float main = base[i];
        if (totalGrow > 0 && ch.flexGrow > 0)
            main += free * (ch.flexGrow / totalGrow);

        float crossAvail = axis == Axis.Horizontal ? innerH : innerW;
        float cross = axis == Axis.Horizontal
            ? ch.height.resolve(innerH)
            : ch.width.resolve(innerW);
        if (isNaN(cross))
            cross = (ch.kind == NodeKind.Text || ch.kind == NodeKind.Button)
                ? ch.fontSize * 1.25f + ch.padding * 2
                : crossAvail;

        float cx, cy, cw, chh;
        if (axis == Axis.Horizontal)
        {
            cx = innerX + cursor;
            cy = alignCross(innerY, innerH, cross, p.alignItems);
            cw = main;
            chh = (p.alignItems == AlignItems.Stretch && isNaN(ch.height.resolve(innerH)))
                ? innerH : cross;
        }
        else
        {
            cx = alignCross(innerX, innerW, cross, p.alignItems);
            cy = innerY + cursor;
            cw = (p.alignItems == AlignItems.Stretch && isNaN(ch.width.resolve(innerW)))
                ? innerW : cross;
            chh = main;
        }

        // Recurse with assigned box
        ch.width = Length.px(cw);
        ch.height = Length.px(chh);
        layoutNode(store, buf[i], cx, cy, cw, chh);

        cursor += main + p.spacing;
    }

    // Grow parent height for VStack if it was auto
    if (axis == Axis.Vertical && p.height.kind == Length.Kind.Auto)
    {
        p.h = cursor - (count ? p.spacing : 0) + p.padding * 2;
    }
}

private float alignCross(float origin, float avail, float size, AlignItems a) @safe @nogc pure nothrow
{
    final switch (a)
    {
    case AlignItems.Start:
    case AlignItems.Stretch:
        return origin;
    case AlignItems.Center:
        return origin + (avail - size) * 0.5f;
    case AlignItems.End:
        return origin + avail - size;
    }
}

private float estimateTextWidth(ref Node n) @safe @nogc pure nothrow
{
    // Approximate monospace-ish advance
    return n.text.length * n.fontSize * 0.55f;
}
