# Gradient Data Layer

A [Transport Fever 3](https://transportfever3.com) mod that adds a data layer coloring built tracks by their gradient, so you can find sections that are too steep for your trains.

Planned:

- A gradient data layer for tracks.
- The steepest gradient of a line, shown in the line info.

**Status:** prototype. A button next to the Data Layers button greys out the map, colors every track and road segment by its steepest gradient (green → yellow → red → black; tracks up to 9%, roads up to 20%), and shows gradients in a tooltip.

## Repository layout

```
nulldozzer_gradients/       The mod itself (this folder is what the game loads)
  mod.json                   Technical definition: mod id, revision, scripts
  _metadata/modinfo.json     Name, description, tags shown in the Mod Hub
  content/gui/nulldozzer_gradients/
    gradient_layer.res.lua   Registers the button in the game's mod button area
    gradient_layer.script.tl Button, tool window, legend and coloring
    gradient_layer.css.lua   Window position
    gradient_tooltip.tl      Hover tooltip
    network_scan.tl          Finds track and road segments
    edge_profile.tl          Measures gradients along a segment
    gradient_scale.tl        Gradient to color
    point_grid.tl            Spatial lookup for the tooltip
    *.d.tl                   Teal type definitions for the modules
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

Then start the game and enable **Gradient Data Layer** in the mod selection when starting or loading a game. Its button appears to the right of the Data Layers button.

After editing scripts, exit to the main menu and load the save again. Edits to already loaded GUI scripts also apply with <kbd>AltGr</kbd>+<kbd>Shift</kbd>+<kbd>R</kbd> (debug mode); new files need the reload. The game log is `userdata/<steam-id>/3493540/local/crash_dump/stdout.txt`.

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
