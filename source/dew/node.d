/// Retained scene-graph node POD types.
module dew.node;

import dew.units;
import dew.input;

public import dew.input : ClickHandler, PointerHandler, TouchCapability, PointerEvent;

enum NodeKind : ubyte
{
    VStack,
    HStack,
    Container,
    Text,
    Button,
    Spacer,
    Custom,
}

/// Opaque handle into a `NodeStore`.
struct NodeId
{
    uint index = uint.max;

    bool valid() const @safe @nogc pure nothrow
    {
        return index != uint.max;
    }
}

/// Flat node record — no virtuals, contiguous storage.
struct Node
{
    NodeKind kind;
    NodeId parent;
    NodeId firstChild;
    NodeId nextSibling;

    Length width = Length.auto_();
    Length height = Length.auto_();
    float spacing = 0;
    float padding = 0;
    float flexGrow = 0;
    float fontSize = 14;
    bool bold;
    AlignItems alignItems = AlignItems.Start;
    JustifyContent justifyContent = JustifyContent.Start;

    /// Interned / owned text slice (may point into arena).
    const(char)[] text;
    ClickHandler onClick;
    PointerHandler onPointer;
    /// Touch / pointer capability mask (see `TouchCapability`).
    uint touchCaps;

    /// Layout output (computed).
    float x, y, w, h;
    bool dirty = true;
}

/// Growable node array with sibling-list helpers.
struct NodeStore
{
    Node[] nodes;

    NodeId alloc(Node n) @safe nothrow
    {
        nodes ~= n;
        return NodeId(cast(uint)(nodes.length - 1));
    }

    ref Node opIndex(NodeId id) @safe @nogc pure nothrow
    {
        assert(id.valid);
        return nodes[id.index];
    }

    void appendChild(NodeId parent, NodeId child) @safe @nogc nothrow
    {
        assert(parent.valid && child.valid);
        nodes[child.index].parent = parent;
        if (!nodes[parent.index].firstChild.valid)
        {
            nodes[parent.index].firstChild = child;
            return;
        }
        auto cur = nodes[parent.index].firstChild;
        while (nodes[cur.index].nextSibling.valid)
            cur = nodes[cur.index].nextSibling;
        nodes[cur.index].nextSibling = child;
    }

    size_t length() const @safe @nogc pure nothrow
    {
        return nodes.length;
    }

    void clear() @safe nothrow
    {
        nodes.length = 0;
    }
}
