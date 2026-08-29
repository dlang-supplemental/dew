/// Single-pass flexbox / box-constraint layout over contiguous nodes.
module dew.layout;

import dew.node;
import dew.units;
import std.algorithm : max, min;
import std.math : isNaN;

/// Optional host-provided text measure. Returns advance width in px.
alias TextMeasureFn = float function(const(char)[] text, float fontSize, bool bold) @safe @nogc nothrow;

/// Default heuristic measure (monospace-ish). Replace via `setTextMeasure`.
TextMeasureFn textMeasure = &defaultTextMeasure;

void setTextMeasure(TextMeasureFn fn) @safe @nogc nothrow
{
    textMeasure = fn is null ? &defaultTextMeasure : fn;
}

float defaultTextMeasure(const(char)[] text, float fontSize, bool bold) @safe @nogc pure nothrow
{
    const factor = bold ? 0.62f : 0.55f;
    return text.length * fontSize * factor;
}

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

    if (n.kind == NodeKind.VStack || n.kind == NodeKind.HStack
        || n.kind == NodeKind.Container || n.kind == NodeKind.ScrollView
        || n.kind == NodeKind.Canvas)
        layoutChildren(store, id);
}

private float measureIntrinsicHeight(ref NodeStore store, NodeId id, float width) @safe
{
    ref Node n = store[id];
    final switch (n.kind)
    {
    case NodeKind.Text:
    case NodeKind.Button:
    case NodeKind.CheckBox:
        return n.fontSize * (n.bold ? 1.4f : 1.25f) + n.padding * 2;
    case NodeKind.TextField:
        if (n.multiline)
        {
            size_t lines = 1;
            foreach (ch; n.text)
                if (ch == '\n')
                    lines++;
            if (!n.text.length)
                lines = 3;
            return lines * n.fontSize * 1.35f + n.padding * 2;
        }
        return n.fontSize * (n.bold ? 1.4f : 1.25f) + n.padding * 2;
    case NodeKind.Spacer:
        return 0;
    case NodeKind.MeshView:
        return 120;
    case NodeKind.Canvas:
        return 240;
    case NodeKind.Custom:
        return n.fontSize + n.padding * 2;
    case NodeKind.VStack:
    case NodeKind.HStack:
    case NodeKind.Container:
    case NodeKind.ScrollView:
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
    NodeId[128] buf;
    size_t count;
    for (auto c = p.firstChild; c.valid && count < buf.length; c = store[c].nextSibling)
        buf[count++] = c;
    if (!count)
        return;

    if (p.flexWrap == FlexWrap.Wrap && axis == Axis.Horizontal)
    {
        layoutWrappedRow(store, parent, buf[0 .. count], innerX, innerY, innerW, innerH);
        return;
    }

    float totalFixed = 0;
    float totalGrow = 0;
    float[128] base;
    foreach (i; 0 .. count)
    {
        ref Node ch = store[buf[i]];
        float main = axis == Axis.Horizontal
            ? ch.width.resolve(innerW)
            : ch.height.resolve(innerH);
        if (isNaN(main))
            main = measureMainAuto(ch, axis);
        base[i] = main;
        totalFixed += main;
        totalGrow += ch.flexGrow;
    }

    const gaps = count > 1 ? p.spacing * (count - 1) : 0;
    const mainSize = axis == Axis.Horizontal ? innerW : innerH;
    float free = mainSize - totalFixed - gaps;
    if (free < 0)
        free = 0;

    // Grow vs justify: flexGrow consumes free space first; else justify distributes it.
    float cursor = justifyStartOffset(p.justifyContent, free, count, totalGrow > 0);
    float gapExtra = 0;
    if (totalGrow <= 0 && count > 1)
    {
        if (p.justifyContent == JustifyContent.SpaceBetween)
            gapExtra = free / (count - 1);
        else if (p.justifyContent == JustifyContent.SpaceAround)
            gapExtra = free / count;
    }

    float contentMain = 0;
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
            cross = (ch.kind == NodeKind.Text || ch.kind == NodeKind.Button
                || ch.kind == NodeKind.TextField || ch.kind == NodeKind.CheckBox)
                ? ch.fontSize * 1.25f + ch.padding * 2
                : crossAvail;

        float cx, cy, cw, chh;
        const scrollOffX = p.kind == NodeKind.ScrollView ? -p.scrollX : 0;
        const scrollOffY = p.kind == NodeKind.ScrollView ? -p.scrollY : 0;
        if (axis == Axis.Horizontal)
        {
            cx = innerX + cursor + scrollOffX;
            cy = alignCross(innerY, innerH, cross, p.alignItems) + scrollOffY;
            cw = main;
            chh = (p.alignItems == AlignItems.Stretch && isNaN(ch.height.resolve(innerH)))
                ? innerH : cross;
        }
        else
        {
            cx = alignCross(innerX, innerW, cross, p.alignItems) + scrollOffX;
            cy = innerY + cursor + scrollOffY;
            cw = (p.alignItems == AlignItems.Stretch && isNaN(ch.width.resolve(innerW)))
                ? innerW : cross;
            chh = main;
        }

        ch.width = Length.px(cw);
        ch.height = Length.px(chh);
        layoutNode(store, buf[i], cx, cy, cw, chh);

        const step = main + p.spacing + gapExtra;
        cursor += step;
        contentMain += main + (i + 1 < count ? p.spacing : 0);
    }

    // Grow parent height for VStack if it was auto
    if (axis == Axis.Vertical && p.height.kind == Length.Kind.Auto)
    {
        p.h = contentMain + p.padding * 2;
    }
}

private void layoutWrappedRow(ref NodeStore store, NodeId parent, NodeId[] kids,
    float innerX, float innerY, float innerW, float innerH) @safe
{
    ref Node p = store[parent];
    float x = 0;
    float y = 0;
    float rowH = 0;
    float contentH = 0;
    foreach (kid; kids)
    {
        ref Node ch = store[kid];
        float main = ch.width.resolve(innerW);
        if (isNaN(main))
            main = measureMainAuto(ch, Axis.Horizontal);
        float cross = ch.height.resolve(innerH);
        if (isNaN(cross))
            cross = ch.fontSize * 1.25f + ch.padding * 2;

        if (x > 0 && x + main > innerW)
        {
            y += rowH + p.spacing;
            contentH = y;
            x = 0;
            rowH = 0;
        }
        const cx = innerX + x - p.scrollX;
        const cy = innerY + y - p.scrollY;
        ch.width = Length.px(main);
        ch.height = Length.px(cross);
        layoutNode(store, kid, cx, cy, main, cross);
        x += main + p.spacing;
        rowH = max(rowH, cross);
        contentH = max(contentH, y + rowH);
    }
    if (p.height.kind == Length.Kind.Auto)
        p.h = contentH + p.padding * 2;
}

private float measureMainAuto(ref Node ch, Axis axis) @safe @nogc nothrow
{
    if (ch.kind == NodeKind.Text || ch.kind == NodeKind.Button
        || ch.kind == NodeKind.TextField || ch.kind == NodeKind.CheckBox)
    {
        if (axis == Axis.Horizontal)
        {
            auto label = ch.text.length ? ch.text : ch.placeholder;
            if (ch.kind == NodeKind.CheckBox)
                return textMeasure(label, ch.fontSize, ch.bold) + ch.padding * 2 + ch.fontSize + 8;
            return textMeasure(label, ch.fontSize, ch.bold) + ch.padding * 2
                + (ch.kind == NodeKind.Button || ch.kind == NodeKind.TextField ? 16 : 0);
        }
        if (ch.kind == NodeKind.TextField && ch.multiline)
        {
            size_t lines = 1;
            foreach (c; ch.text)
                if (c == '\n')
                    lines++;
            if (!ch.text.length)
                lines = 3;
            return lines * ch.fontSize * 1.35f + ch.padding * 2;
        }
        return ch.fontSize * (ch.bold ? 1.4f : 1.25f) + ch.padding * 2;
    }
    if (ch.kind == NodeKind.Spacer)
        return 0;
    if (ch.kind == NodeKind.MeshView)
        return axis == Axis.Horizontal ? 160 : 120;
    if (ch.kind == NodeKind.Canvas)
        return axis == Axis.Horizontal ? 320 : 240;
    return 0;
}

private float justifyStartOffset(JustifyContent j, float free, size_t count, bool growing) @safe @nogc pure nothrow
{
    if (growing || free <= 0 || count == 0)
        return 0;
    final switch (j)
    {
    case JustifyContent.Start:
    case JustifyContent.SpaceBetween:
        return 0;
    case JustifyContent.Center:
        return free * 0.5f;
    case JustifyContent.End:
        return free;
    case JustifyContent.SpaceAround:
        return count ? free / (count * 2) : 0;
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

unittest
{
    NodeStore store;
    Node rootN;
    rootN.kind = NodeKind.VStack;
    rootN.padding = 10;
    rootN.spacing = 4;
    auto root = store.alloc(rootN);
    Node t;
    t.kind = NodeKind.Text;
    t.text = "Hi";
    t.fontSize = 20;
    store.appendChild(root, store.alloc(t));
    Node b;
    b.kind = NodeKind.Button;
    b.text = "Go";
    b.fontSize = 14;
    auto bid = store.alloc(b);
    store.appendChild(root, bid);

    layoutTree(store, root, 200, 200);
    assert(store[bid].h > 10 && store[bid].h < 40);
    assert(store[bid].y > store[root].y);
}

unittest
{
    // JustifyContent.Center on HStack
    NodeStore store;
    Node row;
    row.kind = NodeKind.HStack;
    row.width = Length.px(200);
    row.height = Length.px(40);
    row.justifyContent = JustifyContent.Center;
    row.spacing = 0;
    auto root = store.alloc(row);
    Node a;
    a.kind = NodeKind.Button;
    a.text = "A";
    a.fontSize = 14;
    a.width = Length.px(40);
    a.height = Length.px(20);
    auto aid = store.alloc(a);
    store.appendChild(root, aid);
    layoutTree(store, root, 200, 40);
    // Centered 40px button in 200 → x ≈ 80
    assert(store[aid].x > 70 && store[aid].x < 90);
}
