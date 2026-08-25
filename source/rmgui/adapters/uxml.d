/// Unity UI Toolkit UXML subset → markup.
module rmgui.adapters.uxml;

import rmgui.markup.ctfe;
import std.array : replace, appender;
import std.string : strip, indexOf;

string uxmlToMarkup(string src) @safe pure
{
    auto s = src
        .replace("<ui:VisualElement", "<Container")
        .replace("<ui:Button", "<Button")
        .replace("<ui:Label", "<Text")
        .replace("ui:VisualElement", "Container")
        .replace("ui:Button", "Button")
        .replace("ui:Label", "Text")
        .replace("unity-text", "text");
    // Extremely small XML→brace: <Tag a="b"> → Tag { a: "b";
    auto app = appender!string();
    size_t i;
    while (i < s.length)
    {
        if (s[i] == '<')
        {
            i++;
            bool close = i < s.length && s[i] == '/';
            if (close)
                i++;
            size_t start = i;
            while (i < s.length && s[i] != ' ' && s[i] != '>' && s[i] != '/')
                i++;
            auto tag = s[start .. i];
            if (close)
            {
                app.put("}\n");
                while (i < s.length && s[i] != '>')
                    i++;
                if (i < s.length)
                    i++;
                continue;
            }
            app.put(tag);
            app.put(" {\n");
            while (i < s.length && s[i] != '>' && s[i] != '/')
            {
                while (i < s.length && s[i] == ' ')
                    i++;
                if (i >= s.length || s[i] == '>' || s[i] == '/')
                    break;
                size_t an = i;
                while (i < s.length && s[i] != '=')
                    i++;
                auto attr = s[an .. i].strip;
                if (i < s.length && s[i] == '=')
                    i++;
                if (i < s.length && s[i] == '"')
                {
                    i++;
                    size_t vs = i;
                    while (i < s.length && s[i] != '"')
                        i++;
                    auto val = s[vs .. i];
                    if (i < s.length)
                        i++;
                    auto prop = attr == "text" ? "text" : attr;
                    app.put("  ");
                    app.put(prop);
                    app.put(": \"");
                    app.put(val);
                    app.put("\";\n");
                }
            }
            bool self = i < s.length && s[i] == '/';
            while (i < s.length && s[i] != '>')
                i++;
            if (i < s.length)
                i++;
            if (self)
                app.put("}\n");
            continue;
        }
        i++;
    }
    return app.data;
}

template importUxml(string src)
{
    enum importUxml = compileMarkup(uxmlToMarkup(src));
}

unittest
{
    auto m = uxmlToMarkup(`<ui:Button text="Go" />`);
    assert(m.indexOf("Button") >= 0);
}
