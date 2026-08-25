/// Dioxus RSX / Leptos-style brace tags → markup.
module rmgui.adapters.rsx;

import rmgui.markup.ctfe;
import std.array : replace;

string rsxToMarkup(string src) @safe pure
{
    return src
        .replace("div", "Container")
        .replace("class:", "// class:")
        .replace("onclick:", "on_click:");
}

template importRsx(string src)
{
    enum importRsx = compileMarkup(rsxToMarkup(src));
}

unittest
{
    assert(rsxToMarkup(`VStack { Text { text: "x"; } }`).length > 0);
}
