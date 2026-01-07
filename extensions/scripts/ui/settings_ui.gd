# =============================================================================
# Taj's Mod - Upload Labs
# Settings UI - Handles mod settings interface
# Author: TajemnikTV
# =============================================================================
class_name TajsModSettingsUI
extends RefCounted

const LOG_NAME = "TajsModded:UI"

var _hud_node: Node
var _mod_version: String
var _config_ref = null # Reference to config manager for checking settings

# UI References
var root_control: Control
var settings_panel: PanelContainer
var tab_container: TabContainer
var tab_buttons_container: Container
var _tab_buttons: Array[Button] = []
var settings_button: Button

# Restart Banner State
var _restart_pending := false
var _restart_banner: Control = null
var _restart_indicator: Control = null
var _main_vbox: VBoxContainer = null # Reference to insert banner at top

# Search Bar State
var _search_field: LineEdit = null
var _searchable_rows: Array = [] # [{row: Control, label: String, tab_index: int}]

# Sidebar Collapse State
const SIDEBAR_WIDTH_COLLAPSED := 46.0 # Just enough for icon
const SIDEBAR_WIDTH_EXPANDED := 180.0
var _sidebar: Control = null
var _sidebar_expanded := false
var _sidebar_tween: Tween = null
var _search_container: Control = null

func _init(hud: Node, version: String):
    _hud_node = hud
    _mod_version = version
    _create_ui_structure()

var _is_animating := false
var _tween: Tween = null

func _create_ui_structure() -> void:
    # 1. Container for Mod Menus
    root_control = Control.new()
    root_control.name = "TajsModdedMenus"
    root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root_control.anchor_left = 1.0
    root_control.anchor_right = 1.0
    root_control.anchor_bottom = 1.0
    root_control.offset_left = -1180
    root_control.offset_right = -100
    
    var overlay = _hud_node.get_node_or_null("Main/MainContainer/Overlay")
    if overlay:
        overlay.add_child(root_control)
    else:
        ModLoaderLog.error("Could not find Overlay to attach Settings UI", LOG_NAME)
        return

    # 2. Main Panel
    settings_panel = PanelContainer.new()
    settings_panel.name = "TajsModdedSettingsPanel"
    settings_panel.visible = false
    settings_panel.theme_type_variation = "ShadowPanelContainer"
    settings_panel.anchor_right = 1.0
    settings_panel.anchor_bottom = 1.0
    settings_panel.offset_right = -20.0
    root_control.add_child(settings_panel)
    
    var main_vbox = VBoxContainer.new()
    main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    main_vbox.add_theme_constant_override("separation", 0)
    settings_panel.add_child(main_vbox)
    _main_vbox = main_vbox
    
    # 3. Title
    _create_title_panel(main_vbox)
    
    # 4. Content Area (Tabs)
    _create_content_panel(main_vbox)
    
    # 5. Footer (Version)
    _create_footer_panel(main_vbox)

func _create_title_panel(parent: Control) -> void:
    var title_panel := Panel.new()
    title_panel.custom_minimum_size = Vector2(0, 80)
    title_panel.theme_type_variation = "OverlayPanelTitle"
    parent.add_child(title_panel)
    
    var title_container := HBoxContainer.new()
    title_container.set_anchors_preset(Control.PRESET_FULL_RECT)
    title_container.offset_left = 15; title_container.offset_top = 15
    title_container.offset_right = -15; title_container.offset_bottom = -15
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

func _create_content_panel(parent: Control) -> void:
    var content_panel := PanelContainer.new()
    content_panel.theme_type_variation = "MenuPanel"
    content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    parent.add_child(content_panel)
    
    # Main horizontal split: Sidebar | Content (sidebar on LEFT)
    var main_hbox := HBoxContainer.new()
    main_hbox.add_theme_constant_override("separation", 0)
    content_panel.add_child(main_hbox)
    
    # === LEFT SIDEBAR (icons on left, expands right naturally) ===
    var sidebar := VBoxContainer.new()
    sidebar.name = "Sidebar"
    sidebar.custom_minimum_size = Vector2(SIDEBAR_WIDTH_COLLAPSED, 0)
    sidebar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    sidebar.add_theme_constant_override("separation", 0)
    sidebar.clip_contents = true # Clip text when collapsed
    sidebar.mouse_filter = Control.MOUSE_FILTER_STOP
    main_hbox.add_child(sidebar)
    _sidebar = sidebar
    
    # Connect hover events for expand/collapse
    sidebar.mouse_entered.connect(_on_sidebar_mouse_entered)
    sidebar.mouse_exited.connect(_on_sidebar_mouse_exited)
    
    # Sidebar: Scrollable Tab Buttons
    var tab_scroll := ScrollContainer.new()
    tab_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    tab_scroll.mouse_entered.connect(_on_sidebar_mouse_entered)
    tab_scroll.mouse_exited.connect(_on_sidebar_mouse_exited)
    sidebar.add_child(tab_scroll)
    
    tab_buttons_container = VBoxContainer.new()
    tab_buttons_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tab_buttons_container.add_theme_constant_override("separation", 10)
    tab_buttons_container.mouse_filter = Control.MOUSE_FILTER_PASS
    tab_scroll.add_child(tab_buttons_container)
    
    # Separator between sidebar and content
    var separator := VSeparator.new()
    separator.add_theme_constant_override("separation", 2)
    main_hbox.add_child(separator)
    
    # === RIGHT CONTENT AREA ===
    var content_vbox := VBoxContainer.new()
    content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_vbox.add_theme_constant_override("separation", 0)
    main_hbox.add_child(content_vbox)
    
    # Search field at top of content area
    _create_search_field(content_vbox)
    
    tab_container = TabContainer.new()
    tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tab_container.theme_type_variation = "EmptyTabContainer"
    tab_container.tabs_visible = false
    content_vbox.add_child(tab_container)

# --- Sidebar Collapse/Expand ---

func _on_sidebar_mouse_entered() -> void:
    _expand_sidebar()

func _on_sidebar_mouse_exited() -> void:
    _collapse_sidebar()

func _expand_sidebar() -> void:
    if _sidebar_expanded:
        return
    _sidebar_expanded = true
    
    if _sidebar_tween and _sidebar_tween.is_valid():
        _sidebar_tween.kill()
    
    _sidebar_tween = _sidebar.create_tween()
    _sidebar_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _sidebar_tween.tween_property(_sidebar, "custom_minimum_size:x", SIDEBAR_WIDTH_EXPANDED, 0.2)
    
    # Show button text (icon on left, text on right)
    for btn in _tab_buttons:
        if is_instance_valid(btn):
            var tab_name = btn.name.replace("Tab", "")
            btn.text = "  " + tab_name # Space after icon, then text
            btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
            btn.custom_minimum_size.x = SIDEBAR_WIDTH_EXPANDED

func _collapse_sidebar() -> void:
    if not _sidebar_expanded:
        return
    _sidebar_expanded = false
    
    if _sidebar_tween and _sidebar_tween.is_valid():
        _sidebar_tween.kill()
    
    _sidebar_tween = _sidebar.create_tween()
    _sidebar_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    _sidebar_tween.tween_property(_sidebar, "custom_minimum_size:x", SIDEBAR_WIDTH_COLLAPSED, 0.2)
    
    # Hide button text (icon only, centered)
    for btn in _tab_buttons:
        if is_instance_valid(btn):
            btn.text = ""
            btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
            btn.custom_minimum_size.x = SIDEBAR_WIDTH_COLLAPSED

func _create_footer_panel(parent: Control) -> void:
    var version_panel := PanelContainer.new()
    version_panel.theme_type_variation = "MenuPanelTitle"
    version_panel.custom_minimum_size = Vector2(0, 40)
    parent.add_child(version_panel)
    
    var version_label := Label.new()
    version_label.text = "Taj's Mod v" + _mod_version
    version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    version_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    version_label.add_theme_color_override("font_color", Color(0.627, 0.776, 0.812, 0.8))
    version_panel.add_child(version_label)

# ==============================================================================
# Icon Loading Helpers
# ==============================================================================

## Safely load an icon with fallback support for shipped builds
func _load_icon_safe(icon_path: String, tab_name: String) -> Texture2D:
    # First try direct load
    if ResourceLoader.exists(icon_path):
        var texture = load(icon_path)
        if texture:
            return texture
    
    # Log the failure for debugging
    ModLoaderLog.warning("Could not load icon: %s for tab %s" % [icon_path, tab_name], LOG_NAME)
    
    # Fallback to base game icons based on tab name
    var fallback_icons: Dictionary = {
        "Keybinds": "res://textures/icons/keyboard.png",
        "Mod Manager": "res://textures/icons/puzzle.png",
        "General": "res://textures/icons/cog.png",
        "Visuals": "res://textures/icons/eye_ball.png",
        "Cheats": "res://textures/icons/money.png",
        "Debug": "res://textures/icons/bug.png"
    }
    
    if fallback_icons.has(tab_name):
        var fallback_path = fallback_icons[tab_name]
        if ResourceLoader.exists(fallback_path):
            return load(fallback_path)
    
    # Last resort: use a generic icon from base game
    var generic_fallback = "res://textures/icons/cog.png"
    if ResourceLoader.exists(generic_fallback):
        return load(generic_fallback)
    
    return null

# ==============================================================================
# Public API
# ==============================================================================

func add_mod_button(callback: Callable) -> void:
    var extras_container = _hud_node.get_node_or_null("Main/MainContainer/Overlay/ExtrasButtons/Container")
    if !extras_container: return
    
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
    settings_button.pressed.connect(callback)
    
    extras_container.add_child(settings_button)
    extras_container.move_child(settings_button, 0)

func add_tab(name: String, icon_path: String) -> VBoxContainer:
    # 1. Create content container
    var scroll := ScrollContainer.new()
    scroll.name = name
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    
    var margin := MarginContainer.new()
    margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.add_theme_constant_override("margin_left", 20)
    margin.add_theme_constant_override("margin_right", 20)
    margin.add_theme_constant_override("margin_top", 10)
    scroll.add_child(margin)
    
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 10)
    margin.add_child(vbox)
    
    tab_container.add_child(scroll)
    
    # 2. Create sidebar button (icon-only when collapsed, text on expand)
    var btn := Button.new()
    btn.name = name + "Tab"
    btn.text = "" # Start collapsed (icon-only)
    btn.custom_minimum_size = Vector2(SIDEBAR_WIDTH_COLLAPSED, 50) # Collapsed width, consistent height
    btn.focus_mode = Control.FOCUS_NONE
    btn.theme_type_variation = "TabButton"
    btn.toggle_mode = true
    
    # Robust icon loading with fallback
    var icon_texture = _load_icon_safe(icon_path, name)
    if icon_texture:
        btn.icon = icon_texture
    
    btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER # Center icon when collapsed
    btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
    btn.add_theme_constant_override("icon_max_width", 36) # Larger icons
    btn.add_theme_constant_override("h_separation", 10)
    btn.mouse_entered.connect(_on_sidebar_mouse_entered) # Forward hover events
    btn.mouse_exited.connect(_on_sidebar_mouse_exited)
    
    var target_index = _tab_buttons.size()
    btn.pressed.connect(func(): _on_tab_selected(target_index))
    
    if target_index == 0:
        btn.button_pressed = true
        
    tab_buttons_container.add_child(btn)
    _tab_buttons.append(btn)
    
    return vbox

func _on_tab_selected(index: int) -> void:
    tab_container.current_tab = index
    for i in range(_tab_buttons.size()):
        _tab_buttons[i].set_pressed_no_signal(i == index)

func set_config(config) -> void:
    _config_ref = config

func set_visible(visible: bool) -> void:
    if _is_animating: return
    
    # Close other game UIs when opening our panel
    if visible:
        Signals.set_menu.emit(0, 0) # Close game menus
    
    if settings_button:
        settings_button.set_pressed_no_signal(visible)
    
    # Animate slide in/out (like game's menus.gd)
    if _tween and _tween.is_valid():
        _tween.kill()
    
    _is_animating = true
    
    if visible:
        settings_panel.visible = true
        settings_panel.modulate.a = 0
        settings_panel.position.x = 200 # Start off to the right
        
        _tween = settings_panel.create_tween()
        _tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        _tween.set_parallel()
        _tween.tween_property(settings_panel, "modulate:a", 1.0, 0.25)
        _tween.tween_property(settings_panel, "position:x", 0.0, 0.25)
        _tween.finished.connect(func(): _is_animating = false)
        Sound.play("menu_open")
    else:
        settings_panel.modulate.a = 1
        
        # Clear search when closing
        _clear_search()
        
        _tween = settings_panel.create_tween()
        _tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        _tween.set_parallel()
        _tween.tween_property(settings_panel, "position:x", 200.0, 0.25)
        _tween.tween_property(settings_panel, "modulate:a", 0.0, 0.25)
        _tween.finished.connect(func():
            settings_panel.visible = false
            _is_animating = false
        )
        Sound.play("menu_close")

func is_visible() -> bool:
    if not is_instance_valid(settings_panel):
        return false
    return settings_panel.visible


# --- Search Field ---

func _create_search_field(parent: Control) -> void:
    var search_container := PanelContainer.new()
    search_container.theme_type_variation = "MenuPanelTitle"
    search_container.custom_minimum_size = Vector2(0, 50)
    parent.add_child(search_container)
    _search_container = search_container
    
    var search_margin := MarginContainer.new()
    search_margin.add_theme_constant_override("margin_left", 15)
    search_margin.add_theme_constant_override("margin_right", 15)
    search_margin.add_theme_constant_override("margin_top", 8)
    search_margin.add_theme_constant_override("margin_bottom", 8)
    search_container.add_child(search_margin)
    
    _search_field = LineEdit.new()
    _search_field.placeholder_text = "Search settings..."
    _search_field.clear_button_enabled = true
    _search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _search_field.add_theme_font_size_override("font_size", 24)
    _search_field.text_changed.connect(_filter_rows)
    search_margin.add_child(_search_field)

func _filter_rows(query: String) -> void:
    var search_term := query.strip_edges().to_lower()
    
    for entry in _searchable_rows:
        if not is_instance_valid(entry.row):
            continue
        
        if search_term.is_empty():
            entry.row.visible = true
        else:
            # Check if label contains the search term (case-insensitive)
            var matches: bool = entry.label.to_lower().contains(search_term)
            entry.row.visible = matches

func _clear_search() -> void:
    if _search_field and is_instance_valid(_search_field):
        _search_field.text = ""
        _filter_rows("")

## Track a row for search filtering
func _track_row(row: Control, label_text: String, tab_idx: int) -> void:
    _searchable_rows.append({
        "row": row,
        "label": label_text,
        "tab_index": tab_idx
    })


# --- Widget Builders ---

func add_toggle(parent: Control, label_text: String, initial_val: bool, callback: Callable, tooltip: String = "") -> CheckButton:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 64)
    if tooltip != "":
        row.tooltip_text = tooltip
    parent.add_child(row)
    
    # Track row for search
    _track_row(row, label_text, tab_container.get_child_count() - 1)
    
    var label := Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 32)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    
    var toggle := CheckButton.new()
    toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
    toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    toggle.focus_mode = Control.FOCUS_NONE
    toggle.flat = true
    toggle.button_pressed = initial_val
    toggle.toggled.connect(callback)
    row.add_child(toggle)
    
    return toggle

func add_slider(parent: Control, label_text: String, start_val: float, min_val: float, max_val: float, step: float, suffix: String, callback: Callable) -> HSlider:
    var container := VBoxContainer.new()
    container.add_theme_constant_override("separation", 5)
    parent.add_child(container)
    
    # Track container for search
    _track_row(container, label_text, tab_container.get_child_count() - 1)
    
    var header := HBoxContainer.new()
    container.add_child(header)
    
    var label := Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 32)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(label)
    
    var value_label := Label.new()
    value_label.text = _format_slider_value(start_val, suffix)
    value_label.add_theme_font_size_override("font_size", 32)
    header.add_child(value_label)
    
    var slider := HSlider.new()
    slider.min_value = min_val
    slider.max_value = max_val
    slider.step = step
    slider.value = start_val
    slider.focus_mode = Control.FOCUS_NONE
    
    # Block scroll wheel input when setting is enabled
    var cfg = _config_ref
    slider.gui_input.connect(func(event: InputEvent):
        if cfg and cfg.get_value("disable_slider_scroll", false):
            if event is InputEventMouseButton:
                if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
                    slider.accept_event() # Consume the event to prevent slider value change
    )
    
    slider.value_changed.connect(func(v):
        value_label.text = _format_slider_value(v, suffix)
        callback.call(v)
    )
    container.add_child(slider)
    return slider

func _format_slider_value(value: float, suffix: String) -> String:
    if suffix == "x":
        return str(snapped(value, 0.1)) + suffix
    elif suffix == "%" or suffix == "px":
        return str(int(value)) + suffix
    else:
        return str(snapped(value, 0.1))

func add_button(parent: Control, text: String, callback: Callable) -> Button:
    var btn := Button.new()
    btn.text = text
    btn.custom_minimum_size = Vector2(0, 60)
    btn.theme_type_variation = "TabButton" # Reuse valid style
    btn.focus_mode = Control.FOCUS_NONE
    btn.pressed.connect(callback)
    parent.add_child(btn)
    
    # Track button for search
    _track_row(btn, text, tab_container.get_child_count() - 1)
    
    return btn


# ==============================================================================
# Restart Banner
# ==============================================================================

## Show restart required banner (in-panel + floating indicator)
func show_restart_banner() -> void:
    if _restart_pending:
        return # Already showing
    
    _restart_pending = true
    _create_restart_banner()
    _create_restart_indicator()
    Sound.play("menu_open")

## Hide restart banner and indicator
func hide_restart_banner() -> void:
    _restart_pending = false
    
    if _restart_banner and is_instance_valid(_restart_banner):
        _restart_banner.queue_free()
        _restart_banner = null
    
    if _restart_indicator and is_instance_valid(_restart_indicator):
        _restart_indicator.queue_free()
        _restart_indicator = null

## Check if restart is pending
func is_restart_pending() -> bool:
    return _restart_pending

## Create the in-panel restart banner
func _create_restart_banner() -> void:
    if _restart_banner and is_instance_valid(_restart_banner):
        return # Already exists
    
    if not _main_vbox:
        return
    
    # Create banner container
    var banner = PanelContainer.new()
    banner.name = "RestartBanner"
    banner.custom_minimum_size = Vector2(0, 50)
    
    # Apply amber/warning style
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.85, 0.55, 0.15, 0.95)
    style.set_corner_radius_all(0)
    style.content_margin_left = 15
    style.content_margin_right = 15
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    banner.add_theme_stylebox_override("panel", style)
    
    # Content HBox
    var hbox = HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 10)
    banner.add_child(hbox)
    
    # Icon
    var icon = TextureRect.new()
    icon.custom_minimum_size = Vector2(28, 28)
    icon.texture = load("res://textures/icons/reload.png")
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.self_modulate = Color(1, 1, 1)
    icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    hbox.add_child(icon)
    
    # Label
    var label = Label.new()
    label.text = "Restart required for changes"
    label.add_theme_font_size_override("font_size", 22)
    label.add_theme_color_override("font_color", Color(1, 1, 1))
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    hbox.add_child(label)
    
    # Dismiss button
    var dismiss_btn = Button.new()
    dismiss_btn.text = "Dismiss"
    dismiss_btn.custom_minimum_size = Vector2(90, 34)
    dismiss_btn.focus_mode = Control.FOCUS_NONE
    dismiss_btn.theme_type_variation = "TabButton"
    dismiss_btn.pressed.connect(func():
        Sound.play("menu_close")
        hide_restart_banner()
    )
    hbox.add_child(dismiss_btn)
    
    # Exit Now button
    var exit_btn = Button.new()
    exit_btn.text = "Exit Now"
    exit_btn.custom_minimum_size = Vector2(90, 34)
    exit_btn.focus_mode = Control.FOCUS_NONE
    exit_btn.theme_type_variation = "TabButton"
    exit_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.7))
    exit_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.9))
    exit_btn.pressed.connect(func():
        _hud_node.get_tree().quit()
    )
    hbox.add_child(exit_btn)
    
    # Insert at top of main_vbox
    _main_vbox.add_child(banner)
    _main_vbox.move_child(banner, 0)
    _restart_banner = banner

## Create floating indicator near mod button
func _create_restart_indicator() -> void:
    if _restart_indicator and is_instance_valid(_restart_indicator):
        return # Already exists
    
    if not settings_button or not is_instance_valid(settings_button):
        return
    
    # Create indicator dot
    var indicator = Panel.new()
    indicator.name = "RestartIndicator"
    indicator.custom_minimum_size = Vector2(14, 14)
    indicator.mouse_filter = Control.MOUSE_FILTER_PASS
    indicator.tooltip_text = "Restart required for some settings"
    
    # Amber dot style
    var style = StyleBoxFlat.new()
    style.bg_color = Color(1.0, 0.6, 0.2, 1.0)
    style.set_corner_radius_all(7) # Circular
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.3, 0.2, 0.1, 1.0)
    indicator.add_theme_stylebox_override("panel", style)
    
    # Position at top-right of the button
    var btn_parent = settings_button.get_parent()
    if btn_parent:
        btn_parent.add_child(indicator)
        
        # Position relative to button
        indicator.set_anchors_preset(Control.PRESET_TOP_LEFT)
        indicator.position = settings_button.position + Vector2(settings_button.size.x - 8, -3)
        
        # Re-position when button moves (deferred to catch layout changes)
        settings_button.resized.connect(func():
            if is_instance_valid(indicator) and is_instance_valid(settings_button):
                indicator.position = settings_button.position + Vector2(settings_button.size.x - 8, -3)
        )
    
    _restart_indicator = indicator
