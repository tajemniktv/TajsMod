# ==============================================================================
# Taj's Mod - Upload Labs
# Author: TajemnikTV
# Description: A growing collection of Utility / QoL + Visual Tweaks for Upload Labs
# ==============================================================================
extends Node

const LOG_NAME = "TajsModded:Main"
const MOD_DIR = "TajemnikTV-TajsModded"

# Preload our modules
const ConfigManager = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/config_manager.gd")
const Patcher = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/patcher.gd")
const SettingsUI = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/ui/settings_ui.gd")
const ScreenshotManagerScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/screenshot_manager.gd")
const PaletteControllerScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/palette/palette_controller.gd")
const ColorPickerPanelScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/ui/color_picker_panel.gd")

const WireClearHandlerScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/wire_drop/wire_clear_handler.gd")
const FocusHandlerScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/focus_handler.gd")
const WireColorOverridesScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/wire_color_overrides.gd")
const GotoGroupManagerScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/goto_group_manager.gd")
const GotoGroupPanelScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/goto_group_panel.gd")
const NodeGroupZOrderFixScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/node_group_z_order_fix.gd")
const BuyMaxManagerScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/buy_max_manager.gd")
const CheatManagerScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/cheat_manager.gd")
const NotificationLogPanelScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/ui/notification_log_panel.gd")
const DisconnectedNodeHighlighterScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/disconnected_node_highlighter.gd")
const UpgradeManagerScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/upgrade_manager.gd")
const StickyNoteManagerScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/sticky_note_manager.gd")
const SmoothScrollManagerScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/smooth_scroll_manager.gd")
const UndoManagerScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/undo/undo_manager.gd")
const WorkshopSyncScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/workshop_sync.gd")
const RestartRequiredWindowScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/ui/restart_required_window.gd")
const KeybindsManagerScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/keybinds/keybinds_manager.gd")
const KeybindsUIScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/keybinds/keybinds_ui.gd")
const KeybindsRegistrationScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/keybinds/keybinds_registration.gd")
const ModSettingsScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/mod_settings.gd")
const AttributeTweakerWindowScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/ui/attribute_tweaker_window.gd")
const BreachThreatManagerScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/breach_threat_manager.gd")

# Components
var config # ConfigManager instance
var ui # SettingsUI instance
var screenshot_manager # ScreenshotManager instance
var palette_controller # PaletteController instance
var wire_clear_handler # WireClearHandler instance
var focus_handler # FocusHandler instance
var wire_colors # WireColorOverrides instance
var goto_group_manager # GotoGroupManager instance
var goto_group_panel # GotoGroupPanel instance
var node_group_z_fix # NodeGroupZOrderFix instance
var buy_max_manager # BuyMaxManager instance
var cheat_manager # CheatManager instance
var notification_log_panel # NotificationLogPanel instance
var disconnected_highlighter # DisconnectedNodeHighlighter instance
var sticky_note_manager # StickyNoteManager instance
var upgrade_manager # UpgradeManager instance
var smooth_scroll_manager # SmoothScrollManager instance
var undo_manager # UndoManager instance
var workshop_sync # WorkshopSync instance
var keybinds_manager # KeybindsManager instance
var keybinds_ui # KeybindsUI instance
var keybinds_registration # KeybindsRegistration instance
var settings # TajsModSettings instance
var breach_threat_manager # BreachThreatManager instance


# State
var mod_dir_path: String = ""
var mod_version: String = "0.0.0"
var _desktop_patched := false
var _desktop_patch_failed := false

# Custom Color Picker State
var shared_color_picker # ColorPickerPanel instance
var picker_canvas # CanvasLayer for picker
var _current_picker_callback: Callable
# ==============================================================================
# LIFECYCLE
# ==============================================================================

func _init() -> void:
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/globals.gd")
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/windows_menu.gd")
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/schematic_container.gd")
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/popup_schematic.gd")
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/options_bar.gd")
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scenes/windows/window_group.gd")
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scenes/windows/window_bin.gd")
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scenes/windows/window_inventory.gd") # 6 inputs
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scenes/request_panel.gd")
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/requests_tab.gd")
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/achievements_tab.gd")
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/tokens_tab.gd")
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/upgrades_tab.gd")
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/resource_description.gd")
    
    # Workspace Bounds Extensions (Expanded Board)
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/camera_2d.gd")
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/main_2d.gd")
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/lines.gd")
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/paint.gd")
    
    # WindowContainer hooks (cannot use extensions due to class_name, using Script Hooks API instead)
    # NOTE: Expanded workspace feature shelved - hooks don't work in shipped builds without game dev preprocessing
    # ModLoaderMod.install_script_hooks(
    #     "res://scenes/windows/window_container.gd",
    #     "res://mods-unpacked/TajemnikTV-TajsModded/extensions/scenes/windows/window_container.hooks.gd"
    # )
    
    
    ModLoaderLog.info("TajsModded Initialization...", LOG_NAME)
    mod_dir_path = ModLoaderMod.get_unpacked_dir().path_join(MOD_DIR)
    _load_version()
    
    # Init Config
    config = ConfigManager.new()
    
    # Init Workspace Bounds from config
    const WorkspaceBoundsScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/workspace_bounds.gd")
    WorkspaceBoundsScript.initialize(
        config.get_value("expanded_workspace_enabled", false),
        config.get_value("workspace_multiplier", 1.0)
    )
    
    # Init Screenshot Manager (tree set in _ready)
    screenshot_manager = ScreenshotManagerScript.new()
    screenshot_manager.quality = int(config.get_value("screenshot_quality", 2))
    screenshot_manager.screenshot_folder = config.get_value("screenshot_folder", "user://screenshots")
    screenshot_manager.watermark_enabled = config.get_value("screenshot_watermark", true)
    screenshot_manager.set_config(config)
    
    # Init Palette Controller
    palette_controller = PaletteControllerScript.new()
    add_child(palette_controller)
    
    # Init Wire Clear Handler
    wire_clear_handler = WireClearHandlerScript.new()
    wire_clear_handler.setup(config)
    add_child(wire_clear_handler)
    
    # Init Focus Handler (mute on focus loss)
    focus_handler = FocusHandlerScript.new()
    focus_handler.setup(config)
    add_child(focus_handler)
    
    # Init Smooth Scroll Manager
    smooth_scroll_manager = SmoothScrollManagerScript.new()
    smooth_scroll_manager.name = "SmoothScrollManager"
    add_child(smooth_scroll_manager)
    smooth_scroll_manager.setup(config)
    
    # Init Undo Manager
    undo_manager = UndoManagerScript.new()
    undo_manager.name = "UndoManager"
    add_child(undo_manager)
    
    # Init Keybinds Manager (MUST be early, before other components that need it)
    keybinds_manager = KeybindsManagerScript.new()
    keybinds_manager.name = "KeybindsManager"
    add_child(keybinds_manager)
    keybinds_manager.setup(config, self)

    # Init Breach Threat Manager (auto-escalate threat levels)
    breach_threat_manager = BreachThreatManagerScript.new()
    breach_threat_manager.name = "BreachThreatManager"
    add_child(breach_threat_manager)
    breach_threat_manager.setup(config, config.get_value("debug_mode", false))
    
    # Init Cheat Manager
    cheat_manager = CheatManagerScript.new()
    cheat_manager.setup(self)
    
    # Init Workshop Sync (runs early to trigger downloads ASAP)
    workshop_sync = WorkshopSyncScript.new()
    workshop_sync.name = "WorkshopSync"
    workshop_sync.sync_on_startup = config.get_value("workshop_sync_on_startup", true)
    workshop_sync.high_priority_downloads = config.get_value("workshop_high_priority", true)
    workshop_sync.force_download_all = config.get_value("workshop_force_all", true)
    workshop_sync.set_restart_callback(_show_restart_required_window)
    workshop_sync.set_debug_log_callback(_debug_log_wrapper)
    add_child(workshop_sync)
    
    # Trigger sync on startup if enabled
    if workshop_sync.sync_on_startup:
        call_deferred("_start_workshop_sync")
    
    # Init Wire Color Overrides (applied in _ready when Data is loaded)
    wire_colors = WireColorOverridesScript.new()

func _ready() -> void:
    ModLoaderLog.info("TajsMod is ready to improve your game!", LOG_NAME)
    
    # Setup Keybinds Global Reference & Registration
    Globals.keybinds_manager = keybinds_manager
    keybinds_registration = KeybindsRegistrationScript.new()
    keybinds_registration.setup(keybinds_manager, self)

    # Init Shared Color Picker Overlay
    picker_canvas = CanvasLayer.new()
    picker_canvas.layer = 100 # High Z-index
    picker_canvas.visible = false
    add_child(picker_canvas)
    
    # Backdrop to close on click outside
    var backdrop = ColorRect.new()
    backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
    backdrop.color = Color(0, 0, 0, 0.5)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    # Click to close
    backdrop.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed:
            _close_color_picker()
    )
    picker_canvas.add_child(backdrop)
    
    shared_color_picker = ColorPickerPanelScript.new()
    shared_color_picker.set_anchors_preset(Control.PRESET_CENTER)
    # shared_color_picker.position = ... (centered by preset)
    picker_canvas.add_child(shared_color_picker)
    
    # Connect signals
    shared_color_picker.color_changed.connect(_on_picker_color_changed)
    
    # Apply wire color overrides (Data is now loaded)
    wire_colors.setup(config)
    if config.get_value("custom_wire_colors", true):
        wire_colors.apply_overrides()
    
    # Set tree for screenshot manager (not available in _init)
    screenshot_manager.set_tree(get_tree())
    
    # Apply saved node limit from config
    var saved_limit = config.get_value("node_limit", 400)
    Globals.custom_node_limit = saved_limit
    ModLoaderLog.info("Applied node limit from config: " + str(saved_limit), LOG_NAME)
    
    # Patching
    Patcher.inject_bin_window()
    call_deferred("_sanitize")
    
    # Listen for Main
    get_tree().node_added.connect(_on_node_added)
    call_deferred("_check_existing_main")

func _open_color_picker(start_color: Color, callback: Callable) -> void:
    _current_picker_callback = callback
    shared_color_picker.set_color(start_color)
    picker_canvas.visible = true
    
func _close_color_picker() -> void:
    picker_canvas.visible = false
    _current_picker_callback = Callable()
    
func _on_picker_color_changed(c: Color) -> void:
    if _current_picker_callback.is_valid():
        _current_picker_callback.call(c)

## Register all keybinds with the KeybindsManager
# NOTE: Registration logic moved to extensions/scripts/keybinds/keybinds_registration.gd


func _process(delta: float) -> void:
    # Persistent Patches (only try once on failure to avoid log spam)
    if !_desktop_patched and !_desktop_patch_failed:
        var result = Patcher.patch_desktop_script("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/desktop.gd")
        if result:
            _desktop_patched = true
        else:
            _desktop_patch_failed = true # Don't spam retries
        
    # Update UI Logic
    if settings:
        settings.update_node_label()
    
    # Boot Screen (only patch if custom boot screen is enabled)
    if config.get_value("custom_boot_screen", true):
        var boot = get_tree().root.get_node_or_null("Boot")
        if is_instance_valid(boot):
            Patcher.patch_boot_screen(boot, mod_version, mod_dir_path.path_join("TajsModHeader.png"))

func _input(event: InputEvent) -> void:
    # Controller Input Blocking
    if config.get_value("disable_controller_input", false):
        if event is InputEventJoypadMotion or event is InputEventJoypadButton:
            get_viewport().set_input_as_handled()
            return
    
    # NOTE: Undo/Redo is now handled by KeybindsManager

    # Global Slider Scroll Blocking (affects all sliders - mod and vanilla)
    if config.get_value("disable_slider_scroll", false):
        if event is InputEventMouseButton and event.pressed:
            if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
                # Check if mouse is over any slider
                var hovered_control = _get_hovered_slider()
                if hovered_control:
                    get_viewport().set_input_as_handled()
                    return
    
    # UI Close Logic
    if !ui or !ui.is_visible(): return
    
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var mouse_pos := get_viewport().get_mouse_position()
        var panel_rect: Rect2 = ui.settings_panel.get_global_rect() # Access via property or similar? ui.settings_panel is public?
        # ui.settings_panel is a var in SettingsUI. Let's assume it's accessible or has getter.
        # Actually SettingsUI seems to expose it.
        
        # However, checking existence of picker canvas first
        if picker_canvas and picker_canvas.visible:
            # If picker is open, let its backdrop handle closing, don't close settings UI underneath
            return

        var btn_rect: Rect2 = ui.settings_button.get_global_rect() if ui.settings_button else Rect2()
        
        if !panel_rect.has_point(mouse_pos) and !btn_rect.has_point(mouse_pos):
            ui.set_visible(false)

## Helper to find if a slider control is currently under the mouse cursor
func _get_hovered_slider() -> Control:
    var mouse_pos := get_viewport().get_mouse_position()
    var root := get_tree().root
    return _find_slider_at_point(root, mouse_pos)

func _find_slider_at_point(node: Node, point: Vector2) -> Control:
    # Check children in reverse order (topmost first due to draw order)
    for i in range(node.get_child_count() - 1, -1, -1):
        var child = node.get_child(i)
        var result = _find_slider_at_point(child, point)
        if result:
            return result
    
    # Check if this node is a visible slider containing the point
    if node is HSlider or node is VSlider:
        var slider := node as Control
        if slider.visible and slider.get_global_rect().has_point(point):
            # Also check if any ancestor is invisible
            if _is_control_visible_in_tree(slider):
                return slider
    
    return null

func _is_control_visible_in_tree(control: Control) -> bool:
    var current = control
    while current:
        if not current.visible:
            return false
        current = current.get_parent() as Control
    return true

# ==============================================================================
# SETUP
# ==============================================================================

func _sanitize() -> void:
    Patcher.sanitize_schematics()

func _check_existing_main() -> void:
    var main = get_tree().root.get_node_or_null("Main")
    if main: _setup_for_main(main)

func _on_node_added(node: Node) -> void:
    if node.name == "Main" and node.get_parent().name == "root":
        # Wait for things to settle
        await get_tree().create_timer(0.5).timeout
        _setup_for_main(node)
        Signals.notify.emit("exclamation", "Taj's Mod Initialized")

func _setup_for_main(main_node: Node) -> void:
    var hud = main_node.get_node_or_null("HUD")
    if !hud: return
    
    # Check if already set up by looking for our container in Overlay
    var overlay = hud.get_node_or_null("Main/MainContainer/Overlay")
    if overlay and overlay.has_node("TajsModdedMenus"): return
    
    # Init UI
    ui = SettingsUI.new(hud, mod_version)
    ui.add_mod_button(func(): ui.set_visible(!ui.is_visible()))
    ui.set_config(config) # Pass config reference for slider scroll setting
    
    # Configure screenshot manager
    screenshot_manager.set_ui(ui)
    screenshot_manager.set_log_callback(_debug_log_wrapper)
    
    # Initialize Disconnected Node Highlighter BEFORE building settings menu
    # (settings menu captures highlighter_ref, so it must exist first)
    _setup_disconnected_highlighter()
    
    # Initialize Settings UI via ModSettings class (extracted from this file)
    settings = ModSettingsScript.new()
    settings.setup(self, config, ui, {
        "screenshot_manager": screenshot_manager,
        "wire_colors": wire_colors,
        "palette_controller": palette_controller,
        "focus_handler": focus_handler,
        "smooth_scroll_manager": smooth_scroll_manager,
        "disconnected_highlighter": disconnected_highlighter,
        "sticky_note_manager": sticky_note_manager,
        "undo_manager": undo_manager,
        "workshop_sync": workshop_sync,
        "cheat_manager": cheat_manager,
        "keybinds_manager": keybinds_manager,
        "keybinds_ui": keybinds_ui,
        "node_group_z_fix": node_group_z_fix,
        "buy_max_manager": buy_max_manager,
        "goto_group_panel": goto_group_panel,
        "breach_threat_manager": breach_threat_manager
    })
    settings.build_settings_menu()
    
    # Initialize palette system
    palette_controller.initialize(get_tree(), config, ui, self)
    _register_palette_screenshot_command()
    
    # Connect palette signals to KeybindsManager for context tracking
    if palette_controller and keybinds_manager:
        palette_controller.palette_opened.connect(func(): keybinds_manager.set_palette_open(true))
        palette_controller.palette_closed.connect(func(): keybinds_manager.set_palette_open(false))
    
    # Initialize Go To Group feature
    _setup_goto_group(hud)
    
    # Initialize Node Group Z-Order Fix (contained groups render on top)
    _setup_node_group_z_order()
    
    # Initialize Buy Max feature for upgrade tabs
    _setup_buy_max()
    
    # Initialize Notification Log (Toast History) panel
    _setup_notification_log(hud)
    
    # Initialize Sticky Notes feature
    _setup_sticky_notes()
    
    # Initialize Upgrade Manager (Modifier Keys)
    _setup_upgrade_manager()
    
    # Apply initial visuals
    if config.get_value("extra_glow"):
        _apply_extra_glow(true)
    _apply_ui_opacity(config.get_value("ui_opacity"))
    
    # Apply initial feature states from config
    Globals.select_all_enabled = config.get_value("select_all_enabled", true)
    if not config.get_value("goto_group_enabled", true):
        call_deferred("_set_goto_group_visible", false)
    if not config.get_value("buy_max_enabled", true):
        call_deferred("_set_buy_max_visible", false)
    if not config.get_value("notification_log_enabled", true):
        call_deferred("_set_notification_log_visible", false)
    if node_group_z_fix and not config.get_value("z_order_fix_enabled", true):
        node_group_z_fix.set_enabled(false)
    if disconnected_highlighter and not config.get_value("highlight_disconnected_enabled", true):
        disconnected_highlighter.set_enabled(false)
        
    smooth_scroll_manager.set_enabled(config.get_value("smooth_scroll_enabled", false))
    
    # Setup Undo Manager (connect signals now that desktop exists)
    if undo_manager:
        undo_manager.setup(get_tree(), config, self)
        Globals.undo_manager = undo_manager


## Setup Go To Node Group panel in the HUD
## Adds a button to the bottom-left area that opens a popup to navigate to any Node Group
func _setup_goto_group(hud: Node) -> void:
    # Find the Overlay container where we'll add our panel
    var overlay = hud.get_node_or_null("Main/MainContainer/Overlay")
    if not overlay:
        ModLoaderLog.warning("Could not find HUD Overlay for Go To Group panel", LOG_NAME)
        return
    
    # Check if already set up
    if overlay.has_node("GotoGroupContainer"):
        return
    
    # Create the manager
    goto_group_manager = GotoGroupManagerScript.new()
    goto_group_manager.name = "GotoGroupManager"
    add_child(goto_group_manager)
    
    # Create the panel
    goto_group_panel = GotoGroupPanelScript.new()
    goto_group_panel.name = "GotoGroupPanel"
    goto_group_panel.setup(goto_group_manager)
    
    # Create a container for the panel positioned ABOVE the bottom toolbar
    # The bottom bar is approximately 70px tall, so we position above it
    var goto_container = Control.new()
    goto_container.name = "GotoGroupContainer"
    goto_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    goto_container.custom_minimum_size = Vector2(70, 70)
    
    # Position it above the bottom toolbar (which is ~70px)
    goto_container.anchor_left = 0
    goto_container.anchor_top = 1
    goto_container.anchor_right = 0
    goto_container.anchor_bottom = 1
    goto_container.offset_left = 5
    goto_container.offset_top = -150 # Move higher to avoid overlap
    goto_container.offset_right = 75
    goto_container.offset_bottom = -80 # Above the bottom bar
    
    goto_group_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    goto_container.add_child(goto_group_panel)
    
    overlay.add_child(goto_container)
    ModLoaderLog.info("Go To Group panel added to HUD", LOG_NAME)


## Setup Node Group Z-Order Fix
## Ensures that fully contained Node Groups always render on top of their containers
func _setup_node_group_z_order() -> void:
    # Check if already set up
    if node_group_z_fix != null and is_instance_valid(node_group_z_fix):
        return
    
    # Create the manager
    node_group_z_fix = NodeGroupZOrderFixScript.new()
    node_group_z_fix.name = "NodeGroupZOrderFix"
    add_child(node_group_z_fix)
    
    ModLoaderLog.info("Node Group Z-Order Fix initialized", LOG_NAME)


## Setup Buy Max feature for upgrade tabs
## Adds a "Buy Max" button to purchase multiple upgrades at once
func _setup_buy_max() -> void:
    # Check if already set up
    if buy_max_manager != null and is_instance_valid(buy_max_manager):
        return
    
    # Create the manager
    buy_max_manager = BuyMaxManagerScript.new()
    buy_max_manager.name = "BuyMaxManager"
    add_child(buy_max_manager)
    
    # Initialize after a short delay to ensure UI is ready
    await get_tree().create_timer(0.1).timeout
    buy_max_manager.setup(get_tree(), config)
    
    # Apply initial visibility state (fixes race condition on startup)
    var enabled = config.get_value("buy_max_enabled", true)
    _set_buy_max_visible(enabled)
    
    ModLoaderLog.info("Buy Max feature initialized", LOG_NAME)


## Setup Disconnected Node Highlighter
## Visually highlights nodes that are not connected to the main graph
func _setup_disconnected_highlighter() -> void:
    # Check if already set up
    if disconnected_highlighter != null and is_instance_valid(disconnected_highlighter):
        return
    
    # Create the highlighter
    disconnected_highlighter = DisconnectedNodeHighlighterScript.new()
    disconnected_highlighter.name = "DisconnectedNodeHighlighter"
    add_child(disconnected_highlighter)
    
    # Initialize with config and tree (pass self for debug mode access)
    disconnected_highlighter.setup(config, get_tree(), self)
    
    ModLoaderLog.info("Disconnected Node Highlighter initialized", LOG_NAME)


## Setup Sticky Notes feature
## Allows players to place editable text notes on the canvas
func _setup_sticky_notes() -> void:
    # Check if already set up
    if sticky_note_manager != null and is_instance_valid(sticky_note_manager):
        return
    
    # Create the manager
    sticky_note_manager = StickyNoteManagerScript.new()
    sticky_note_manager.name = "StickyNoteManager"
    add_child(sticky_note_manager)
    
    # Initialize with config and tree
    sticky_note_manager.setup(config, get_tree(), self)
    
    # Apply debug setting (settings class will handle this when built)
    var debug_enabled = config.get_value("debug_mode", false)
    sticky_note_manager.set_debug_enabled(debug_enabled)
    
    ModLoaderLog.info("Sticky Notes feature initialized", LOG_NAME)


## Start Workshop Sync (deferred call)
func _start_workshop_sync() -> void:
    if workshop_sync:
        workshop_sync.start_sync()


## Show the Restart Required modal window
func _show_restart_required_window() -> void:
    var window = RestartRequiredWindowScript.new()
    window.name = "RestartRequiredWindow"
    
    # Set dismiss callback to trigger the settings banner
    window.set_dismiss_callback(func():
        if ui:
            ui.show_restart_banner()
    )
    
    get_tree().root.add_child(window)
    ModLoaderLog.info("Showing Restart Required window", LOG_NAME)

# ==============================================================================
# HELPERS
# ==============================================================================

func _load_version() -> void:
    var manifest_path := mod_dir_path.path_join("manifest.json")
    if FileAccess.file_exists(manifest_path):
        var file := FileAccess.open(manifest_path, FileAccess.READ)
        if file:
            var json := JSON.new()
            if json.parse(file.get_as_text()) == OK:
                var data = json.get_data()
                if data is Dictionary and data.has("version_number"):
                    mod_version = data["version_number"]

## Debug log wrapper - forwards to settings.add_debug_log when available
func _debug_log_wrapper(message: String, force: bool = false) -> void:
    if settings:
        settings.add_debug_log(message, force)
    else:
        # Fallback: just log to ModLoader
        ModLoaderLog.info(message, LOG_NAME)

## Public method to update node limit from palette
func set_node_limit(value: int) -> void:
    if settings:
        settings.set_node_limit(value)
    else:
        config.set_value("node_limit", value)
        Globals.custom_node_limit = value

## Public method to update extra glow from palette
func set_extra_glow(enabled: bool) -> void:
    if settings:
        settings.set_extra_glow(enabled)
    else:
        config.set_value("extra_glow", enabled)
        _apply_extra_glow(enabled)

func _apply_extra_glow(enabled: bool) -> void:
    var main = get_tree().root.get_node_or_null("Main")
    if !main: return
    
    var env_node = main.find_child("WorldEnvironment", true, false)
    if !env_node or !env_node.environment: return
    
    var env: Environment = env_node.environment
    
    if enabled:
        env.glow_enabled = true
        env.glow_intensity = config.get_value("glow_intensity")
        env.glow_strength = config.get_value("glow_strength")
        env.glow_bloom = config.get_value("glow_bloom")
        env.glow_hdr_threshold = config.get_value("glow_sensitivity")
    else:
        # Reset to defaults or just disable glow_enabled
        env.glow_enabled = false

func _apply_ui_opacity(value: float) -> void:
    # This likely modifies a theme or node modulate. 
    # For now, we can set modulate on the HUD's main container if accessible.
    var main = get_tree().root.get_node_or_null("Main")
    if main:
        var hud = main.get_node_or_null("HUD")
        if hud:
            var main_container = hud.get_node_or_null("Main/MainContainer")
            if main_container:
                main_container.modulate.a = value / 100.0


## Helper to show/hide Go To Group panel
func _set_goto_group_visible(visible: bool) -> void:
    if goto_group_panel:
        var container = goto_group_panel.get_parent()
        if container:
            container.visible = visible

## Helper to show/hide Buy Max button
func _set_buy_max_visible(visible: bool) -> void:
    if buy_max_manager and is_instance_valid(buy_max_manager):
        buy_max_manager.set_visible(visible)


## Helper to show/hide Notification Log panel
func _set_notification_log_visible(visible: bool) -> void:
    if notification_log_panel and notification_log_panel.toggle_btn:
        notification_log_panel.toggle_btn.visible = visible
        if not visible and notification_log_panel.is_popup_open:
            notification_log_panel._close_popup()


## Setup Notification Log (Toast History) panel in the HUD
## Adds a bell button that shows a popup with the last 20 notifications
func _setup_notification_log(hud: Node) -> void:
    # Find the Overlay where we'll add our button container
    var overlay = hud.get_node_or_null("Main/MainContainer/Overlay")
    if not overlay:
        ModLoaderLog.warning("Could not find Overlay for Notification Log", LOG_NAME)
        return
    
    # Check if already set up
    if overlay.has_node("NotificationLogContainer"):
        return
    
    # Create a container positioned to the LEFT of ExtrasButtons
    var container = Control.new()
    container.name = "NotificationLogContainer"
    container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    container.anchor_left = 1
    container.anchor_top = 0
    container.anchor_right = 1
    container.anchor_bottom = 0
    # Position to the left of ExtrasButtons (~70px for button width + margin)
    container.offset_left = -140 # Far enough left to clear ExtrasButtons
    container.offset_top = 10
    container.offset_right = -80
    container.offset_bottom = 70
    
    overlay.add_child(container)
    
    # Create the panel
    notification_log_panel = NotificationLogPanelScript.new()
    notification_log_panel.name = "NotificationLogPanel"
    container.add_child(notification_log_panel)
    
    # Connect to Signals.notify to capture all notifications
    if not Signals.notify.is_connected(_on_notification_received):
        Signals.notify.connect(_on_notification_received)
    
    ModLoaderLog.info("Notification Log panel added to HUD", LOG_NAME)


## Callback for Signals.notify - captures notifications for the log
func _on_notification_received(icon: String, text: String) -> void:
    if notification_log_panel:
        notification_log_panel.add_notification(icon, text)


## Sync a settings toggle UI with its config value (called from palette commands)
func sync_settings_toggle(config_key: String) -> void:
    if settings:
        settings.sync_settings_toggle(config_key)


func _register_palette_screenshot_command() -> void:
    # Override the screenshot command to use our screenshot manager
    var registry = palette_controller.get_registry()
    var sm = screenshot_manager # Capture reference for closure
    
    registry.register({
        "id": "cmd_take_screenshot",
        "title": "Take Screenshot",
        "category_path": ["Taj's Mod", "Screenshots"],
        "keywords": ["screenshot", "capture", "photo", "save", "image"],
        "hint": "Capture a full desktop screenshot",
        "icon_path": "res://textures/icons/centrifuge.png",
        "badge": "SAFE",
        "run": func(ctx): sm.take_screenshot()
    })
    
    registry.register({
        "id": "cmd_open_screenshot_folder",
        "title": "Open Screenshot Folder",
        "category_path": ["Taj's Mod", "Screenshots"],
        "keywords": ["screenshot", "folder", "open", "browse", "explorer"],
        "hint": "Open the screenshot folder in your file explorer",
        "icon_path": "res://textures/icons/folder.png",
        "badge": "SAFE",
        "run": func(ctx): sm.open_screenshot_folder()
    })
    
    registry.register({
        "id": "cmd_screenshot_selection",
        "title": "Screenshot: Capture Selection",
        "category_path": ["Taj's Mod", "Screenshots"],
        "keywords": ["screenshot", "capture", "selection", "nodes", "crop", "area", "selected"],
        "hint": "Capture a screenshot of selected nodes only",
        "icon_path": "res://textures/icons/centrifuge.png",
        "badge": "SAFE",
        "can_run": func(ctx): return Globals and Globals.selections.size() > 0,
        "run": func(ctx): sm.take_screenshot_selection()
    })


## Setup Upgrade Manager (Modifier Keys)
## Handles bulk upgrades (x10, x100) using modifier keys on window upgrade buttons
func _setup_upgrade_manager() -> void:
    # Check if already set up
    if upgrade_manager != null and is_instance_valid(upgrade_manager):
        return
        
    # Create the manager
    upgrade_manager = UpgradeManagerScript.new()
    upgrade_manager.name = "UpgradeManager"
    add_child(upgrade_manager)
    
    # Initialize
    upgrade_manager.setup(get_tree(), config, self)
    
    ModLoaderLog.info("Upgrade Manager initialized", LOG_NAME)

## API: Returns the user-friendly name of this mod
func get_mod_name() -> String:
    return "Taj's Mod"
