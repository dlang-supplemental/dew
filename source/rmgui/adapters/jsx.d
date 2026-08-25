/// JSX/TSX subset → markup (XML tags with `{expr}` props).
module rmgui.adapters.jsx;

import rmgui.adapters.uxml : uxmlToMarkup;
import rmgui.markup.ctfe;
import std.array : replace;

string jsxToMarkup(string src) @safe pure
{
    auto s = src
        .replace("<VStack", "<VStack")
        .replace("gap={", "spacing=\"")
        .replace("}", "\"");
    // Reuse UXML brace emitter after normalizing to quote attrs
    return uxmlToMarkup(s);
}

template importJsx(string src)
{
    enum importJsx = compileMarkup(jsxToMarkup(src));
}

unittest
{
    assert(jsxToMarkup(`<Button text="Ok" />`).length > 0);
}
