/**
 * Headless gallery — validates DSL, markup, layout, software paint, tgc hook.
 * GPU hosts attach VelloRenderBackend to an HWND separately.
 */
module gallery;

import std.stdio;
import tgc.gcobj;
import rmgui;

void saveProfile() @safe
{
    writeln("saveProfile clicked");
}

void main()
{
    writeln("rmgui gallery ", rmguiVersion);

    App app;
    beginUi(app.ui);
    scope (exit)
        endUi();

    auto root = VStack(
        Text("Engine Configuration").fontSize(18).bold(),
        HStack(
            Text("Render Backend:"),
            Text("Vello + wgpu3d")
        ),
        Button("Apply").onClick(&saveProfile)
    ).spacing(8).padding(16);

    auto card = mixin(uiMarkup!`
        VStack {
            spacing: 12;
            Text { text: "Profile Settings"; bold: true; }
            Button { text: "Save"; on_click: saveProfile; }
        }
    `);

    app.setRoot(HStack(root, card).spacing(24).padding(8));
    auto sw = new SoftwareBackend(800, 480);
    app.backend = sw;
    app.resize(800, 480);
    app.frame();

    writeln("nodes=", app.ui.store.length, " cmds=", app.list.cmds.length,
        " frames=", sw.frameCount);
    assert(sw.frameCount == 1);
    assert(app.list.cmds.length > 0);

    auto sl = slintToMarkup(`VerticalBox { spacing: 4px; Text { text: "Slint"; } }`);
    assert(sl.length > 0);

    auto wgpu = new Wgpu3dViewport();
    assert(wgpu.initHeadless(320, 240));

    writeln("gallery OK");
}
