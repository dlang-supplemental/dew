/// KDL layout docs → DSL code (very low friction tree format).
module dew.adapters.kdl;

import dew.markup.ctfe;
import std.array : appender;
import std.string : strip, splitLines, indexOf;

/**
 * Translate a minimal KDL UI tree:
 * ---
 * VStack spacing=12 {
 *   Text text="Hello" bold=#true
 *   Button text="Save"
 * }
 * ---
 */
string kdlToMarkup(string src) @safe pure
{
    // Convert `Node prop=val` lines into brace markup heuristically
    auto app = appender!string();
    foreach (line; src.splitLines)
    {
        auto t = line.strip;
        if (!t.length || t[0] == '/' || t[0] == '#')
            continue;
        // prop=value → prop: value;
        auto outLine = t;
        // crude: replace `=` with `: ` for props (not perfect for nested)
        import std.array : replace;
        outLine = outLine.replace("=#true", ": true").replace("=#false", ": false");
        outLine = outLine.replace("=\"", ": \"");
        // spacing=12 → spacing: 12
        // only when looks like ident=number
        app.put(outLine);
        app.put("\n");
    }
    return app.data;
}

template importKdl(string src)
{
    enum importKdl = compileMarkup(kdlToMarkup(src));
}

unittest
{
    auto m = kdlToMarkup(`VStack spacing=8 { Text text="Hi" }`);
    assert(m.length > 0);
}
