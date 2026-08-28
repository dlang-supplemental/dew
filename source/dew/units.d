/// Layout and style units for dew.
module dew.units;

/// Length with unit tag.
///
/// `Kind.Px` is a **logical** pixel (DIP). Physical framebuffer pixels are
/// obtained via `dew.scale.ScaleFactor` on the paint path — do not bake DPI
/// into widget declarations.
struct Length
{
    float value = 0;
    enum Kind : ubyte { Px, Percent, Auto }
    Kind kind = Kind.Auto;

    static Length px(float v) @safe @nogc pure nothrow
    {
        return Length(v, Kind.Px);
    }

    static Length percent(float v) @safe @nogc pure nothrow
    {
        return Length(v, Kind.Percent);
    }

    static Length auto_() @safe @nogc pure nothrow
    {
        return Length(0, Kind.Auto);
    }

    float resolve(float parent) const @safe @nogc pure nothrow
    {
        final switch (kind)
        {
        case Kind.Px: return value;
        case Kind.Percent: return parent * (value / 100.0f);
        case Kind.Auto: return float.nan;
        }
    }
}

/// UFCS helpers: `12.px`, `50.percent`.
Length px(float v) @safe @nogc pure nothrow { return Length.px(v); }
Length percent(float v) @safe @nogc pure nothrow { return Length.percent(v); }

enum AlignItems : ubyte
{
    Start,
    Center,
    End,
    Stretch,
}

enum JustifyContent : ubyte
{
    Start,
    Center,
    End,
    SpaceBetween,
    SpaceAround,
}

enum Axis : ubyte
{
    Horizontal,
    Vertical,
}

enum FlexWrap : ubyte
{
    NoWrap,
    Wrap,
}
