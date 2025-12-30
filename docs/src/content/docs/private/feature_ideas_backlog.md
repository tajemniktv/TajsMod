---
title: Feature Ideas Backlog - Taj's Mod
description: This document consolidates all mod ideas, feature backlog, roadmap, and technical context into a single reference.
---

## HUD/UX and Settings

**1) Settings Search Bar**
DONE

**2) Compact Settings Mode**
Player value: fit more options on screen for small monitors.
User flow: toggle Compact Mode in General tab to reduce row height and font size.
Implementation sketch: Touch `settings_ui.gd` to add a global style toggle; add config key in `config_manager.gd`. Hooks: none. Data: `compact_ui` flag. UI: apply theme overrides to rows and panel margins.
Effort: S | Risk: low | Save compatibility: safe

**3) Toast History Panel**
DONE

**4) Restart Required Banner**
DONE

**5) Profile Switcher (Minimal)**
Player value: quick switch between visual/QoL presets.
User flow: choose a profile from dropdown in settings; it swaps mod config sections.
Implementation sketch: Touch `config_manager.gd` to store profiles; `settings_ui.gd` to add dropdown; `mod_main.gd` to apply. Hooks: none. Data: nested config dictionaries. UI: OptionButton.
Effort: M | Risk: medium | Save compatibility: safe

**6) HUD Quick Toggles Bar**
Player value: toggle wire colors, glow, palette tools without opening settings.
User flow: small expandable strip in HUD overlay with 3-5 toggles.
Implementation sketch: Touch `mod_main.gd` `_setup_for_main` to add buttons; reuse `SettingsUI` callbacks. Hooks: none. Data: existing config keys. UI: row of `ButtonMenu` icons.
Effort: S | Risk: low | Save compatibility: safe

**7) Context Help Tooltips**
DONE

**8) Palette Onboarding Tooltip**
DONE

## Visuals and Customization

**9) Wire Color Presets**
Player value: quick swap between color themes (high-contrast, pastel, monochrome).
User flow: pick a preset from Visuals tab; wires update.
Implementation sketch: Touch `wire_color_overrides.gd` to load preset tables; `mod_main.gd` to add preset dropdown. Hooks: none. Data: preset id in config. UI: OptionButton + Apply.
Effort: S | Risk: low | Save compatibility: safe

**10) Group Pattern Opacity Slider**
DONE

**11) UI Color Theme Variants**
Player value: match HUD to personal taste (cool, warm, low-contrast).
User flow: choose theme variant in Visuals tab, applies to mod panels.
Implementation sketch: Touch `settings_ui.gd`, `palette_overlay.gd`, `color_picker_panel.gd` to apply theme colors. Hooks: none. Data: theme id in config. UI: OptionButton.
Effort: M | Risk: medium | Save compatibility: safe

**12) Boot Screen Variant Selector**
Player value: choose between modded boot art, vanilla, or minimalist.
User flow: pick boot style in Debug tab.
Implementation sketch: Touch `mod_main.gd` and `patcher.gd` to swap textures/labels. Hooks: Boot node. Data: config key `boot_style`. UI: radio or dropdown.
Effort: M | Risk: medium | Save compatibility: safe

**13) Group Title Glow**
Player value: make groups easier to locate.
User flow: toggle glow outline on group title bars.
Implementation sketch: Touch `window_group.gd` to add stylebox glow or modulate. Hooks: none. Data: config key or per-group toggle. UI: button in group title.
Effort: S | Risk: low | Save compatibility: maybe (per-group flag if stored)

**14) Wire Thickness Slider**
Player value: improve readability in dense graphs.
User flow: slider in Visuals to set wire width.
Implementation sketch: Touch connector drawing code in base game is not directly patched; workaround: override connector script if extension is allowed. Needs hook: connector line width property. UI: slider in Visuals. Data: config key.
Effort: L | Risk: high | Save compatibility: safe

**15) Background Grid Density**
Player value: better spatial orientation at different zoom levels.
User flow: choose grid density in Visuals.
Implementation sketch: Touch `mod_main.gd` to find `Main/HUD/Lines` or `Desktop/Lines` and adjust properties if exposed; may require new hook in base grid script. Data: config key. UI: slider.
Effort: M | Risk: medium | Save compatibility: safe

**16) Screenshot Watermark Toggle**
DONE

## Node Graph Workflow Boosters

**17) Box Select to Group**
Player value: instant grouping for organization.
User flow: select nodes, run action to create group bounding selected nodes.
Implementation sketch: Touch `default_commands.gd` or new utility; use `Signals.create_window` to spawn group at bounds; set group size. Hooks: `Globals.selections`, `Signals.create_window`. Data: none. UI: palette command + hotkey.
Effort: M | Risk: medium | Save compatibility: safe

**18) Snap Align Left/Right/Top/Bottom**
Player value: clean layouts fast.
User flow: select nodes, run Align Left, etc.
Implementation sketch: Touch `default_commands.gd` or new utility; move windows via `Signals.move_selection` or direct position changes. Hooks: `Signals.selection_set` or `Globals.selections`. Data: none. UI: palette commands.
Effort: S | Risk: low | Save compatibility: safe

**19) Distribute Horizontally/Vertically**
Player value: even spacing for large selections.
User flow: select nodes, run Distribute H or V.
Implementation sketch: Similar to alignment; compute bounds from `Globals.selections`. Hooks: none. Data: none. UI: palette command.
Effort: S | Risk: low | Save compatibility: safe

**20) Auto-Arrange by Category**
Player value: auto layout by node type.
User flow: run action, nodes cluster by Data.windows category.
Implementation sketch: Touch `default_commands.gd`; use `Data.windows` to map category; position in grid. Hooks: none. Data: none. UI: palette command.
Effort: M | Risk: medium | Save compatibility: safe

**21) Lasso Select Connectors**
Player value: faster wire cleanup.
User flow: drag a lasso to select connectors and clear them.
Implementation sketch: Needs connector selection support; potential workaround: iterate connectors by screen rect. Touch `wire_clear_handler.gd` and maybe extend selection in `Globals`. Hooks: `Signals.selection_set` is available but connectors selection is limited. Data: none. UI: new tool mode.
Effort: L | Risk: high | Save compatibility: safe

**22) Wire Reroute (Swap Source/Target)**
Player value: fix wiring mistakes without delete/reconnect.
User flow: select a connector, choose new compatible target from list.
Implementation sketch: Touch `wire_drop_connector.gd` and add a picker mode; use `Signals.delete_connection` + `Signals.create_connection`. Hooks: `Signals.connection_created`. Data: none. UI: palette action + popup list.
Effort: M | Risk: medium | Save compatibility: safe

**23) Multi-Connect Batch**
Player value: connect one output to many compatible inputs quickly.
User flow: select an output, choose multiple targets from list, auto-connect.
Implementation sketch: Use `node_compatibility_filter.gd` to list candidates; call `Signals.create_connection` in loop. Hooks: `Signals.create_connection`. Data: none. UI: picker with multi-select.
Effort: L | Risk: medium | Save compatibility: safe

**24) Group Color Sync to Contents**
Player value: group color reflects dominant resource type.
User flow: press button to auto-pick group color based on contained nodes.
Implementation sketch: Touch `window_group.gd` to analyze nodes in bounds and map to resource colors (via `Data.resources` and `Data.connectors`). Hooks: none. Data: store `custom_color`. UI: button in group title.
Effort: M | Risk: medium | Save compatibility: maybe

**25) Node Limit Meter in HUD**
Player value: see node usage without opening settings.
User flow: small text in HUD top bar with warning color at 90 percent.
Implementation sketch: Touch `mod_main.gd` to add label to HUD; reuse `_update_node_label`. Hooks: none. Data: none. UI: Label in overlay.
Effort: S | Risk: low | Save compatibility: safe

**26) Bookmark Camera Positions**
Player value: jump between areas of large graphs.
User flow: save 3-5 bookmarks and jump via palette.
Implementation sketch: Touch `palette_config.gd` for bookmark list; store positions in config; use `Signals.center_camera` or camera tween. Hooks: none. Data: `camera_bookmarks`. UI: palette commands + small HUD list.
Effort: M | Risk: medium | Save compatibility: safe

**27) Quick Replace Node**
Player value: swap node type without re-wiring.
User flow: select a node, choose replacement from picker; connections transfer if compatible.
Implementation sketch: Use `window.save()` + replace with new window; rewire matching ResourceContainers. Touch `wire_drop_connector.gd` and new utility. Hooks: `Signals.create_window`, `Signals.delete_connection`. Data: none. UI: palette action.
Effort: L | Risk: high | Save compatibility: safe

**28) Selection Stats Panel**
Player value: see total cost, output, or count for selected nodes.
User flow: select nodes; panel shows aggregate info.
Implementation sketch: Touch `mod_main.gd` to add a small panel; read node properties like `level`, `cost`. Hooks: `Signals.selection_set`. Data: none. UI: Panel in HUD overlay.
Effort: M | Risk: medium | Save compatibility: safe

**29) Auto-Expand Group to Fit Contents**
Player value: keep groups tidy after moving nodes.
User flow: click button to resize group to bounding box of enclosed nodes.
Implementation sketch: Touch `window_group.gd` to compute bounds from contained nodes and set size. Hooks: none. Data: none. UI: button in group title popup.
Effort: S | Risk: low | Save compatibility: safe

**30) Node Search and Focus**
Player value: find nodes by name or type quickly.
User flow: use palette to search nodes and center camera on result.
Implementation sketch: Touch `palette_overlay.gd` (new picker mode) or add command in `default_commands.gd`; use `Data.windows` and `Globals.desktop` children. Hooks: none. Data: none. UI: palette search results.
Effort: M | Risk: medium | Save compatibility: safe

## Command Palette Actions (new)

**31) Palette Action: Toggle Wire Drop Menu**
DONE

**32) Palette Action: Clear All Wires in Selection**
DONE

**33) Palette Action: Lock/Unlock Selected Groups**
Player value: protect layout.
User flow: select group nodes, run Lock or Unlock.
Implementation sketch: Touch `default_commands.gd`; call `toggle_lock` if available. Hooks: `Globals.selections`. Data: group save already stores `locked`. UI: action only when groups selected.
Effort: S | Risk: low | Save compatibility: safe

**34) Palette Action: Toggle Palette Tools Mode**
Player value: quick opt-in to gameplay tools.
User flow: run Enable Tools or Disable Tools in palette.
Implementation sketch: Use `palette_config.gd` `set_tools_enabled`; update context. Hooks: none. Data: palette config. UI: palette actions with OPT-IN badge.
Effort: S | Risk: low | Save compatibility: safe

**35) Palette Action: Set Node Limit (Presets)**
Player value: one-tap limit changes.
User flow: choose presets like 400, 800, unlimited.
Implementation sketch: Touch `default_commands.gd`; call `mod_main.set_node_limit`. Hooks: none. Data: config `node_limit`. UI: palette category with preset actions.
Effort: S | Risk: low | Save compatibility: safe

**36) Palette Action: Jump to Group (List)**
DONE

**37) Palette Action: Toggle UI Opacity Cycle**
DONE

**38) Palette Action: Screenshot (Area of Selection)**
WIP

**39) Palette Action: Focus on Money/Research Nodes**
Player value: find key economy nodes quickly.
User flow: run Focus Money Nodes; camera centers on cluster.
Implementation sketch: Iterate windows for resource containers with matching resource; use `Signals.center_camera`. Hooks: none. Data: `Data.resources`. UI: palette actions.
Effort: M | Risk: medium | Save compatibility: safe

**40) Palette Action: Toggle Group Pattern**
Player value: quick styling for groups.
User flow: select group, run Cycle Pattern.
Implementation sketch: Call `cycle_pattern` on selected group nodes. Hooks: `Globals.selections`. Data: group save already handles pattern_index. UI: palette action only when group selected.
Effort: S | Risk: low | Save compatibility: safe

**41) Palette Action: Clean Orphaned Connectors**
Player value: fix visual glitches and reduce clutter.
User flow: run command; remove connectors without valid endpoints.
Implementation sketch: Use `Globals.desktop.connections` and `Signals.delete_connection` if endpoints missing. Hooks: none. Data: none. UI: palette action with warning badge.
Effort: M | Risk: medium | Save compatibility: safe

**42) Palette Action: Export/Import Mod Config**
Player value: share settings across machines.
User flow: run Export Config to file; run Import Config to apply.
Implementation sketch: Touch `config_manager.gd` to read/write `user://tajs_mod_config.json` and `.bak`; use `FileAccess`. Hooks: none. Data: config file. UI: palette actions.
Effort: M | Risk: medium | Save compatibility: safe

## QoL, Upgrades, and Economy

**43) Upgrade Queue (Selected Nodes)**
Player value: spend money evenly across selected nodes.
User flow: select nodes and run Upgrade Queue to round-robin upgrades.
Implementation sketch: Reuse logic from `options_bar.gd` buy-max loop; add new utility and palette action. Hooks: `Globals.selections`. Data: none. UI: palette action.
Effort: S | Risk: low | Save compatibility: safe

**44) Buy Max for Current Category Tab**
DONE?

**45) Schematic Quick Save (Selection)**
Player value: save frequently without opening menu.
User flow: select nodes, run Save Selection as Schematic.
Implementation sketch: Use `Data.save_schematic` with `Globals.desktop.export_selection` if available; may require hook to export selection only. UI: palette action. Data: new schematic.
Effort: L | Risk: high | Save compatibility: safe

**46) Auto-Sell Bin Metrics**
Player value: see how much the Bin deletes.
User flow: hover bin window to see counts or add a small counter.
Implementation sketch: Touch `window_bin.gd` to track counts during `process`; store in runtime only. Hooks: none. Data: none. UI: label in bin window.
Effort: M | Risk: medium | Save compatibility: safe

**47) Focus Mute Exceptions**
Player value: keep SFX on while muted or vice versa.
User flow: toggle options for SFX/UI/BGM when unfocused.
Implementation sketch: Extend `focus_handler.gd` to adjust buses 1/2/3 separately; add settings in `mod_main.gd`. Hooks: `AudioServer`. Data: config keys. UI: toggles and sliders.
Effort: M | Risk: medium | Save compatibility: safe

**48) Node Limit Warning Tooltip**
Player value: understand why node creation failed.
User flow: when limit hit, show tooltip with current and max counts.
Implementation sketch: Touch `windows_menu.gd`, `wire_drop_connector.gd`, `schematic_container.gd` to show detailed message. Hooks: `Signals.notify`. Data: none. UI: notification text.
Effort: S | Risk: low | Save compatibility: safe

## Performance, Diagnostics, and Interop

**49) Palette Performance Mode**
Player value: smoother palette in huge command lists.
User flow: enable Performance Mode to limit results and reduce UI redraw.
Implementation sketch: Touch `palette_overlay.gd` to cap results and disable icon loading; store config flag. Hooks: none. Data: config. UI: toggle in settings.
Effort: S | Risk: low | Save compatibility: safe

**50) Wire Cache Refresh Button**
Player value: fix wire color or compatibility issues after mod updates.
User flow: press Refresh Cache in Visuals or Debug.
Implementation sketch: Touch `node_compatibility_filter.gd` `clear_cache`, `wire_color_overrides.gd`; add UI button in `mod_main.gd`. Hooks: none. Data: none. UI: button.
Effort: S | Risk: low | Save compatibility: safe

**51) Safe Mode (Disable All Patches)**
Player value: recover from broken mod states.
User flow: toggle Safe Mode, which skips script extensions and patches.
Implementation sketch: Touch `mod_main.gd` `_init` and `_ready` to guard installs with config; add config key and UI toggle. Hooks: none. Data: config `safe_mode`.
Effort: M | Risk: medium | Save compatibility: safe

**52) Mod Conflict Reporter**
Player value: detect other mods patching same scripts.
User flow: open Debug tab to see warnings about script extensions.
Implementation sketch: Query ModLoader for installed extensions and compare against known list; add to debug panel. Hooks: ModLoader APIs. Data: none. UI: debug label list.
Effort: M | Risk: medium | Save compatibility: safe

**53) Screenshot Capture Queue**
Player value: capture large bases without manual timing.
User flow: set interval and count; screenshots take sequentially.
Implementation sketch: Extend `screenshot_manager.gd` with timer queue; add UI fields in settings. Hooks: `SceneTree` timers. Data: config. UI: inputs in screenshot section.
Effort: M | Risk: medium | Save compatibility: safe

## Big Bets (Major Features)

**54) Node Graph Auto-Layout Engine**
Player value: one-click tidy layout for large networks.
User flow: run Auto-Layout; nodes reposition based on connections.
Implementation sketch: New `extensions/scripts/utilities/auto_layout.gd`; requires access to connector graph (`Globals.desktop.connections`). Hooks: `Signals.move_selection` or direct positions. Data: layout settings in config. UI: palette action + settings.
Effort: L | Risk: high | Save compatibility: safe

**55) Schematic Diff and Merge Tool**
Player value: compare two schematics and merge changes.
User flow: open tool, pick schematics A/B, preview diff, apply.
Implementation sketch: New UI panel; use `Data.schematics` dictionaries and `Data.save_schematic`. Hooks: none. Data: new merged schematic. UI: modal panel with list and preview.
Effort: L | Risk: high | Save compatibility: safe

**56) Selection Macro Recorder**
Player value: record repetitive build actions.
User flow: start recording, perform actions, save macro, replay.
Implementation sketch: Hook into `Signals.create_window`, `Signals.create_connection`, `Signals.move_selection`; store macro in config. UI: palette actions and small recorder overlay.
Effort: L | Risk: high | Save compatibility: maybe (new macro data)

**57) Modular Group Templates**
Player value: reuse group layouts as templates.
User flow: save group as template and spawn later with one command.
Implementation sketch: Store group contents as schematic + metadata; add `Data.save_schematic` integration and template list in config. UI: template picker in palette.
Effort: L | Risk: high | Save compatibility: safe

**58) Cross-Save Settings Sync**
Player value: keep mod settings across devices.
User flow: export config and import on another machine; optional Steam Cloud if available.
Implementation sketch: add import/export in `config_manager.gd`; for cloud, needs game hook to save to cloud path. UI: settings panel buttons. Data: config file. API wishlist: cloud save path access.
Effort: L | Risk: medium | Save compatibility: safe

## Experimental / High Risk

**59) Live Throughput Heatmap**
Player value: visualize bottlenecks on the graph.
User flow: toggle heatmap; wires and nodes glow based on throughput.
Implementation sketch: needs per-connector throughput data from base scripts; currently not exposed. Workaround: sample ResourceContainers if they expose counts. API wishlist: signal for resource transfer amounts. UI: toggle in Visuals.
Effort: L | Risk: high | Save compatibility: safe

**60) Adaptive Wire Routing (Avoid Overlap)**
Player value: cleaner wiring in dense areas.
User flow: toggle adaptive routing; wires curve around nodes.
Implementation sketch: requires connector draw logic changes in base; likely needs engine hook or script extension on connector. API wishlist: custom wire renderer or path controls. UI: toggle in Visuals.
Effort: L | Risk: high | Save compatibility: safe

**61) Smart Auto-Upgrade Assistant**
Player value: optimize upgrades based on resource goals.
User flow: pick goal (money/research), assistant upgrades nodes to maximize output.
Implementation sketch: needs access to node production data and upgrade effects; not exposed in mod scripts. Workaround: heuristic based on node type and level. API wishlist: node output stats. UI: wizard panel.
Effort: L | Risk: high | Save compatibility: safe
