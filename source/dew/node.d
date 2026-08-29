/// Retained scene-graph node POD types.
module dew.node;

import dew.units;
import dew.input;
import dew.display_list : ColorRgba;

public import dew.input : ClickHandler, PointerHandler, KeyHandler, TouchCapability, PointerEvent;
public import dew.display_list : ColorRgba;

enum NodeKind : ubyte
{
    VStack,
    HStack,
    Container,
    ScrollView,
    Text,
    Button,
    TextField,
    CheckBox,
    Spacer,
    /// Composited 3D/mesh embed (RGBA blit from a `Wgpu3dViewport` or custom buffer).
    MeshView,
    /// Freeform surface for ink / diagram hosts (fills `bgColor`, optional grid).
    Canvas,
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
    FlexWrap flexWrap = FlexWrap.NoWrap;

    /// Interned / owned text slice (may point into arena).
    const(char)[] text;
    /// Placeholder for TextField when `text` is empty.
    const(char)[] placeholder;
    ClickHandler onClick;
    PointerHandler onPointer;
    KeyHandler onKey;
    /// Touch / pointer capability mask (see `TouchCapability`).
    uint touchCaps;

    /// Participates in Tab focus order when true (Buttons/fields are always focusable).
    bool focusable;
    /// CheckBox checked state / TextField password flag reuse.
    bool checked;
    bool password;

    /// ScrollView content offset (positive = content shifted up/left).
    float scrollX = 0;
    float scrollY = 0;
    /// Clip children to the node's box when painting (ScrollView defaults on).
    bool clipContent;

    /// MeshView: RGBA8 buffer composited via ImageBlit (may be null / empty).
    const(ubyte)[] meshPixels;
    uint meshSrcW;
    uint meshSrcH;

    /// Optional solid fill behind the node (Canvas / sticky note surfaces).
    bool fillBackground;
    ColorRgba bgColor = ColorRgba(255, 255, 255, 255);
    /// TextField: wrap/`\n` aware editing surface.
    bool multiline;
    /// Canvas: draw a light rule grid under children.
    bool showGrid;

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
