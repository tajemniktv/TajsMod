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

# UI References
var root_control: Control
var settings_panel: PanelContainer
var tab_container: TabContainer
var tab_buttons_container: Container
var _tab_buttons: Array[Button] = []
var settings_button: Button

# Signals can't be defined in RefCounted easily without `extends Object` and `add_user_signal` or just using Callables.
# We will use Callables passed in.

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
    
    var content_vbox := VBoxContainer.new()
    content_vbox.add_theme_constant_override("separation", 10)
    content_panel.add_child(content_vbox)
    
    # Tab Container
    tab_container = TabContainer.new()
    tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tab_container.theme_type_variation = "EmptyTabContainer"
    tab_container.tabs_visible = false
    content_vbox.add_child(tab_container)
    
    # Tab Buttons Area
    var buttons_panel := Panel.new()
    buttons_panel.custom_minimum_size = Vector2(0, 110)
    buttons_panel.theme_type_variation = "MenuPanelTitle"
    content_vbox.add_child(buttons_panel)
    
    tab_buttons_container = HBoxContainer.new()
    tab_buttons_container.set_anchors_preset(Control.PRESET_FULL_RECT)
    tab_buttons_container.offset_left = 15; tab_buttons_container.offset_top = 15
    tab_buttons_container.offset_right = -15; tab_buttons_container.offset_bottom = -15
    tab_buttons_container.add_theme_constant_override("separation", 10)
    buttons_panel.add_child(tab_buttons_container)

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
    
    # 2. Create button
    var btn := Button.new()
    btn.name = name + "Tab"
    btn.text = name
    btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
    btn.focus_mode = Control.FOCUS_NONE
    btn.theme_type_variation = "TabButton"
    btn.toggle_mode = true
    btn.icon = load(icon_path)
    btn.add_theme_constant_override("icon_max_width", 40)
    
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


# --- Widget Builders ---

func add_toggle(parent: Control, label_text: String, initial_val: bool, callback: Callable) -> CheckButton:
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(0, 64)
    parent.add_child(row)
    
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
    return btn
