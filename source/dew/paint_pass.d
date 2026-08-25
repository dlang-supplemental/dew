/// Lower laid-out nodes into a display list.
module dew.paint_pass;

import dew.node;
import dew.display_list;

/// Emit draw commands for the subtree at `root`.
void paintTree(ref NodeStore store, NodeId root, ref DisplayList list) @safe
{
    if (!root.valid)
        return;
    paintNode(store, root, list);
}

private void paintNode(ref NodeStore store, NodeId id, ref DisplayList list) @safe
{
    ref Node n = store[id];
    const clip = n.clipContent || n.kind == NodeKind.ScrollView;
    if (clip)
        list.clipPush(n.x, n.y, n.w, n.h);

    final switch (n.kind)
    {
    case NodeKind.VStack:
    case NodeKind.HStack:
    case NodeKind.Container:
    case NodeKind.ScrollView:
    case NodeKind.Spacer:
    case NodeKind.Custom:
        break;
    case NodeKind.Text:
        list.textRun(n.x + n.padding, n.y + n.padding + n.fontSize,
            n.fontSize, n.bold, n.text, ColorRgba.rgb(30, 30, 30));
        break;
    case NodeKind.Button:
        list.fillRect(n.x, n.y, n.w, n.h, ColorRgba.rgb(45, 110, 200));
        list.strokeRect(n.x, n.y, n.w, n.h, ColorRgba.rgb(30, 80, 160));
        list.textRun(n.x + n.padding + 8, n.y + n.h * 0.5f + n.fontSize * 0.35f,
            n.fontSize, true, n.text, ColorRgba.rgb(255, 255, 255));
        break;
    case NodeKind.TextField:
        list.fillRect(n.x, n.y, n.w, n.h, ColorRgba.rgb(250, 250, 252));
        list.strokeRect(n.x, n.y, n.w, n.h, ColorRgba.rgb(120, 120, 130));
        auto shown = n.text.length ? n.text : n.placeholder;
        auto col = n.text.length ? ColorRgba.rgb(20, 20, 24) : ColorRgba.rgb(140, 140, 150);
        if (n.password && n.text.length)
        {
            // Paint a bullets bar instead of leaking glyphs.
            list.fillRect(n.x + n.padding + 6, n.y + n.h * 0.45f,
                min(n.w - n.padding * 2 - 12, n.text.length * n.fontSize * 0.4f),
                n.fontSize * 0.2f, col);
        }
        else
        {
            list.textRun(n.x + n.padding + 6, n.y + n.h * 0.5f + n.fontSize * 0.35f,
                n.fontSize, false, shown, col);
        }
        break;
    case NodeKind.CheckBox:
        const box = n.fontSize;
        list.strokeRect(n.x + n.padding, n.y + (n.h - box) * 0.5f, box, box,
            ColorRgba.rgb(60, 60, 70));
        if (n.checked)
            list.fillRect(n.x + n.padding + 3, n.y + (n.h - box) * 0.5f + 3,
                box - 6, box - 6, ColorRgba.rgb(45, 110, 200));
        list.textRun(n.x + n.padding + box + 8, n.y + n.h * 0.5f + n.fontSize * 0.35f,
            n.fontSize, false, n.text, ColorRgba.rgb(30, 30, 30));
        break;
    }

    for (auto c = n.firstChild; c.valid; c = store[c].nextSibling)
        paintNode(store, c, list);

    if (clip)
        list.clipPop();
}

private float min(float a, float b) @safe @nogc pure nothrow
{
    return a < b ? a : b;
}
