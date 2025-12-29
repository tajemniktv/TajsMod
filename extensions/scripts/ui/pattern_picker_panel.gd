# ==============================================================================
# Taj's Mod - Upload Labs
# Pattern Picker Panel - Visual pattern selector with full customization
# Author: TajemnikTV
# ==============================================================================
extends PanelContainer
class_name PatternPickerPanel

# Signals
signal settings_changed(pattern_index: int, color: Color, alpha: float, spacing: float, thickness: float)
signal settings_committed(pattern_index: int, color: Color, alpha: float, spacing: float, thickness: float)

# Constants
const PANEL_SIZE = Vector2(420, 380)
const PREVIEW_SIZE = Vector2(50, 50)
const PREVIEW_COLS = 6

# Pattern definitions
const PATTERN_NAMES = [
    "None", "Horizontal", "Vertical", "Diagonal /", "Diagonal \\",
    "Grid", "Diamond", "Dots", "Zigzag", "Waves", "Brick"
]
const PATTERN_COUNT = 11

# Current state
var _pattern_index: int = 0
var _pattern_color: Color = Color(0, 0, 0, 1.0)
var _pattern_alpha: float = 0.4
var _pattern_spacing: float = 20.0
var _pattern_thickness: float = 4.0

# UI References
var _preview_buttons: Array[Control] = []
var _color_btn: Button
var _color_preview: ColorRect
var _alpha_slider: HSlider
var _alpha_label: Label
var _spacing_slider: HSlider
var _spacing_label: Label
var _thickness_slider: HSlider
var _thickness_label: Label

# Color picker reference
var _color_picker_layer: CanvasLayer = null
var _color_picker: ColorPickerPanel = null

# Dragging state for panel
var _drag_offset = null


func _gui_input(event: InputEvent):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _drag_offset = get_global_mouse_position() - global_position
            else:
                _drag_offset = null
    elif event is InputEventMouseMotion and _drag_offset != null:
        global_position = get_global_mouse_position() - _drag_offset


func _init():
    custom_minimum_size = PANEL_SIZE


func _ready():
    _setup_panel_style()
    _build_ui()
    _update_all_ui()


func _setup_panel_style():
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.0862745, 0.101961, 0.137255, 1.0)
    style.border_color = Color(0.270064, 0.332386, 0.457031, 1.0)
    style.set_border_width_all(2)
    style.set_corner_radius_all(16)
    style.set_content_margin_all(16)
    style.shadow_color = Color(0, 0, 0, 0.3)
    style.shadow_size = 8
    add_theme_stylebox_override("panel", style)


func _build_ui():
    var main_vbox = VBoxContainer.new()
    main_vbox.add_theme_constant_override("separation", 12)
    add_child(main_vbox)
    
    # === HEADER ===
    var header = HBoxContainer.new()
    main_vbox.add_child(header)
    
    var title = Label.new()
    title.text = "Pattern Settings"
    title.add_theme_font_size_override("font_size", 18)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    
    var close_btn = Button.new()
    close_btn.text = "✕"
    close_btn.flat = true
    close_btn.add_theme_font_size_override("font_size", 16)
    close_btn.pressed.connect(_on_close_pressed)
    header.add_child(close_btn)
    
    # === PATTERN GRID ===
    var pattern_label = Label.new()
    pattern_label.text = "Pattern Style"
    pattern_label.add_theme_font_size_override("font_size", 14)
    pattern_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
    main_vbox.add_child(pattern_label)
    
    var grid = GridContainer.new()
    grid.columns = PREVIEW_COLS
    grid.add_theme_constant_override("h_separation", 6)
    grid.add_theme_constant_override("v_separation", 6)
    main_vbox.add_child(grid)
    
    for i in range(PATTERN_COUNT):
        var preview = _create_pattern_preview(i)
        grid.add_child(preview)
        _preview_buttons.append(preview)
    
    # === SEPARATOR ===
    var sep = HSeparator.new()
    sep.add_theme_constant_override("separation", 8)
    main_vbox.add_child(sep)
    
    # === COLOR ROW ===
    var color_row = HBoxContainer.new()
    color_row.add_theme_constant_override("separation", 8)
    main_vbox.add_child(color_row)
    
    var color_label = Label.new()
    color_label.text = "Color:"
    color_label.add_theme_font_size_override("font_size", 14)
    color_label.custom_minimum_size.x = 80
    color_row.add_child(color_label)
    
    _color_preview = ColorRect.new()
    _color_preview.custom_minimum_size = Vector2(32, 24)
    _color_preview.color = _pattern_color
    color_row.add_child(_color_preview)
    
    _color_btn = Button.new()
    _color_btn.text = "Pick Color..."
    _color_btn.add_theme_font_size_override("font_size", 14)
    _color_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _color_btn.pressed.connect(_on_color_btn_pressed)
    color_row.add_child(_color_btn)
    
    # === OPACITY SLIDER ===
    var opacity_row = _create_slider_row("Opacity:", 0.0, 1.0, 0.01, _pattern_alpha)
    _alpha_slider = opacity_row.slider
    _alpha_label = opacity_row.label
    _alpha_slider.value_changed.connect(_on_alpha_changed)
    main_vbox.add_child(opacity_row.container)
    
    # === SPACING SLIDER ===
    var spacing_row = _create_slider_row("Spacing:", 8.0, 50.0, 1.0, _pattern_spacing)
    _spacing_slider = spacing_row.slider
    _spacing_label = spacing_row.label
    _spacing_slider.value_changed.connect(_on_spacing_changed)
    main_vbox.add_child(spacing_row.container)
    
    # === THICKNESS SLIDER ===
    var thickness_row = _create_slider_row("Thickness:", 1.0, 10.0, 0.5, _pattern_thickness)
    _thickness_slider = thickness_row.slider
    _thickness_label = thickness_row.label
    _thickness_slider.value_changed.connect(_on_thickness_changed)
    main_vbox.add_child(thickness_row.container)
    
    # Setup color picker overlay
    _setup_color_picker()


func _create_slider_row(label_text: String, min_val: float, max_val: float, step: float, initial: float) -> Dictionary:
    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    
    var label = Label.new()
    label.text = label_text
    label.add_theme_font_size_override("font_size", 14)
    label.custom_minimum_size.x = 80
    row.add_child(label)
    
    var slider = HSlider.new()
    slider.min_value = min_val
    slider.max_value = max_val
    slider.step = step
    slider.value = initial
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slider.custom_minimum_size.x = 180
    row.add_child(slider)
    
    var value_label = Label.new()
    value_label.add_theme_font_size_override("font_size", 14)
    value_label.custom_minimum_size.x = 50
    value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(value_label)
    
    return {"container": row, "slider": slider, "label": value_label}


func _create_pattern_preview(pattern_index: int) -> Control:
    var btn = Button.new()
    btn.custom_minimum_size = PREVIEW_SIZE
    btn.toggle_mode = true
    btn.focus_mode = Control.FOCUS_NONE
    btn.tooltip_text = PATTERN_NAMES[pattern_index]
    
    # Style the button
    var normal_style = StyleBoxFlat.new()
    normal_style.bg_color = Color(0.12, 0.14, 0.18, 1.0)
    normal_style.border_color = Color(0.25, 0.3, 0.4, 1.0)
    normal_style.set_border_width_all(1)
    normal_style.set_corner_radius_all(6)
    btn.add_theme_stylebox_override("normal", normal_style)
    
    var pressed_style = StyleBoxFlat.new()
    pressed_style.bg_color = Color(0.2, 0.25, 0.35, 1.0)
    pressed_style.border_color = Color(0.4, 0.6, 0.9, 1.0)
    pressed_style.set_border_width_all(2)
    pressed_style.set_corner_radius_all(6)
    btn.add_theme_stylebox_override("pressed", pressed_style)
    
    var hover_style = StyleBoxFlat.new()
    hover_style.bg_color = Color(0.15, 0.18, 0.24, 1.0)
    hover_style.border_color = Color(0.3, 0.4, 0.55, 1.0)
    hover_style.set_border_width_all(1)
    hover_style.set_corner_radius_all(6)
    btn.add_theme_stylebox_override("hover", hover_style)
    
    # Add pattern preview drawer
    var preview = PatternPreview.new()
    preview.pattern_type = pattern_index
    preview.set_anchors_preset(Control.PRESET_FULL_RECT)
    preview.offset_left = 4
    preview.offset_top = 4
    preview.offset_right = -4
    preview.offset_bottom = -4
    preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
    btn.add_child(preview)
    
    var idx = pattern_index
    btn.pressed.connect(func(): _on_pattern_selected(idx))
    
    return btn


func _setup_color_picker():
    _color_picker_layer = CanvasLayer.new()
    _color_picker_layer.name = "PatternColorPickerLayer"
    _color_picker_layer.layer = 101
    _color_picker_layer.visible = false
    
    var bg_overlay = ColorRect.new()
    bg_overlay.name = "BackgroundOverlay"
    bg_overlay.color = Color(0, 0, 0, 0.4)
    bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    bg_overlay.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            _color_picker_layer.visible = false
    )
    _color_picker_layer.add_child(bg_overlay)
    
    _color_picker = ColorPickerPanel.new()
    _color_picker.name = "PatternColorPicker"
    _color_picker.set_color(_pattern_color)
    _color_picker.color_changed.connect(_on_color_picked)
    _color_picker.color_committed.connect(func(c):
        _color_picker_layer.visible = false
    )
    _color_picker_layer.add_child(_color_picker)
    
    # Add to root when ready
    call_deferred("_add_picker_to_root")


func _add_picker_to_root():
    if _color_picker_layer and not _color_picker_layer.is_inside_tree():
        get_tree().root.add_child(_color_picker_layer)


func _notification(what):
    if what == NOTIFICATION_PREDELETE:
        if is_instance_valid(_color_picker_layer):
            _color_picker_layer.queue_free()


# === EVENT HANDLERS ===

func _on_pattern_selected(index: int):
    _pattern_index = index
    _update_selection_ui()
    _emit_changed()
    Sound.play("click2")


func _on_color_btn_pressed():
    if _color_picker_layer:
        _color_picker_layer.visible = true
        _color_picker.position = (_color_picker.get_viewport_rect().size - _color_picker.size) / 2
        Sound.play("click2")


func _on_color_picked(new_color: Color):
    _pattern_color = new_color
    _color_preview.color = new_color
    _emit_changed()


func _on_alpha_changed(value: float):
    _pattern_alpha = value
    _alpha_label.text = str(int(value * 100)) + "%"
    _update_previews()
    _emit_changed()


func _on_spacing_changed(value: float):
    _pattern_spacing = value
    _spacing_label.text = str(int(value)) + "px"
    _update_previews()
    _emit_changed()


func _on_thickness_changed(value: float):
    _pattern_thickness = value
    _thickness_label.text = str(snapped(value, 0.5)) + "px"
    _update_previews()
    _emit_changed()


func _on_close_pressed():
    settings_committed.emit(_pattern_index, _pattern_color, _pattern_alpha, _pattern_spacing, _pattern_thickness)
    Sound.play("click2")


func _emit_changed():
    settings_changed.emit(_pattern_index, _pattern_color, _pattern_alpha, _pattern_spacing, _pattern_thickness)


# === PUBLIC API ===

func set_settings(index: int, color: Color, alpha: float, spacing: float, thickness: float):
    _pattern_index = index
    _pattern_color = color
    _pattern_alpha = alpha
    _pattern_spacing = spacing
    _pattern_thickness = thickness
    _update_all_ui()


func get_settings() -> Dictionary:
    return {
        "pattern_index": _pattern_index,
        "pattern_color": _pattern_color,
        "pattern_alpha": _pattern_alpha,
        "pattern_spacing": _pattern_spacing,
        "pattern_thickness": _pattern_thickness
    }


func _update_all_ui():
    # Safety check: if UI hasn't been built yet, just return
    # The state variables are already updated, _ready() will call this again
    if not is_instance_valid(_color_preview):
        return
    
    _update_selection_ui()
    _color_preview.color = _pattern_color
    if _color_picker:
        _color_picker.set_color(_pattern_color)
    
    _alpha_slider.value = _pattern_alpha
    _alpha_label.text = str(int(_pattern_alpha * 100)) + "%"
    
    _spacing_slider.value = _pattern_spacing
    _spacing_label.text = str(int(_pattern_spacing)) + "px"
    
    _thickness_slider.value = _pattern_thickness
    _thickness_label.text = str(snapped(_pattern_thickness, 0.5)) + "px"
    
    _update_previews()


func _update_selection_ui():
    if _preview_buttons.is_empty():
        return
    for i in range(_preview_buttons.size()):
        var btn = _preview_buttons[i] as Button
        btn.button_pressed = (i == _pattern_index)


func _update_previews():
    for i in range(_preview_buttons.size()):
        var btn = _preview_buttons[i]
        var preview = btn.get_child(0) as PatternPreview
        if preview:
            preview.color = Color(_pattern_color.r, _pattern_color.g, _pattern_color.b, _pattern_alpha)
            preview.spacing = _pattern_spacing
            preview.thickness = _pattern_thickness
            preview.queue_redraw()


# ==============================================================================
# PatternPreview - Mini pattern drawer for previews
# ==============================================================================
class PatternPreview extends Control:
    var pattern_type: int = 0
    var color: Color = Color(0, 0, 0, 0.4)
    var spacing: float = 20.0
    var thickness: float = 4.0
    
    func _ready():
        resized.connect(queue_redraw)
        clip_contents = true
    
    func _draw():
        if pattern_type == 0: return
        
        var s = get_size()
        # Scale down for preview
        var scale_factor = min(s.x / 50.0, s.y / 50.0)
        var step = max(spacing * scale_factor * 0.5, 4.0)
        var width = max(thickness * scale_factor * 0.5, 1.0)
        
        match pattern_type:
            1: _draw_horizontal(s, step, width)
            2: _draw_vertical(s, step, width)
            3: _draw_diagonal_slash(s, step, width)
            4: _draw_diagonal_backslash(s, step, width)
            5: _draw_grid(s, step, width)
            6: _draw_diamond(s, step, width)
            7: _draw_dots(s, step, width)
            8: _draw_zigzag(s, step, width)
            9: _draw_waves(s, step, width)
            10: _draw_brick(s, step, width)
    
    func _draw_horizontal(s: Vector2, step: float, width: float):
        var y = step / 2.0
        while y < s.y:
            draw_line(Vector2(0, y), Vector2(s.x, y), color, width)
            y += step
    
    func _draw_vertical(s: Vector2, step: float, width: float):
        var x = step / 2.0
        while x < s.x:
            draw_line(Vector2(x, 0), Vector2(x, s.y), color, width)
            x += step
    
    func _draw_diagonal_slash(s: Vector2, step: float, width: float):
        var x = -s.y
        while x < s.x:
            draw_line(Vector2(x, 0), Vector2(x + s.y, s.y), color, width)
            x += step
    
    func _draw_diagonal_backslash(s: Vector2, step: float, width: float):
        var x = 0.0
        while x < s.x + s.y:
            draw_line(Vector2(x, 0), Vector2(x - s.y, s.y), color, width)
            x += step
    
    func _draw_grid(s: Vector2, step: float, width: float):
        _draw_horizontal(s, step, width)
        _draw_vertical(s, step, width)
    
    func _draw_diamond(s: Vector2, step: float, width: float):
        _draw_diagonal_slash(s, step, width)
        _draw_diagonal_backslash(s, step, width)
    
    func _draw_dots(s: Vector2, step: float, width: float):
        var radius = max(width, 1.5)
        var x = step / 2.0
        while x < s.x:
            var y = step / 2.0
            while y < s.y:
                draw_circle(Vector2(x, y), radius, color)
                y += step
            x += step
    
    func _draw_zigzag(s: Vector2, step: float, width: float):
        var y = step / 2.0
        while y < s.y:
            var points = PackedVector2Array()
            var x = 0.0
            var up = true
            while x <= s.x:
                var py = y - step * 0.3 if up else y + step * 0.3
                points.append(Vector2(x, py))
                x += step * 0.5
                up = !up
            if points.size() >= 2:
                draw_polyline(points, color, width)
            y += step
    
    func _draw_waves(s: Vector2, step: float, width: float):
        var y = step / 2.0
        while y < s.y:
            var points = PackedVector2Array()
            var x = 0.0
            while x <= s.x + step:
                var wave_y = y + sin(x / step * PI) * step * 0.3
                points.append(Vector2(x, wave_y))
                x += 2.0
            if points.size() >= 2:
                draw_polyline(points, color, width)
            y += step
    
    func _draw_brick(s: Vector2, step: float, width: float):
        var y = 0.0
        var row = 0
        while y < s.y:
            draw_line(Vector2(0, y), Vector2(s.x, y), color, width)
            var offset = (step * 0.5) if row % 2 == 1 else 0.0
            var x = offset
            while x < s.x:
                var next_y = min(y + step, s.y)
                draw_line(Vector2(x, y), Vector2(x, next_y), color, width)
                x += step
            y += step
            row += 1
