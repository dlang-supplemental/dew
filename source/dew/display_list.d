/// Flat draw command buffer emitted after layout.
module dew.display_list;

import dew.scale;

enum DrawOp : ubyte
{
    FillRect,
    StrokeRect,
    FillRoundedRect,
    FillCircle,
    TextRun,
    ClipPush,
    ClipPop,
    PathBegin,
    PathMoveTo,
    PathLineTo,
    PathClose,
    PathFill,
    PathStroke,
    ImageBlit,
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
    /// Stroke width, corner radius, or unused.
    float param;
    uint srcW, srcH;
    const(ubyte)[] pixels;
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

    void strokeRect(float x, float y, float w, float h, ColorRgba c, float width = 1) @safe nothrow
    {
        DrawCmd d;
        d.op = DrawOp.StrokeRect;
        d.x = x;
        d.y = y;
        d.w = w;
        d.h = h;
        d.color = c;
        d.param = width;
        cmds ~= d;
    }

    void fillRoundedRect(float x, float y, float w, float h, float radius, ColorRgba c) @safe nothrow
    {
        DrawCmd d;
        d.op = DrawOp.FillRoundedRect;
        d.x = x;
        d.y = y;
        d.w = w;
        d.h = h;
        d.param = radius;
        d.color = c;
        cmds ~= d;
    }

    void fillCircle(float cx, float cy, float radius, ColorRgba c) @safe nothrow
    {
        DrawCmd d;
        d.op = DrawOp.FillCircle;
        d.x = cx;
        d.y = cy;
        d.param = radius;
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

    void clipPush(float x, float y, float w, float h) @safe nothrow
    {
        DrawCmd d;
        d.op = DrawOp.ClipPush;
        d.x = x;
        d.y = y;
        d.w = w;
        d.h = h;
        cmds ~= d;
    }

    void clipPop() @safe nothrow
    {
        DrawCmd d;
        d.op = DrawOp.ClipPop;
        cmds ~= d;
    }

    void pathBegin() @safe nothrow
    {
        DrawCmd d;
        d.op = DrawOp.PathBegin;
        cmds ~= d;
    }

    void pathMoveTo(float x, float y) @safe nothrow
    {
        DrawCmd d;
        d.op = DrawOp.PathMoveTo;
        d.x = x;
        d.y = y;
        cmds ~= d;
    }

    void pathLineTo(float x, float y) @safe nothrow
    {
        DrawCmd d;
        d.op = DrawOp.PathLineTo;
        d.x = x;
        d.y = y;
        cmds ~= d;
    }

    void pathClose() @safe nothrow
    {
        DrawCmd d;
        d.op = DrawOp.PathClose;
        cmds ~= d;
    }

    void pathFill(ColorRgba c) @safe nothrow
    {
        DrawCmd d;
        d.op = DrawOp.PathFill;
        d.color = c;
        cmds ~= d;
    }

    void pathStroke(float width, ColorRgba c) @safe nothrow
    {
        DrawCmd d;
        d.op = DrawOp.PathStroke;
        d.param = width;
        d.color = c;
        cmds ~= d;
    }

    /// RGBA8 unpremultiplied, row-major `srcW * srcH * 4` bytes.
    void imageBlit(float x, float y, float dstW, float dstH,
        uint srcW, uint srcH, const(ubyte)[] pixels) @safe nothrow
    {
        DrawCmd d;
        d.op = DrawOp.ImageBlit;
        d.x = x;
        d.y = y;
        d.w = dstW;
        d.h = dstH;
        d.srcW = srcW;
        d.srcH = srcH;
        d.pixels = pixels;
        cmds ~= d;
    }
    /// Multiply geometry into physical pixels using `scale` (no-op when identity).
    /// Layout/hit-test stay logical; call this after `paintTree` before `present`.
    void applyContentScale(ScaleFactor scale) @safe @nogc nothrow
    {
        if (scale.isIdentity)
            return;
        const sx = scale.x;
        const sy = scale.y;
        // Uniform-ish stroke / radius / font: average axes (non-uniform DPI is rare).
        const sAvg = (sx + sy) * 0.5f;
        foreach (ref d; cmds)
        {
            final switch (d.op)
            {
            case DrawOp.FillRect:
            case DrawOp.StrokeRect:
            case DrawOp.FillRoundedRect:
            case DrawOp.ClipPush:
            case DrawOp.ImageBlit:
                d.x *= sx;
                d.y *= sy;
                d.w *= sx;
                d.h *= sy;
                if (d.op == DrawOp.StrokeRect || d.op == DrawOp.FillRoundedRect)
                    d.param *= sAvg;
                break;
            case DrawOp.FillCircle:
                d.x *= sx;
                d.y *= sy;
                d.param *= sAvg;
                break;
            case DrawOp.TextRun:
                d.x *= sx;
                d.y *= sy;
                d.fontSize *= sAvg;
                break;
            case DrawOp.PathMoveTo:
            case DrawOp.PathLineTo:
                d.x *= sx;
                d.y *= sy;
                break;
            case DrawOp.PathStroke:
                d.param *= sAvg;
                break;
            case DrawOp.ClipPop:
            case DrawOp.PathBegin:
            case DrawOp.PathClose:
            case DrawOp.PathFill:
                break;
            }
        }
    }
}
