/// CPU display-list rasterizer for tests / headless CI.
module rmgui.backend.software;

import rmgui.backend.iface;
import rmgui.display_list;

/// RGBA8 framebuffer filled from the display list (rects + stub glyphs).
final class SoftwareBackend : RenderBackend
{
    ubyte[] pixels;
    uint width, height;
    size_t frameCount;

    this(uint w = 800, uint h = 600) @safe
    {
        resize(w, h);
    }

    override void resize(uint w, uint h) @safe
    {
        width = w;
        height = h;
        pixels.length = cast(size_t) w * h * 4;
        pixels[] = 0;
    }

    override void present(ref DisplayList list, uint w, uint h) @safe
    {
        if (w != width || h != height)
            resize(w, h);
        // Clear to dark gray
        foreach (i; 0 .. pixels.length / 4)
        {
            pixels[i * 4 + 0] = 40;
            pixels[i * 4 + 1] = 40;
            pixels[i * 4 + 2] = 44;
            pixels[i * 4 + 3] = 255;
        }
        foreach (ref cmd; list.cmds)
        {
            final switch (cmd.op)
            {
            case DrawOp.FillRect:
                fillRect(cmd.x, cmd.y, cmd.w, cmd.h, cmd.color);
                break;
            case DrawOp.StrokeRect:
                strokeRect(cmd.x, cmd.y, cmd.w, cmd.h, cmd.color);
                break;
            case DrawOp.TextRun:
                // Approximate glyphs as small bars
                auto tw = cmd.text.length * cmd.fontSize * 0.5f;
                fillRect(cmd.x, cmd.y - cmd.fontSize, tw, cmd.fontSize * 0.15f, cmd.color);
                break;
            case DrawOp.ClipPush:
            case DrawOp.ClipPop:
                break;
            }
        }
        frameCount++;
    }

    override void shutdown() @safe
    {
        pixels.length = 0;
    }

    private void fillRect(float fx, float fy, float fw, float fh, ColorRgba c) @safe
    {
        import std.algorithm : clamp, max, min;
        int x0 = cast(int) fx;
        int y0 = cast(int) fy;
        int x1 = cast(int)(fx + fw);
        int y1 = cast(int)(fy + fh);
        x0 = clamp(x0, 0, cast(int) width);
        y0 = clamp(y0, 0, cast(int) height);
        x1 = clamp(x1, 0, cast(int) width);
        y1 = clamp(y1, 0, cast(int) height);
        foreach (y; y0 .. y1)
        {
            foreach (x; x0 .. x1)
            {
                size_t i = (cast(size_t) y * width + x) * 4;
                pixels[i + 0] = c.r;
                pixels[i + 1] = c.g;
                pixels[i + 2] = c.b;
                pixels[i + 3] = c.a;
            }
        }
    }

    private void strokeRect(float fx, float fy, float fw, float fh, ColorRgba c) @safe
    {
        fillRect(fx, fy, fw, 1, c);
        fillRect(fx, fy + fh - 1, fw, 1, c);
        fillRect(fx, fy, 1, fh, c);
        fillRect(fx + fw - 1, fy, 1, fh, c);
    }
}
