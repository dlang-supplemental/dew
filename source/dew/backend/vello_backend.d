/**
 * Primary 2D GPU backend — Vello via `vello-d`.
 *
 * Emits fills/strokes/paths/glyphs into a Vello scene and presents to a
 * platform surface (HWND / X11 / Wayland).
 */
module dew.backend.vello_backend;

import dew.backend.iface;
import dew.backend.font;
import dew.display_list;

version (DewHeadless)
{
    final class VelloRenderBackend : RenderBackend
    {
        override void resize(uint, uint) @safe {}
        override void present(ref DisplayList, uint, uint) @safe {}
        override void shutdown() @safe {}
        void attach(void*, void*, uint, uint, int = 0) @safe {}
        void attachX11(void*, ulong, int, uint, uint, int = 0) @safe {}
        void attachWayland(void*, void*, uint, uint, int = 0) @safe {}
    }
    alias VelloBackend = VelloRenderBackend;
}
else
{
    import vello;
    import vello.bindings : VelloBackendId = VelloBackend;

    /// GPU 2D presenter backed by Vello.
    final class VelloRenderBackend : RenderBackend
    {
        private Context ctx;
        private Scene scene;
        private uint width, height;
        private bool ready;

        void attach(void* hwnd, void* hinstance, uint w, uint h,
            VelloBackendId backend = VelloBackendId.All) @trusted
        {
            initVello();
            width = w;
            height = h;
            ctx = new Context(hwnd, hinstance, w, h, backend);
            scene = new Scene();
            ready = ctx !is null && ctx.valid;
        }

        void attachX11(void* display, ulong window, int screen, uint w, uint h,
            VelloBackendId backend = VelloBackendId.All) @trusted
        {
            initVello();
            width = w;
            height = h;
            ctx = Context.forX11(display, window, screen, w, h, backend);
            scene = new Scene();
            ready = ctx !is null && ctx.valid;
        }

        void attachWayland(void* display, void* surface, uint w, uint h,
            VelloBackendId backend = VelloBackendId.All) @trusted
        {
            initVello();
            width = w;
            height = h;
            ctx = Context.forWayland(display, surface, w, h, backend);
            scene = new Scene();
            ready = ctx !is null && ctx.valid;
        }

        @property bool attached() const @safe @nogc pure nothrow
        {
            return ready;
        }

        override void resize(uint w, uint h) @trusted
        {
            width = w;
            height = h;
            if (ready && ctx !is null)
                ctx.resize(w, h);
        }

        override void present(ref DisplayList list, uint w, uint h) @trusted
        {
            if (!ready)
                return;
            if (w != width || h != height)
                resize(w, h);
            scene.reset();
            scene.clear(Color(0.12f, 0.12f, 0.14f, 1.0f));
            auto font = uiFontBytes();
            const fontIdx = uiFontIndex();
            foreach (ref cmd; list.cmds)
            {
                final switch (cmd.op)
                {
                case DrawOp.FillRect:
                    scene.fillRect(cmd.x, cmd.y, cmd.w, cmd.h,
                        cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a);
                    break;
                case DrawOp.StrokeRect:
                    const sw = cmd.param > 0 ? cmd.param : 1;
                    scene.strokeRect(cmd.x, cmd.y, cmd.w, cmd.h, sw,
                        cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a);
                    break;
                case DrawOp.FillRoundedRect:
                    scene.fillRoundedRect(cmd.x, cmd.y, cmd.w, cmd.h, cmd.param,
                        cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a);
                    break;
                case DrawOp.FillCircle:
                    scene.fillCircle(cmd.x, cmd.y, cmd.param,
                        cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a);
                    break;
                case DrawOp.TextRun:
                    if (font.length && cmd.text.length)
                    {
                        scene.drawText(font, fontIdx, cmd.fontSize,
                            cmd.x, cmd.y, cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a,
                            cmd.text);
                    }
                    else
                    {
                        auto tw = cmd.text.length * cmd.fontSize * 0.5;
                        scene.fillRect(cmd.x, cmd.y - cmd.fontSize * 0.8, tw, cmd.fontSize * 0.12,
                            cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a);
                    }
                    break;
                case DrawOp.ClipPush:
                    scene.pushClipRect(cmd.x, cmd.y, cmd.w, cmd.h);
                    break;
                case DrawOp.ClipPop:
                    scene.popLayer();
                    break;
                case DrawOp.PathBegin:
                    scene.beginPath();
                    break;
                case DrawOp.PathMoveTo:
                    scene.moveTo(cmd.x, cmd.y);
                    break;
                case DrawOp.PathLineTo:
                    scene.lineTo(cmd.x, cmd.y);
                    break;
                case DrawOp.PathClose:
                    scene.closePath();
                    break;
                case DrawOp.PathFill:
                    scene.fillPath(cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a);
                    break;
                case DrawOp.PathStroke:
                    scene.strokePath(cmd.param > 0 ? cmd.param : 1,
                        cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a);
                    break;
                case DrawOp.ImageBlit:
                    if (cmd.pixels.length && cmd.srcW && cmd.srcH)
                        scene.drawImage(cmd.x, cmd.y, cmd.w, cmd.h,
                            cmd.srcW, cmd.srcH, cmd.pixels);
                    break;
                }
            }
            ctx.render(scene);
        }

        override void shutdown() @trusted
        {
            scene = null;
            ctx = null;
            ready = false;
        }
    }

    alias VelloBackend = VelloRenderBackend;
}
