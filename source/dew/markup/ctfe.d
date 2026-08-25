/**
 * CTFE markup → Pure D typed DSL lowering (Slint/QML-inspired brace syntax).
 *
 * Example:
 * ---
 * enum src = `VStack { spacing: 12; Text { text: "Hi"; bold: true; } }`;
 * mixin(uiMarkup!src);
 * ---
 */
module dew.markup.ctfe;

/// Compile-time entry: returns D code instantiating the typed DSL.
template uiMarkup(string src)
{
    enum uiMarkup = compileMarkup(src);
}

/// Parse declarative markup into a D expression string.
string compileMarkup(string src) @safe pure
{
    size_t i = 0;
    skipWs(src, i);
    auto expr = parseElement(src, i);
    skipWs(src, i);
    if (i != src.length)
        return `assert(0, "markup: trailing junk")`;
    return expr;
}

private void skipWs(string s, ref size_t i) @safe pure nothrow
{
    while (i < s.length)
    {
        char c = s[i];
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r')
        {
            i++;
            continue;
        }
        if (c == '/' && i + 1 < s.length && s[i + 1] == '/')
        {
            i += 2;
            while (i < s.length && s[i] != '\n')
                i++;
            continue;
        }
        break;
    }
}

private bool isIdentStart(char c) @safe pure nothrow
{
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '_';
}

private bool isIdent(char c) @safe pure nothrow
{
    return isIdentStart(c) || (c >= '0' && c <= '9');
}

private string parseIdent(string s, ref size_t i) @safe pure
{
    skipWs(s, i);
    size_t start = i;
    if (i >= s.length || !isIdentStart(s[i]))
        return null;
    i++;
    while (i < s.length && isIdent(s[i]))
        i++;
    return s[start .. i];
}

private string parseString(string s, ref size_t i) @safe pure
{
    skipWs(s, i);
    if (i >= s.length || s[i] != '"')
        return null;
    i++;
    size_t start = i;
    while (i < s.length && s[i] != '"')
    {
        if (s[i] == '\\' && i + 1 < s.length)
            i += 2;
        else
            i++;
    }
    auto body_ = s[start .. i];
    if (i < s.length && s[i] == '"')
        i++;
    return `"` ~ body_ ~ `"`;
}

private string parseNumber(string s, ref size_t i) @safe pure
{
    skipWs(s, i);
    size_t start = i;
    if (i < s.length && (s[i] == '-' || s[i] == '+'))
        i++;
    bool any;
    while (i < s.length && ((s[i] >= '0' && s[i] <= '9') || s[i] == '.'))
    {
        any = true;
        i++;
    }
    // optional unit suffix px/%
    if (i + 1 < s.length && s[i] == 'p' && s[i + 1] == 'x')
        i += 2;
    else if (i < s.length && s[i] == '%')
        i++;
    if (!any)
        return null;
    return s[start .. i];
}

private string parseValue(string s, ref size_t i) @safe pure
{
    skipWs(s, i);
    if (i < s.length && s[i] == '"')
        return parseString(s, i);
    if (i < s.length && (s[i] == '-' || s[i] == '+' || (s[i] >= '0' && s[i] <= '9')))
    {
        auto n = parseNumber(s, i);
        // Strip unit for D float literal
        if (n.length >= 2 && n[$ - 2 .. $] == "px")
            return n[0 .. $ - 2];
        if (n.length && n[$ - 1] == '%')
            return n[0 .. $ - 1];
        return n;
    }
    auto id = parseIdent(s, i);
    if (id == "true" || id == "false")
        return id;
    if (id !is null)
        return id; // callback / symbol name (no & — DSL wraps as delegate)
    return null;
}

private string mapProp(string name, string value) @safe pure
{
    // Shared vocabulary with DSL method names
    switch (name)
    {
    case "spacing":
        return ".spacing(" ~ value ~ ")";
    case "padding":
        return ".padding(" ~ value ~ ")";
    case "width":
        return ".width(" ~ value ~ ")";
    case "height":
        return ".height(" ~ value ~ ")";
    case "font_size":
    case "font-size":
        return ".fontSize(" ~ value ~ ")";
    case "bold":
        return ".bold(" ~ value ~ ")";
    case "flex_grow":
    case "flex-grow":
        return ".flexGrow(" ~ value ~ ")";
    case "text":
        // handled specially for Text/Button ctor
        return null;
    case "on_click":
    case "on-click":
        return ".onClick(() { " ~ value ~ "(); })";
    default:
        return "." ~ name ~ "(" ~ value ~ ")";
    }
}

private string parseElement(string s, ref size_t i) @safe pure
{
    auto tag = parseIdent(s, i);
    if (tag is null)
        return `assert(0, "markup: expected element")`;

    skipWs(s, i);
    if (i >= s.length || s[i] != '{')
        return mapCtor(tag, null, null, null);

    i++; // {
    string textLit;
    string mods;
    string kids;
    while (true)
    {
        skipWs(s, i);
        if (i >= s.length)
            return `assert(0, "markup: unclosed block")`;
        if (s[i] == '}')
        {
            i++;
            break;
        }
        // Lookahead: property `name:` vs nested element `Name {`
        size_t save = i;
        auto name = parseIdent(s, i);
        skipWs(s, i);
        if (name !is null && i < s.length && s[i] == ':')
        {
            i++; // :
            auto val = parseValue(s, i);
            skipWs(s, i);
            if (i < s.length && s[i] == ';')
                i++;
            if (name == "text")
                textLit = val;
            else
            {
                auto m = mapProp(name, val);
                if (m !is null)
                    mods ~= m;
            }
            continue;
        }
        // nested element — rewind and parse
        i = save;
        auto child = parseElement(s, i);
        skipWs(s, i);
        if (i < s.length && s[i] == ';')
            i++;
        if (kids.length)
            kids ~= ", ";
        kids ~= child;
    }
    return mapCtor(tag, textLit, mods, kids);
}

private string mapCtor(string tag, string textLit, string mods, string kids) @safe pure
{
    string base;
    switch (tag)
    {
    case "VStack":
    case "VerticalBox":
        base = kids.length ? "VStack(" ~ kids ~ ")" : "VStack()";
        break;
    case "HStack":
    case "HorizontalBox":
        base = kids.length ? "HStack(" ~ kids ~ ")" : "HStack()";
        break;
    case "Container":
    case "Rectangle":
    case "Box":
        base = kids.length ? "Container(" ~ kids ~ ")" : "Container()";
        break;
    case "Text":
        base = "Text(" ~ (textLit.length ? textLit : `""`) ~ ")";
        break;
    case "Button":
        base = "Button(" ~ (textLit.length ? textLit : `""`) ~ ")";
        break;
    case "Spacer":
        base = "Spacer()";
        break;
    default:
        // Custom component: Tag() then mods; children as .child if any
        base = tag ~ "()";
        if (kids.length)
            mods ~= ".children([" ~ kids ~ "])";
        break;
    }
    return base ~ (mods ? mods : "");
}

unittest
{
    enum code = compileMarkup(`
        VStack {
            spacing: 12;
            Text { text: "Hello"; bold: true; font_size: 16; }
            Button { text: "Save"; on_click: saveProfile; }
        }
    `);
    assert(code.length > 0);
    assert(code[0 .. 6] == "VStack");
}
