/// Whole-UI DPI / content scale — logical layout units vs physical pixels.
///
/// Vello (and the software backend) paint in **physical** framebuffer pixels.
/// Widget sizes, padding, and font sizes in dew are **logical** units. Hosts
/// supply a `ScaleFactor` from the platform (GLFW content scale, Win32
/// DPI / 96, etc.); `App` layouts in logical space and scales the display list
/// before present. Open-shell / terminal / host-widget stacks should depend on
/// this module rather than inventing per-app DPI math.
module dew.scale;

/// Per-axis content scale (typically uniform; non-uniform is rare but allowed).
struct ScaleFactor
{
    float x = 1.0f;
    float y = 1.0f;

    static ScaleFactor identity() @safe @nogc pure nothrow
    {
        return ScaleFactor(1.0f, 1.0f);
    }

    static ScaleFactor uniform(float s) @safe @nogc pure nothrow
    {
        return ScaleFactor(s, s);
    }

    /// True when both axes are effectively 1x (no scaling needed).
    bool isIdentity(float eps = 1e-4f) const @safe @nogc pure nothrow
    {
        import std.math : abs;
        return abs(x - 1.0f) <= eps && abs(y - 1.0f) <= eps;
    }

    @property float average() const @safe @nogc pure nothrow
    {
        return (x + y) * 0.5f;
    }

    float logicalToPhysicalX(float logical) const @safe @nogc pure nothrow
    {
        return logical * x;
    }

    float logicalToPhysicalY(float logical) const @safe @nogc pure nothrow
    {
        return logical * y;
    }

    float physicalToLogicalX(float physical) const @safe @nogc pure nothrow
    {
        return x == 0 ? 0 : physical / x;
    }

    float physicalToLogicalY(float physical) const @safe @nogc pure nothrow
    {
        return y == 0 ? 0 : physical / y;
    }

    /// Scale a logical point into physical framebuffer coordinates.
    void logicalToPhysical(ref float px, ref float py) const @safe @nogc pure nothrow
    {
        px *= x;
        py *= y;
    }

    /// Scale a logical size (w,h) into physical pixels.
    void logicalSizeToPhysical(ref float w, ref float h) const @safe @nogc pure nothrow
    {
        w *= x;
        h *= y;
    }

    void physicalToLogical(ref float px, ref float py) const @safe @nogc pure nothrow
    {
        if (x != 0)
            px /= x;
        if (y != 0)
            py /= y;
    }

    void physicalSizeToLogical(ref float w, ref float h) const @safe @nogc pure nothrow
    {
        if (x != 0)
            w /= x;
        if (y != 0)
            h /= y;
    }
}

/// Build a scale from raw DPI (Windows: `GetDpiForWindow` -> dpi/96).
ScaleFactor contentScaleFromDpi(uint dpiX, uint dpiY, uint baseDpi = 96) @safe @nogc pure nothrow
{
    if (baseDpi == 0)
        return ScaleFactor.identity;
    return ScaleFactor(cast(float) dpiX / baseDpi, cast(float) dpiY / baseDpi);
}

/// Uniform DPI helper (common when only one axis is reported).
ScaleFactor contentScaleFromDpiUniform(uint dpi, uint baseDpi = 96) @safe @nogc pure nothrow
{
    return contentScaleFromDpi(dpi, dpi, baseDpi);
}

/**
 * Signature matching `glfwGetWindowContentScale(window, &x, &y)`.
 *
 * Dew does not link GLFW; hosts pass `cast(GlfwContentScaleFn)&glfwGetWindowContentScale`
 * (or any compatible thunk) together with the window pointer.
 */
alias GlfwContentScaleFn = extern (C) void function(void* window, float* xScale, float* yScale) nothrow @nogc;

/// Read content scale via a GLFW-compatible function pointer (stub-safe).
ScaleFactor contentScaleFromGlfw(void* window, GlfwContentScaleFn getScale) @trusted @nogc nothrow
{
    float sx = 1.0f;
    float sy = 1.0f;
    if (window !is null && getScale !is null)
        getScale(window, &sx, &sy);
    if (sx <= 0)
        sx = 1.0f;
    if (sy <= 0)
        sy = 1.0f;
    return ScaleFactor(sx, sy);
}

/// Platform / host probe for live content scale (monitor moves, WM_DPICHANGED).
interface ContentScaleSource
{
    ScaleFactor contentScale() @safe;
}

/// Always 1x1 — headless tests and backends without DPI.
final class StubContentScaleSource : ContentScaleSource
{
    ScaleFactor contentScale() @safe @nogc pure nothrow
    {
        return ScaleFactor.identity;
    }
}

/// Fixed factor (unit tests, forced zoom).
final class FixedContentScaleSource : ContentScaleSource
{
    ScaleFactor value;

    this() @safe @nogc pure nothrow {}

    this(ScaleFactor v) @safe @nogc pure nothrow
    {
        value = v;
    }

    this(float uniformScale) @safe @nogc pure nothrow
    {
        value = ScaleFactor.uniform(uniformScale);
    }

    ScaleFactor contentScale() @safe @nogc pure nothrow
    {
        return value;
    }
}

/// GLFW window probe without compiling GLFW into dew itself.
final class GlfwContentScaleSource : ContentScaleSource
{
    void* window;
    GlfwContentScaleFn getScale;

    this(void* win, GlfwContentScaleFn fn) @safe @nogc pure nothrow
    {
        window = win;
        getScale = fn;
    }

    ScaleFactor contentScale() @safe @nogc nothrow
    {
        return contentScaleFromGlfw(window, getScale);
    }
}

unittest
{
    const s100 = ScaleFactor.uniform(1.0f);
    const s150 = ScaleFactor.uniform(1.5f);
    assert(s100.isIdentity);
    assert(!s150.isIdentity);
    assert(s100.logicalToPhysicalX(100) == 100);
    assert(s150.logicalToPhysicalX(100) == 150);
    assert(s150.physicalToLogicalX(150) == 100);
    assert(contentScaleFromDpiUniform(144).x == 1.5f);
    assert(contentScaleFromDpi(96, 96).isIdentity);

    float x = 10, y = 20;
    s150.logicalToPhysical(x, y);
    assert(x == 15 && y == 30);
    s150.physicalToLogical(x, y);
    assert(x == 10 && y == 20);

    auto stub = new StubContentScaleSource();
    assert(stub.contentScale().isIdentity);
    auto fixed = new FixedContentScaleSource(1.5f);
    assert(fixed.contentScale().x == 1.5f);

    // GLFW thunk without linking GLFW.
    extern (C) void fakeGlfwScale(void* win, float* sx, float* sy) nothrow @nogc
    {
        assert(win !is null);
        *sx = 1.25f;
        *sy = 1.5f;
    }

    auto fromGlfw = contentScaleFromGlfw(cast(void*) 1, cast(GlfwContentScaleFn) &fakeGlfwScale);
    assert(fromGlfw.x == 1.25f && fromGlfw.y == 1.5f);
    auto glfwSrc = new GlfwContentScaleSource(cast(void*) 1, cast(GlfwContentScaleFn) &fakeGlfwScale);
    assert(glfwSrc.contentScale().y == 1.5f);
}
