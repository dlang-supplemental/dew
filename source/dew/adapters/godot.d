/// Godot `.tscn` Control nodes → markup.
module dew.adapters.godot;

import dew.markup.ctfe;
import std.array : appender, replace;
import std.string : strip, splitLines, startsWith, indexOf;

string godotToMarkup(string src) @safe pure
{
    auto app = appender!string();
    foreach (line; src.splitLines)
    {
        auto t = line.strip;
        if (t.startsWith("[node") && t.indexOf("type=\"VBoxContainer\"") >= 0)
            app.put("VStack {\n");
        else if (t.startsWith("[node") && t.indexOf("type=\"HBoxContainer\"") >= 0)
            app.put("HStack {\n");
        else if (t.startsWith("[node") && t.indexOf("type=\"Button\"") >= 0)
            app.put("Button {\n");
        else if (t.startsWith("[node") && t.indexOf("type=\"Label\"") >= 0)
            app.put("Text {\n");
        else if (t.startsWith("text = "))
        {
            auto v = t.replace("text = ", "text: ");
            app.put("  ");
            app.put(v);
            app.put(";\n}\n");
        }
    }
    return app.data;
}

template importGodot(string src)
{
    enum importGodot = compileMarkup(godotToMarkup(src));
}

unittest
{
    auto m = godotToMarkup(`[node name="B" type="Button"]
text = "Hi"`);
    assert(m.indexOf("Button") >= 0);
}
