# Gradient Data Layer

A [Transport Fever 3](https://transportfever3.com) mod that adds a data layer coloring built tracks by their gradient, so you can find sections that are too steep for your trains.

Planned:

- A gradient data layer for tracks.
- The steepest gradient of a line, shown in the line info.

**Status:** skeleton only. The mod loads and writes a line to the in-game console, but has no features yet.

## Repository layout

```
nulldozzer_gradients/       The mod itself (this folder is what the game loads)
  mod.json                   Technical definition: mod id, revision, scripts
  _metadata/modinfo.json     Name, description, tags shown in the Mod Hub
  content/mod.script.tl      Mod script functions (Teal)
tlconfig.lua, all_def.tl     Teal type-checking config for the editor
```

Everything outside `nulldozzer_gradients/` is development tooling and is not part of the mod.

## Local development

Link the mod folder into the game's staging area, so the game loads it straight from this repository. In PowerShell:

```powershell
New-Item -ItemType Junction `
  -Path "C:\Program Files (x86)\Steam\userdata\<steam-id>\3493540\local\staging_area\nulldozzer_gradients" `
  -Target "<path-to-this-repo>\nulldozzer_gradients"
```

Then start the game, enable **Gradient Data Layer** in the mod selection when starting or loading a game, and open the console (the key below <kbd>Esc</kbd>). It should show `[nulldozzer_gradients] loaded`.

Turning on debug mode in the game's advanced settings enables extra tools for testing, such as the debug window (<kbd>AltGr</kbd>+<kbd>D</kbd>).

## Editor setup (optional)

For autocompletion and type checking in VS Code:

1. Install [Teal](https://github.com/teal-language/tl) (the `tl` compiler).
2. Install the recommended [Teal extension](https://marketplace.visualstudio.com/items?itemName=pdesaulniers.vscode-teal) and set the path to the `tl` executable in its settings.
3. If the game is not in the default Steam library, adjust the path in `tlconfig.lua`.

## References

- [TF3 Modding Manual](https://wiki.transportfever3.com/doku.php?id=modding:start)
- [Mod Definition](https://wiki.transportfever3.com/doku.php?id=modding:general:moddefinition) (`mod.json`, `modinfo.json`, `strings.json`)
- [Mod Parameters & Scripts](https://wiki.transportfever3.com/doku.php?id=modding:general:modscripts)
- [Guidelines & Requirements](https://wiki.transportfever3.com/doku.php?id=modding:general:guidelines)
- [Scripting API Reference](https://wiki.transportfever3.com/script-doc/)
