# ==============================================================================
# Taj's Mod - Upload Labs
# Group Window Extension - Expanded color palette, patterns, and customization
# Author: TajemnikTV
# ==============================================================================
extends "res://scenes/windows/window_group.gd"

signal group_changed

# Expanded color palette
const NEW_COLORS: Array[String] = [
    "1a202c", "1a2b22", "1a292b", "1a1b2b", "211a2b", "2b1a27", "2b1a1a",
    "BE4242", "FFA500", "FFFF00", "00FF00", "00FFFF", "0000FF", "800080", "FF00FF", "252525", "000000"
]

# Pattern state
var pattern_index: int = 0
var pattern_color: Color = Color(0, 0, 0, 1.0)
var pattern_alpha: float = 0.4
var pattern_spacing: float = 20.0
var pattern_thickness: float = 4.0
var pattern_drawers: Array[Control] = []

# Other state
var custom_color: Color = Color.TRANSPARENT # Custom RGB color for group background
var color_picker_btn = null
var locked: bool = false

# Pattern picker overlay
var _pattern_picker_layer: CanvasLayer = null
var _pattern_picker: Control = null

# Vanilla colors for achievement compatibility (same as base game's window_group.gd)
# The Stylist achievement requires 7 distinct color INDICES, not color values
const VANILLA_COLORS: Array[String] = ["1a202c", "1a2b22", "1a292b", "1a1b2b", "211a2b", "2b1a27", "2b1a1a"]

# ==============================================================================
# PatternDrawer - Draws patterns on group panels (supports 11 patterns)
# ==============================================================================
const PatternDrawerScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/ui/pattern_drawer.gd")


func _ready() -> void:
    super._ready()
    
    # Inject Pattern Drawer into TitlePanel
    var title_panel = get_node_or_null("TitlePanel")
    if title_panel:
        # Pattern removed from TitlePanel
        var title_container = title_panel.get_node_or_null("TitleContainer")
        if title_container:
            # === Pattern Button (opens pattern picker) ===
            var pattern_btn = Button.new()
            pattern_btn.name = "PatternButton"
            pattern_btn.custom_minimum_size = Vector2(40, 40)
            pattern_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
            pattern_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
            pattern_btn.focus_mode = Control.FOCUS_NONE
            pattern_btn.theme_type_variation = "SettingButton"
            pattern_btn.add_theme_constant_override("icon_max_width", 20)
            pattern_btn.icon = load("res://textures/icons/grid.png")
            pattern_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
            pattern_btn.expand_icon = true
            pattern_btn.tooltip_text = "Pattern Settings"
            pattern_btn.pressed.connect(_open_pattern_picker)
            
            title_container.add_child(pattern_btn)
            if title_container.get_child_count() >= 3:
                title_container.move_child(pattern_btn, 3)
            
            # === Color Picker Setup ===
            var old_color_btn = title_container.get_node_or_null("ColorButton")
            _setup_color_picker(old_color_btn)
            
            # === Upgrade All Button ===
            var upgrade_btn = Button.new()
            upgrade_btn.name = "UpgradeAllButton"
            upgrade_btn.custom_minimum_size = Vector2(40, 40)
            upgrade_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
            upgrade_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
            upgrade_btn.focus_mode = Control.FOCUS_NONE
            upgrade_btn.theme_type_variation = "SettingButton"
            upgrade_btn.add_theme_constant_override("icon_max_width", 20)
            upgrade_btn.icon = load("res://textures/icons/up_arrow.png")
            upgrade_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
            upgrade_btn.expand_icon = true
            upgrade_btn.tooltip_text = "Upgrade All Nodes in Group"
            upgrade_btn.pressed.connect(upgrade_all_nodes)
            
            title_container.add_child(upgrade_btn)
            if title_container.get_child_count() >= 4:
                title_container.move_child(upgrade_btn, 4)

    # Inject Pattern Drawer into PanelContainer (Content)
    var body_panel = get_node_or_null("PanelContainer")
    if body_panel:
        var body_drawer = PatternDrawerScript.new()
        body_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
        body_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        body_panel.add_child(body_drawer)
        body_panel.move_child(body_drawer, 0)
        pattern_drawers.append(body_drawer)

    # Apply initial pattern
    update_pattern()
    
    # Setup pattern picker overlay
    _setup_pattern_picker()


func _setup_color_picker(old_color_btn):
    var picker_layer = CanvasLayer.new()
    picker_layer.name = "ColorPickerLayer"
    picker_layer.layer = 100
    picker_layer.visible = false
    get_tree().root.call_deferred("add_child", picker_layer)
    
    var bg_overlay = ColorRect.new()
    bg_overlay.name = "BackgroundOverlay"
    bg_overlay.color = Color(0, 0, 0, 0.4)
    bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    picker_layer.add_child(bg_overlay)
    
    var custom_picker = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/ui/color_picker_panel.gd").new()
    custom_picker.name = "ColorPickerPanel"
    
    if custom_color != Color.TRANSPARENT:
        custom_picker.set_color(custom_color)
    else:
        custom_picker.set_color(Color(NEW_COLORS[color]))
    
    picker_layer.add_child(custom_picker)
    color_picker_btn = custom_picker
    
    var show_picker = func():
        picker_layer.visible = true
        custom_picker.position = (custom_picker.get_viewport_rect().size - custom_picker.size) / 2
        Sound.play("click2")
    
    var hide_picker = func():
        picker_layer.visible = false
    
    bg_overlay.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            hide_picker.call()
    )
    
    custom_picker.color_changed.connect(_on_color_picked)
    custom_picker.color_committed.connect(func(c):
        hide_picker.call()
    )
    
    if old_color_btn:
        if old_color_btn.pressed.is_connected(_on_color_button_pressed):
            old_color_btn.pressed.disconnect(_on_color_button_pressed)
        old_color_btn.pressed.connect(func():
            show_picker.call()
        )


func _setup_pattern_picker():
    _pattern_picker_layer = CanvasLayer.new()
    _pattern_picker_layer.name = "PatternPickerLayer"
    _pattern_picker_layer.layer = 101
    _pattern_picker_layer.visible = false
    
    var bg_overlay = ColorRect.new()
    bg_overlay.name = "BackgroundOverlay"
    bg_overlay.color = Color(0, 0, 0, 0.4)
    bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    bg_overlay.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            _close_pattern_picker()
    )
    _pattern_picker_layer.add_child(bg_overlay)
    
    _pattern_picker = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/ui/pattern_picker_panel.gd").new()
    _pattern_picker.name = "PatternPickerPanel"
    _pattern_picker.set_settings(pattern_index, pattern_color, pattern_alpha, pattern_spacing, pattern_thickness)
    _pattern_picker.settings_changed.connect(_on_pattern_settings_changed)
    _pattern_picker.settings_committed.connect(func(idx, c, a, sp, th):
        _close_pattern_picker()
    )
    _pattern_picker_layer.add_child(_pattern_picker)
    
    get_tree().root.call_deferred("add_child", _pattern_picker_layer)


func _open_pattern_picker():
    if _pattern_picker_layer:
        _pattern_picker.set_settings(pattern_index, pattern_color, pattern_alpha, pattern_spacing, pattern_thickness)
        _pattern_picker_layer.visible = true
        _pattern_picker.position = (_pattern_picker.get_viewport_rect().size - _pattern_picker.size) / 2
        Sound.play("click2")


func _close_pattern_picker():
    if _pattern_picker_layer:
        _pattern_picker_layer.visible = false


func _on_pattern_settings_changed(idx: int, c: Color, a: float, sp: float, th: float):
    pattern_index = idx
    pattern_color = c
    pattern_alpha = a
    pattern_spacing = sp
    pattern_thickness = th
    update_pattern()
    group_changed.emit()


func update_color() -> void:
    var use_color: Color
    if custom_color != Color.TRANSPARENT:
        use_color = custom_color
    else:
        use_color = Color(NEW_COLORS[color])
    $TitlePanel.self_modulate = use_color
    $PanelContainer.self_modulate = use_color


func cycle_color() -> void:
    if color_picker_btn and color_picker_btn.get_parent():
        var popup = color_picker_btn.get_parent()
        if popup and popup.has_method("popup_centered"):
            popup.popup_centered()
    else:
        color += 1
        if color >= NEW_COLORS.size():
            color = 0
        custom_color = Color.TRANSPARENT
        update_color()
        color_changed.emit()
        group_changed.emit()


func _on_pattern_selected(id: int) -> void:
    pattern_index = id
    update_pattern()
    group_changed.emit()
    Sound.play("click2")


func _on_color_picked(new_color: Color) -> void:
    custom_color = new_color
    # Map to nearest vanilla color INDEX for Stylist achievement compatibility
    # The achievement checks for 7 distinct color indices (0-6)
    color = _find_nearest_vanilla_color_index(new_color)
    update_color()
    color_changed.emit()
    group_changed.emit()
    Sound.play("click2")


# Find the vanilla color index (0-6) that is closest to the given color.
# This ensures the Stylist achievement can track distinct colors even when
# using the custom color picker.
func _find_nearest_vanilla_color_index(target: Color) -> int:
    var best_index := 0
    var best_distance := INF
    
    for i in range(VANILLA_COLORS.size()):
        var vanilla_color = Color(VANILLA_COLORS[i])
        # Use Euclidean distance in RGB space
        var distance = sqrt(
            pow(target.r - vanilla_color.r, 2) +
            pow(target.g - vanilla_color.g, 2) +
            pow(target.b - vanilla_color.b, 2)
        )
        if distance < best_distance:
            best_distance = distance
            best_index = i
    
    return best_index


func cycle_pattern() -> void:
    pattern_index += 1
    if pattern_index > 10:
        pattern_index = 0
    update_pattern()
    group_changed.emit()
    Sound.play("click2")


func update_pattern() -> void:
    for drawer in pattern_drawers:
        drawer.set_pattern(pattern_index)
        drawer.set_style(pattern_color, pattern_alpha, pattern_spacing, pattern_thickness)


func upgrade_all_nodes() -> void:
    var upgraded_count = 0
    var skipped_count = 0
    var my_rect = get_rect()
    
    for window in get_tree().get_nodes_in_group("selectable"):
        if window == self:
            continue
        if !my_rect.encloses(window.get_rect()):
            continue
        
        if !window.has_method("upgrade"):
            continue
        
        if window.has_method("can_upgrade"):
            if !window.can_upgrade():
                skipped_count += 1
                continue
            if window.has_method("_on_upgrade_button_pressed"):
                window._on_upgrade_button_pressed()
                upgraded_count += 1
                continue
        
        var cost = window.get("cost")
        if cost != null and cost > 0:
            if cost > Globals.currencies.get("money", 0):
                skipped_count += 1
                continue
            Globals.currencies["money"] -= cost
        
        var arg_count = _get_method_arg_count(window, "upgrade")
        if arg_count == 0:
            window.upgrade()
        else:
            window.upgrade(1)
        upgraded_count += 1
    
    if upgraded_count > 0:
        Sound.play("upgrade")
        var msg = "Upgraded " + str(upgraded_count) + " nodes"
        if skipped_count > 0:
            msg += " (" + str(skipped_count) + " skipped - can't afford)"
        Signals.notify.emit("check", msg)
    else:
        Sound.play("error")
        if skipped_count > 0:
            Signals.notify.emit("exclamation", "Can't afford any upgrades (" + str(skipped_count) + " nodes)")
        else:
            Signals.notify.emit("exclamation", "No upgradeable nodes in group")


func _get_method_arg_count(obj: Object, method_name: String) -> int:
    var script = obj.get_script()
    if script:
        for method in script.get_script_method_list():
            if method.name == method_name:
                return method.args.size()
    return 1


# ==============================================================================
# Persistence - Save/Export/Load
# ==============================================================================
func save() -> Dictionary:
    var data = super.save()
    data["pattern_index"] = pattern_index
    data["pattern_color"] = pattern_color.to_html(true)
    data["pattern_alpha"] = pattern_alpha
    data["pattern_spacing"] = pattern_spacing
    data["pattern_thickness"] = pattern_thickness
    data["locked"] = locked
    if custom_color != Color.TRANSPARENT:
        data["custom_color"] = custom_color.to_html(true)
    return data


func export() -> Dictionary:
    var data = super.export()
    data["pattern_index"] = pattern_index
    data["pattern_color"] = pattern_color.to_html(true)
    data["pattern_alpha"] = pattern_alpha
    data["pattern_spacing"] = pattern_spacing
    data["pattern_thickness"] = pattern_thickness
    data["locked"] = locked
    if custom_color != Color.TRANSPARENT:
        data["custom_color"] = custom_color.to_html(true)
    return data


func _load_custom_data() -> void:
    # Restore custom color
    if has_meta("custom_color"):
        var color_str = get_meta("custom_color")
        custom_color = Color.html(color_str)
        update_color()
    
    # Restore pattern settings
    if has_meta("pattern_color"):
        pattern_color = Color.html(get_meta("pattern_color"))
    if has_meta("pattern_alpha"):
        pattern_alpha = get_meta("pattern_alpha")
    if has_meta("pattern_spacing"):
        pattern_spacing = get_meta("pattern_spacing")
    if has_meta("pattern_thickness"):
        pattern_thickness = get_meta("pattern_thickness")
    
    update_pattern()


# ==============================================================================
# Lock functionality
# ==============================================================================
func toggle_lock() -> void:
    locked = !locked
    if locked:
        Signals.notify.emit("lock", "Group locked")
    else:
        Signals.notify.emit("unlock", "Group unlocked")


func is_locked() -> bool:
    return locked


func grab(g: bool) -> void:
    if locked and g:
        Sound.play("error")
        return
    super.grab(g)


func _on_move_selection(to: Vector2) -> void:
    if locked:
        return
    super._on_move_selection(to)


func set_resizing(l: bool, t: bool, r: bool, b: bool) -> void:
    if locked and (l or t or r or b):
        Sound.play("error")
        return
    super.set_resizing(l, t, r, b)

func set_custom_name(new_name: String) -> void:
    super.set_custom_name(new_name)
    group_changed.emit()

func set_icon(icon: String) -> void:
    super.set_icon(icon)
    group_changed.emit()

# Apply data (for Undo/Redo)
func load_data(data: Dictionary) -> void:
    if data.has("custom_name"): set_custom_name(data["custom_name"])
    if data.has("custom_icon"): set_icon(data["custom_icon"])
    if data.has("color"):
        color = data["color"]
        
    if data.has("pattern_index"): pattern_index = data["pattern_index"]
    if data.has("pattern_color"): pattern_color = Color.html(data["pattern_color"])
    if data.has("pattern_alpha"): pattern_alpha = data["pattern_alpha"]
    if data.has("pattern_spacing"): pattern_spacing = data["pattern_spacing"]
    if data.has("pattern_thickness"): pattern_thickness = data["pattern_thickness"]
    
    if data.has("custom_color"):
        custom_color = Color.html(data["custom_color"])
    else:
        custom_color = Color.TRANSPARENT
        
    if data.has("locked"):
        locked = data["locked"]
        
    update_color()
    update_pattern()
    # No signal emission to prevent infinite loop if used inside undo?
    # Actually, we WANT signal if we want to update UI?
    # But usually Undo action shouldn't record another Undo step.
    # The command executes this.
