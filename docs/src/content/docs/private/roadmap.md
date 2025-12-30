---
title: Taj's Mod - Combined Ideas & Roadmap
description: This document consolidates all mod ideas, feature backlog, roadmap, and technical context into a single reference.
---

## Table of Contents

1. [Current Feature Set](#current-feature-set)
2. [Architecture Overview](#architecture-overview)
3. [Constraints & Technical Notes](#constraints--technical-notes)
4. [Prioritized Roadmap](#prioritized-roadmap)
5. [Quick Wins](#quick-wins)
6. [Feature Ideas Backlog](#feature-ideas-backlog)
7. [Big Bets (Major Features)](#big-bets-major-features)
8. [Experimental / High Risk](#experimental--high-risk)
9. [API & Hooks Wishlist](#api--hooks-wishlist)

---

## Current Feature Set

### HUD/UX

- Mod settings panel with puzzle button in HUD extras; custom tabs (General, Visuals, Cheats, Debug) and footer
- Real-time node counter with limit warning inside the settings panel
- Restart-required dialog for settings that need reload
- Go To Group quick panel (bottom-left) with popup list of groups and camera tweening

### Visuals

- Extra glow controls (intensity/strength/bloom/sensitivity) via `WorldEnvironment`
- UI opacity slider that modulates HUD alpha
- Expanded group node colors and patterns with persistence
- Custom wire colors with RGB picker; overrides `Data.resources` and `Data.connectors`
- Custom boot screen text and logo injection

### Node Graph Workflow

- Wire drop node picker: drop a wire on empty canvas to spawn compatible nodes
- Right-click to clear all wires from a connector
- Ctrl+A select all nodes on desktop
- Group Z-order fix for contained groups with debounced updates
- Group lock/unlock and Upgrade All for nodes inside group
- Bin node injection with universal receiver inputs
- 6-input container upgrade for inventory
- Node limit control (custom max or unlimited) enforced in window creation, paste, schematics, and wire drop

### Command Palette

- Command palette overlay with fuzzy search, favorites/recents, and navigation breadcrumbs
- Command registry and default command set (select/deselect, center view, upgrade, settings toggles)
- Palette config persistence (favorites/recents/tools enabled) stored in mod config

### QoL/Shop/Upgrades

- Buy Max button injected into upgrades tab for bulk purchases
- Buy Max for selected nodes in options bar
- Cheats panel (currency/attribute adjustments) in settings UI
- Mute on focus loss with configurable background volume
- High-quality tiled screenshots with configurable output

### Performance/Diagnostics

- Debug log panel with optional verbose logging
- Node compatibility cache built deferred to avoid startup stalls
- Z-order fix uses debounced rect hashing to reduce churn

### Accessibility

- UI opacity adjustment
- Wire color customization for better contrast
- Focus mute to reduce background audio fatigue

### Misc

- Additional schematic icon options in save UI
- Schematic sanitizer for missing `window` keys

---

## Architecture Overview

- **Entry point:** `mod_main.gd` preloads services, installs script extensions, and wires managers during `_init` and `_ready`
- **Services/managers:** Config, ScreenshotManager, PaletteController, WireClearHandler, FocusHandler, WireColorOverrides, GotoGroupManager/Panel, NodeGroupZOrderFix, BuyMaxManager, CheatManager
- **Initialization flow:** `_init` installs extensions and creates managers; `_ready` builds shared color picker, applies wire color overrides, applies node limit, injects bin window, defers sanitation; waits for Main/HUD before UI setup
- **Update loop:** `_process` patches desktop once and refreshes node info label; avoids repeated heavy operations
- **Performance safeguards:** deferred cache building for compatibility filter, debounced z-order fix, screenshot tiling to avoid oversized textures

### UI/UX Patterns & Components

- Settings panel: `PanelContainer` with title/content/footer and tab buttons
- Toggle rows: label + `CheckButton`
- Slider rows: label + `HSlider` with value label
- Action buttons: `TabButton` style
- Palette overlay: dim background + centered panel + search + results list + breadcrumbs
- Color picker: HSV plane, sliders, swatches, recents, RGBA inputs
- Popup lists: `PopupMenu` for pattern selection
- Notifications via `Signals.notify.emit` and `Sound.play`

### Input Model

- **Palette:** Middle mouse button toggles, XButton1/XButton2 for back/forward
- **Palette keyboard:** arrows, Enter, Esc, Tab, Left/Backspace for back, Ctrl+F to favorite
- **Wire clear:** right-click on connector
- **Desktop:** Ctrl+A selects all nodes
- **Go To Group popup:** Esc or click outside to close
- **Settings:** button toggles panel; click outside closes

### Data & Persistence

- Main mod config: `user://tajs_mod_config.json` managed by `config_manager.gd`
- Palette config stored under `"palette"` inside main config, with migration from legacy file
- Wire color overrides stored in `wire_colors_hex` inside mod config
- Group custom data saved via `save()`/`export()` (pattern index, lock state, custom_color)
- Node limit stored in config and mirrored to `Globals.custom_node_limit`
- Schematics saved through game `Data.save_schematic` with extended icon list

---

## Constraints & Technical Notes

> [!IMPORTANT] > **Technical Reality Check:**
>
> - **Wiring:** The game uses `Signals.create_connection(from, to)` and `Signals.delete_connection(from, to)`. There is no single `disconnect_all()` method; we must iterate `ResourceContainer`s.
> - **State:** `Data` is the global singleton for persistence. `Data.schematics` holds blueprints.
> - **Upgrades:** There is NO global `Upgrades.buy()` method. Purchases must be simulated via UI interaction or by replicating `upgrade_panel.gd` logic.
> - **Nodes:** Nodes are `WindowContainer`s containing `ResourceContainer`s. Logic is split between `desktop.gd` and `resource_container.gd`.

### Known Risks & Fragility

- Heavy reliance on specific scene tree paths (e.g., `Main/MainContainer/Overlay`, `ExtrasButtons/Container`, upgrades tab structure). Game UI refactors will break injections.
- Desktop script patching replaces script at runtime (`patcher.gd`), which can desync if base script changes.
- Wire compatibility cache loads each window scene to inspect ResourceContainers; can be expensive on large window sets.
- Wire color overrides mutate `Data.resources` and `Data.connectors` globally; other mods altering the same data can conflict.
- Bin window inputs skip tutorial to avoid breaking tutorial steps.
- Drag dead zone feature is blocked by a base `class_name` conflict (not implementable via script extension).
- Palette input is hard-coded to mouse buttons and keyboard; no dynamic remap hook exists.

### Potential Breakpoints for Game Updates

- `Data.windows` schema, `Data.schematics` shape, or connector APIs
- Signal names/typos (e.g., `Signals.connection_droppped`) used by wire drop
- Camera and HUD node names used by screenshot and UI injection

---

## Prioritized Roadmap

### Top 10 Ideas (Impact vs Effort)

1. Align and Distribute selection (Ideas 18, 19)
2. HUD quick toggles bar (Idea 6)
3. Wire color presets (Idea 9)
4. Settings search bar (Idea 1) - Done
5. Node search and focus (Idea 30) - Done
6. Palette actions for wire drop and group lock (Ideas 31, 33)
7. Selection stats panel (Idea 28)
8. Node limit warning tooltip (Idea 48)
9. Wire cache refresh button (Idea 50)
10. Screenshot selection capture (Idea 38)

---

### Next Patch (v0.2.x - Small, Low Risk)

#### Focus: Polish existing foundations

- [ ] **Polish:** Smart Wire Drop - Ensure compatibility checks
- [ ] Settings search bar (Idea 1)
- [ ] HUD quick toggles bar (Idea 6)
- [ ] Context help tooltips (Idea 7)
- [ ] Wire color presets (Idea 9)
- [ ] Align left/right/top/bottom (Idea 18)
- [ ] Distribute H/V (Idea 19)
- [ ] Palette: Toggle Wire Drop Menu (Idea 31)
- [ ] Palette: Lock/Unlock Selected Groups (Idea 33)
- [ ] Node limit warning tooltip (Idea 48)
- [ ] Wire cache refresh button (Idea 50)
- [ ] **New:** Mass Wire Delete (Easy win via Signals)

---

### Next Minor (v0.3.x - Medium Scope)

#### Focus: Tools for power users and modders

- [ ] Selection stats panel (Idea 28)
- [ ] Node search and focus (Idea 30)
- [ ] Screenshot selection capture (Idea 38)
- [ ] Camera bookmarks (Idea 26)
- [ ] Buy Max per tab (Idea 44)
- [ ] Group pattern opacity slider (Idea 10)
- [ ] UI color theme variants (Idea 11)
- [ ] RGB Picker API - exposed for other mods
- [ ] Layout Snapshots ("Save layout to clipboard/memory")
- [ ] Zen Mode (Toggle HUD visibility)
- [ ] Resource Rate Meter (Money/sec display)

---

### Next Major (v1.0.0 - Large Scope)

#### Focus: The Ecosystem

- [ ] Node graph auto-layout engine (Idea 54)
- [ ] Schematic diff and merge tool (Idea 55)
- [ ] Selection macro recorder (Idea 56)
- [ ] Modular group templates (Idea 57)
- [ ] Cross-save settings sync (Idea 58)
- [ ] Lasso select connectors (Idea 21) - if new hooks land
- [ ] Shared Settings Hook
- [ ] Minimap

---

## Quick Wins

These are low-effort, low-risk features to ship quickly:

| Feature                               | Idea # | Effort | Risk |
| ------------------------------------- | ------ | ------ | ---- |
| Settings search bar                   | 1      | S      | Low  |
| Compact settings mode                 | 2      | S      | Low  |
| Restart required banner               | 4      | S      | Low  |
| HUD quick toggles bar                 | 6      | S      | Low  |
| Context help tooltips                 | 7      | S      | Low  |
| Wire color presets                    | 9      | S      | Low  |
| Align left/right/top/bottom           | 18     | S      | Low  |
| Distribute H/V                        | 19     | S      | Low  |
| Node limit warning tooltip            | 48     | S      | Low  |
| Wire cache refresh button             | 50     | S      | Low  |
| Palette: Toggle Wire Drop Menu        | 31     | S      | Low  |
| Palette: Clear All Wires in Selection | 32     | S      | Low  |
| Palette: Lock/Unlock Selected Groups  | 33     | S      | Low  |
| Palette: Toggle Palette Tools Mode    | 34     | S      | Low  |
| Palette: Set Node Limit (Presets)     | 35     | S      | Low  |

---

## Feature Ideas Backlog

All ideas are grounded in existing systems in this repo and the base game sources. Each idea includes name, player value, user flow, implementation sketch, effort, risk, and save compatibility impact.

### HUD/UX and Settings

#### 1) Settings Search Bar

**Player value:** Faster access to toggles when the panel grows.  
**User flow:** Open settings, type to filter rows across tabs.  
**Implementation:** Touch `settings_ui.gd` (add search field + filter), `mod_main.gd` (store references to created rows).  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 2) Compact Settings Mode

**Player value:** Fit more options on screen for small monitors.  
**User flow:** Toggle Compact Mode in General tab to reduce row height and font size.  
**Implementation:** Touch `settings_ui.gd` to add a global style toggle; add config key.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 3) Toast History Panel

**Player value:** Review recent notifications (errors, success).  
**User flow:** Click a small bell icon to open a list of the last 20 toasts.  
**Implementation:** Touch `mod_main.gd` to wrap `Signals.notify.emit` calls; add `notification_log_panel.gd` (new).  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 4) Restart Required Banner

**Player value:** Avoid missing restart-needed changes.  
**User flow:** After toggling 6-input containers, a small banner appears until restart or dismiss.  
**Implementation:** Touch `mod_main.gd` `_show_restart_dialog`; add lightweight banner in `settings_ui.gd`.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 5) Profile Switcher (Minimal)

**Player value:** Quick switch between visual/QoL presets.  
**User flow:** Choose a profile from dropdown in settings; it swaps mod config sections.  
**Implementation:** Touch `config_manager.gd` to store profiles; `settings_ui.gd` to add dropdown.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 6) HUD Quick Toggles Bar

**Player value:** Toggle wire colors, glow, palette tools without opening settings.  
**User flow:** Small expandable strip in HUD overlay with 3-5 toggles.  
**Implementation:** Touch `mod_main.gd` `_setup_for_main` to add buttons; reuse `SettingsUI` callbacks.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 7) Context Help Tooltips

**Player value:** Clarify what each toggle does.  
**User flow:** Hover over a setting to see a short explanation.  
**Implementation:** Touch `mod_main.gd` `_build_settings_menu` to set `tooltip_text` on rows.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 8) Palette Onboarding Tooltip

**Player value:** Discover the palette hotkeys and favorites.  
**User flow:** First time opening palette, show a short hint box.  
**Implementation:** Touch `palette_overlay.gd` to show once; store `palette_onboarded` in config.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

---

### Visuals and Customization

#### 9) Wire Color Presets

**Player value:** Quick swap between color themes (high-contrast, pastel, monochrome).  
**User flow:** Pick a preset from Visuals tab; wires update.  
**Implementation:** Touch `wire_color_overrides.gd` to load preset tables; add preset dropdown.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 10) Group Pattern Opacity Slider

**Player value:** Make patterns subtle or bold.  
**User flow:** Slider in group window to adjust pattern alpha.  
**Implementation:** Touch `window_group.gd` (store pattern alpha, update PatternDrawer).  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Maybe (new saved field on groups)

#### 11) UI Color Theme Variants

**Player value:** Match HUD to personal taste (cool, warm, low-contrast).  
**User flow:** Choose theme variant in Visuals tab, applies to mod panels.  
**Implementation:** Touch `settings_ui.gd`, `palette_overlay.gd`, `color_picker_panel.gd` to apply theme colors.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 12) Boot Screen Variant Selector

**Player value:** Choose between modded boot art, vanilla, or minimalist.  
**User flow:** Pick boot style in Debug tab.  
**Implementation:** Touch `mod_main.gd` and `patcher.gd` to swap textures/labels.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 13) Group Title Glow

**Player value:** Make groups easier to locate.  
**User flow:** Toggle glow outline on group title bars.  
**Implementation:** Touch `window_group.gd` to add stylebox glow or modulate.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Maybe (per-group flag if stored)

#### 14) Wire Thickness Slider

**Player value:** Improve readability in dense graphs.  
**User flow:** Slider in Visuals to set wire width.  
**Implementation:** Needs connector draw logic changes in base; likely needs engine hook.  
**Effort:** L | **Risk:** High | **Save compatibility:** Safe

#### 15) Background Grid Density

**Player value:** Better spatial orientation at different zoom levels.  
**User flow:** Choose grid density in Visuals.  
**Implementation:** Touch `mod_main.gd` to find `Main/HUD/Lines` or `Desktop/Lines` and adjust properties if exposed.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 16) Screenshot Watermark Toggle

**Player value:** Branded or clean captures.  
**User flow:** Toggle watermark before capture.  
**Implementation:** Touch `screenshot_manager.gd` to overlay a label/texture.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

---

### Node Graph Workflow Boosters

#### 17) Box Select to Group

**Player value:** Instant grouping for organization.  
**User flow:** Select nodes, run action to create group bounding selected nodes.  
**Implementation:** Use `Signals.create_window` to spawn group at bounds; set group size.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 18) Snap Align Left/Right/Top/Bottom

**Player value:** Clean layouts fast.  
**User flow:** Select nodes, run Align Left, etc.  
**Implementation:** Move windows via `Signals.move_selection` or direct position changes.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 19) Distribute Horizontally/Vertically

**Player value:** Even spacing for large selections.  
**User flow:** Select nodes, run Distribute H or V.  
**Implementation:** Similar to alignment; compute bounds from `Globals.selections`.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 20) Auto-Arrange by Category

**Player value:** Auto layout by node type.  
**User flow:** Run action, nodes cluster by `Data.windows` category.  
**Implementation:** Use `Data.windows` to map category; position in grid.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 21) Lasso Select Connectors

**Player value:** Faster wire cleanup.  
**User flow:** Drag a lasso to select connectors and clear them.  
**Implementation:** Needs connector selection support; iterate connectors by screen rect.  
**Effort:** L | **Risk:** High | **Save compatibility:** Safe

#### 22) Wire Reroute (Swap Source/Target)

**Player value:** Fix wiring mistakes without delete/reconnect.  
**User flow:** Select a connector, choose new compatible target from list.  
**Implementation:** Use `Signals.delete_connection` + `Signals.create_connection`.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 23) Multi-Connect Batch

**Player value:** Connect one output to many compatible inputs quickly.  
**User flow:** Select an output, choose multiple targets from list, auto-connect.  
**Implementation:** Use `node_compatibility_filter.gd` to list candidates; call `Signals.create_connection` in loop.  
**Effort:** L | **Risk:** Medium | **Save compatibility:** Safe

#### 24) Group Color Sync to Contents

**Player value:** Group color reflects dominant resource type.  
**User flow:** Press button to auto-pick group color based on contained nodes.  
**Implementation:** Touch `window_group.gd` to analyze nodes in bounds and map to resource colors.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Maybe

#### 25) Node Limit Meter in HUD

**Player value:** See node usage without opening settings.  
**User flow:** Small text in HUD top bar with warning color at 90%.  
**Implementation:** Touch `mod_main.gd` to add label to HUD; reuse `_update_node_label`.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 26) Bookmark Camera Positions

**Player value:** Jump between areas of large graphs.  
**User flow:** Save 3-5 bookmarks and jump via palette.  
**Implementation:** Store positions in config; use `Signals.center_camera` or camera tween.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 27) Quick Replace Node

**Player value:** Swap node type without re-wiring.  
**User flow:** Select a node, choose replacement from picker; connections transfer if compatible.  
**Implementation:** Use `window.save()` + replace with new window; rewire matching ResourceContainers.  
**Effort:** L | **Risk:** High | **Save compatibility:** Safe

#### 28) Selection Stats Panel

**Player value:** See total cost, output, or count for selected nodes.  
**User flow:** Select nodes; panel shows aggregate info.  
**Implementation:** Touch `mod_main.gd` to add a small panel; read node properties like `level`, `cost`.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 29) Auto-Expand Group to Fit Contents

**Player value:** Keep groups tidy after moving nodes.  
**User flow:** Click button to resize group to bounding box of enclosed nodes.  
**Implementation:** Touch `window_group.gd` to compute bounds from contained nodes and set size.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 30) Node Search and Focus

**Player value:** Find nodes by name or type quickly.  
**User flow:** Use palette to search nodes and center camera on result.  
**Implementation:** Add command in `default_commands.gd`; use `Data.windows` and `Globals.desktop` children.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

---

### Command Palette Actions

#### 31) Toggle Wire Drop Menu

**Player value:** Quickly enable/disable feature.  
**User flow:** Open palette, run Toggle Wire Drop Menu; context-aware badge shows current state.  
**Implementation:** Add command; call `palette_controller.set_wire_drop_enabled`.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 32) Clear All Wires in Selection

**Player value:** Batch cleanup.  
**User flow:** Select nodes, run action; wires on their connectors are cleared.  
**Implementation:** Iterate selected windows and emit `Signals.delete_connection`.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 33) Lock/Unlock Selected Groups

**Player value:** Protect layout.  
**User flow:** Select group nodes, run Lock or Unlock.  
**Implementation:** Call `toggle_lock` on selected group nodes.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe
DONE

#### 34) Toggle Palette Tools Mode

**Player value:** Quick opt-in to gameplay tools.  
**User flow:** Run Enable Tools or Disable Tools in palette.  
**Implementation:** Use `palette_config.gd` `set_tools_enabled`.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 35) Set Node Limit (Presets)

**Player value:** One-tap limit changes.  
**User flow:** Choose presets like 400, 800, unlimited.  
**Implementation:** Call `mod_main.set_node_limit`.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 36) Jump to Group (List)

**Player value:** Faster than HUD panel for keyboard users.  
**User flow:** Open palette, type group name, jump.  
**Implementation:** Use `goto_group_manager.gd` to list groups and call `navigate_to_group`.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 37) Toggle UI Opacity Cycle

**Player value:** Quick visibility control.  
**User flow:** Run Cycle UI Opacity to 100/75/50.  
**Implementation:** Expand with more steps and status label.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 38) Screenshot (Area of Selection)

**Player value:** Capture only selected nodes.  
**User flow:** Select nodes, run Capture Selection.  
**Implementation:** Touch `screenshot_manager.gd` to accept bounds override.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 39) Focus on Money/Research Nodes

**Player value:** Find key economy nodes quickly.  
**User flow:** Run Focus Money Nodes; camera centers on cluster.  
**Implementation:** Iterate windows for resource containers with matching resource; use `Signals.center_camera`.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 40) Toggle Group Pattern

**Player value:** Quick styling for groups.  
**User flow:** Select group, run Cycle Pattern.  
**Implementation:** Call `cycle_pattern` on selected group nodes.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 41) Clean Orphaned Connectors

**Player value:** Fix visual glitches and reduce clutter.  
**User flow:** Run command; remove connectors without valid endpoints.  
**Implementation:** Use `Globals.desktop.connections` and `Signals.delete_connection` if endpoints missing.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 42) Export/Import Mod Config

**Player value:** Share settings across machines.  
**User flow:** Run Export Config to file; run Import Config to apply.  
**Implementation:** Touch `config_manager.gd` to read/write files.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

---

### QoL, Upgrades, and Economy

#### 43) Upgrade Queue (Selected Nodes)

**Player value:** Spend money evenly across selected nodes.  
**User flow:** Select nodes and run Upgrade Queue to round-robin upgrades.  
**Implementation:** Reuse logic from `options_bar.gd` buy-max loop; add new utility and palette action.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 44) Buy Max for Current Category Tab

**Player value:** Faster upgrades within current upgrades tab.  
**User flow:** In upgrades menu, press Buy Max for current tab only.  
**Implementation:** Extend `buy_max_manager.gd` to add a second button or shift-click logic.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 45) Schematic Quick Save (Selection)

**Player value:** Save frequently without opening menu.  
**User flow:** Select nodes, run Save Selection as Schematic.  
**Implementation:** Use `Data.save_schematic` with `Globals.desktop.export_selection` if available.  
**Effort:** L | **Risk:** High | **Save compatibility:** Safe

#### 46) Auto-Sell Bin Metrics

**Player value:** See how much the Bin deletes.  
**User flow:** Hover bin window to see counts or add a small counter.  
**Implementation:** Touch `window_bin.gd` to track counts during `process`; store in runtime only.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 47) Focus Mute Exceptions

**Player value:** Keep SFX on while muted or vice versa.  
**User flow:** Toggle options for SFX/UI/BGM when unfocused.  
**Implementation:** Extend `focus_handler.gd` to adjust buses 1/2/3 separately.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 48) Node Limit Warning Tooltip

**Player value:** Understand why node creation failed.  
**User flow:** When limit hit, show tooltip with current and max counts.  
**Implementation:** Touch `windows_menu.gd`, `wire_drop_connector.gd`, `schematic_container.gd` to show detailed message.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

---

### Performance, Diagnostics, and Interop

#### 49) Palette Performance Mode

**Player value:** Smoother palette in huge command lists.  
**User flow:** Enable Performance Mode to limit results and reduce UI redraw.  
**Implementation:** Touch `palette_overlay.gd` to cap results and disable icon loading.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 50) Wire Cache Refresh Button

**Player value:** Fix wire color or compatibility issues after mod updates.  
**User flow:** Press Refresh Cache in Visuals or Debug.  
**Implementation:** Touch `node_compatibility_filter.gd` `clear_cache`, `wire_color_overrides.gd`.  
**Effort:** S | **Risk:** Low | **Save compatibility:** Safe

#### 51) Safe Mode (Disable All Patches)

**Player value:** Recover from broken mod states.  
**User flow:** Toggle Safe Mode, which skips script extensions and patches.  
**Implementation:** Touch `mod_main.gd` `_init` and `_ready` to guard installs with config.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 52) Mod Conflict Reporter

**Player value:** Detect other mods patching same scripts.  
**User flow:** Open Debug tab to see warnings about script extensions.  
**Implementation:** Query ModLoader for installed extensions and compare against known list.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

#### 53) Screenshot Capture Queue

**Player value:** Capture large bases without manual timing.  
**User flow:** Set interval and count; screenshots take sequentially.  
**Implementation:** Extend `screenshot_manager.gd` with timer queue.  
**Effort:** M | **Risk:** Medium | **Save compatibility:** Safe

---

## Big Bets (Major Features)

These are high-effort, high-impact features for major releases.

#### 54) Node Graph Auto-Layout Engine

**Player value:** One-click tidy layout for large networks.  
**User flow:** Run Auto-Layout; nodes reposition based on connections.  
**Implementation:** New `auto_layout.gd`; requires access to connector graph (`Globals.desktop.connections`).  
**Effort:** L | **Risk:** High | **Save compatibility:** Safe

#### 55) Schematic Diff and Merge Tool

**Player value:** Compare two schematics and merge changes.  
**User flow:** Open tool, pick schematics A/B, preview diff, apply.  
**Implementation:** New UI panel; use `Data.schematics` dictionaries and `Data.save_schematic`.  
**Effort:** L | **Risk:** High | **Save compatibility:** Safe

#### 56) Selection Macro Recorder

**Player value:** Record repetitive build actions.  
**User flow:** Start recording, perform actions, save macro, replay.  
**Implementation:** Hook into `Signals.create_window`, `Signals.create_connection`, `Signals.move_selection`; store macro in config.  
**Effort:** L | **Risk:** High | **Save compatibility:** Maybe (new macro data)

#### 57) Modular Group Templates

**Player value:** Reuse group layouts as templates.  
**User flow:** Save group as template and spawn later with one command.  
**Implementation:** Store group contents as schematic + metadata; add `Data.save_schematic` integration.  
**Effort:** L | **Risk:** High | **Save compatibility:** Safe

#### 58) Cross-Save Settings Sync

**Player value:** Keep mod settings across devices.  
**User flow:** Export config and import on another machine; optional Steam Cloud if available.  
**Implementation:** Add import/export in `config_manager.gd`; for cloud, needs game hook to save to cloud path.  
**Effort:** L | **Risk:** Medium | **Save compatibility:** Safe

---

## Experimental / High Risk

> [!CAUTION]
> These features have significant technical challenges or require base game hooks that don't exist yet.

#### 59) Live Throughput Heatmap

**Player value:** Visualize bottlenecks on the graph.  
**User flow:** Toggle heatmap; wires and nodes glow based on throughput.  
**Implementation:** Needs per-connector throughput data from base scripts; currently not exposed.  
**Effort:** L | **Risk:** High | **Save compatibility:** Safe

#### 60) Adaptive Wire Routing (Avoid Overlap)

**Player value:** Cleaner wiring in dense areas.  
**User flow:** Toggle adaptive routing; wires curve around nodes.  
**Implementation:** Requires connector draw logic changes in base; likely needs engine hook.  
**Effort:** L | **Risk:** High | **Save compatibility:** Safe

#### 61) Smart Auto-Upgrade Assistant

**Player value:** Optimize upgrades based on resource goals.  
**User flow:** Pick goal (money/research), assistant upgrades nodes to maximize output.  
**Implementation:** Needs access to node production data and upgrade effects; not exposed in mod scripts.  
**Effort:** L | **Risk:** High | **Save compatibility:** Safe

#### Investigate / Maybe

- **Garbage Collect:** `Data.gd` has `wiping` flag and `save_routine`. Manually triggering GC is risky. **Verdict:** Moved to Backlog.
- **Replace Node:** `WindowContainer` destruction/creation is heavy. Keeping wires attached when input/output slots might change is complex. **Verdict:** "Maybe", high risk of crashes.

---

## API & Hooks Wishlist

Features that would enable more advanced mod capabilities if the base game provided them:

- **Connector draw customization** (line width, routing control) to enable wire thickness and adaptive routing
- **Throughput/transfer metrics** per connector or ResourceContainer for heatmaps and smart upgrades
- **Export selection to schematic** without opening the schematic UI
- **Stable hooks for upgrades tab discovery** (named nodes or a signal) to avoid brittle UI tree traversal
- **Safe camera control API** (center/zoom) with bounds helpers for bookmark and focus tools
- **Access to grid/lines node settings** or a public API for grid density and visibility
- **Cloud save path exposure** for config sync

---

> **Legend:**  
> **Effort:** S = Small (1-2 hours), M = Medium (half day), L = Large (1+ days)  
> **Risk:** Low = isolated change, Medium = touches multiple systems, High = fragile or experimental

---

## Version Roadmap

> **Current Version:** v0.20.0 (December 2025)  
> **Next Development:** v0.21.0

This roadmap organizes features into themed releases, balancing quick wins with larger improvements. Each version includes a theme, target features, estimated effort, and dependencies.

---

### v0.0.22 — "Polish & Tooltips"

**Theme:** UX polish and discoverability  
**Estimated Effort:** 1-2 days

| Feature                            | Idea # | Effort | Notes                                  |
| ---------------------------------- | ------ | ------ | -------------------------------------- |
| Context help tooltips for settings | 7      | S      | Add `tooltip_text` to all setting rows |
| Node limit warning tooltip         | 48     | S      | Show current/max counts when limit hit |
| Palette onboarding tooltip         | 8      | S      | First-open hint with hotkeys           |
| Restart required banner            | 4      | S      | Persistent banner until restart        |

**Acceptance Criteria:**

- [ ] Every setting row has a helpful tooltip on hover
- [ ] When node creation fails due to limit, user sees informative message
- [ ] First palette open shows brief keyboard shortcuts guide
- [ ] After toggling restart-required settings, banner appears in settings header

---

### v0.0.23 — "Quick Actions"

**Theme:** Palette power user commands  
**Estimated Effort:** 1-2 days

| Feature                               | Idea # | Effort | Notes                            |
| ------------------------------------- | ------ | ------ | -------------------------------- |
| Palette: Toggle Wire Drop Menu        | 31     | S      | Status badge shows current state |
| Palette: Lock/Unlock Selected Groups  | 33     | S      | Contextual action                |
| Palette: Toggle Palette Tools Mode    | 34     | S      | OPT-IN badge                     |
| Palette: Set Node Limit (Presets)     | 35     | S      | 400, 800, 1200, Unlimited        |
| Palette: Clear All Wires in Selection | 32     | S      | Mass wire delete                 |

**Acceptance Criteria:**

- [ ] All commands appear in palette with appropriate badges
- [ ] Lock/Unlock only visible when groups selected
- [ ] Clear Wires shows warning about no undo
- [ ] Node limit presets apply immediately

---

### v0.0.24 — "Wire Presets"

**Theme:** Visual customization  
**Estimated Effort:** 2-3 days

| Feature                     | Idea # | Effort | Notes                                     |
| --------------------------- | ------ | ------ | ----------------------------------------- |
| Wire color presets          | 9      | S      | High-contrast, Pastel, Monochrome, Custom |
| Wire cache refresh button   | 50     | S      | Fix issues after updates                  |
| Screenshot watermark toggle | 16     | S      | Optional branding on captures             |

**Acceptance Criteria:**

- [ ] Presets dropdown in Visuals tab with 3+ built-in themes
- [ ] "Apply Preset" updates wires immediately
- [ ] Refresh Cache button clears compatibility filter cache
- [ ] Watermark toggle adds/removes mod branding on screenshots

---

### v0.0.25 — "Alignment Tools"

**Theme:** Node graph organization  
**Estimated Effort:** 2-3 days

| Feature                            | Idea # | Effort | Notes                 |
| ---------------------------------- | ------ | ------ | --------------------- |
| Align Left/Right/Top/Bottom        | 18     | S      | Palette commands      |
| Distribute Horizontally/Vertically | 19     | S      | Even spacing          |
| Auto-expand group to fit contents  | 29     | S      | Button in group title |

**Acceptance Criteria:**

- [ ] Select 3+ nodes → Align Left → All nodes share same X position
- [ ] Distribute H/V creates even spacing based on bounds
- [ ] Group "Fit Contents" button resizes to bounding box + padding
- [ ] Wires update correctly after alignment

---

### v0.0.26 — "HUD Enhancements"

**Theme:** At-a-glance information  
**Estimated Effort:** 2-3 days

| Feature                 | Idea # | Effort | Notes                   |
| ----------------------- | ------ | ------ | ----------------------- |
| HUD quick toggles bar   | 6      | S      | 3-5 most-used toggles   |
| Node limit meter in HUD | 25     | S      | Warning color at 90%    |
| Settings search bar     | 1      | S      | Filter rows across tabs |

**Acceptance Criteria:**

- [ ] Expandable strip in HUD with toggles for: Wire Colors, Glow, Wire Drop Menu
- [ ] Node counter visible without opening settings; turns yellow/red near limit
- [ ] Search bar filters settings rows in real-time as user types
- [ ] Search persists between settings opens (optional)

---

### v0.0.27 — "Node Search"

**Theme:** Navigation and discovery  
**Estimated Effort:** 3-4 days

| Feature                                | Idea # | Effort | Notes                         |
| -------------------------------------- | ------ | ------ | ----------------------------- |
| Node search and focus                  | 30     | M      | Palette picker mode for nodes |
| Palette: Jump to Group (List)          | 36     | M      | Keyboard-friendly group nav   |
| Palette: Focus on Money/Research Nodes | 39     | M      | Quick economy node finding    |

**Acceptance Criteria:**

- [ ] Palette search mode lists all nodes by name/type
- [ ] Selecting a node centers camera on it and selects it
- [ ] Jump to Group provides searchable list in palette
- [ ] Focus Money/Research finds cluster and centers view

---

### v0.0.28 — "Screenshot+"

**Theme:** Enhanced capture capabilities  
**Estimated Effort:** 3-4 days

| Feature                        | Idea # | Effort | Notes                       |
| ------------------------------ | ------ | ------ | --------------------------- |
| Screenshot (Area of Selection) | 38     | M      | Capture only selected nodes |
| Screenshot capture queue       | 53     | M      | Interval-based captures     |

**Acceptance Criteria:**

- [ ] With nodes selected, "Capture Selection" crops to bounding box
- [ ] Queue UI allows setting count and interval
- [ ] Progress indicator during queue capture
- [ ] All screenshots save to configured folder

---

### v0.0.29 — "Selection Stats"

**Theme:** Information and analytics  
**Estimated Effort:** 3-4 days

| Feature               | Idea # | Effort | Notes                             |
| --------------------- | ------ | ------ | --------------------------------- |
| Selection stats panel | 28     | M      | Aggregate info for selected nodes |
| Auto-sell bin metrics | 46     | M      | Runtime counters                  |
| Resource rate meter   | (new)  | M      | Money/sec display in HUD          |

**Acceptance Criteria:**

- [ ] Panel shows: node count, total cost, upgrade levels
- [ ] Bin window tooltip shows items processed this session
- [ ] Resource rate shows average income/research per second
- [ ] Updates in real-time as selection changes

---

### v0.0.30 — "Camera Bookmarks"

**Theme:** Large graph navigation  
**Estimated Effort:** 2-3 days

| Feature                        | Idea # | Effort | Notes             |
| ------------------------------ | ------ | ------ | ----------------- |
| Bookmark camera positions      | 26     | M      | Save 5+ positions |
| Palette commands for bookmarks | 26     | S      | Jump via palette  |

**Acceptance Criteria:**

- [ ] Save Bookmark 1-5 via palette commands or hotkeys
- [ ] Jump to Bookmark 1-5 smoothly tweens camera
- [ ] Bookmarks persist in mod config across sessions
- [ ] Visual indicator in HUD shows available bookmarks

---

### v0.0.31 — "Group Enhancements"

**Theme:** Group node polish  
**Estimated Effort:** 3-4 days

| Feature                       | Idea # | Effort | Notes                    |
| ----------------------------- | ------ | ------ | ------------------------ |
| Group pattern opacity slider  | 10     | M      | Per-group setting        |
| Group title glow              | 13     | S      | Toggle in group title    |
| Group color sync to contents  | 24     | M      | Auto-pick based on nodes |
| Palette: Toggle Group Pattern | 40     | S      | Quick cycling            |

**Acceptance Criteria:**

- [ ] Opacity slider 0-100% affects pattern visibility
- [ ] Title glow makes group header stand out
- [ ] "Sync Color" analyzes contained nodes and picks dominant resource color
- [ ] Pattern cycle via palette matches existing button behavior

---

### v0.0.32 — "Theme & Profiles"

**Theme:** Personalization  
**Estimated Effort:** 4-5 days

| Feature                      | Idea # | Effort | Notes                    |
| ---------------------------- | ------ | ------ | ------------------------ |
| UI color theme variants      | 11     | M      | Cool, Warm, Low-contrast |
| Profile switcher (minimal)   | 5      | M      | Swap config presets      |
| Boot screen variant selector | 12     | M      | Modded, Vanilla, Minimal |
| Compact settings mode        | 2      | S      | Reduced row height       |

**Acceptance Criteria:**

- [ ] Theme dropdown with 3+ variants affecting mod panels
- [ ] Profile dropdown shows saved presets; "Save Current" and "Load" buttons
- [ ] Boot style selector in Debug with preview
- [ ] Compact mode toggle shrinks all settings rows

---

### v0.0.33 — "Advanced Workflows"

**Theme:** Power user features  
**Estimated Effort:** 4-5 days

| Feature                           | Idea # | Effort | Notes                       |
| --------------------------------- | ------ | ------ | --------------------------- |
| Box select to group               | 17     | M      | Create group from selection |
| Wire reroute (swap source/target) | 22     | M      | Fix wiring mistakes         |
| Buy Max for current category tab  | 44     | M      | Tab-specific upgrade        |

**Acceptance Criteria:**

- [ ] "Create Group from Selection" spawns group sized to contain all selected
- [ ] Wire reroute shows picker of compatible targets
- [ ] Tab-specific Buy Max only affects current upgrades page
- [ ] All actions available via palette

---

### v0.0.34 — "Config Management"

**Theme:** Settings portability  
**Estimated Effort:** 2-3 days

| Feature                  | Idea # | Effort | Notes                       |
| ------------------------ | ------ | ------ | --------------------------- |
| Export/Import mod config | 42     | M      | Share settings              |
| Toast history panel      | 3      | M      | Review notifications        |
| Palette performance mode | 49     | S      | Cap results for large lists |

**Acceptance Criteria:**

- [ ] Export creates JSON file with all mod settings
- [ ] Import validates and applies settings, shows what changed
- [ ] Toast history accessible via bell icon; stores last 20 notifications
- [ ] Performance mode toggle caps palette results at 50

---

### v0.0.35 — "Diagnostics & Safety"

**Theme:** Stability and debugging  
**Estimated Effort:** 3-4 days

| Feature                         | Idea # | Effort | Notes                         |
| ------------------------------- | ------ | ------ | ----------------------------- |
| Safe mode (disable all patches) | 51     | M      | Recovery option               |
| Mod conflict reporter           | 52     | M      | Detect overlapping extensions |
| Clean orphaned connectors       | 41     | M      | Fix visual glitches           |

**Acceptance Criteria:**

- [ ] Safe Mode toggle skips all script extensions on next restart
- [ ] Conflict reporter lists other mods touching same scripts
- [ ] Clean Orphaned Connectors removes invalid connections
- [ ] All actions have confirmation dialogs

---

### v0.0.36 — "Auto-Arrange"

**Theme:** Auto-layout foundations  
**Estimated Effort:** 5-7 days

| Feature                  | Idea # | Effort | Notes                 |
| ------------------------ | ------ | ------ | --------------------- |
| Auto-arrange by category | 20     | M      | Cluster nodes by type |
| Focus mute exceptions    | 47     | M      | Per-bus control       |

**Acceptance Criteria:**

- [ ] Auto-arrange clusters nodes by their Data.windows category
- [ ] Spacing and grid configurable via settings
- [ ] Focus mute allows toggling SFX/BGM/UI independently
- [ ] Preview of arrangement before applying (optional)

---

## Major Releases

### v0.1.0 — "The Flow Update"

**Theme:** Polish and stability for wider release  
**Target:** After v0.0.36 stabilizes

**Milestone Goals:**

- [ ] All Quick Wins (Ideas 1-9, 16, 18-19, 31-35, 48, 50) implemented
- [ ] Settings panel fully searchable with tooltips
- [ ] Palette has comprehensive command coverage
- [ ] Alignment and distribution tools complete
- [ ] Screenshot manager fully featured
- [ ] Full compatibility verified with game v1.1.7+

---

### v0.2.0 — "The Platform Update"

**Theme:** Tools for power users and modders  
**Target:** Q1 2026

| Feature                          | Idea # | Notes                                 |
| -------------------------------- | ------ | ------------------------------------- |
| RGB Picker API export            | 6 (V2) | `TajsMod.open_color_picker(callback)` |
| Layout snapshots                 | (new)  | Save/restore layout via clipboard     |
| Zen Mode                         | (new)  | Toggle all HUD visibility             |
| Schematic quick save (selection) | 45     | Save selected nodes as schematic      |

---

### v0.3.0 — "The Navigation Update"

**Theme:** Large graph management  
**Target:** Q2 2026

| Feature                 | Idea # | Notes                     |
| ----------------------- | ------ | ------------------------- |
| Lasso select connectors | 21     | If new hooks available    |
| Multi-connect batch     | 23     | One output to many inputs |
| Quick replace node      | 27     | Swap type, keep wires     |

---

### v1.0.0 — "The Ecosystem"

**Theme:** Major feature completion  
**Target:** Q3-Q4 2026

| Feature                       | Idea # | Notes                          |
| ----------------------------- | ------ | ------------------------------ |
| Node graph auto-layout engine | 54     | One-click tidy layout          |
| Schematic diff and merge tool | 55     | Compare and combine schematics |
| Selection macro recorder      | 56     | Record and replay actions      |
| Modular group templates       | 57     | Reusable group layouts         |
| Cross-save settings sync      | 58     | Steam Cloud or export          |
| Minimap                       | (new)  | Graph overview panel           |

---

## Version Summary Table

| Version   | Theme              | Key Features                       | Est. Effort |
| --------- | ------------------ | ---------------------------------- | ----------- |
| 0.0.22    | Polish & Tooltips  | Tooltips, warnings, onboarding     | 1-2 days    |
| 0.0.23    | Quick Actions      | Palette commands                   | 1-2 days    |
| 0.0.24    | Wire Presets       | Color themes, cache refresh        | 2-3 days    |
| 0.0.25    | Alignment Tools    | Align, distribute, fit group       | 2-3 days    |
| 0.0.26    | HUD Enhancements   | Quick toggles, search, meter       | 2-3 days    |
| 0.0.27    | Node Search        | Palette node/group search          | 3-4 days    |
| 0.0.28    | Screenshot+        | Selection capture, queue           | 3-4 days    |
| 0.0.29    | Selection Stats    | Stats panel, resource rate         | 3-4 days    |
| 0.0.30    | Camera Bookmarks   | Save/jump positions                | 2-3 days    |
| 0.0.31    | Group Enhancements | Opacity, glow, color sync          | 3-4 days    |
| 0.0.32    | Theme & Profiles   | UI themes, profiles, boot          | 4-5 days    |
| 0.0.33    | Advanced Workflows | Box→Group, reroute, tab buy        | 4-5 days    |
| 0.0.34    | Config Management  | Export/import, toast history       | 2-3 days    |
| 0.0.35    | Diagnostics        | Safe mode, conflicts, cleanup      | 3-4 days    |
| 0.0.36    | Auto-Arrange       | Category layout, focus mute        | 5-7 days    |
| **0.1.0** | **Flow Update**    | **Stable release milestone**       | —           |
| 0.2.0     | Platform Update    | APIs, snapshots, Zen Mode          | 2-3 weeks   |
| 0.3.0     | Navigation Update  | Lasso, multi-connect, replace      | 2-3 weeks   |
| **1.0.0** | **Ecosystem**      | **Auto-layout, macros, templates** | 4-6 weeks   |

---

## Release Principles

1. **Ship small, ship often** — Each 0.0.x release should be completable in 1-5 days
2. **Theme coherence** — Group related features for easier testing and documentation
3. **Backwards compatible** — Config migrations, save compatibility maintained
4. **Test before release** — Each version verified against latest game version
5. **Document changes** — Changelog updated with every release
6. **User feedback** — Prioritize based on community requests between releases

---

> **Note:** This roadmap is a living document. Feature order and grouping may change based on:
>
> - User feedback and feature requests
> - Game updates that affect mod compatibility
> - Technical discoveries during implementation
> - Community contributions and PRs
