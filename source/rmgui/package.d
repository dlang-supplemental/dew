/**
 * rmgui — modern retained-mode GUI for D.
 *
 * Layers: typed DSL → scene/layout → display list → software or Vello backend.
 * CTFE markup and foreign adapters (Slint, QML, KDL, …) lower into the same DSL.
 */
module rmgui;

public import rmgui.units;
public import rmgui.arena;
public import rmgui.node;
public import rmgui.signal;
public import rmgui.dsl;
public import rmgui.layout;
public import rmgui.display_list;
public import rmgui.paint_pass;
public import rmgui.event;
public import rmgui.app;
public import rmgui.markup.ctfe;
public import rmgui.adapters;
public import rmgui.backend;

enum string rmguiVersion = {
    import std.string : strip;
    return import("VERSION").strip;
}();
