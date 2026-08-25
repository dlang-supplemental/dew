/// QML subset → dew markup (near 1:1 with Slint ancestor syntax).
module dew.adapters.qml;

import dew.adapters.slint : slintToMarkup;
import dew.markup.ctfe;

string qmlToMarkup(string src) @safe pure
{
    return slintToMarkup(src
        .replace("Column", "VStack")
        .replace("Row", "HStack")
        .replace("Item", "Container"));
}

template importQml(string src)
{
    enum importQml = compileMarkup(qmlToMarkup(src));
}

private string replace(string s, string a, string b) @safe pure
{
    import std.array : replace;
    return s.replace(a, b);
}

unittest
{
    auto m = qmlToMarkup(`Column { spacing: 4; Text { text: "Q"; } }`);
    assert(m.length > 0);
}
