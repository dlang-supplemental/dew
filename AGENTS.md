# Agent notes — rmgui

Project facts for agents. Workstation/env facts live only in `$CODE_ROOT/MEMORIES.md`.

- DUB package name is `rmgui`; GitHub repo is `dlang-supplemental/rmgui`
- Pure D typed DSL is canonical; CTFE markup and format adapters lower into it
- Default paint path is the software backend; enable `RmguiVello` + `vello-d` for GPU
- Depend on `tgc` (`~>0.1.1`); UI frame path prefers arenas / `@nogc`; domain logic may use `tgc`
- GPU: `-c gpu` pulls registry `vello-d` (`~>0.1.3`) + `bindbc-wgpu` — never path-pin local `../vello-d`
- Default/headless configs set `RmguiHeadless` so CI does not run the Vello Rust pre-build
- 3D embeds: wgpu (`bindbc-wgpu`) to stay in the same API family as Vello
- Registry metadata in `assets/`; categories: `library.gui`, `library.graphics`, `library.nogc`
- Publish via sibling `dub-publish` / `dubx`
- Version source of truth: `VERSION` + git tag `vX.Y.Z`
