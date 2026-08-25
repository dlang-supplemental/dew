/**
 * Primary 2D GPU backend — Vello via `vello-d`.
 *
 * Emits fill/stroke rects into a Vello scene and presents to an HWND surface.
 */
module rmgui.backend.vello_backend;

import rmgui.backend.iface;
import rmgui.display_list;

version (RmguiHeadless)
{
    final class VelloRenderBackend : RenderBackend
    {
        override void resize(uint, uint) @safe {}
        override void present(ref DisplayList, uint, uint) @safe {}
        override void shutdown() @safe {}
        void attach(void*, void*, uint, uint, int = 0) @safe {}
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
            ready = true;
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
            foreach (ref cmd; list.cmds)
            {
                final switch (cmd.op)
                {
                case DrawOp.FillRect:
                    scene.fillRect(cmd.x, cmd.y, cmd.w, cmd.h,
                        cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a);
                    break;
                case DrawOp.StrokeRect:
                    scene.fillRect(cmd.x, cmd.y, cmd.w, 1,
                        cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a);
                    scene.fillRect(cmd.x, cmd.y + cmd.h - 1, cmd.w, 1,
                        cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a);
                    scene.fillRect(cmd.x, cmd.y, 1, cmd.h,
                        cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a);
                    scene.fillRect(cmd.x + cmd.w - 1, cmd.y, 1, cmd.h,
                        cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a);
                    break;
                case DrawOp.TextRun:
                    auto tw = cmd.text.length * cmd.fontSize * 0.5;
                    scene.fillRect(cmd.x, cmd.y - cmd.fontSize * 0.8, tw, cmd.fontSize * 0.12,
                        cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a);
                    break;
                case DrawOp.ClipPush:
                case DrawOp.ClipPop:
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
