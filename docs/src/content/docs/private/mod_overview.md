---
title: Mod Context Pack - Taj''s Mod for Upload Labs
description: This document
---

## A) What the mod already does (feature inventory)

### HUD/UX

el with a puzzle button in HUD extras; custom tabs and footer (`mod_main.gd` `_setup_for_main`, `extensions/scripts/ui/settings_ui.gd`). Touches HUD overlay at `Main/MainContainer/Overlay` and `ExtrasButtons/Container`.

- Real-time node counter with limit warning inside the settings panel (`mod_main.gd` `_update_node_label`). Reads `Globals.max_window_count` and `Globals.custom_node_limit`.
- Restart-required dialog for settings that need reload (`mod_main.gd` `_show_restart_dialog`). Uses HUD overlay and `Sound.play`.
- Go To Group quick panel (bottom-left) with popup list of groups (`extensions/scripts/utilities/goto_group_panel.gd`, `goto_group_manager.gd`). Uses camera tweening and `Signals.center_camera`.

### Visuals

- Extra glow controls (intensity/strength/bloom/sensitivity) via `WorldEnvironment` (`mod_main.gd` `_apply_extra_glow`).
- UI opacity slider that modulates `HUD/MainContainer` alpha (`mod_main.gd` `_apply_ui_opacity`).
- Expanded group node colors and patterns with persistence (`extensions/scenes/windows/window_group.gd`). Adds pattern overlay and custom color picker.
- Custom wire colors with RGB picker; overrides `Data.resources` and `Data.connectors` (`extensions/scripts/utilities/wire_color_overrides.gd`, `mod_main.gd` `_add_wire_color_section`).
- Custom boot screen text and logo injection (`extensions/scripts/utilities/patcher.gd` `patch_boot_screen`).

### Node graph workflow

- Wire drop node picker: drop a wire on empty canvas to spawn compatible nodes (`extensions/scripts/wire_drop/wire_drop_handler.gd`, `node_compatibility_filter.gd`, `palette_overlay.gd` picker mode). Uses `Signals.connection_droppped` and `Signals.create_connection`.
- Right-click to clear all wires from a connector (`extensions/scripts/wire_drop/wire_clear_handler.gd`). Uses `Signals.delete_connection`.
- Ctrl+A select all nodes on desktop (`extensions/scripts/desktop.gd`).
- Group Z-order fix for contained groups (`extensions/scripts/utilities/node_group_z_order_fix.gd`) with debounced updates.
- Group lock/unlock and Upgrade All for nodes inside group (`extensions/scenes/windows/window_group.gd`, `extensions/scripts/options_bar.gd`).
- Bin node injection with universal receiver inputs (`extensions/scripts/utilities/patcher.gd` `inject_bin_window`, `extensions/scenes/windows/window_bin.gd`, `extensions/scenes/bin_input.gd`, `extensions/scenes/resource_container.gd`).
- 6-input container upgrade for inventory (`extensions/scenes/windows/window_inventory.gd`).
- Node limit control (custom max or unlimited) enforced in window creation, paste, schematics, and wire drop (`mod_main.gd`, `extensions/scripts/windows_menu.gd`, `extensions/scripts/desktop.gd`, `extensions/scripts/schematic_container.gd`, `extensions/scripts/wire_drop/wire_drop_connector.gd`).

### Command palette

- Command palette overlay with fuzzy search, favorites/recents, and navigation breadcrumbs (`extensions/scripts/palette/palette_overlay.gd`, `fuzzy_search.gd`).
- Command registry and default command set (select/deselect, center view, upgrade, settings toggles) (`extensions/scripts/palette/command_registry.gd`, `default_commands.gd`).
- Palette config persistence (favorites/recents/tools enabled) stored in mod config (`extensions/scripts/palette/palette_config.gd`).

### QoL/Shop/Upgrades

- Buy Max button injected into upgrades tab for bulk purchases (`extensions/scripts/utilities/buy_max_manager.gd`).
- Buy Max for selected nodes in options bar (`extensions/scripts/options_bar.gd`).
- Cheats panel (currency/attribute adjustments) in settings UI (`extensions/scripts/utilities/cheat_manager.gd`).
- Mute on focus loss with configurable background volume (`extensions/scripts/utilities/focus_handler.gd`).
- High-quality tiled screenshots with configurable output (`extensions/scripts/utilities/screenshot_manager.gd`).

### Performance/Diagnostics

- Debug log panel with optional verbose logging (`mod_main.gd` `_add_debug_log`).
- Node compatibility cache built deferred to avoid startup stalls (`extensions/scripts/wire_drop/node_compatibility_filter.gd`).
- Z-order fix uses debounced rect hashing to reduce churn (`extensions/scripts/utilities/node_group_z_order_fix.gd`).

### Accessibility

- UI opacity adjustment (`mod_main.gd`).
- Wire color customization for better contrast (`wire_color_overrides.gd`).
- Focus mute to reduce background audio fatigue (`focus_handler.gd`).

### Mod interoperability

- Script extensions applied through ModLoader (`mod_main.gd` `_init` with `ModLoaderMod.install_script_extension`).
- Uses game globals and signals (`D:\SteamLibrary\steamapps\common\Upload Labs\Upload Labs Source Files\scripts\signals.gd`, `scripts\data.gd`, `scripts\utils.gd`) rather than custom hooks.

### Misc

- Additional schematic icon options in save UI (`extensions/scripts/popup_schematic.gd`).
- Schematic sanitizer for missing `window` keys (`extensions/scripts/utilities/patcher.gd` `sanitize_schematics`).

## B) UI/UX patterns and components already used

- Settings panel: `PanelContainer` with title/content/footer and tab buttons (`extensions/scripts/ui/settings_ui.gd`).
- Toggle rows: label + `CheckButton` (`settings_ui.gd` `add_toggle`).
- Slider rows: label + `HSlider` with value label (`settings_ui.gd` `add_slider`).
- Action buttons: `TabButton` style (`settings_ui.gd` `add_button`, `mod_main.gd` debug buttons).
- Palette overlay: dim background + centered panel + search + results list + breadcrumbs (`extensions/scripts/palette/palette_overlay.gd`).
- Color picker: HSV plane, sliders, swatches, recents, RGBA inputs (`extensions/scripts/ui/color_picker_panel.gd`).
- Popup lists: `PopupMenu` used in group window for pattern selection (`extensions/scenes/windows/window_group.gd`).
- HUD buttons injected into existing containers (extras buttons, options bar, bottom-left panel).
- Notifications via `Signals.notify.emit` and `Sound.play` throughout.

## C) Input model

- Palette: middle mouse button toggles (`extensions/scripts/palette/palette_controller.gd`), XButton1/XButton2 for back/forward. Keyboard in palette: arrows, Enter, Esc, Tab, Left/Backspace for back, Ctrl+F to favorite (`extensions/scripts/palette/palette_overlay.gd`).
- Wire clear: right-click on connector (`extensions/scripts/wire_drop/wire_clear_handler.gd`).
- Desktop: Ctrl+A selects all nodes (`extensions/scripts/desktop.gd`).
- Go To Group popup: Esc or click outside to close (`extensions/scripts/utilities/goto_group_panel.gd`).
- Settings button toggles panel; click outside closes (`extensions/scripts/ui/settings_ui.gd`, `mod_main.gd` `_input`).

Note: README mentions Spacebar for palette; no Spacebar handling exists in code.

## D) Data & persistence

- Main mod config: `user://tajs_mod_config.json` managed by `extensions/scripts/utilities/config_manager.gd`.
- Palette config stored under `"palette"` inside the main config (`extensions/scripts/palette/palette_config.gd`), with migration from legacy `user://tajs_mod_palette.json`.
- Wire color overrides stored in `wire_colors_hex` inside mod config (`wire_color_overrides.gd`).
- Group custom data saved via `save()`/`export()` in `extensions/scenes/windows/window_group.gd` (pattern index, lock state, custom_color).
- Node limit stored in config and mirrored to `Globals.custom_node_limit` (`mod_main.gd`, `extensions/scripts/globals.gd`).
- Schematics saved through game `Data.save_schematic` with extended icon list (`extensions/scripts/popup_schematic.gd`).

## E) Architecture overview

- Entry point: `mod_main.gd` preloads services, installs script extensions, and wires managers during `_init` and `_ready`.
- Services/managers: Config, ScreenshotManager, PaletteController, WireClearHandler, FocusHandler, WireColorOverrides, GotoGroupManager/Panel, NodeGroupZOrderFix, BuyMaxManager, CheatManager.
- Initialization flow: `_init` installs extensions and creates managers; `_ready` builds shared color picker, applies wire color overrides, applies node limit, injects bin window, defers sanitation; waits for Main/HUD before UI setup.
- Update loop: `_process` patches desktop once and refreshes node info label; avoids repeated heavy operations.
- Performance safeguards: deferred cache building for compatibility filter, debounced z-order fix, screenshot tiling to avoid oversized textures.

## F) Constraints & risks

- Heavy reliance on specific scene tree paths (e.g., `Main/MainContainer/Overlay`, `ExtrasButtons/Container`, upgrades tab structure). Game UI refactors will break injections.
- Desktop script patching replaces script at runtime (`patcher.gd` `patch_desktop_script`), which can desync if base script changes.
- Wire compatibility cache loads each window scene to inspect ResourceContainers; can be expensive on large window sets.
- Wire color overrides mutate `Data.resources` and `Data.connectors` globally; other mods altering the same data can conflict.
- Bin window inputs skip tutorial to avoid breaking tutorial steps (`window_bin.gd`).
- Drag dead zone feature is blocked by a base class_name conflict (not implementable via script extension per comment in `mod_main.gd`).
- Palette input is hard-coded to mouse buttons and keyboard; no dynamic remap hook exists.

Potential breakpoints for game updates:

- `Data.windows` schema, `Data.schematics` shape, or connector APIs.
- Signal names/typos (e.g., `Signals.connection_droppped`) used by wire drop.
- Camera and HUD node names used by screenshot and UI injection.
