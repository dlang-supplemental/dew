/**
 * 3D embed viewport — wgpu via `bindbc-wgpu`.
 *
 * Chosen over raylib/bgfx/Vulkan-raw because Vello already runs on wgpu; one
 * GPU API family keeps the TCB smaller for mixed 2D UI + 3D viewports.
 */
module rmgui.backend.wgpu3d;

import rmgui.backend.iface;
import rmgui.display_list;

/// Viewport leaf that clears with wgpu (device bootstrap in v0.1).
final class Wgpu3dViewport : RenderBackend
{
    uint width = 640;
    uint height = 480;
    bool ready;
    float[4] clearColor = [0.08f, 0.10f, 0.18f, 1.0f];

    version (RmguiHeadless)
    {
        bool initHeadless(uint w = 640, uint h = 480) @safe
        {
            width = w;
            height = h;
            ready = true;
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
            if (support != WGPUSupport.wgpu && support != WGPUSupport.wgpuNative)
            {
                ready = false;
                return false;
            }
            WGPUInstanceDescriptor desc;
            instance = wgpuCreateInstance(&desc);
            ready = instance !is null;
            return ready;
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
        }
    }

    override void resize(uint w, uint h) @safe
    {
        width = w;
        height = h;
    }

    override void present(ref DisplayList, uint w, uint h) @safe
    {
        resize(w, h);
    }

    version (RmguiHeadless)
    {
        override void shutdown() @safe
        {
            ready = false;
        }
    }
}
