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
        if (n.fillBackground)
            list.fillRect(n.x, n.y, n.w, n.h, n.bgColor);
        break;
    case NodeKind.Canvas:
        list.fillRect(n.x, n.y, n.w, n.h,
            n.fillBackground ? n.bgColor : ColorRgba.rgb(252, 250, 240));
        list.strokeRect(n.x, n.y, n.w, n.h, ColorRgba.rgb(180, 170, 140));
        if (n.showGrid)
        {
            enum float step = 24;
            for (float gx = n.x + step; gx < n.x + n.w; gx += step)
                list.fillRect(gx, n.y, 1, n.h, ColorRgba.rgba(200, 190, 160, 80));
            for (float gy = n.y + step; gy < n.y + n.h; gy += step)
                list.fillRect(n.x, gy, n.w, 1, ColorRgba.rgba(200, 190, 160, 80));
        }
        break;
    case NodeKind.MeshView:
        if (n.meshPixels.length && n.meshSrcW && n.meshSrcH)
            list.imageBlit(n.x, n.y, n.w, n.h, n.meshSrcW, n.meshSrcH, n.meshPixels);
        else
            list.fillRect(n.x, n.y, n.w, n.h, ColorRgba.rgb(20, 26, 40));
        break;
    case NodeKind.Text:
        list.textRun(n.x + n.padding, n.y + n.padding + n.fontSize,
            n.fontSize, n.bold, n.text, ColorRgba.rgb(30, 30, 30));
        break;
    case NodeKind.Button:
        list.fillRoundedRect(n.x, n.y, n.w, n.h, 6, ColorRgba.rgb(45, 110, 200));
        list.strokeRect(n.x, n.y, n.w, n.h, ColorRgba.rgb(30, 80, 160));
        list.textRun(n.x + n.padding + 8, n.y + n.h * 0.5f + n.fontSize * 0.35f,
            n.fontSize, true, n.text, ColorRgba.rgb(255, 255, 255));
        break;
    case NodeKind.TextField:
        list.fillRect(n.x, n.y, n.w, n.h,
            n.fillBackground ? n.bgColor : ColorRgba.rgb(250, 250, 252));
        list.strokeRect(n.x, n.y, n.w, n.h, ColorRgba.rgb(120, 120, 130));
        auto shown = n.text.length ? n.text : n.placeholder;
        auto col = n.text.length ? ColorRgba.rgb(20, 20, 24) : ColorRgba.rgb(140, 140, 150);
        if (n.password && n.text.length)
        {
            list.fillRect(n.x + n.padding + 6, n.y + n.h * 0.45f,
                min(n.w - n.padding * 2 - 12, n.text.length * n.fontSize * 0.4f),
                n.fontSize * 0.2f, col);
        }
        else if (n.multiline)
        {
            float ly = n.y + n.padding + n.fontSize;
            size_t start = 0;
            foreach (i, ch; shown)
            {
                if (ch == '\n' || i + 1 == shown.length)
                {
                    const end = (ch == '\n') ? i : i + 1;
                    auto line = shown[start .. end];
                    if (line.length && line[$ - 1] == '\r')
                        line = line[0 .. $ - 1];
                    list.textRun(n.x + n.padding + 6, ly, n.fontSize, n.bold, line, col);
                    ly += n.fontSize * 1.35f;
                    start = i + 1;
                }
            }
            if (!shown.length)
                list.textRun(n.x + n.padding + 6, n.y + n.padding + n.fontSize,
                    n.fontSize, false, n.placeholder, ColorRgba.rgb(140, 140, 150));
        }
        else
        {
            list.textRun(n.x + n.padding + 6, n.y + n.h * 0.5f + n.fontSize * 0.35f,
                n.fontSize, n.bold, shown, col);
        }
        break;
    case NodeKind.CheckBox:
        const box = n.fontSize;
        const bx = n.x + n.padding;
        const by = n.y + (n.h - box) * 0.5f;
        list.strokeRect(bx, by, box, box, ColorRgba.rgb(60, 60, 70));
        if (n.checked)
        {
            list.pathBegin();
            list.pathMoveTo(bx + box * 0.2f, by + box * 0.55f);
            list.pathLineTo(bx + box * 0.42f, by + box * 0.75f);
            list.pathLineTo(bx + box * 0.82f, by + box * 0.28f);
            list.pathStroke(2, ColorRgba.rgb(45, 110, 200));
        }
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
