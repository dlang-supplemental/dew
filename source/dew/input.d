/// Normalized pointer / touch types shared by nodes and the dispatcher.
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

unittest
{
    auto e = touchDown(10, 20, 3);
    assert(e.kind == PointerKind.Touch && e.id == 3);
}
