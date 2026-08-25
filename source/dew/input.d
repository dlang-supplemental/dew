/// Normalized pointer / touch / key types shared by nodes and the dispatcher.
module dew.input;

enum PointerButton : ubyte
{
    Left = 1,
    Right = 2,
    Middle = 4,
    Contact = 8,
}

enum PointerKind : ubyte
{
    Mouse,
    Touch,
    Pen,
    Unknown,
}

enum PointerPhase : ubyte
{
    Down,
    Move,
    Up,
    Cancel,
}

/**
 * Normalized pointer sample. Hosts map WM_POINTER / SDL_FINGER / etc. into this.
 * Multi-touch: each contact keeps a stable `id` for the lifetime of the gesture.
 */
struct PointerEvent
{
    float x, y;
    PointerButton button;
    bool pressed;
    PointerKind kind = PointerKind.Mouse;
    PointerPhase phase = PointerPhase.Down;
    uint id;
    float pressure = 1;
    bool primary = true;
}

enum TouchCapability : uint
{
    None = 0,
    Tap = 1 << 0,
    Drag = 1 << 1,
    MultiTouch = 1 << 2,
    TouchTarget = 1 << 3,
}

enum float defaultTouchSlop = 8;

alias ClickHandler = void delegate() @safe;
alias PointerHandler = void delegate(PointerEvent ev) @safe;

enum KeyPhase : ubyte
{
    Down,
    Up,
    Repeat,
}

/// Minimal keyboard sample for focus traversal and form submit.
struct KeyEvent
{
    /// Logical key: `"Tab"`, `"Enter"`, `"Escape"`, `"ArrowUp"`, …
    string key;
    KeyPhase phase = KeyPhase.Down;
    bool shift;
    bool ctrl;
    bool alt;
    bool meta;
}

alias KeyHandler = void delegate(KeyEvent ev) @safe;

PointerEvent touchDown(float x, float y, uint id = 1, bool primary = true) @safe @nogc pure nothrow
{
    PointerEvent e;
    e.x = x;
    e.y = y;
    e.kind = PointerKind.Touch;
    e.phase = PointerPhase.Down;
    e.button = PointerButton.Contact;
    e.pressed = true;
    e.id = id;
    e.primary = primary;
    e.pressure = 1;
    return e;
}

PointerEvent touchMove(float x, float y, uint id = 1, bool primary = true) @safe @nogc pure nothrow
{
    auto e = touchDown(x, y, id, primary);
    e.phase = PointerPhase.Move;
    return e;
}

PointerEvent touchUp(float x, float y, uint id = 1, bool primary = true) @safe @nogc pure nothrow
{
    auto e = touchDown(x, y, id, primary);
    e.phase = PointerPhase.Up;
    e.pressed = false;
    return e;
}

PointerEvent touchCancel(float x, float y, uint id = 1, bool primary = true) @safe @nogc pure nothrow
{
    auto e = touchDown(x, y, id, primary);
    e.phase = PointerPhase.Cancel;
    e.pressed = false;
    return e;
}

PointerEvent mouseDown(float x, float y, PointerButton button = PointerButton.Left) @safe @nogc pure nothrow
{
    PointerEvent e;
    e.x = x;
    e.y = y;
    e.kind = PointerKind.Mouse;
    e.phase = PointerPhase.Down;
    e.button = button;
    e.pressed = true;
    e.id = 0;
    e.primary = true;
    return e;
}

PointerEvent mouseMove(float x, float y, bool pressed = false,
    PointerButton button = PointerButton.Left) @safe @nogc pure nothrow
{
    auto e = mouseDown(x, y, button);
    e.phase = PointerPhase.Move;
    e.pressed = pressed;
    return e;
}

PointerEvent mouseUp(float x, float y, PointerButton button = PointerButton.Left) @safe @nogc pure nothrow
{
    auto e = mouseDown(x, y, button);
    e.phase = PointerPhase.Up;
    e.pressed = false;
    return e;
}

KeyEvent keyDown(string key, bool shift = false) @safe pure nothrow
{
    KeyEvent e;
    e.key = key;
    e.phase = KeyPhase.Down;
    e.shift = shift;
    return e;
}

unittest
{
    auto e = touchDown(10, 20, 3);
    assert(e.kind == PointerKind.Touch && e.id == 3);
    auto m = touchMove(12, 24, 3);
    assert(m.phase == PointerPhase.Move && m.id == 3);
    auto u = touchUp(12, 24, 3);
    assert(u.phase == PointerPhase.Up && !u.pressed);
    auto k = keyDown("Tab", true);
    assert(k.key == "Tab" && k.shift);
}
