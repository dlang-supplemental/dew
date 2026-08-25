/**
 * Pure D typed DSL — canonical UI construction API.
 *
 * Markup CTFE and foreign adapters lower into these builders.
 */
module dew.dsl;

import dew.node;
import dew.units;
import dew.input;
import dew.arena;

/// Builder wrapping a `NodeId` with method chaining.
struct Widget
{
    NodeId id;
    NodeStore* store;

    private ref Node n() @safe @nogc
    {
        return (*store)[id];
    }

    Widget spacing(float v) @safe @nogc
    {
        n.spacing = v;
        return this;
    }

    Widget padding(float v) @safe @nogc
    {
        n.padding = v;
        return this;
    }

    Widget width(Length l) @safe @nogc
    {
        n.width = l;
        return this;
    }

    Widget width(float px) @safe @nogc
    {
        n.width = Length.px(px);
        return this;
    }

    Widget height(Length l) @safe @nogc
    {
        n.height = l;
        return this;
    }

    Widget height(float px) @safe @nogc
    {
        n.height = Length.px(px);
        return this;
    }

    Widget flexGrow(float g) @safe @nogc
    {
        n.flexGrow = g;
        return this;
    }

    Widget alignItems(AlignItems a) @safe @nogc
    {
        n.alignItems = a;
        return this;
    }

    Widget justifyContent(JustifyContent j) @safe @nogc
    {
        n.justifyContent = j;
        return this;
    }

    Widget flexWrap(FlexWrap w) @safe @nogc
    {
        n.flexWrap = w;
        return this;
    }

    Widget fontSize(float s) @safe @nogc
    {
        n.fontSize = s;
        return this;
    }

    Widget bold(bool b = true) @safe @nogc
    {
        n.bold = b;
        return this;
    }

    Widget onClick(ClickHandler h) @safe @nogc
    {
        n.onClick = h;
        return this;
    }

    Widget onPointer(PointerHandler h) @safe @nogc
    {
        n.onPointer = h;
        return this;
    }

    Widget onKey(KeyHandler h) @safe @nogc
    {
        n.onKey = h;
        return this;
    }

    Widget touchCaps(uint caps) @safe @nogc
    {
        n.touchCaps = caps;
        return this;
    }

    /// Enable tap + enlarged touch target (common for buttons).
    Widget touchFriendly(bool enable = true) @safe @nogc
    {
        if (enable)
            n.touchCaps |= TouchCapability.Tap | TouchCapability.TouchTarget;
        else
            n.touchCaps = TouchCapability.None;
        return this;
    }

    /// Enable drag tracking (Move past slop marks the capture as dragging).
    Widget draggable(bool enable = true) @safe @nogc
    {
        if (enable)
            n.touchCaps |= TouchCapability.Drag | TouchCapability.Tap;
        else
            n.touchCaps &= ~TouchCapability.Drag;
        return this;
    }

    Widget focusable(bool enable = true) @safe @nogc
    {
        n.focusable = enable;
        return this;
    }

    Widget placeholder(const(char)[] p) @safe @nogc
    {
        n.placeholder = p;
        return this;
    }

    Widget checked(bool v) @safe @nogc
    {
        n.checked = v;
        return this;
    }

    Widget password(bool v = true) @safe @nogc
    {
        n.password = v;
        return this;
    }

    Widget scrollOffset(float sx, float sy) @safe @nogc
    {
        n.scrollX = sx;
        n.scrollY = sy;
        return this;
    }

    Widget clipContent(bool enable = true) @safe @nogc
    {
        n.clipContent = enable;
        return this;
    }

    Widget child(Widget c) @safe
    {
        store.appendChild(id, c.id);
        return this;
    }

    Widget children(Widget[] kids) @safe
    {
        foreach (c; kids)
            store.appendChild(id, c.id);
        return this;
    }
}

/// Context that owns the node store while building a tree.
struct UiBuilder
{
    NodeStore store;
    /// Optional frame arena for text slices (`@nogc`-friendly rebuilds).
    Arena* arena;

    /// Reset arena between rebuilds when set.
    void beginFrame() @safe nothrow
    {
        if (arena !is null)
            arena.reset();
        store.clear();
    }

    private const(char)[] intern(const(char)[] s) return @trusted nothrow
    {
        if (arena is null || !s.length)
            return s;
        return arena.dupString(s);
    }

    Widget make(NodeKind kind, const(char)[] text = null) return @safe nothrow
    {
        Node n;
        n.kind = kind;
        n.text = intern(text);
        if (kind == NodeKind.ScrollView)
            n.clipContent = true;
        auto id = store.alloc(n);
        return Widget(id, &store);
    }

    Widget meshView(const(ubyte)[] rgba, uint srcW, uint srcH) return @safe nothrow
    {
        auto w = make(NodeKind.MeshView);
        (*w.store)[w.id].meshPixels = rgba;
        (*w.store)[w.id].meshSrcW = srcW;
        (*w.store)[w.id].meshSrcH = srcH;
        return w;
    }

    Widget vstack(Widget[] kids...) return @safe
    {
        auto w = make(NodeKind.VStack);
        foreach (c; kids)
            store.appendChild(w.id, c.id);
        return w;
    }

    Widget hstack(Widget[] kids...) return @safe
    {
        auto w = make(NodeKind.HStack);
        foreach (c; kids)
            store.appendChild(w.id, c.id);
        return w;
    }

    Widget container(Widget[] kids...) return @safe
    {
        auto w = make(NodeKind.Container);
        foreach (c; kids)
            store.appendChild(w.id, c.id);
        return w;
    }

    Widget scrollView(Widget[] kids...) return @safe
    {
        auto w = make(NodeKind.ScrollView);
        foreach (c; kids)
            store.appendChild(w.id, c.id);
        return w;
    }

    Widget text(const(char)[] s) return @safe nothrow
    {
        return make(NodeKind.Text, s);
    }

    Widget button(const(char)[] label) return @safe nothrow
    {
        return make(NodeKind.Button, label);
    }

    Widget textField(const(char)[] value = null) return @safe
    {
        auto w = make(NodeKind.TextField, value);
        w.focusable(true);
        return w;
    }

    Widget checkBox(const(char)[] label, bool isChecked = false) return @safe
    {
        auto w = make(NodeKind.CheckBox, label);
        w.checked(isChecked).focusable(true).touchFriendly();
        return w;
    }

    Widget spacer(float grow = 1) return @safe
    {
        auto w = make(NodeKind.Spacer);
        w.flexGrow(grow);
        return w;
    }
}

// --- Free-function style used by CTFE lowering / hand-written UI ---

private UiBuilder* tlsBuilder;

/// Begin a build session (sets TLS builder used by free functions).
void beginUi(ref UiBuilder b) @trusted
{
    tlsBuilder = &b;
}

/// End build session.
void endUi() @trusted
{
    tlsBuilder = null;
}

private ref UiBuilder ui() @trusted
{
    assert(tlsBuilder !is null, "call beginUi before DSL free functions");
    return *tlsBuilder;
}

Widget VStack(Widget[] kids...) @safe
{
    return ui.vstack(kids);
}

Widget HStack(Widget[] kids...) @safe
{
    return ui.hstack(kids);
}

Widget Container(Widget[] kids...) @safe
{
    return ui.container(kids);
}

Widget ScrollView(Widget[] kids...) @safe
{
    return ui.scrollView(kids);
}

Widget Text(const(char)[] s) @safe
{
    return ui.text(s);
}

Widget Button(const(char)[] label) @safe
{
    return ui.button(label);
}

Widget TextField(const(char)[] value = null) @safe
{
    return ui.textField(value);
}

Widget CheckBox(const(char)[] label, bool isChecked = false) @safe
{
    return ui.checkBox(label, isChecked);
}

Widget MeshView(const(ubyte)[] rgba, uint srcW, uint srcH) @safe
{
    return ui.meshView(rgba, srcW, srcH);
}

Widget Spacer(float grow = 1) @safe
{
    return ui.spacer(grow);
}

/// Marker used in markup lowering: `Spacing(12)` becomes `.spacing(12)` on parent.
struct Spacing
{
    float value;
}

Widget applySpacing(Widget w, Spacing s) @safe @nogc
{
    return w.spacing(s.value);
}
