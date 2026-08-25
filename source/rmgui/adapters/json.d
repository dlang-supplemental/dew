/// JSON / YAML-ish object trees → markup.
module rmgui.adapters.json;

import rmgui.markup.ctfe;
import std.json;
import std.array : Appender, appender;
import std.conv : to;

string jsonToMarkup(string src)
{
    auto j = parseJSON(src);
    auto app = appender!string();
    emit(j, app);
    return app.data;
}

private void emit(JSONValue v, ref Appender!string app)
{
    if (v.type != JSONType.object)
        return;
    auto type = "type" in v.object ? v["type"].str : "Container";
    app.put(type);
    app.put(" {\n");
    foreach (k, val; v.object)
    {
        if (k == "type" || k == "children")
            continue;
        app.put("  ");
        app.put(k);
        app.put(": ");
        if (val.type == JSONType.string)
        {
            app.put(`"`);
            app.put(val.str);
            app.put(`"`);
        }
        else if (val.type == JSONType.integer)
            app.put(to!string(val.integer));
        else if (val.type == JSONType.float_)
            app.put(to!string(val.floating));
        else if (val.type == JSONType.true_)
            app.put("true");
        else if (val.type == JSONType.false_)
            app.put("false");
        app.put(";\n");
    }
    if ("children" in v.object && v["children"].type == JSONType.array)
    {
        foreach (c; v["children"].array)
            emit(c, app);
    }
    app.put("}\n");
}

template importJson(string src)
{
    enum importJson = compileMarkup(jsonToMarkup(src));
}

unittest
{
    import std.string : indexOf;
    auto m = jsonToMarkup(`{"type":"VStack","spacing":8,"children":[{"type":"Text","text":"Hi"}]}`);
    assert(m.indexOf("VStack") >= 0);
}
