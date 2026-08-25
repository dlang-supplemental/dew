# Agent notes — dew

Project facts for agents. Workstation/env facts live only in `$CODE_ROOT/MEMORIES.md`.

- DUB package name is `dew`; GitHub repo is `dlang-supplemental/dew`
- Former name: `rmgui` (DUB package **removed** from code.dlang.org; use `dew` only)
- Tagline: **Dew it!** (not “Just Dew it” — avoid Nike slogan parody in product chrome)
- Pure D typed DSL is canonical; CTFE markup and format adapters lower into it
- Companion app-kit: `dlang-supplemental/dui` (depends on `dew`)
- GPU: `-c gpu` pulls registry `vello-d` (`~>0.1.3`) + `bindbc-wgpu` — never path-pin local `../vello-d`
- Default/headless configs set `DewHeadless` so CI does not run the Vello Rust pre-build
- Pointer: `App.pointers` (`PointerRouter`) captures contacts; button `onClick` fires on **Up**
- 3D embeds: wgpu (`bindbc-wgpu`) to stay in the same API family as Vello
- DUB versions: keep `version` in `dub.sdl` in sync with `VERSION` / `DEW_VERSION` / tag `vX.Y.Z`
- Registry metadata in `assets/`; categories: `library.gui`, `library.graphics`, `library.nogc`
- Version source of truth: `VERSION` + git tag `vX.Y.Z` (also keep `DEW_VERSION` in sync for `import`)
