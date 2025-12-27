# ==============================================================================
# Taj's Mod - Upload Labs
# Author: TajemnikTV
# Description: TBD
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

# State
var mod_dir_path: String = ""
var mod_version: String = "0.0.0"
var _desktop_patched := false
var _node_info_label: Label = null # Reference for updates
var _debug_log_label: Label = null # Debug log display
var _debug_mode := false # Toggle for verbose debug logging
var _node_limit_slider: HSlider = null
var _node_limit_value_label: Label = null
var _extra_glow_toggle: CheckButton = null
var _extra_glow_sub: MarginContainer = null
var _settings_toggles: Dictionary = {} # config_key -> CheckButton reference

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
    
    ModLoaderLog.info("TajsModded Initialization...", LOG_NAME)
    mod_dir_path = ModLoaderMod.get_unpacked_dir().path_join(MOD_DIR)
    _load_version()
    
    # Init Config
    config = ConfigManager.new()
    
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
    
    # Init Wire Color Overrides (applied in _ready when Data is loaded)
    wire_colors = WireColorOverridesScript.new()

func _ready() -> void:
    ModLoaderLog.info("TajsModded ready!", LOG_NAME)
    
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

func _process(delta: float) -> void:
    # Persistent Patches
    if !_desktop_patched:
        _desktop_patched = Patcher.patch_desktop_script("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/desktop.gd")
        
    # Update UI Logic
    _update_node_label()
    
    # Boot Screen (only patch if custom boot screen is enabled)
    if config.get_value("custom_boot_screen", true):
        var boot = get_tree().root.get_node_or_null("Boot")
        if is_instance_valid(boot):
            Patcher.patch_boot_screen(boot, mod_version, mod_dir_path.path_join("icon.png"))

func _input(event: InputEvent) -> void:
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
    
    # Configure screenshot manager
    screenshot_manager.set_ui(ui)
    screenshot_manager.set_log_callback(_add_debug_log)
    
    _build_settings_menu()
    
    # Initialize palette system
    palette_controller.initialize(get_tree(), config, ui, self)
    _register_palette_screenshot_command()
    
    # Initialize Go To Group feature
    _setup_goto_group(hud)
    
    # Initialize Node Group Z-Order Fix (contained groups render on top)
    _setup_node_group_z_order()
    
    # Initialize Buy Max feature for upgrade tabs
    _setup_buy_max()
    
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
    if node_group_z_fix and not config.get_value("z_order_fix_enabled", true):
        node_group_z_fix.set_enabled(false)


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
    buy_max_manager.setup(get_tree())
    
    ModLoaderLog.info("Buy Max feature initialized", LOG_NAME)


func _build_settings_menu() -> void:
    # --- GENERAL ---
    var gen_vbox = ui.add_tab("General", "res://textures/icons/cog.png")
    
    # Wire Drop Node Menu toggle
    _settings_toggles["wire_drop_menu_enabled"] = ui.add_toggle(gen_vbox, "Wire Drop Node Menu", config.get_value("wire_drop_menu_enabled"), func(v):
        config.set_value("wire_drop_menu_enabled", v)
        palette_controller.set_wire_drop_enabled(v)
    )
    
    # 6-Input Containers toggle (Issue #18) - requires restart
    _settings_toggles["six_input_containers"] = ui.add_toggle(gen_vbox, "6-Input Containers ⟳", config.get_value("six_input_containers"), func(v):
        config.set_value("six_input_containers", v)
        _show_restart_dialog()
    )
    
    # Command Palette toggle
    _settings_toggles["command_palette_enabled"] = ui.add_toggle(gen_vbox, "Command Palette (MMB)", config.get_value("command_palette_enabled"), func(v):
        config.set_value("command_palette_enabled", v)
        if palette_controller:
            palette_controller.set_palette_enabled(v)
    )
    
    # Right-click Wire Clear toggle
    _settings_toggles["right_click_clear_enabled"] = ui.add_toggle(gen_vbox, "Right-click Wire Clear", config.get_value("right_click_clear_enabled"), func(v):
        config.set_value("right_click_clear_enabled", v)
        if wire_clear_handler:
            wire_clear_handler.set_enabled(v)
    )
    
    # Select All (Ctrl+A) toggle
    _settings_toggles["select_all_enabled"] = ui.add_toggle(gen_vbox, "Ctrl+A Select All", config.get_value("select_all_enabled"), func(v):
        config.set_value("select_all_enabled", v)
        Globals.select_all_enabled = v
    )
    
    # Go To Group Panel toggle
    _settings_toggles["goto_group_enabled"] = ui.add_toggle(gen_vbox, "Go To Group Button", config.get_value("goto_group_enabled"), func(v):
        config.set_value("goto_group_enabled", v)
        _set_goto_group_visible(v)
    )
    
    # Buy Max Button toggle
    _settings_toggles["buy_max_enabled"] = ui.add_toggle(gen_vbox, "Buy Max Button", config.get_value("buy_max_enabled"), func(v):
        config.set_value("buy_max_enabled", v)
        _set_buy_max_visible(v)
    )
    
    # Z-Order Fix toggle
    _settings_toggles["z_order_fix_enabled"] = ui.add_toggle(gen_vbox, "Group Z-Order Fix", config.get_value("z_order_fix_enabled"), func(v):
        config.set_value("z_order_fix_enabled", v)
        if node_group_z_fix:
            node_group_z_fix.set_enabled(v)
    )
    
    # Node Info Label (Custom)
    var info_row = HBoxContainer.new()
    _node_info_label = Label.new()
    _node_info_label.text = "Nodes: ... / ..."
    _node_info_label.add_theme_font_size_override("font_size", 24)
    _node_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _node_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    info_row.add_child(_node_info_label)
    gen_vbox.add_child(info_row)
    
    # Node Limit (Custom with ∞ support)
    _add_node_limit_slider(gen_vbox)
    
    # Screenshot Section
    screenshot_manager.add_screenshot_section(gen_vbox, ui, config)
    
    # Focus Mute Section (Issue #11)
    var fh = focus_handler # Capture for closure
    _settings_toggles["mute_on_focus_loss"] = ui.add_toggle(gen_vbox, "Mute on Focus Loss", config.get_value("mute_on_focus_loss"), func(v):
        fh.set_enabled(v)
    )
    ui.add_slider(gen_vbox, "Background Volume", config.get_value("background_volume"), 0, 100, 5, "%", func(v):
        fh.set_background_volume(v)
    )
    
    # Note: Drag Dead Zone (Issue #13) cannot be implemented via script extension
    # due to class_name WindowContainer conflict. Would require game code change.
    
    # --- VISUALS ---
    var vis_vbox = ui.add_tab("Visuals", "res://textures/icons/eye_ball.png")
    
    # Wire Colors Section
    _add_wire_color_section(vis_vbox)
    
    # Glow toggle + sub-settings container
    var glow_container = VBoxContainer.new()
    glow_container.add_theme_constant_override("separation", 10)
    vis_vbox.add_child(glow_container)
    
    # Sub-settings (initially hidden)
    var glow_sub = MarginContainer.new()
    glow_sub.name = "glow_sub_settings"
    glow_sub.add_theme_constant_override("margin_left", 30)
    glow_sub.visible = config.get_value("extra_glow")
    
    var glow_sub_vbox = VBoxContainer.new()
    glow_sub_vbox.add_theme_constant_override("separation", 10)
    glow_sub.add_child(glow_sub_vbox)
    
    _extra_glow_toggle = ui.add_toggle(glow_container, "Extra Glow", config.get_value("extra_glow"), func(v):
        config.set_value("extra_glow", v)
        glow_sub.visible = v
        _apply_extra_glow(v)
    )
    _extra_glow_sub = glow_sub
    
    glow_container.add_child(glow_sub)
    
    ui.add_slider(glow_sub_vbox, "Intensity", config.get_value("glow_intensity"), 0.0, 5.0, 0.1, "x", func(v):
        config.set_value("glow_intensity", v)
        _apply_extra_glow(true)
    )
    ui.add_slider(glow_sub_vbox, "Strength", config.get_value("glow_strength"), 0.5, 2.0, 0.05, "x", func(v):
        config.set_value("glow_strength", v)
        _apply_extra_glow(true)
    )
    ui.add_slider(glow_sub_vbox, "Bloom", config.get_value("glow_bloom"), 0.0, 0.5, 0.05, "", func(v):
        config.set_value("glow_bloom", v)
        _apply_extra_glow(true)
    )
    ui.add_slider(glow_sub_vbox, "Sensitivity", config.get_value("glow_sensitivity"), 0.0, 1.0, 0.05, "", func(v):
        config.set_value("glow_sensitivity", v)
        _apply_extra_glow(true)
    )
    
    ui.add_slider(vis_vbox, "UI Opacity", config.get_value("ui_opacity"), 50, 100, 5, "%", func(v):
        config.set_value("ui_opacity", v)
        _apply_ui_opacity(v)
    )
    
    # --- CHEATS ---
    var cheat_vbox = ui.add_tab("Cheats", "res://textures/icons/money.png")
    cheat_manager = CheatManagerScript.new()
    cheat_manager.build_cheats_tab(cheat_vbox)
    
    # --- DEBUG ---
    var debug_vbox = ui.add_tab("Debug", "res://textures/icons/bug.png")
    
    ui.add_button(debug_vbox, "Reset All Settings", func():
        config.reset_to_defaults()
        # Apply defaults immediately
        Globals.custom_node_limit = config.get_value("node_limit")
        screenshot_manager.quality = int(config.get_value("screenshot_quality", 2))
        screenshot_manager.screenshot_folder = config.get_value("screenshot_folder", "user://screenshots")
        screenshot_manager.watermark_enabled = config.get_value("screenshot_watermark", true)
        wire_colors.set_enabled(config.get_value("custom_wire_colors", true))
        _apply_extra_glow(config.get_value("extra_glow"))
        _apply_ui_opacity(config.get_value("ui_opacity"))
        _add_debug_log("Settings reset to defaults")
        Signals.notify.emit("check", "Settings reset!")
    )
    
    # Custom Boot Screen toggle
    ui.add_toggle(debug_vbox, "Custom Boot Screen ⟳", config.get_value("custom_boot_screen", true), func(v):
        config.set_value("custom_boot_screen", v)
    )
    
    # Debug mode toggle
    var debug_toggle = ui.add_toggle(debug_vbox, "Enable Debug Logging", _debug_mode, func(v):
        _debug_mode = v
        _add_debug_log("Debug mode " + ("enabled" if v else "disabled"), true)
    )
    
    # Debug info buttons
    ui.add_button(debug_vbox, "Log Debug Info", func():
        _add_debug_log("=== DEBUG INFO ===", true)
        _add_debug_log("Money: " + str(Globals.currencies.get("money", 0)), true)
        _add_debug_log("Research: " + str(Globals.currencies.get("research", 0)), true)
        _add_debug_log("Tokens: " + str(Globals.currencies.get("token", 0)), true)
        _add_debug_log("Node Limit: " + str(Globals.custom_node_limit), true)
        _add_debug_log("Max Money: " + str(Globals.max_money), true)
        _add_debug_log("Max Research: " + str(Globals.max_research), true)
    )
    
    # Debug log label
    var log_label = Label.new()
    log_label.name = "DebugLogLabel"
    log_label.text = "Debug Log:\n"
    log_label.add_theme_font_size_override("font_size", 18)
    log_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
    log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    debug_vbox.add_child(log_label)
    _debug_log_label = log_label


func _add_wire_color_section(parent: Control) -> void:
    var wire_container = VBoxContainer.new()
    wire_container.add_theme_constant_override("separation", 10)
    parent.add_child(wire_container)
    
    # Sub-settings (shown when toggle is on)
    var wire_sub = MarginContainer.new()
    wire_sub.name = "wire_color_sub"
    wire_sub.add_theme_constant_override("margin_left", 20)
    wire_sub.visible = config.get_value("custom_wire_colors", true)
    
    var wire_sub_vbox = VBoxContainer.new()
    wire_sub_vbox.add_theme_constant_override("separation", 6)
    wire_sub.add_child(wire_sub_vbox)
    
    var wc = wire_colors # Capture for closure
    var sub_ref = wire_sub
    var self_ref = self
    
    # Main toggle
    ui.add_toggle(wire_container, "Custom Wire Colors", config.get_value("custom_wire_colors", true), func(v):
        config.set_value("custom_wire_colors", v)
        sub_ref.visible = v
        wc.set_enabled(v)
        self_ref._refresh_all_connectors()
    )
    
    wire_container.add_child(wire_sub)
    
    # Define categories
    var categories = {
        "⚡ Speeds": ["download_speed", "upload_speed", "clock_speed", "gpu_speed", "code_speed", "work_speed"],
        "💰 Resources": ["money", "research", "token", "power", "research_power", "contribution"],
        "🔓 Hacking": ["hack_power", "hack_experience", "virus", "trojan", "infected_computer"],
        "📊 Data Types": ["bool", "char", "int", "float", "bitflag", "bigint", "decimal", "string", "vector"],
        "🧠 AI / Neural": ["ai", "neuron_text", "neuron_image", "neuron_sound", "neuron_video", "neuron_program", "neuron_game"],
        "🚀 Boosts": ["boost_component", "boost_research", "boost_hack", "boost_code", "overclock"],
        "📦 Other": ["heat", "vulnerability", "storage", "corporation_data", "government_data", "litecoin", "bitcoin", "ethereum"]
    }
    
    var configurable = wire_colors.get_configurable_wires()
    
    # Create collapsible sections for each category
    for category_name in categories:
        var resource_ids = categories[category_name]
        _add_wire_category(wire_sub_vbox, category_name, resource_ids, configurable)
    
    # Apply button to refresh all connectors
    var apply_btn = Button.new()
    apply_btn.text = "🔄 Apply Colors"
    apply_btn.tooltip_text = "Refresh all visible wires with new colors"
    apply_btn.theme_type_variation = "TabButton"
    apply_btn.custom_minimum_size = Vector2(0, 45)
    apply_btn.pressed.connect(_refresh_all_connectors)
    wire_sub_vbox.add_child(apply_btn)


func _add_wire_category(parent: Control, category_name: String, resource_ids: Array, all_wires: Dictionary) -> void:
    var section = VBoxContainer.new()
    section.add_theme_constant_override("separation", 4)
    parent.add_child(section)
    
    # Content container (collapsible)
    var content = VBoxContainer.new()
    content.add_theme_constant_override("separation", 4)
    content.visible = false
    
    var content_margin = MarginContainer.new()
    content_margin.add_theme_constant_override("margin_left", 15)
    content_margin.add_child(content)
    
    # Header button to toggle
    var header = Button.new()
    header.text = "▶ " + category_name
    header.theme_type_variation = "TabButton"
    header.custom_minimum_size = Vector2(0, 35)
    header.alignment = HORIZONTAL_ALIGNMENT_LEFT
    
    var content_ref = content
    header.pressed.connect(func():
        content_ref.visible = !content_ref.visible
        header.text = ("▼ " if content_ref.visible else "▶ ") + category_name
    )
    
    section.add_child(header)
    section.add_child(content_margin)
    
    # Add color pickers for each resource in this category
    for resource_id in resource_ids:
        if all_wires.has(resource_id):
            _add_wire_color_picker(content, all_wires[resource_id], resource_id)


func _add_wire_color_picker(parent: Control, label_text: String, resource_id: String) -> void:
    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    parent.add_child(row)
    
    var label = Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 22)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    
    # Custom Color Button using shared picker
    var btn = Button.new()
    btn.custom_minimum_size = Vector2(80, 36)
    
    # Current color state
    var current_col = wire_colors.get_color(resource_id)
    
    # Style the button to show color
    var style = StyleBoxFlat.new()
    style.bg_color = current_col
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.3, 0.3, 0.3)
    style.set_corner_radius_all(4)
    btn.add_theme_stylebox_override("normal", style)
    btn.add_theme_stylebox_override("hover", style)
    btn.add_theme_stylebox_override("pressed", style)
    
    var wc = wire_colors
    var res_id = resource_id
    var self_ref = self
    
    # Open shared picker on press
    btn.pressed.connect(func():
        _open_color_picker(wc.get_color(res_id), func(new_col):
            # Update storage
            wc.set_color_from_rgb(res_id, new_col)
            # Update button visual
            style.bg_color = new_col
            # Note: We don't refresh all connectors on every drag frame for performance,
            # If we want live updates, we can uncomment:
            # self_ref._refresh_all_connectors()
        )
    )
    
    row.add_child(btn)
    
    # Reset button
    var reset_btn = Button.new()
    reset_btn.text = "↺"
    reset_btn.tooltip_text = "Reset to default"
    reset_btn.custom_minimum_size = Vector2(36, 36)
    reset_btn.pressed.connect(func():
        wc.reset_color(res_id)
        var def_col = wc.get_original_color(res_id)
        style.bg_color = def_col
        self_ref._refresh_all_connectors()
    )
    row.add_child(reset_btn)


func _refresh_all_connectors() -> void:
    # Refresh wire lines (Connector nodes that draw the actual lines)
    var connectors = get_tree().get_nodes_in_group("connector")
    for connector in connectors:
        # Connector class stores color and has output ResourceContainer
        if connector is Connector:
            # Get the output connector button to read the current color
            var output_res = connector.output
            if output_res:
                var output_connector_btn = output_res.get_node_or_null("OutputConnector")
                if output_connector_btn and output_connector_btn.has_method("get_connector_color"):
                    var color_name = output_connector_btn.get_connector_color()
                    if Data.connectors.has(color_name):
                        connector.color = Color(Data.connectors[color_name].color)
                        # Also update the pivot color
                        if connector.pivot:
                            connector.pivot.self_modulate = connector.color
                        # Redraw the wire
                        connector.draw_update()
    
    # Refresh connector buttons (the input/output circles on windows)
    var windows = get_tree().get_nodes_in_group("window")
    for window in windows:
        var buttons = _find_connector_buttons(window)
        for btn in buttons:
            if btn.has_method("update_connector_button"):
                btn.update_connector_button()
    
    Signals.notify.emit("check", "Wire colors refreshed!")


func _find_connector_buttons(node: Node) -> Array:
    var result = []
    if node.has_method("update_connector_button"):
        result.append(node)
    for child in node.get_children():
        result.append_array(_find_connector_buttons(child))
    return result


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

func _add_debug_log(message: String, force: bool = false) -> void:
    # Skip verbose logs if debug mode is off (unless forced)
    if not _debug_mode and not force:
        return
    
    var timestamp = Time.get_time_string_from_system()
    var log_line = "[" + timestamp + "] " + message
    ModLoaderLog.info(message, LOG_NAME)
    if _debug_log_label:
        _debug_log_label.text += log_line + "\n"
        # Keep only last 20 lines
        var lines = _debug_log_label.text.split("\n")
        if lines.size() > 21:
            lines = lines.slice(lines.size() - 21)
            _debug_log_label.text = "\n".join(lines)


func _add_node_limit_slider(parent: Control) -> void:
    var container := VBoxContainer.new()
    container.add_theme_constant_override("separation", 5)
    parent.add_child(container)
    
    var header := HBoxContainer.new()
    container.add_child(header)
    
    var label := Label.new()
    label.text = "Node Limit"
    label.add_theme_font_size_override("font_size", 32)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(label)
    
    _node_limit_value_label = Label.new()
    var current_val = config.get_value("node_limit")
    _node_limit_value_label.text = "∞" if current_val == -1 else str(int(current_val))
    _node_limit_value_label.add_theme_font_size_override("font_size", 32)
    header.add_child(_node_limit_value_label)
    
    # Slider: Use 0-2050 range, where 2050 represents ∞ (-1 internally)
    _node_limit_slider = HSlider.new()
    _node_limit_slider.min_value = 50
    _node_limit_slider.max_value = 2050 # 2050 = ∞
    _node_limit_slider.step = 50
    # Map -1 to 2050 for display
    _node_limit_slider.value = 2050 if current_val == -1 else current_val
    _node_limit_slider.focus_mode = Control.FOCUS_NONE
    
    var vl = _node_limit_value_label
    _node_limit_slider.value_changed.connect(func(v):
        var actual_val = -1 if v >= 2050 else int(v)
        vl.text = "∞" if actual_val == -1 else str(actual_val)
        config.set_value("node_limit", actual_val)
        Globals.custom_node_limit = actual_val
    )
    container.add_child(_node_limit_slider)

## Public method to update node limit from palette
func set_node_limit(value: int) -> void:
    config.set_value("node_limit", value)
    Globals.custom_node_limit = value
    if _node_limit_slider:
        _node_limit_slider.value = 2050 if value == -1 else value
    if _node_limit_value_label:
        _node_limit_value_label.text = "∞" if value == -1 else str(value)

## Public method to update extra glow from palette
func set_extra_glow(enabled: bool) -> void:
    config.set_value("extra_glow", enabled)
    _apply_extra_glow(enabled)
    if _extra_glow_toggle:
        _extra_glow_toggle.button_pressed = enabled
    if _extra_glow_sub:
        _extra_glow_sub.visible = enabled

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
    if buy_max_manager and is_instance_valid(buy_max_manager._buy_max_button):
        buy_max_manager._buy_max_button.visible = visible


## Sync a settings toggle UI with its config value (called from palette commands)
func sync_settings_toggle(config_key: String) -> void:
    if _settings_toggles.has(config_key):
        var toggle = _settings_toggles[config_key]
        if toggle and is_instance_valid(toggle):
            toggle.set_pressed_no_signal(config.get_value(config_key, true))


func _show_restart_dialog() -> void:
    # Create overlay to block input and darken background
    var overlay = ColorRect.new()
    overlay.name = "RestartDialogOverlay"
    overlay.color = Color(0, 0, 0, 0.6)
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    
    # Create centered dialog using game's theme
    var dialog = PanelContainer.new()
    dialog.name = "RestartDialog"
    dialog.custom_minimum_size = Vector2(380, 0)
    dialog.theme_type_variation = "ShadowPanelContainer"
    
    # Main VBox for title panel + content + footer
    var main_vbox = VBoxContainer.new()
    main_vbox.add_theme_constant_override("separation", 0)
    dialog.add_child(main_vbox)
    
    # Title Panel (styled like game's overlays)
    var title_panel = Panel.new()
    title_panel.custom_minimum_size = Vector2(0, 60)
    title_panel.theme_type_variation = "OverlayPanelTitle"
    main_vbox.add_child(title_panel)
    
    var title_container = HBoxContainer.new()
    title_container.set_anchors_preset(Control.PRESET_FULL_RECT)
    title_container.offset_left = 15
    title_container.offset_top = 10
    title_container.offset_right = -15
    title_container.offset_bottom = -10
    title_container.alignment = BoxContainer.ALIGNMENT_CENTER
    title_panel.add_child(title_container)
    
    var title_icon = TextureRect.new()
    title_icon.custom_minimum_size = Vector2(32, 32)
    title_icon.texture = load("res://textures/icons/reload.png")
    title_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    title_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    title_icon.self_modulate = Color(1, 0.75, 0.3)
    title_container.add_child(title_icon)
    
    var title = Label.new()
    title.text = " Restart Required"
    title.add_theme_font_size_override("font_size", 28)
    title_container.add_child(title)
    
    # Content Panel
    var content_panel = PanelContainer.new()
    content_panel.theme_type_variation = "MenuPanel"
    main_vbox.add_child(content_panel)
    
    var content_margin = MarginContainer.new()
    content_margin.add_theme_constant_override("margin_left", 25)
    content_margin.add_theme_constant_override("margin_right", 25)
    content_margin.add_theme_constant_override("margin_top", 20)
    content_margin.add_theme_constant_override("margin_bottom", 20)
    content_panel.add_child(content_margin)
    
    var content_vbox = VBoxContainer.new()
    content_vbox.add_theme_constant_override("separation", 20)
    content_margin.add_child(content_vbox)
    
    # Message
    var msg = Label.new()
    msg.text = "This change will take effect after\nrestarting the game."
    msg.add_theme_font_size_override("font_size", 24)
    msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content_vbox.add_child(msg)
    
    # Buttons row
    var btn_row = HBoxContainer.new()
    btn_row.add_theme_constant_override("separation", 15)
    btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
    content_vbox.add_child(btn_row)
    
    # Later button
    var later_btn = Button.new()
    later_btn.text = "Later"
    later_btn.theme_type_variation = "TabButton"
    later_btn.custom_minimum_size = Vector2(130, 55)
    later_btn.focus_mode = Control.FOCUS_NONE
    later_btn.pressed.connect(func():
        Sound.play("menu_close")
        overlay.queue_free()
    )
    btn_row.add_child(later_btn)
    
    # Exit Now button
    var exit_btn = Button.new()
    exit_btn.text = "Exit Now"
    exit_btn.theme_type_variation = "TabButton"
    exit_btn.custom_minimum_size = Vector2(130, 55)
    exit_btn.focus_mode = Control.FOCUS_NONE
    exit_btn.add_theme_color_override("font_color", Color(1.0, 0.55, 0.35))
    exit_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.7, 0.5))
    exit_btn.pressed.connect(func():
        get_tree().quit()
    )
    btn_row.add_child(exit_btn)
    
    # Add dialog to overlay
    overlay.add_child(dialog)
    
    # Get the HUD to add the overlay
    var main = get_tree().root.get_node_or_null("Main")
    if main:
        var hud = main.get_node_or_null("HUD")
        if hud:
            hud.add_child(overlay)
            Sound.play("menu_open")
            
            # Center the dialog after it's added
            await get_tree().process_frame
            dialog.position = (overlay.size - dialog.size) / 2


func _update_node_label() -> void:
    if !_node_info_label or !ui.is_visible(): return
    
    if is_instance_valid(Globals):
        var current = Globals.max_window_count
        var limit = Globals.custom_node_limit if "custom_node_limit" in Globals else -1
        var limit_str = "∞" if limit == -1 else str(limit)
        
        _node_info_label.text = "Nodes: %d / %s" % [current, limit_str]
        
        if limit != -1 and current >= limit:
            _node_info_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
        else:
            _node_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

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
