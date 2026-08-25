/**
 * Windowed dew demo: GLFW window + VelloRenderBackend + small UI.
 *
 * Build (Windows): MSVC toolchain (`link.exe` on PATH) and Rust/`cargo`
 * for the `vello-d` bridge. From repo root:
 *
 *   dub build --root examples/vello-window
 *
 * Headless CI uses `examples/gallery` with `-c headless` / `DewHeadless`.
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

void main()
{
    writeln("dew ", dewVersion, " — ", dewSlogan);
    writeln("vello-window: GLFW + VelloRenderBackend");

    version (Windows)
    {
        runWindows();
    }
    else
    {
        stderr.writeln(
            "dew-vello-window: Windows HWND path only for now (matches vello-d demos).");
    }
}

version (Windows)
void runWindows()
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

    HWND hwnd = glfwGetWin32Window(window);
    HINSTANCE hinstance = GetModuleHandleA(null);

    auto gpu = new VelloRenderBackend();
    gpu.attach(cast(void*) hwnd, cast(void*) hinstance, winW, winH);
    scope (exit)
        gpu.shutdown();

    App app;
    beginUi(app.ui);
    scope (exit)
        endUi();

    int clicks;

    void rebuild() @safe
    {
        app.ui.store.clear();
        beginUi(app.ui);
        auto label = format("clicks: %s", clicks);
        app.setRoot(VStack(
            Text("dew + Vello").fontSize(22).bold(),
            Text(label).fontSize(16),
            Button("Tap / click")
                .touchFriendly()
                .onClick(() { clicks++; })
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

        const down = glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_LEFT) == GLFW_PRESS;
        if (down && !mouseWasDown)
        {
            double mx, my;
            glfwGetCursorPos(window, &mx, &my);
            PointerEvent ev;
            ev.x = cast(float) mx;
            ev.y = cast(float) my;
            ev.kind = PointerKind.Mouse;
            ev.phase = PointerPhase.Down;
            ev.button = PointerButton.Left;
            ev.pressed = true;
            ev.primary = true;
            const before = clicks;
            if (app.pointer(ev) || clicks != before)
                rebuild();
        }
        mouseWasDown = down;

        app.frame();
    }
}
