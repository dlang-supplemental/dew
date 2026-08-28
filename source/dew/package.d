/**
 * dew — modern retained-mode GUI for D.
 *
 * Layers: typed DSL → scene/layout → display list → software or Vello backend.
 * CTFE markup and foreign adapters (Slint, QML, KDL, …) lower into the same DSL.
 *
 * Tagline: Dew it!
 */
module dew;

public import dew.units;
public import dew.scale;
public import dew.arena;
public import dew.node;
public import dew.input;
public import dew.signal;
public import dew.dsl;
public import dew.layout;
public import dew.display_list;
public import dew.paint_pass;
public import dew.event;
public import dew.app;
public import dew.markup.ctfe;
public import dew.adapters;
public import dew.backend;

enum string dewVersion = {
    import std.string : strip;
    // Unique string-import name so dependents' VERSION files do not shadow.
    return import("DEW_VERSION").strip;
}();

enum string dewSlogan = "Dew it!";
