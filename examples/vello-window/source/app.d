/**
 * Windowed dew demo: GLFW window + VelloRenderBackend + small UI.
 *
 * Build: MSVC/Windows SDK (or Linux link) + Rust/`cargo` for the `vello-d`
 * bridge. From repo root:
 *
 *   dub build --root examples/vello-window
 *
 * Headless CI uses `examples/gallery` with `-c headless` / `DewHeadless`.
 *
 * Platforms: Windows (HWND), Linux X11, Linux Wayland (when GLFW provides
 * native handles). macOS still needs a Metal surface constructor in vello-d.
 */
module vello_window;

import std.stdio;
import std.format : format;
import dew;
import glfw3.api;

version (Windows)
{
    import core.sys.windows.windows;
    extern (C) HWND glfwGetWin32Window(GLFWwindow* window);
}
else version (linux)
{
    extern (C) void* glfwGetX11Display();
    extern (C) ulong glfwGetX11Window(GLFWwindow* window);
    extern (C) void* glfwGetWaylandDisplay();
    extern (C) void* glfwGetWaylandWindow(GLFWwindow* window);
}

void main()
{
    writeln("dew ", dewVersion, " — ", dewSlogan);
    writeln("vello-window: GLFW + VelloRenderBackend");

    version (Windows)
        runWindowed();
    else version (linux)
        runWindowed();
    else
    {
        stderr.writeln(
            "dew-vello-window: this platform needs a vello-d surface constructor (macOS Metal TBD).");
    }
}

version (Windows)
    enum bool dewVelloWindowHost = true;
else version (linux)
    enum bool dewVelloWindowHost = true;
else
    enum bool dewVelloWindowHost = false;

static if (dewVelloWindowHost)
void runWindowed()
{
    if (!glfwInit())
    {
        stderr.writeln("glfwInit failed");
        return;
    }
    scope (exit)
        glfwTerminate();

    glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
    enum int winW = 800;
    enum int winH = 600;
    auto window = glfwCreateWindow(winW, winH, "dew — Dew it!", null, null);
    if (window is null)
    {
        stderr.writeln("glfwCreateWindow failed");
        return;
    }
    scope (exit)
        glfwDestroyWindow(window);

    auto gpu = new VelloRenderBackend();
    if (!attachBackend(gpu, window, winW, winH))
    {
        stderr.writeln("VelloRenderBackend attach failed");
        return;
    }
    scope (exit)
        gpu.shutdown();

    Arena frameArena;
    scope (exit)
        frameArena.dispose();

    App app;
    app.ui.arena = &frameArena;
    beginUi(app.ui);
    scope (exit)
        endUi();

    int clicks;
    auto mesh = new Wgpu3dViewport();
    mesh.initHeadless(240, 160);
    mesh.renderEmbed();

    void rebuild() @safe
    {
        app.ui.beginFrame();
        beginUi(app.ui);
        auto label = format("clicks: %s", clicks);
        app.setRoot(VStack(
            Text("dew + Vello").fontSize(22).bold(),
            Text(label).fontSize(16),
            Button("Tap / click")
                .touchFriendly()
                .onClick(() { clicks++; }),
            CheckBox("Remember me", true),
            MeshView(mesh.embedPixels, mesh.width, mesh.height)
                .width(240).height(160),
        ).spacing(12).padding(24));
    }

    rebuild();
    app.backend = gpu;
    app.resize(winW, winH);
    app.frame();

    bool mouseWasDown;
    while (!glfwWindowShouldClose(window))
    {
        glfwPollEvents();

        int fbW, fbH;
        glfwGetFramebufferSize(window, &fbW, &fbH);
        if (fbW > 0 && fbH > 0
            && (fbW != cast(int) app.width || fbH != cast(int) app.height))
            app.resize(fbW, fbH);

        double mx, my;
        glfwGetCursorPos(window, &mx, &my);
        const down = glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_LEFT) == GLFW_PRESS;

        if (down != mouseWasDown)
        {
            PointerEvent ev;
            ev.x = cast(float) mx;
            ev.y = cast(float) my;
            ev.kind = PointerKind.Mouse;
            ev.phase = down ? PointerPhase.Down : PointerPhase.Up;
            ev.button = PointerButton.Left;
            ev.pressed = down;
            ev.primary = true;
            const before = clicks;
            if (app.pointer(ev) || clicks != before)
                rebuild();
        }
        else if (down)
        {
            PointerEvent ev;
            ev.x = cast(float) mx;
            ev.y = cast(float) my;
            ev.kind = PointerKind.Mouse;
            ev.phase = PointerPhase.Move;
            ev.button = PointerButton.Left;
            ev.pressed = true;
            ev.primary = true;
            app.pointer(ev);
        }
        mouseWasDown = down;

        mesh.renderEmbed();
        app.frame();
    }
}

static if (dewVelloWindowHost)
bool attachBackend(VelloRenderBackend gpu, GLFWwindow* window, uint w, uint h) @trusted
{
    version (Windows)
    {
        HWND hwnd = glfwGetWin32Window(window);
        HINSTANCE hinstance = GetModuleHandleA(null);
        gpu.attach(cast(void*) hwnd, cast(void*) hinstance, w, h);
        return gpu.attached;
    }
    else version (linux)
    {
        // Prefer Wayland when GLFW created a Wayland window; else X11.
        auto wlDisp = glfwGetWaylandDisplay();
        auto wlSurf = glfwGetWaylandWindow(window);
        if (wlDisp !is null && wlSurf !is null)
        {
            gpu.attachWayland(wlDisp, wlSurf, w, h);
            if (gpu.attached)
                return true;
        }
        auto xDisp = glfwGetX11Display();
        auto xWin = glfwGetX11Window(window);
        if (xDisp !is null && xWin != 0)
        {
            gpu.attachX11(xDisp, xWin, 0, w, h);
            return gpu.attached;
        }
        return false;
    }
    else
        return false;
}
