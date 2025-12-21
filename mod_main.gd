# ==============================================================================
# Taj's Mod - Upload Labs
# Author: TajemnikTV
# Description: TBD
# ==============================================================================
extends Node


# ==============================================================================
# CONSTANTS
# ==============================================================================

const MOD_DIR := "TajemnikTV-TajsModded"
const LOG_NAME := "TajemnikTV-TajsModded:Main"
const CONFIG_PATH := "user://TajsModded_config.json"


# ==============================================================================
# ==============================================================================
# VARIABLES
# ==============================================================================


# Paths
var mod_dir_path := ""
var mod_version := "?.?.?" # Loaded from manifest.json
var _desktop_patched := false

# UI References
var settings_button: Button = null
var settings_panel: PanelContainer = null
var tab_container: TabContainer = null
var tab_buttons: Array[Button] = []

# State
var is_animating := false
var current_tab := 0

# Default configuration values (single source of truth)
const DEFAULT_CONFIG := {
    # General tab
    "enable_features": true,
    "node_limit": 400,
    "screenshot_quality": 0.5,
    # Visuals tab
    "extra_glow": false,
    "glow_intensity": 2.0,
    "glow_strength": 1.3,
    "glow_bloom": 0.2,
    "glow_sensitivity": 0.8,
    "ui_opacity": 100.0,
    # Debug tab
}

# Configuration (persisted to file)
var mod_config := DEFAULT_CONFIG.duplicate()


# ==============================================================================
# LIFECYCLE FUNCTIONS
# ==============================================================================

func _init() -> void:
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/globals.gd")
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/windows_menu.gd")
    ModLoaderMod.install_script_extension("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/schematic_container.gd")
    ModLoaderLog.info("TajsModded Initialization...", LOG_NAME)
    mod_dir_path = ModLoaderMod.get_unpacked_dir().path_join(MOD_DIR)
    _load_mod_version()
    load_config()


func _ready() -> void:
    ModLoaderLog.info("TajsModded ready!", LOG_NAME)
    
    # DEBUG: Check what limit we loaded
    if "custom_node_limit" in Globals:
        ModLoaderLog.info("DEBUG: Globals.custom_node_limit at startup: " + str(Globals.custom_node_limit), LOG_NAME)
    else:
        ModLoaderLog.warning("DEBUG: Globals.custom_node_limit NOT FOUND at startup", LOG_NAME)
    
    # Listen for Main node being added
    get_tree().node_added.connect(_on_node_added)
    
    # Check if Main already exists (mod may load after main scene)
    call_deferred("_check_existing_main")


func _input(event: InputEvent) -> void:
    # Close panel when user clicks outside of it
    if !settings_panel or !settings_panel.visible or is_animating:
        return
    
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var mouse_pos := get_viewport().get_mouse_position()
        var panel_rect := settings_panel.get_global_rect()
        
        # Don't close if clicking on the settings button
        var button_rect := Rect2()
        if settings_button:
            button_rect = settings_button.get_global_rect()
        
        if !panel_rect.has_point(mouse_pos) and !button_rect.has_point(mouse_pos):
            toggle_settings_panel(false)


# ==============================================================================
# INITIALIZATION HELPERS
# ==============================================================================

func _check_existing_main() -> void:
    var main_node := get_tree().root.get_node_or_null("Main")
    if main_node:
        ModLoaderLog.info("Main node found during init check", LOG_NAME)
        # Wait for HUD to fully load
        await get_tree().create_timer(0.5).timeout
        if is_instance_valid(main_node):
            var hud := main_node.get_node_or_null("HUD")
            if hud:
                var extras := hud.get_node_or_null("Main/MainContainer/Overlay/ExtrasButtons/Container")
                if extras and !extras.has_node("TajsModdedSettings"):
                    setup_mod_button(main_node)
func _process(delta: float) -> void:
    # Continuously try to patch desktop until successful
    # Continuously try to patch desktop until successful
    if !_desktop_patched and is_instance_valid(Globals.desktop):
        _patch_desktop_script()
        
    # Update Node Info Label if visible
    if settings_panel and settings_panel.visible:
        _update_node_info()
        
    # Check for Boot screen
    var boot = get_tree().root.get_node_or_null("Boot")
    if is_instance_valid(boot):
        _patch_boot_screen(boot)


func _patch_boot_screen(boot_node: Node) -> void:
    var name_label = boot_node.get_node_or_null("LogoContainer/Name")
    var init_label = boot_node.get_node_or_null("LogoContainer/Label")
    
    # Check if we already applied our change by checking the main label
    if name_label and !name_label.text.begins_with("Taj's Mod"):
        name_label.text = "Taj's Mod OS " + ProjectSettings.get_setting("application/config/version")
        
        if init_label:
            init_label.text = "Initializing - Mod v" + mod_version
        # Add custom icon above the main logo
        var logo_rect = boot_node.get_node_or_null("LogoContainer/Logo")
        if logo_rect and !logo_rect.has_node("TajsModIcon"):
            var custom_icon_tex = load(mod_dir_path.path_join("icon.png"))
            if custom_icon_tex:
                var new_icon = TextureRect.new()
                new_icon.name = "TajsModIcon"
                new_icon.texture = custom_icon_tex
                new_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                new_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                # Adjust size and position relative to the main logo
                # Image is 4:1 ratio (2048x512), so we need a wide container
                var target_width = 360
                var target_height = 90 # 4:1 ratio
                
                new_icon.custom_minimum_size = Vector2(target_width, target_height)
                new_icon.size = Vector2(target_width, target_height)
                
                # Center on the TOP edge of the main logo (Slight overlap downwards)
                new_icon.position = Vector2(
                    (logo_rect.size.x - new_icon.size.x) / 2,
                     - new_icon.size.y + 25 # Sit on top, overlap 25px down
                )
                
                logo_rect.add_child(new_icon)


func _update_node_info() -> void:
    if !settings_panel or !settings_panel.visible:
        return

    # Find the label if we don't have a direct reference or if we want to be safe
    if !tab_container: return
    var general_tab = tab_container.get_node_or_null("General")
    if !general_tab: return
    
    # Path: MarginContainer/VBoxContainer/node_info_container/NodeInfoLabel
    var label = general_tab.get_node_or_null("MarginContainer/VBoxContainer/node_info_container/NodeInfoLabel")
    
    if label and is_instance_valid(Globals):
        var current = Globals.max_window_count
        var limit = Globals.custom_node_limit if "custom_node_limit" in Globals else -1
        
        var limit_str = "∞" if limit == -1 else str(limit)
        label.text = "Nodes: %d / %s" % [current, limit_str]
        
        # Color coding
        if limit != -1 and current >= limit:
            label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3)) # Red if full
        else:
             label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))


func _patch_desktop_script() -> void:
    # Check if already patched
    if Globals.desktop.get_script().resource_path == "res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/desktop.gd":
        _desktop_patched = true
        return

    ModLoaderLog.info("Attempting to patch Desktop script...", LOG_NAME)
    var new_script = load("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/desktop.gd")
    if new_script:
        Globals.desktop.set_script(new_script)
        ModLoaderLog.info("Desktop script patched successfully!", LOG_NAME)
        _desktop_patched = true
    else:
        ModLoaderLog.error("Failed to load desktop patch patch script", LOG_NAME)
        # Don't try again if file missing
        _desktop_patched = true


func _load_mod_version() -> void:
    # Load version from manifest.json
    var manifest_path := mod_dir_path.path_join("manifest.json")
    if FileAccess.file_exists(manifest_path):
        var file := FileAccess.open(manifest_path, FileAccess.READ)
        if file:
            var json_string := file.get_as_text()
            file.close()
            var json := JSON.new()
            if json.parse(json_string) == OK:
                var data = json.get_data()
                if data is Dictionary and data.has("version_number"):
                    mod_version = data["version_number"]
                    ModLoaderLog.info("Mod version: " + mod_version, LOG_NAME)
                    return
    ModLoaderLog.warning("Could not load version from manifest.json", LOG_NAME)


func _on_node_added(node: Node) -> void:
    # Looking for Main node under root
    if node.name == "Main" and node.get_parent().name == "root":
        ModLoaderLog.info("Main node detected via node_added signal!", LOG_NAME)
        # Wait for HUD to fully load
        await get_tree().create_timer(0.5).timeout
        if is_instance_valid(node):
            # Check if button already exists in this new Main instance
            var hud := node.get_node_or_null("HUD")
            if hud:
                var extras := hud.get_node_or_null("Main/MainContainer/Overlay/ExtrasButtons/Container")
                if extras and !extras.has_node("TajsModdedSettings"):
                     setup_mod_button(node)
                Signals.notify.emit("exclamation", "Taj's Mod Initialized")


# ==============================================================================
# UI SETUP
# ==============================================================================

func setup_mod_button(main: Node) -> void:
    # Find HUD and extras button container (top right corner)
    var hud := main.get_node_or_null("HUD")
    if !hud:
        ModLoaderLog.warning("HUD not found!", LOG_NAME)
        return
    
    var extras_container := hud.get_node_or_null("Main/MainContainer/Overlay/ExtrasButtons/Container")
    if !extras_container:
        ModLoaderLog.warning("ExtrasButtons container not found!", LOG_NAME)
        return
    
    # Create mod settings button (matching game's button style)
    settings_button = Button.new()
    settings_button.name = "TajsModdedSettings"
    settings_button.custom_minimum_size = Vector2(80, 80)
    settings_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
    settings_button.focus_mode = Control.FOCUS_NONE
    settings_button.theme_type_variation = "ButtonMenu"
    settings_button.toggle_mode = true
    settings_button.icon = load("res://textures/icons/puzzle.png")
    settings_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    settings_button.expand_icon = true
    settings_button.tooltip_text = "Taj's Mod Settings"
    
    # Add at the beginning of the list
    extras_container.add_child(settings_button)
    extras_container.move_child(settings_button, 0)
    
    # Connect signal
    settings_button.pressed.connect(_on_settings_button_pressed)
    
    # Create settings panel (initially hidden)
    _create_settings_panel(hud)
    
    # Apply node limit from config
    _apply_node_limit(mod_config["node_limit"])
    
    ModLoaderLog.info("Mod button added to UI!", LOG_NAME)
    
    # Apply visuals
    if mod_config["extra_glow"]:
        _apply_extra_glow(true)
        
    _apply_ui_opacity(mod_config["ui_opacity"])


func _create_settings_panel(hud: Node) -> void:
    # Create our own container
    var mod_menu_container := Control.new()
    mod_menu_container.name = "TajsModdedMenus"
    mod_menu_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    # Same positioning as Menus container
    mod_menu_container.anchor_left = 1.0
    mod_menu_container.anchor_right = 1.0
    mod_menu_container.anchor_bottom = 1.0
    mod_menu_container.offset_left = -1180
    mod_menu_container.offset_right = -100
    
    # Add to Overlay (before Menus to be behind it)
    var overlay := hud.get_node_or_null("Main/MainContainer/Overlay")
    if overlay:
        overlay.add_child(mod_menu_container)
    
    # Main panel
    settings_panel = PanelContainer.new()
    settings_panel.name = "TajsModdedSettingsPanel"
    settings_panel.visible = false
    settings_panel.theme_type_variation = "ShadowPanelContainer"
    
    # Fill the container
    settings_panel.anchor_right = 1.0
    settings_panel.anchor_bottom = 1.0
    settings_panel.offset_right = -20.0
    
    # Main container
    var main_vbox := VBoxContainer.new()
    main_vbox.name = "MainVBox"
    main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    main_vbox.add_theme_constant_override("separation", 0)
    settings_panel.add_child(main_vbox)
    
    # Title panel
    _create_title_panel(main_vbox)
    
    # Content panel with tabs
    _create_content_panel(main_vbox)
    
    # Version label with background
    var version_panel := PanelContainer.new()
    version_panel.name = "VersionPanel"
    version_panel.theme_type_variation = "MenuPanelTitle" # Semi-transparent blur effect
    version_panel.custom_minimum_size = Vector2(0, 40)
    main_vbox.add_child(version_panel)
    
    var version_label := Label.new()
    version_label.text = "Taj's Mod v" + mod_version
    version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    version_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    version_label.add_theme_color_override("font_color", Color(0.627, 0.776, 0.812, 0.8))
    version_label.add_theme_font_size_override("font_size", 20)
    version_panel.add_child(version_label)
    
    # Add panel to our container
    mod_menu_container.add_child(settings_panel)
    
    _connect_auto_close_signals()
    apply_config_to_ui()


func _create_title_panel(parent: VBoxContainer) -> void:
    var title_panel := Panel.new()
    title_panel.name = "TitlePanel"
    title_panel.custom_minimum_size = Vector2(0, 80)
    title_panel.theme_type_variation = "OverlayPanelTitle"
    parent.add_child(title_panel)
    
    var title_container := HBoxContainer.new()
    title_container.set_anchors_preset(Control.PRESET_FULL_RECT)
    title_container.offset_left = 15
    title_container.offset_top = 15
    title_container.offset_right = -15
    title_container.offset_bottom = -15
    title_container.add_theme_constant_override("separation", 10)
    title_container.alignment = BoxContainer.ALIGNMENT_CENTER
    title_panel.add_child(title_container)
    
    var title_icon := TextureRect.new()
    title_icon.custom_minimum_size = Vector2(48, 48)
    title_icon.texture = load("res://textures/icons/puzzle.png")
    title_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    title_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    title_icon.self_modulate = Color(0.567, 0.69465, 0.9, 1)
    title_container.add_child(title_icon)
    
    var title_label := Label.new()
    title_label.text = "Taj's Mod"
    title_label.add_theme_font_size_override("font_size", 40)
    title_container.add_child(title_label)


func _create_content_panel(parent: VBoxContainer) -> void:
    var content_panel := PanelContainer.new()
    content_panel.name = "ContentPanel"
    content_panel.theme_type_variation = "MenuPanel"
    content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    parent.add_child(content_panel)
    
    var content_vbox := VBoxContainer.new()
    content_vbox.add_theme_constant_override("separation", 10)
    content_panel.add_child(content_vbox)
    
    # Tab container (tabs hidden, controlled by buttons)
    tab_container = TabContainer.new()
    tab_container.name = "TabContainer"
    tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tab_container.theme_type_variation = "EmptyTabContainer"
    tab_container.tabs_visible = false
    content_vbox.add_child(tab_container)
    
    # Create tabs
    tab_container.add_child(_create_general_tab())
    tab_container.add_child(_create_visuals_tab())
    tab_container.add_child(_create_debug_tab())
    tab_container.add_child(_create_cheats_tab())
    
    # Tab buttons panel
    _create_tab_buttons(content_vbox)


func _create_tab_buttons(parent: VBoxContainer) -> void:
    var buttons_panel := Panel.new()
    buttons_panel.name = "TabButtonsPanel"
    buttons_panel.custom_minimum_size = Vector2(0, 110)
    buttons_panel.theme_type_variation = "MenuPanelTitle"
    parent.add_child(buttons_panel)
    
    var buttons_container := HBoxContainer.new()
    buttons_container.set_anchors_preset(Control.PRESET_FULL_RECT)
    buttons_container.offset_left = 15
    buttons_container.offset_top = 15
    buttons_container.offset_right = -15
    buttons_container.offset_bottom = -15
    buttons_container.add_theme_constant_override("separation", 10)
    buttons_panel.add_child(buttons_container)
    
    tab_buttons.clear()
    var tab_data := [
        {"name": "General", "icon": "res://textures/icons/cog.png"},
        {"name": "Visuals", "icon": "res://textures/icons/eye_ball.png"},
        {"name": "Debug", "icon": "res://textures/icons/bug.png"},
        {"name": "Cheats", "icon": "res://textures/icons/money.png"}
    ]
    
    for i in range(tab_data.size()):
        var btn := Button.new()
        btn.name = tab_data[i]["name"] + "Tab"
        btn.text = tab_data[i]["name"]
        btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
        btn.focus_mode = Control.FOCUS_NONE
        btn.theme_type_variation = "TabButton"
        btn.add_theme_constant_override("icon_max_width", 40)
        btn.add_theme_font_size_override("font_size", 28)
        btn.toggle_mode = true
        btn.button_pressed = (i == 0)
        btn.icon = load(tab_data[i]["icon"])
        btn.pressed.connect(_on_tab_button_pressed.bind(i))
        buttons_container.add_child(btn)
        tab_buttons.append(btn)


# ==============================================================================
# TAB CREATION
# ==============================================================================

func _create_tab_scroll_container(tab_name: String) -> Array:
    # Creates the standard scroll container structure for a tab. Returns [scroll, vbox].
    var scroll := ScrollContainer.new()
    scroll.name = tab_name
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    
    var margin := MarginContainer.new()
    margin.name = "MarginContainer"
    margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.add_theme_constant_override("margin_left", 20)
    margin.add_theme_constant_override("margin_right", 20)
    margin.add_theme_constant_override("margin_top", 10)
    scroll.add_child(margin)
    
    var vbox := VBoxContainer.new()
    vbox.name = "VBoxContainer"
    vbox.add_theme_constant_override("separation", 10)
    margin.add_child(vbox)
    
    return [scroll, vbox]


func _create_general_tab() -> ScrollContainer:
    var result := _create_tab_scroll_container("General")
    var scroll: ScrollContainer = result[0]
    var vbox: VBoxContainer = result[1]
    
    
    _add_toggle_setting(vbox, "Enable Mod Features", "enable_features")
    _add_node_info_label(vbox)
    _add_node_limit_slider(vbox)
    
    _add_screenshot_quality_selector(vbox)
    
    # Screenshot Button
    var screenshot_btn := Button.new()
    screenshot_btn.name = "ScreenshotButton"
    screenshot_btn.text = "Take Screenshot"
    screenshot_btn.custom_minimum_size = Vector2(0, 60)
    screenshot_btn.theme_type_variation = "TabButton"
    screenshot_btn.focus_mode = Control.FOCUS_NONE
    screenshot_btn.pressed.connect(_take_screenshot)
    vbox.add_child(screenshot_btn)
    
    return scroll


func _create_visuals_tab() -> ScrollContainer:
    var result := _create_tab_scroll_container("Visuals")
    var scroll: ScrollContainer = result[0]
    var vbox: VBoxContainer = result[1]
    
    _add_glow_settings_section(vbox)
    _add_slider_setting(vbox, "UI Opacity", "ui_opacity", 50, 100, 5, "%")
    
    return scroll


func _create_debug_tab() -> ScrollContainer:
    var result := _create_tab_scroll_container("Debug")
    var scroll: ScrollContainer = result[0]
    var vbox: VBoxContainer = result[1]
    
    # _add_toggle_setting(vbox, "Show Debug Info", "show_debug_info")
    # _add_toggle_setting(vbox, "Verbose Logging", "verbose_logging")
    
    # Reset button
    var reset_btn := Button.new()
    reset_btn.name = "ResetButton"
    reset_btn.text = "Reset All Settings"
    reset_btn.custom_minimum_size = Vector2(0, 60)
    reset_btn.theme_type_variation = "TabButton"
    reset_btn.focus_mode = Control.FOCUS_NONE
    reset_btn.pressed.connect(_on_reset_settings_pressed)
    vbox.add_child(reset_btn)
    
    return scroll


func _create_cheats_tab() -> ScrollContainer:
    var result := _create_tab_scroll_container("Cheats")
    var scroll: ScrollContainer = result[0]
    var vbox: VBoxContainer = result[1]
    
    # Warning label
    var warning := Label.new()
    warning.text = "⚠️ Using cheats may affect game balance!"
    warning.add_theme_font_size_override("font_size", 20)
    warning.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
    warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(warning)
    
    # Currency buttons
    _add_cheat_button_pair(vbox, "Money", "money", "res://textures/icons/money.png")
    _add_cheat_button_pair(vbox, "Tokens", "token", "res://textures/icons/token.png")
    _add_cheat_button_pair(vbox, "Research", "research", "res://textures/icons/research.png")
    
    return scroll


func _add_glow_settings_section(parent: VBoxContainer) -> void:
    # Glow Config Section
    _add_toggle_setting(parent, "Extra Glow Customization", "extra_glow")
    
    var container := VBoxContainer.new()
    container.name = "glow_settings_container"
    container.add_theme_constant_override("separation", 10)
    # Add indent
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 30)
    margin.add_child(container)
    parent.add_child(margin)
    
    # Sliders
    _add_slider_setting(container, "Intensity", "glow_intensity", 0.0, 5.0, 0.1, "")
    _add_slider_setting(container, "Strength", "glow_strength", 0.5, 2.0, 0.05, "")
    _add_slider_setting(container, "Bloom", "glow_bloom", 0.0, 0.5, 0.05, "")
    _add_slider_setting(container, "Sensitivity", "glow_sensitivity", 0.0, 1.0, 0.05, "")
    
    # Initial visibility
    margin.visible = mod_config["extra_glow"]


# ==============================================================================
# UI HELPER FUNCTIONS
# ==============================================================================

func _add_toggle_setting(parent: VBoxContainer, label_text: String, config_key: String) -> void:
    var row := HBoxContainer.new()
    row.name = config_key + "_row"
    row.custom_minimum_size = Vector2(0, 64)
    parent.add_child(row)
    
    var label := Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 32)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    
    var toggle := CheckButton.new()
    toggle.name = config_key + "_toggle"
    toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
    toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    toggle.focus_mode = Control.FOCUS_NONE
    toggle.flat = true
    toggle.toggled.connect(func(toggled): _on_setting_toggled(config_key, toggled))
    row.add_child(toggle)


func _add_slider_setting(parent: VBoxContainer, label_text: String, config_key: String, min_val: float, max_val: float, step: float, suffix: String) -> void:
    var container := VBoxContainer.new()
    container.name = config_key + "_container"
    container.add_theme_constant_override("separation", 5)
    parent.add_child(container)
    
    var header := HBoxContainer.new()
    header.name = config_key + "_header"
    container.add_child(header)
    
    var label := Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 32)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(label)
    
    var value_label := Label.new()
    value_label.name = config_key + "_value"
    value_label.text = _format_slider_value(mod_config[config_key], suffix)
    value_label.add_theme_font_size_override("font_size", 32)
    header.add_child(value_label)
    
    var slider := HSlider.new()
    slider.name = config_key + "_slider"
    slider.min_value = min_val
    slider.max_value = max_val
    slider.step = step
    slider.value = mod_config[config_key]
    slider.focus_mode = Control.FOCUS_NONE
    slider.value_changed.connect(func(value): _on_setting_slider_changed(config_key, value, suffix))
    container.add_child(slider)


func _add_node_info_label(parent: VBoxContainer) -> void:
    var container := HBoxContainer.new()
    container.name = "node_info_container"
    container.custom_minimum_size = Vector2(0, 40)
    parent.add_child(container)
    
    var label := Label.new()
    label.name = "NodeInfoLabel"
    label.text = "Nodes: ... / ..."
    label.add_theme_font_size_override("font_size", 24)
    label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    container.add_child(label)
    
    # Store reference (but we need to find it again later if we don't make it a class var... 
    # Actually, let's just use find_child in _process to stay stateless or add a class var.
    # The user asked for it "under or above Node Limit". I put it above.)


func _add_screenshot_quality_selector(parent: VBoxContainer) -> void:
    var container := VBoxContainer.new()
    container.name = "screenshot_quality_container"
    container.add_theme_constant_override("separation", 10)
    parent.add_child(container)
    
    var label := Label.new()
    label.text = "Screenshot Quality"
    label.add_theme_font_size_override("font_size", 32)
    container.add_child(label)
    
    var buttons_row := HBoxContainer.new()
    buttons_row.name = "buttons_row"
    buttons_row.add_theme_constant_override("separation", 10)
    container.add_child(buttons_row)
    
    var options = [
        {"label": "Low", "value": 0.25},
        {"label": "Medium", "value": 0.5},
        {"label": "High", "value": 0.75},
        {"label": "Original", "value": 1.0}
    ]
    
    var group = ButtonGroup.new()
    
    for opt in options:
        var btn := Button.new()
        btn.name = "QualityBtn_" + str(opt["value"])
        btn.text = opt["label"]
        btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        btn.focus_mode = Control.FOCUS_NONE
        btn.theme_type_variation = "TabButton"
        btn.toggle_mode = true
        btn.button_group = group
        # Auto-select current config
        if is_equal_approx(mod_config.get("screenshot_quality", 0.5), opt["value"]):
            btn.button_pressed = true
            
        btn.pressed.connect(func(): _on_quality_selected(opt["value"]))
        buttons_row.add_child(btn)


func _on_quality_selected(value: float) -> void:
    mod_config["screenshot_quality"] = value
    save_config()
    ModLoaderLog.info("Screenshot quality set to: " + str(value), LOG_NAME)
    Sound.play("click")


func _format_slider_value(value: float, suffix: String) -> String:
    if suffix == "x":
        return str(snapped(value, 0.1)) + suffix
    elif suffix == "%":
        return str(int(value)) + suffix
    else:
        return str(snapped(value, 0.1))


func _add_node_limit_slider(parent: VBoxContainer) -> void:
    var container := VBoxContainer.new()
    container.name = "node_limit_container"
    container.add_theme_constant_override("separation", 5)
    parent.add_child(container)
    
    var header := HBoxContainer.new()
    header.name = "node_limit_header"
    container.add_child(header)
    
    var label := Label.new()
    label.text = "Node Limit"
    label.add_theme_font_size_override("font_size", 32)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(label)
    
    var value_label := Label.new()
    value_label.name = "node_limit_value"
    value_label.add_theme_font_size_override("font_size", 32)
    # Display ∞ for -1, otherwise the number
    var current_val = mod_config["node_limit"]
    value_label.text = "∞" if current_val == -1 else str(int(current_val))
    header.add_child(value_label)
    
    var slider := HSlider.new()
    slider.name = "node_limit_slider"
    slider.min_value = 100
    slider.max_value = 1100 # 1100 represents -1 (unlimited)
    slider.step = 100
    # Convert -1 to slider value
    slider.value = 1100 if current_val == -1 else current_val
    slider.focus_mode = Control.FOCUS_NONE
    slider.value_changed.connect(_on_node_limit_changed)
    container.add_child(slider)


func _on_node_limit_changed(value: float) -> void:
    # 1100 = unlimited (-1)
    var actual_value: int = -1 if value >= 1100 else int(value)
    mod_config["node_limit"] = actual_value
    save_config()
    _apply_node_limit(actual_value)
    _update_node_limit_label(actual_value)


func _apply_node_limit(limit: int) -> void:
    ModLoaderLog.info("Applying Node Limit: " + str(limit), LOG_NAME)
    if is_instance_valid(Globals):
        # Override if features disabled
        if !mod_config["enable_features"]:
            limit = 400
            
        # We now set the CUSTOM limit, not the window count itself!
        if "custom_node_limit" in Globals:
            Globals.custom_node_limit = limit
            ModLoaderLog.info("Globals.custom_node_limit set to: " + str(limit), LOG_NAME)
        else:
             ModLoaderLog.warning("Globals.custom_node_limit not found. Extension not loaded?", LOG_NAME)

func _apply_extra_glow(enabled: bool) -> void:
    # Override if features disabled
    if !mod_config["enable_features"]:
        enabled = false

    # Find Main node if we don't have it passed (usually via tree)
    var main := get_tree().root.get_node_or_null("Main")
    if !is_instance_valid(main):
        return
        
    var world_env := main.get_node_or_null("WorldEnvironment")
    if !world_env or !world_env.environment:
        return
        
    var env: Environment = world_env.environment
    
    if enabled:
        env.glow_intensity = mod_config["glow_intensity"]
        env.glow_strength = mod_config["glow_strength"]
        env.glow_bloom = mod_config["glow_bloom"]
        # Sensitivity 0.0 -> Threshold 1.0 (Low glow)
        # Sensitivity 1.0 -> Threshold 0.0 (Max glow - everything glows)
        env.glow_hdr_threshold = lerp(1.0, 0.0, mod_config["glow_sensitivity"])
        ModLoaderLog.info("Extra glow applied", LOG_NAME)
    else:
        # Reset to defaults
        env.glow_intensity = 0.8
        env.glow_strength = 1.0
        env.glow_bloom = 0.0
        env.glow_hdr_threshold = 1.0
        ModLoaderLog.info("Extra glow disabled", LOG_NAME)


func _update_node_limit_label(value: int) -> void:
    if !tab_container:
        return
    var general_tab = tab_container.get_node_or_null("General")
    if !general_tab:
        return
    var value_label = general_tab.get_node_or_null("MarginContainer/VBoxContainer/node_limit_container/node_limit_header/node_limit_value")
    if value_label:
        value_label.text = "∞" if value == -1 else str(value)


func _apply_ui_opacity(value: float) -> void:
    # Override if features disabled
    if !mod_config["enable_features"]:
        value = 100.0

    # Find Main node
    var main := get_tree().root.get_node_or_null("Main")
    if !is_instance_valid(main):
        return
        
    var hud_main := main.get_node_or_null("HUD/Main")
    if hud_main:
        hud_main.modulate.a = value / 100.0
        ModLoaderLog.debug("UI Opacity set to: " + str(value) + "%", LOG_NAME)


func _take_screenshot() -> void:
    # 1. Notify start
    Signals.notify.emit("exclamation", "Capturing High-Res...")
    
    # 2. Hide UI
    var main = get_tree().root.get_node_or_null("Main")
    var hud = main.get_node_or_null("HUD")
    var hud_was_visible = true
    if hud:
        hud_was_visible = hud.visible
        hud.visible = false
        
    # Hide our panel
    var panel_was_visible = false
    if settings_panel and settings_panel.visible:
        toggle_settings_panel(false)
        panel_was_visible = true
        # Wait for anim
        await get_tree().create_timer(0.3).timeout
        
    await get_tree().process_frame
    await get_tree().process_frame
    
    # 3. Find Camera
    var viewport = get_viewport()
    var camera = viewport.get_camera_2d()
    
    if !camera:
        # Fallback to simple viewport capture if no camera found
        ModLoaderLog.warning("No camera found, taking simple screenshot", LOG_NAME)
        _capture_and_save(viewport.get_texture().get_image())
    else:
        # High-Res Tiled Capture
        await _take_high_res_screenshot(camera, viewport)
        
    # 4. Restore UI
    if hud: hud.visible = hud_was_visible
    if panel_was_visible: toggle_settings_panel(true)


func _take_high_res_screenshot(main_camera: Camera2D, viewport: Viewport) -> void:
    ModLoaderLog.info("Starting High-Res Capture with Temp Camera...", LOG_NAME)
    
    # Calculate Bounds (Full Board)
    var bounds = Rect2()
    var initialized = false
    
    if is_instance_valid(Globals.desktop):
        for child in Globals.desktop.get_children():
             # Skip non-visual nodes
            if not (child is CanvasItem):
                continue
            if !child.visible: continue
            var rect = Rect2()
            
            if child is Control:
                rect = child.get_global_rect()
            elif child is Node2D:
                 rect = Rect2(child.global_position, Vector2.ZERO)
            
            if rect.has_area() or (child is Node2D):
                if !initialized:
                    bounds = rect
                    initialized = true
                else:
                    bounds = bounds.merge(rect)
    
    if !initialized:
        # Fallback to current view if bounds specific calculation fails
        var center = main_camera.get_screen_center_position()
        var size = viewport.get_visible_rect().size / main_camera.zoom
        bounds = Rect2(center - size / 2, size)

    # Grow bounds for padding
    bounds = bounds.grow(100)
    ModLoaderLog.info("Screenshot Bounds: " + str(bounds), LOG_NAME)
    
    # Create Temporary Camera
    var temp_cam = Camera2D.new()
    temp_cam.zoom = Vector2.ONE
    temp_cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
    temp_cam.position_smoothing_enabled = false
    
    # Add to the same parent as the main camera to share the coordinate space
    main_camera.get_parent().add_child(temp_cam)
    
    # Activate Temp Camera
    temp_cam.make_current()
    
    var vp_size = viewport.get_visible_rect().size
    var full_image: Image
    
    var x = bounds.position.x
    while x < bounds.end.x:
        var y = bounds.position.y
        while y < bounds.end.y:
            # Move Temp Camera
            temp_cam.global_position = Vector2(x, y)
            
            # Wait for render 
            # Needs at least 2 frames for camera update to propagate through the engine
            await get_tree().process_frame
            await get_tree().process_frame
            await get_tree().create_timer(0.1).timeout
            
            var chunk = viewport.get_texture().get_image()
            
            # Initialize Full Image on first chunk to ensure Format matches!
            # (Fixes the "format != p_src->format" error)
            if !full_image:
                full_image = Image.create(int(bounds.size.x), int(bounds.size.y), false, chunk.get_format())
            
            var region_w = min(bounds.end.x - x, vp_size.x)
            var region_h = min(bounds.end.y - y, vp_size.y)
            var src_rect = Rect2(0, 0, region_w, region_h)
            
            full_image.blit_rect(chunk, src_rect, Vector2(x - bounds.position.x, y - bounds.position.y))
            
            y += vp_size.y
        x += vp_size.x
        
    # Cleanup
    temp_cam.queue_free()
    # Main camera should automatically become current again, or we can force it:
    if is_instance_valid(main_camera):
        main_camera.make_current()
    
    # Resize based on quality setting
    # Using Cubic interpolation for good balance of speed/quality
    var quality: float = mod_config.get("screenshot_quality", 0.5)
    
    # Only resize if not 1.0 (Original)
    if quality < 0.99:
        var new_width = int(full_image.get_width() * quality)
        var new_height = int(full_image.get_height() * quality)
        if new_width > 0 and new_height > 0:
            full_image.resize(new_width, new_height, Image.INTERPOLATE_CUBIC)
    
    _capture_and_save(full_image)


func _capture_and_save(img: Image) -> void:
    # Create directory
    var dir = DirAccess.open("user://")
    if !dir.dir_exists("screenshots"):
        dir.make_dir("screenshots")
    
    # Generate filename with timestamp
    var time = Time.get_datetime_dict_from_system()
    var filename = "screenshot_%04d-%02d-%02d_%02d-%02d-%02d.jpg" % [time.year, time.month, time.day, time.hour, time.minute, time.second]
    var path = "user://screenshots/".path_join(filename)
    
    # Save as JPG (Quality 0.8 is a good balance)
    var err = img.save_jpg(path, 0.8)
    
    if err == OK:
        ModLoaderLog.info("Screenshot saved to: " + path, LOG_NAME)
        # Globalize path for easier access
        var global_path = ProjectSettings.globalize_path(path)
        ModLoaderLog.info("Full path: " + global_path, LOG_NAME)
        
        Signals.notify.emit("exclamation", "Screenshot Saved!")
        Sound.play("click")
    else:
        ModLoaderLog.error("Failed to save screenshot: " + str(err), LOG_NAME)
        Signals.notify.emit("exclamation", "Screenshot Failed!")


func _add_cheat_button_pair(parent: VBoxContainer, label_text: String, currency_key: String, icon_path: String) -> void:
    var row := HBoxContainer.new()
    row.name = currency_key + "_row"
    row.custom_minimum_size = Vector2(0, 64)
    row.add_theme_constant_override("separation", 10)
    parent.add_child(row)
    
    # Icon
    var icon := TextureRect.new()
    icon.custom_minimum_size = Vector2(40, 40)
    icon.texture = load(icon_path)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.self_modulate = Color(0.567, 0.69465, 0.9, 1)
    row.add_child(icon)
    
    # Label
    var label := Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 28)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    
    # Remove button
    var remove_btn := Button.new()
    remove_btn.name = currency_key + "_remove"
    remove_btn.text = "-10%"
    remove_btn.custom_minimum_size = Vector2(100, 50)
    remove_btn.theme_type_variation = "TabButton"
    remove_btn.focus_mode = Control.FOCUS_NONE
    remove_btn.pressed.connect(func(): _modify_currency(currency_key, -0.1))
    row.add_child(remove_btn)
    
    # Add button
    var add_btn := Button.new()
    add_btn.name = currency_key + "_add"
    add_btn.text = "+10%"
    add_btn.custom_minimum_size = Vector2(100, 50)
    add_btn.theme_type_variation = "TabButton"
    add_btn.focus_mode = Control.FOCUS_NONE
    add_btn.pressed.connect(func(): _modify_currency(currency_key, 0.1))
    row.add_child(add_btn)


func _modify_currency(currency_key: String, percent: float) -> void:
    if !is_instance_valid(Globals):
        return
    
    # Check for Shift key for 100% instead of 10%
    if Input.is_key_pressed(KEY_SHIFT):
        percent = 1.0 if percent > 0 else -1.0
    
    if Globals.currencies.has(currency_key):
        var current_val = Globals.currencies[currency_key]
        var amount_to_change = current_val * percent
        
        # Minimum change for low values
        if percent > 0 and current_val < 1000:
            amount_to_change = max(amount_to_change, 100.0 if currency_key == "money" else 10.0)
        
        Globals.currencies[currency_key] += amount_to_change
        
        # Prevent negative
        if Globals.currencies[currency_key] < 0:
            Globals.currencies[currency_key] = 0
        
        var action = "Added" if percent > 0 else "Removed"
        var pct = "100%" if abs(percent) >= 1.0 else "10%"
        ModLoaderLog.info(action + " " + pct + " " + currency_key, LOG_NAME)
        
        Sound.play("click")


# ==============================================================================
# PANEL ANIMATION
# ==============================================================================

func toggle_settings_panel(show: bool) -> void:
    if !settings_panel or is_animating:
        return
    
    # Close other game menus when opening our panel
    if show and Signals:
        Signals.set_menu.emit(0, 0)
    
    is_animating = true
    
    if show:
        settings_panel.visible = true
        settings_panel.modulate.a = 0
        # Start off-screen (like game's menus.gd)
        settings_panel.position.x = settings_panel.get_parent().size.x + 15
        
        var tween := create_tween()
        tween.set_parallel()
        tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(settings_panel, "modulate:a", 1.0, 0.25)
        tween.tween_property(settings_panel, "position:x", 0, 0.25)
        tween.chain().tween_callback(func(): is_animating = false)
        
        Sound.play("menu_open")
    else:
        var tween := create_tween()
        tween.set_parallel()
        tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT) # Same easing as game
        tween.tween_property(settings_panel, "modulate:a", 0.0, 0.25)
        tween.tween_property(settings_panel, "position:x", settings_panel.get_parent().size.x + 15, 0.25)
        tween.chain().tween_callback(func():
            settings_panel.visible = false
            is_animating = false
        )
        
        Sound.play("menu_close")
    
    if settings_button:
        settings_button.button_pressed = show


# ==============================================================================
# EVENT HANDLERS
# ==============================================================================

func _on_settings_button_pressed() -> void:
    toggle_settings_panel(!settings_panel.visible if settings_panel else false)
    Sound.play("click_toggle")


func _on_tab_button_pressed(tab_index: int) -> void:
    if tab_container:
        tab_container.current_tab = tab_index
        current_tab = tab_index
        for i in range(tab_buttons.size()):
            tab_buttons[i].button_pressed = (i == tab_index)
        Sound.play("click_toggle")


func _on_setting_toggled(config_key: String, value: bool) -> void:
    mod_config[config_key] = value
    save_config()
    ModLoaderLog.info(config_key + ": " + str(value), LOG_NAME)
    
    if config_key == "enable_features":
        # Refresh all features
        _apply_node_limit(mod_config["node_limit"])
        _apply_extra_glow(mod_config["extra_glow"])
        _apply_ui_opacity(mod_config["ui_opacity"])
    
    if config_key == "extra_glow":
        _apply_extra_glow(value)
        _update_glow_settings_visibility(value)
        
        
func _update_glow_settings_visibility(visible: bool) -> void:
    if !tab_container:
        return
    var visuals_tab = tab_container.get_node_or_null("Visuals")
    if !visuals_tab:
        return
    # The margin container holding the glow sliders is slightly tricky to find by path since we added it dynamically
    # But we know it's in the VBoxContainer. 
    # Let's iterate or find children.
    # We didn't give the MarginContainer a specific name in _add_glow_settings_section, doing that would be better.
    # But we named the vbox inside it "glow_settings_container".
    var vbox = visuals_tab.get_node_or_null("MarginContainer/VBoxContainer")
    if vbox:
        for child in vbox.get_children():
            if child is MarginContainer and child.get_child_count() > 0 and child.get_child(0).name == "glow_settings_container":
                child.visible = visible
                break


func _on_setting_slider_changed(config_key: String, value: float, suffix: String) -> void:
    mod_config[config_key] = value
    save_config()
    ModLoaderLog.info(config_key + ": " + str(value), LOG_NAME)
    _update_slider_label(config_key, value, suffix)
    
    if config_key == "extra_glow" or config_key.begins_with("glow_"):
        if mod_config["extra_glow"]:
             _apply_extra_glow(true)
        
    if config_key == "ui_opacity":
        _apply_ui_opacity(value)


func _update_slider_label(config_key: String, value: float, suffix: String) -> void:
    if !tab_container:
        return
    
    # Helper to find node recursively
    var label_name = config_key + "_value"
    var found_label: Label = null
    
    # Scan all tabs
    for tab in tab_container.get_children():
        found_label = _find_node_by_name(tab, label_name)
        if found_label:
            found_label.text = _format_slider_value(value, suffix)
            break

func _find_node_by_name(node: Node, name_to_find: String) -> Node:
    if node.name == name_to_find:
        return node
    for child in node.get_children():
        var found = _find_node_by_name(child, name_to_find)
        if found:
            return found
    return null


func _on_reset_settings_pressed() -> void:
    mod_config = DEFAULT_CONFIG.duplicate()
    save_config()
    apply_config_to_ui()
    ModLoaderLog.info("Settings reset to defaults", LOG_NAME)
    Sound.play("click")


# ==============================================================================
# CONFIG PERSISTENCE
# ==============================================================================

func save_config() -> void:
    var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(mod_config, "  "))
        file.close()
        ModLoaderLog.debug("Config saved to " + CONFIG_PATH, LOG_NAME)


func load_config() -> void:
    if FileAccess.file_exists(CONFIG_PATH):
        var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
        if file:
            var json_string := file.get_as_text()
            file.close()
            var json := JSON.new()
            if json.parse(json_string) == OK:
                var data = json.get_data()
                if data is Dictionary:
                    # Merge loaded data with defaults (keeps new options working)
                    for key in data:
                        if mod_config.has(key):
                            mod_config[key] = data[key]
                    
                    # Migration: extra_glow float -> bool (from intermediate version)
                    if mod_config["extra_glow"] is float:
                        mod_config["extra_glow"] = mod_config["extra_glow"] > 0.0
                        ModLoaderLog.info("Migrated extra_glow from float to bool", LOG_NAME)
                    
                    # Migration: glow_threshold -> glow_sensitivity
                    if data.has("glow_threshold") and !mod_config.has("glow_sensitivity"):
                        mod_config["glow_sensitivity"] = clamp(1.0 - data["glow_threshold"], 0.0, 1.0)
                        ModLoaderLog.info("Migrated glow_threshold to sensitivity", LOG_NAME)
                        
                        ModLoaderLog.info("Migrated glow_threshold to sensitivity", LOG_NAME)
                    
                    _sanitize_config()
                        
                    ModLoaderLog.info("Config loaded from " + CONFIG_PATH, LOG_NAME)
            else:
                ModLoaderLog.warning("Failed to parse config JSON", LOG_NAME)
    else:
        ModLoaderLog.info("No config file found, using defaults", LOG_NAME)


func _sanitize_config() -> void:
    # Ensure node_limit is valid
    # If it's 0 or very small (likely corruption or uninitialized), reset to default 400
    if mod_config["node_limit"] != -1 and mod_config["node_limit"] < 100:
        ModLoaderLog.warning("Node Limit found to be < 100 (" + str(mod_config["node_limit"]) + "). Resetting to 400.", LOG_NAME)
        mod_config["node_limit"] = 400
        save_config()


func apply_config_to_ui() -> void:
    if !tab_container:
        return
    
    for tab in tab_container.get_children():
        var margin := tab.get_node_or_null("MarginContainer")
        if !margin:
            continue
        var vbox := margin.get_child(0) if margin.get_child_count() > 0 else null
        if !vbox:
            continue
        
        for child in vbox.get_children():
            var child_name: String = child.name
            
            # Handle toggle rows
            if child_name.ends_with("_row"):
                var config_key := child_name.replace("_row", "")
                var toggle := child.get_node_or_null(config_key + "_toggle")
                if toggle and mod_config.has(config_key):
                    toggle.button_pressed = mod_config[config_key]
            
            # Handle slider containers
            elif child_name.ends_with("_container"):
                var config_key := child_name.replace("_container", "")
                var slider := child.get_node_or_null(config_key + "_slider")
                var value_label := child.get_node_or_null(config_key + "_header/" + config_key + "_value")
                if slider and mod_config.has(config_key):
                    slider.value = mod_config[config_key]
                if value_label and mod_config.has(config_key):
                    if config_key == "node_limit":
                        var val = mod_config[config_key]
                        value_label.text = "∞" if val == -1 else str(int(val))
                    else:
                        var suffix := "%" if config_key == "ui_opacity" else ""
                        value_label.text = _format_slider_value(mod_config[config_key], suffix)
    
            # Handle Quality Selector
            elif child_name == "screenshot_quality_container":
                var btn_row = child.get_node_or_null("buttons_row")
                if btn_row:
                    for btn in btn_row.get_children():
                        if btn is Button:
                            # Extract value from name "QualityBtn_0.5"
                             var val_str = btn.name.replace("QualityBtn_", "")
                             if val_str.is_valid_float():
                                 var val = val_str.to_float()
                                 btn.button_pressed = is_equal_approx(mod_config["screenshot_quality"], val)


# ==============================================================================
# AUTO-CLOSE HANDLERS
# ==============================================================================

func _connect_auto_close_signals() -> void:
    if Signals:
        Signals.menu_set.connect(_on_menu_changed)
    
    # Connect to other ExtrasButtons to close when they're clicked
    var extras_container := get_tree().root.get_node_or_null("Main/HUD/Main/MainContainer/Overlay/ExtrasButtons/Container")
    if extras_container:
        for child in extras_container.get_children():
            if child is Button and child != settings_button:
                child.pressed.connect(_on_other_button_pressed)


func _on_menu_changed(menu: int, _tab: int) -> void:
    # Close panel when any other menu opens
    if menu != 0 and settings_panel and settings_panel.visible:
        toggle_settings_panel(false)


func _on_other_button_pressed() -> void:
    # Close panel when another ExtrasButton is clicked
    if settings_panel and settings_panel.visible:
        toggle_settings_panel(false)
