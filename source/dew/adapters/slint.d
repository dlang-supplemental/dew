/// Slint subset → CTFE markup / DSL code.
module dew.adapters.slint;

import dew.markup.ctfe;
import std.array : replace, appender;
import std.string : strip, indexOf, splitLines;

/**
 * Best-effort translate of a Slint-ish snippet into dew CTFE markup.
 * Full `.slint` scripts / animations are out of scope for the subset parser.
 */
string slintToMarkup(string src) @safe pure
{
    auto s = src
        .replace("VerticalBox", "VStack")
        .replace("HorizontalBox", "HStack")
        .replace("Rectangle", "Container")
        .replace("font-size", "font_size")
        .replace("in-out property", "// property")
        .replace("export component", "// component");
    // Drop `inherits X` clauses on the same line
    auto app = appender!string();
    foreach (line; s.splitLines)
    {
        auto t = line.strip;
        auto inh = t.indexOf("inherits ");
        if (inh >= 0 && t.indexOf("{") < 0)
            continue;
        if (t.startsWith("clicked =>"))
        {
            app.put("            on_click: clicked;\n");
            continue;
        }
        app.put(line);
        app.put("\n");
    }
    return app.data;
}

/// CTFE: lower Slint subset straight to D DSL code.
template importSlint(string src)
{
    enum importSlint = compileMarkup(slintToMarkup(src));
}

private bool startsWith(string s, string p) @safe pure nothrow
{
    return s.length >= p.length && s[0 .. p.length] == p;
}

unittest
{
    enum m = slintToMarkup(`VerticalBox { spacing: 8px; Text { text: "Hi"; } }`);
    assert(m.indexOf("VStack") >= 0);
}
