/// Render backend interface.
module rmgui.backend.iface;

import rmgui.display_list;

interface RenderBackend
{
    void resize(uint width, uint height) @safe;
    void present(ref DisplayList list, uint width, uint height) @safe;
    void shutdown() @safe;
}
