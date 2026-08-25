/**
 * Default UI font bytes for Vello glyph runs.
 *
 * Loads a system TrueType/OpenType once; callers may replace via `setUiFont`.
 */
module dew.backend.font;

import std.file : exists, read;
import std.path : buildPath;

private __gshared ubyte[] gFontBytes;
private __gshared uint gFontIndex;
private __gshared bool gTriedLoad;

/// Replace the UI font blob (TrueType/OpenType). Copied into owned storage.
void setUiFont(const(ubyte)[] bytes, uint fontIndex = 0) @trusted
{
    gFontBytes = bytes.dup;
    gFontIndex = fontIndex;
    gTriedLoad = true;
}

/// Font face index inside a collection (usually 0).
uint uiFontIndex() @trusted @nogc nothrow
{
    return gFontIndex;
}

/// Lazily load a system UI font; empty if none found (text falls back to stub paint).
const(ubyte)[] uiFontBytes() @trusted
{
    if (!gTriedLoad)
    {
        gTriedLoad = true;
        loadDefaultFont();
    }
    return gFontBytes;
}

private void loadDefaultFont() @trusted
{
    version (Windows)
    {
        auto windir = environmentGet("WINDIR");
        if (!windir.length)
            windir = `C:\Windows`;
        immutable candidates = [
            buildPath(windir, "Fonts", "segoeui.ttf"),
            buildPath(windir, "Fonts", "arial.ttf"),
            buildPath(windir, "Fonts", "calibri.ttf"),
        ];
        foreach (p; candidates)
        {
            if (exists(p))
            {
                gFontBytes = cast(ubyte[]) read(p);
                gFontIndex = 0;
                return;
            }
        }
    }
    else version (linux)
    {
        immutable candidates = [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/TTF/DejaVuSans.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
            "/usr/share/fonts/truetype/freefont/FreeSans.ttf",
        ];
        foreach (p; candidates)
        {
            if (exists(p))
            {
                gFontBytes = cast(ubyte[]) read(p);
                gFontIndex = 0;
                return;
            }
        }
    }
    else version (OSX)
    {
        immutable candidates = [
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/Library/Fonts/Arial.ttf",
            "/System/Library/Fonts/SFNS.ttf",
        ];
        foreach (p; candidates)
        {
            if (exists(p))
            {
                gFontBytes = cast(ubyte[]) read(p);
                gFontIndex = 0;
                return;
            }
        }
    }
}

private string environmentGet(string name) @trusted
{
    import std.process : environment;
    try
        return environment.get(name, null);
    catch (Exception)
        return null;
}
