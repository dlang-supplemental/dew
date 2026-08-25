/// RON (Rusty Object Notation) layout structs → markup.
module dew.adapters.ron;

import dew.markup.ctfe;
import std.array : replace;

string ronToMarkup(string src) @safe pure
{
    return src
        .replace("(", " {")
        .replace(")", "}")
        .replace(":", ": ");
}

template importRon(string src)
{
    enum importRon = compileMarkup(ronToMarkup(src));
}

unittest
{
    assert(ronToMarkup(`VStack(spacing: 8)`).length > 0);
}
