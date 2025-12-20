# ==============================================================================
# Taj's Mod - Upload Labs
# Author: TajemnikTV
# Version: 0.0.1
# Description: Settings panel mod with customizable options for Upload Labs game
# ==============================================================================
extends Node


# ==============================================================================
# CONSTANTS
# ==============================================================================

const MOD_DIR := "TajemnikTV-TajsModded"
const LOG_NAME := "TajemnikTV-TajsModded:Main"
const CONFIG_PATH := "user://TajsModded_config.json"


# ==============================================================================
# VARIABLES
# ==============================================================================

# Paths
var mod_dir_path := ""
var mod_version := "?.?.?" # Loaded from manifest.json

# UI References
var settings_button: Button = null
var settings_panel: PanelContainer = null
var tab_container: TabContainer = null
var tab_buttons: Array[Button] = []

# State
var is_ready := false
var is_animating := false
var current_tab := 0

# Configuration (persisted to file)
var mod_config := {
    # General tab
    "enable_features": true,
    "auto_claim_achievements": false,
    "enhanced_stats": false,
    "animation_speed": 1.0,
    # Visuals tab
    "custom_particles": false,
    "extra_glow": false,
    "compact_numbers": false,
    "ui_opacity": 100.0,
    # Debug tab
    "show_debug_info": false,
    "verbose_logging": false
}


# ==============================================================================
# LIFECYCLE FUNCTIONS
# ==============================================================================

func _init() -> void:
    ModLoaderLog.info("TajsModded Initialization...", LOG_NAME)
    mod_dir_path = ModLoaderMod.get_unpacked_dir().path_join(MOD_DIR)
    _load_mod_version()
    load_config()


func _ready() -> void:
    ModLoaderLog.info("TajsModded ready!", LOG_NAME)
    
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
    if is_ready:
        return
    
    var main_node := get_tree().root.get_node_or_null("Main")
    if main_node:
        ModLoaderLog.info("Main node found on startup, setting up...", LOG_NAME)
        # Wait for HUD to fully load
        await get_tree().create_timer(0.5).timeout
        if is_instance_valid(main_node) and !is_ready:
            setup_mod_button(main_node)
            is_ready = true


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
    if is_ready:
        return
    
    # Looking for Main node under root
    if node.name == "Main" and node.get_parent().name == "root":
        ModLoaderLog.info("Main node detected via node_added signal!", LOG_NAME)
        # Wait for HUD to fully load
        await get_tree().create_timer(0.5).timeout
        if is_instance_valid(node) and !is_ready:
            setup_mod_button(node)
            is_ready = true


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
    settings_button.tooltip_text = "TajsModded Settings"
    
    # Add at the beginning of the list
    extras_container.add_child(settings_button)
    extras_container.move_child(settings_button, 0)
    
    # Connect signal
    settings_button.pressed.connect(_on_settings_button_pressed)
    
    # Create settings panel (initially hidden)
    _create_settings_panel(hud)
    
    ModLoaderLog.info("Mod button added to UI!", LOG_NAME)


func _create_settings_panel(hud: Node) -> void:
    # Create our own container (like Menus but independent, not animated by game)
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
    
    # Main panel - like game's Settings panel
    settings_panel = PanelContainer.new()
    settings_panel.name = "TajsModdedSettingsPanel"
    settings_panel.visible = false
    settings_panel.theme_type_variation = "ShadowPanelContainer"
    
    # Fill the container (like Settings in Menus)
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
    
    # Version label
    var version_label := Label.new()
    version_label.text = "Taj's Mod v" + mod_version
    version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    version_label.add_theme_color_override("font_color", Color(0.627, 0.776, 0.812, 0.7))
    version_label.add_theme_font_size_override("font_size", 16)
    main_vbox.add_child(version_label)
    
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
        {"name": "Debug", "icon": "res://textures/icons/bug.png"}
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
    _add_toggle_setting(vbox, "Auto-claim Achievements", "auto_claim_achievements")
    _add_toggle_setting(vbox, "Enhanced Stats Display", "enhanced_stats")
    _add_slider_setting(vbox, "Animation Speed", "animation_speed", 0.5, 2.0, 0.1, "x")
    
    return scroll


func _create_visuals_tab() -> ScrollContainer:
    var result := _create_tab_scroll_container("Visuals")
    var scroll: ScrollContainer = result[0]
    var vbox: VBoxContainer = result[1]
    
    _add_toggle_setting(vbox, "Custom Particle Effects", "custom_particles")
    _add_toggle_setting(vbox, "Extra Glow Effects", "extra_glow")
    _add_toggle_setting(vbox, "Compact Number Display", "compact_numbers")
    _add_slider_setting(vbox, "UI Opacity", "ui_opacity", 50, 100, 5, "%")
    
    return scroll


func _create_debug_tab() -> ScrollContainer:
    var result := _create_tab_scroll_container("Debug")
    var scroll: ScrollContainer = result[0]
    var vbox: VBoxContainer = result[1]
    
    _add_toggle_setting(vbox, "Show Debug Info", "show_debug_info")
    _add_toggle_setting(vbox, "Verbose Logging", "verbose_logging")
    
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


func _format_slider_value(value: float, suffix: String) -> String:
    if suffix == "x":
        return str(snapped(value, 0.1)) + suffix
    else:
        return str(int(value)) + suffix


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
    # TODO: Implement actual feature logic based on config_key


func _on_setting_slider_changed(config_key: String, value: float, suffix: String) -> void:
    mod_config[config_key] = value
    save_config()
    ModLoaderLog.info(config_key + ": " + str(value), LOG_NAME)
    _update_slider_label(config_key, value, suffix)
    # TODO: Implement actual feature logic based on config_key


func _update_slider_label(config_key: String, value: float, suffix: String) -> void:
    if !tab_container:
        return
    
    for tab in tab_container.get_children():
        var container = tab.get_node_or_null("MarginContainer/VBoxContainer/" + config_key + "_container")
        if !container:
            continue
        var value_label = container.get_node_or_null(config_key + "_header/" + config_key + "_value")
        if value_label:
            value_label.text = _format_slider_value(value, suffix)
            break


func _on_reset_settings_pressed() -> void:
    mod_config = {
        "enable_features": true,
        "auto_claim_achievements": false,
        "enhanced_stats": false,
        "animation_speed": 1.0,
        "custom_particles": false,
        "extra_glow": false,
        "compact_numbers": false,
        "ui_opacity": 100.0,
        "show_debug_info": false,
        "verbose_logging": false
    }
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
                    ModLoaderLog.info("Config loaded from " + CONFIG_PATH, LOG_NAME)
            else:
                ModLoaderLog.warning("Failed to parse config JSON", LOG_NAME)
    else:
        ModLoaderLog.info("No config file found, using defaults", LOG_NAME)


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
                    var suffix := "x" if config_key == "animation_speed" else "%"
                    value_label.text = _format_slider_value(mod_config[config_key], suffix)


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
