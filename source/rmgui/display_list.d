/// Flat draw command buffer emitted after layout.
module rmgui.display_list;

enum DrawOp : ubyte
{
    FillRect,
    StrokeRect,
    TextRun,
    ClipPush,
    ClipPop,
}

struct ColorRgba
{
    ubyte r, g, b, a = 255;

    static ColorRgba rgb(ubyte r, ubyte g, ubyte b) @safe @nogc pure nothrow
    {
        return ColorRgba(r, g, b, 255);
    }
}

struct DrawCmd
{
    DrawOp op;
    float x, y, w, h;
    ColorRgba color;
    float fontSize;
    bool bold;
    const(char)[] text;
}

struct DisplayList
{
    DrawCmd[] cmds;

    void clear() @safe nothrow
    {
        cmds.length = 0;
    }

    void fillRect(float x, float y, float w, float h, ColorRgba c) @safe nothrow
    {
        DrawCmd d;
        d.op = DrawOp.FillRect;
        d.x = x;
        d.y = y;
        d.w = w;
        d.h = h;
        d.color = c;
        cmds ~= d;
    }

    void strokeRect(float x, float y, float w, float h, ColorRgba c) @safe nothrow
    {
        DrawCmd d;
        d.op = DrawOp.StrokeRect;
        d.x = x;
        d.y = y;
        d.w = w;
        d.h = h;
        d.color = c;
        cmds ~= d;
    }

    void textRun(float x, float y, float fontSize, bool bold, const(char)[] text, ColorRgba c) @safe nothrow
    {
        DrawCmd d;
        d.op = DrawOp.TextRun;
        d.x = x;
        d.y = y;
        d.fontSize = fontSize;
        d.bold = bold;
        d.text = text;
        d.color = c;
        cmds ~= d;
    }
}
