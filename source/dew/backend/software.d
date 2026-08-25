/// CPU display-list rasterizer for tests / headless CI.
module dew.backend.software;

import dew.backend.iface;
import dew.display_list;
import std.algorithm : clamp, max, min;
import std.math : sqrt;

/// RGBA8 framebuffer filled from the display list (rects + stub glyphs + clip stack).
final class SoftwareBackend : RenderBackend
{
    ubyte[] pixels;
    uint width, height;
    size_t frameCount;

    private struct ClipRect
    {
        int x0, y0, x1, y1;
    }

    private ClipRect[32] clipStack;
    private size_t clipDepth;

    private struct PathPt
    {
        float x, y;
        bool move;
    }

    private PathPt[256] pathPts;
    private size_t pathLen;

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
        clipDepth = 0;
        pathLen = 0;
    }

    override void present(ref DisplayList list, uint w, uint h) @safe
    {
        if (w != width || h != height)
            resize(w, h);
        clipDepth = 0;
        pathLen = 0;
        pushClip(0, 0, cast(int) width, cast(int) height);
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
            case DrawOp.FillRoundedRect:
                fillRect(cmd.x, cmd.y, cmd.w, cmd.h, cmd.color);
                break;
            case DrawOp.FillCircle:
                fillCircle(cmd.x, cmd.y, cmd.param, cmd.color);
                break;
            case DrawOp.TextRun:
                auto tw = cmd.text.length * cmd.fontSize * 0.5f;
                fillRect(cmd.x, cmd.y - cmd.fontSize, tw, cmd.fontSize * 0.15f, cmd.color);
                break;
            case DrawOp.ClipPush:
                pushClip(cast(int) cmd.x, cast(int) cmd.y,
                    cast(int)(cmd.x + cmd.w), cast(int)(cmd.y + cmd.h));
                break;
            case DrawOp.ClipPop:
                if (clipDepth > 1)
                    clipDepth--;
                break;
            case DrawOp.PathBegin:
                pathLen = 0;
                break;
            case DrawOp.PathMoveTo:
                if (pathLen < pathPts.length)
                    pathPts[pathLen++] = PathPt(cmd.x, cmd.y, true);
                break;
            case DrawOp.PathLineTo:
                if (pathLen < pathPts.length)
                    pathPts[pathLen++] = PathPt(cmd.x, cmd.y, false);
                break;
            case DrawOp.PathClose:
                break;
            case DrawOp.PathFill:
            case DrawOp.PathStroke:
                strokePathApprox(cmd.color);
                break;
            case DrawOp.ImageBlit:
                blitImage(cmd.x, cmd.y, cmd.w, cmd.h, cmd.srcW, cmd.srcH, cmd.pixels);
                break;
            }
        }
        frameCount++;
    }

    override void shutdown() @safe
    {
        pixels.length = 0;
    }

    private void pushClip(int x0, int y0, int x1, int y1) @safe @nogc nothrow
    {
        if (clipDepth >= clipStack.length)
            return;
        if (clipDepth == 0)
        {
            clipStack[clipDepth++] = ClipRect(x0, y0, x1, y1);
            return;
        }
        auto p = clipStack[clipDepth - 1];
        clipStack[clipDepth++] = ClipRect(
            max(p.x0, x0), max(p.y0, y0), min(p.x1, x1), min(p.y1, y1));
    }

    private void fillRect(float fx, float fy, float fw, float fh, ColorRgba c) @safe
    {
        int x0 = cast(int) fx;
        int y0 = cast(int) fy;
        int x1 = cast(int)(fx + fw);
        int y1 = cast(int)(fy + fh);
        if (clipDepth)
        {
            auto clip = clipStack[clipDepth - 1];
            x0 = max(x0, clip.x0);
            y0 = max(y0, clip.y0);
            x1 = min(x1, clip.x1);
            y1 = min(y1, clip.y1);
        }
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

    private void fillCircle(float cx, float cy, float radius, ColorRgba c) @safe
    {
        const r2 = radius * radius;
        const x0 = cast(int)(cx - radius);
        const y0 = cast(int)(cy - radius);
        const x1 = cast(int)(cx + radius) + 1;
        const y1 = cast(int)(cy + radius) + 1;
        foreach (y; y0 .. y1)
        {
            foreach (x; x0 .. x1)
            {
                const dx = x + 0.5f - cx;
                const dy = y + 0.5f - cy;
                if (dx * dx + dy * dy <= r2)
                    fillRect(x, y, 1, 1, c);
            }
        }
    }

    private void strokePathApprox(ColorRgba c) @safe
    {
        if (pathLen < 2)
            return;
        foreach (i; 1 .. pathLen)
        {
            if (pathPts[i].move)
                continue;
            // Crude 1px polyline
            auto x0 = pathPts[i - 1].x;
            auto y0 = pathPts[i - 1].y;
            auto x1 = pathPts[i].x;
            auto y1 = pathPts[i].y;
            const steps = cast(int)(sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)) + 1);
            foreach (s; 0 .. steps + 1)
            {
                const t = cast(float) s / (steps ? steps : 1);
                fillRect(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, 1, 1, c);
            }
        }
    }

    private void blitImage(float fx, float fy, float dw, float dh,
        uint srcW, uint srcH, const(ubyte)[] src) @safe
    {
        if (!src.length || !srcW || !srcH)
            return;
        const need = cast(size_t) srcW * srcH * 4;
        if (src.length < need)
            return;
        foreach (dy; 0 .. cast(int) dh)
        {
            const sy = cast(int)((dy + 0.5f) * srcH / dh);
            if (sy < 0 || sy >= cast(int) srcH)
                continue;
            foreach (dx; 0 .. cast(int) dw)
            {
                const sx = cast(int)((dx + 0.5f) * srcW / dw);
                if (sx < 0 || sx >= cast(int) srcW)
                    continue;
                const si = (cast(size_t) sy * srcW + sx) * 4;
                ColorRgba c;
                c.r = src[si + 0];
                c.g = src[si + 1];
                c.b = src[si + 2];
                c.a = src[si + 3];
                fillRect(fx + dx, fy + dy, 1, 1, c);
            }
        }
    }
}
