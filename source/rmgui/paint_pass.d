/// Lower laid-out nodes into a display list.
module rmgui.paint_pass;

import rmgui.node;
import rmgui.display_list;

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
    final switch (n.kind)
    {
    case NodeKind.VStack:
    case NodeKind.HStack:
    case NodeKind.Container:
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
    }

    for (auto c = n.firstChild; c.valid; c = store[c].nextSibling)
        paintNode(store, c, list);
}
