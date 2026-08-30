/**
 * 3D embed viewport — wgpu via `bindbc-wgpu`.
 *
 * Chosen over raylib/bgfx/Vulkan-raw because Vello already runs on wgpu; one
 * GPU API family keeps the TCB smaller for mixed 2D UI + 3D viewports.
 *
 * v0.1.5 scaffolding: produce an RGBA8 mesh embed buffer that the 2D pass
 * composites via `DrawOp.ImageBlit` (CPU clear / optional soft mesh). Shared
 * wgpu device with Vello remains a follow-up once vello-d exports device handles.
 */
module dew.backend.wgpu3d;

import dew.backend.iface;
import dew.display_list;

/// Provider that fills an RGBA8 buffer for a MeshView leaf each frame.
alias MeshEmbedPaint = void delegate(ubyte[] rgba, uint w, uint h) @safe;

/// Viewport leaf that clears with wgpu (device bootstrap) and exposes RGBA embeds.
final class Wgpu3dViewport : RenderBackend
{
    uint width = 640;
    uint height = 480;
    bool ready;
    float[4] clearColor = [0.08f, 0.10f, 0.18f, 1.0f];
    /// Latest embed pixels (row-major RGBA8), sized `width * height * 4`.
    ubyte[] embedPixels;
    MeshEmbedPaint customPaint;

    version (DewHeadless)
    {
        bool initHeadless(uint w = 640, uint h = 480) @safe
        {
            width = w;
            height = h;
            ready = true;
            ensureEmbedBuffer();
            return true;
        }
    }
    else
    {
        import bindbc.wgpu;

        private WGPUInstance instance;
        private WGPUDevice device;
        private WGPUQueue queue;

        bool initHeadless(uint w = 640, uint h = 480) @trusted
        {
            width = w;
            height = h;
            // Dynamic load; fail soft if native lib absent (CI without GPU).
            auto support = loadWGPU();
            if (support != WGPUSupport.wgpu25)
            {
                ready = false;
                ensureEmbedBuffer();
                // Soft-ready: CPU embed path still works without native wgpu.
                ready = true;
                return true;
            }
            WGPUInstanceDescriptor desc;
            instance = wgpuCreateInstance(&desc);
            ready = instance !is null;
            if (!ready)
                ready = true; // CPU fallback
            ensureEmbedBuffer();
            return true;
        }

        override void shutdown() @trusted
        {
            if (device)
                wgpuDeviceRelease(device);
            if (instance)
                wgpuInstanceRelease(instance);
            device = null;
            instance = null;
            queue = null;
            ready = false;
            embedPixels.length = 0;
        }
    }

    override void resize(uint w, uint h) @safe
    {
        width = w;
        height = h;
        ensureEmbedBuffer();
    }

    /// Fill `embedPixels` for compositing into the 2D display list.
    void renderEmbed() @safe
    {
        ensureEmbedBuffer();
        if (customPaint !is null)
        {
            customPaint(embedPixels, width, height);
            return;
        }
        paintClearWithSoftTriangle();
    }

    override void present(ref DisplayList, uint w, uint h) @safe
    {
        resize(w, h);
        renderEmbed();
    }

    version (DewHeadless)
    {
        override void shutdown() @safe
        {
            ready = false;
            embedPixels.length = 0;
        }
    }

    private void ensureEmbedBuffer() @safe
    {
        const need = cast(size_t) width * height * 4;
        if (embedPixels.length != need)
            embedPixels.length = need;
    }

    private void paintClearWithSoftTriangle() @safe
    {
        const cr = cast(ubyte)(clearColor[0] * 255);
        const cg = cast(ubyte)(clearColor[1] * 255);
        const cb = cast(ubyte)(clearColor[2] * 255);
        const ca = cast(ubyte)(clearColor[3] * 255);
        foreach (i; 0 .. embedPixels.length / 4)
        {
            embedPixels[i * 4 + 0] = cr;
            embedPixels[i * 4 + 1] = cg;
            embedPixels[i * 4 + 2] = cb;
            embedPixels[i * 4 + 3] = ca;
        }
        // Soft triangle (mesh placeholder) in the center — proves ImageBlit compositing.
        const ax = width * 0.50f;
        const ay = height * 0.22f;
        const bx = width * 0.18f;
        const by = height * 0.78f;
        const cx = width * 0.82f;
        const cy = height * 0.78f;
        foreach (y; 0 .. height)
        {
            foreach (x; 0 .. width)
            {
                if (pointInTri(x + 0.5f, y + 0.5f, ax, ay, bx, by, cx, cy))
                {
                    const i = (cast(size_t) y * width + x) * 4;
                    embedPixels[i + 0] = 80;
                    embedPixels[i + 1] = 180;
                    embedPixels[i + 2] = 220;
                    embedPixels[i + 3] = 255;
                }
            }
        }
    }
}

private bool pointInTri(float px, float py,
    float ax, float ay, float bx, float by, float cx, float cy) @safe @nogc pure nothrow
{
    const v0x = cx - ax;
    const v0y = cy - ay;
    const v1x = bx - ax;
    const v1y = by - ay;
    const v2x = px - ax;
    const v2y = py - ay;
    const dot00 = v0x * v0x + v0y * v0y;
    const dot01 = v0x * v1x + v0y * v1y;
    const dot02 = v0x * v2x + v0y * v2y;
    const dot11 = v1x * v1x + v1y * v1y;
    const dot12 = v1x * v2x + v1y * v2y;
    const inv = 1.0f / (dot00 * dot11 - dot01 * dot01 + 1e-12f);
    const u = (dot11 * dot02 - dot01 * dot12) * inv;
    const v = (dot00 * dot12 - dot01 * dot02) * inv;
    return (u >= 0) && (v >= 0) && (u + v < 1);
}
