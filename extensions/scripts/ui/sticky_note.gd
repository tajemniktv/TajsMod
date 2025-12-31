# ==============================================================================
# Taj's Mod - Upload Labs
# Sticky Note - Draggable, editable text notes for canvas labeling
# Styled to match Group Node aesthetic
# Author: TajemnikTV
# ==============================================================================
extends Control
class_name TajsStickyNote

const LOG_NAME = "TajsModded:StickyNote"

# Preload dependencies
const ColorPickerPanelScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/ui/color_picker_panel.gd")
const PatternPickerPanelScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/ui/pattern_picker_panel.gd")
const PatternDrawerScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/ui/pattern_drawer.gd")

# Signals for manager synchronization
signal note_changed(note_id: String)
signal note_deleted(note_id: String)
signal note_duplicated(note_id: String, new_position: Vector2)
signal drag_started()
signal drag_ended()
signal selection_changed(selected: bool)

# Note properties
var note_id: String = ""
var title_text: String = "Note"
var body_text: String = ""
var note_color: Color = Color("1a202c")

# Pattern state
var pattern_index: int = 0
var pattern_color: Color = Color(0, 0, 0, 1.0)
var pattern_alpha: float = 0.4
var pattern_spacing: float = 20.0
var pattern_thickness: float = 4.0
var pattern_drawers: Array[Control] = []

# UI References
var _title_panel: Panel
var _body_panel: Panel
var _title_button: Button
var _title_edit: LineEdit
var _body_edit: TextEdit
var _color_btn: Button
var _pattern_btn: Button
var _duplicate_btn: Button
var _delete_btn: Button

# Resize Handles (Controls)
var _resize_handles: Dictionary = {}

# Pickers
var _color_picker_layer: CanvasLayer = null
var _color_picker: Control = null
var _pattern_picker_layer: CanvasLayer = null
var _pattern_picker: Control = null

# State
var _is_dragging := false
var _drag_offset := Vector2.ZERO
var _is_resizing := false
var _resize_dir := Vector2.ZERO # Direction of resize (-1, 0, 1)
var _resize_start_rect := Rect2()
var _resize_start_mouse := Vector2.ZERO
var _min_size := Vector2(200, 100)
var _is_editing_title := false
var _is_hovered := false
var _is_selected := false: set = _set_selected

# Manager reference
var _manager = null

# Visual Constants
const HANDLE_SIZE = 8.0 # Radius
const HANDLE_OFFSET = 10.0 # Further offset
const HANDLE_COLOR = Color("ff8500")
const OUTLINE_COLOR = Color("ff8500")
const OUTLINE_WIDTH = 2.0

func _init() -> void:
    custom_minimum_size = Vector2(200, 100)
    size = Vector2(280, 140)
    mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
    _build_ui()
    _setup_pickers()
    
    # Apply initial content
    if _title_button:
        _title_button.text = title_text if title_text else "Note"
    if _body_edit:
        _body_edit.text = body_text
        
    # Apply initial visuals
    update_color()
    update_pattern()
    _update_visual_state()
    
    mouse_entered.connect(func():
        _is_hovered = true
        queue_redraw()
    )
    mouse_exited.connect(func():
        _is_hovered = false
        queue_redraw()
    )
    
    z_index = 10

func _build_ui() -> void:
    # === TITLE PANEL ===
    _title_panel = Panel.new()
    _title_panel.name = "TitlePanel"
    # TITLE HEIGHT: 56px
    _title_panel.anchor_left = 0
    _title_panel.anchor_top = 0
    _title_panel.anchor_right = 1
    _title_panel.anchor_bottom = 0
    _title_panel.offset_bottom = 56 # Increased from 40 to 56
    _title_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _title_panel.gui_input.connect(_on_title_panel_input)
    
    # Styling
    var title_style = StyleBoxFlat.new()
    title_style.bg_color = Color(1, 1, 1, 0.5)
    title_style.corner_radius_top_left = 12
    title_style.corner_radius_top_right = 12
    title_style.corner_radius_bottom_right = 0
    title_style.corner_radius_bottom_left = 0
    title_style.shadow_color = Color(0, 0, 0, 0.1)
    title_style.shadow_size = 2
    # Ensure no borders
    title_style.border_width_left = 0
    title_style.border_width_top = 0
    title_style.border_width_right = 0
    title_style.border_width_bottom = 0
    _title_panel.add_theme_stylebox_override("panel", title_style)
    add_child(_title_panel)
    
    # Pattern Drawer for Title
    var title_pattern = PatternDrawerScript.new()
    title_pattern.set_anchors_preset(Control.PRESET_FULL_RECT)
    _title_panel.add_child(title_pattern)
    pattern_drawers.append(title_pattern)
    
    # Title container
    var title_container = HBoxContainer.new()
    title_container.name = "TitleContainer"
    title_container.set_anchors_preset(Control.PRESET_FULL_RECT)
    title_container.add_theme_constant_override("separation", 4)
    
    # Margins
    var title_margin = MarginContainer.new()
    title_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    title_margin.add_theme_constant_override("margin_left", 6)
    title_margin.add_theme_constant_override("margin_right", 6)
    title_margin.add_theme_constant_override("margin_top", 4)
    title_margin.add_theme_constant_override("margin_bottom", 4)
    title_margin.add_child(title_container)
    _title_panel.add_child(title_margin)
    
    # Note icon
    var note_icon = Label.new()
    note_icon.text = "📝"
    note_icon.add_theme_font_size_override("font_size", 18)
    note_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    note_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title_container.add_child(note_icon)
    
    # Title button
    _title_button = Button.new()
    _title_button.name = "TitleButton"
    _title_button.text = "Note"
    _title_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _title_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    _title_button.flat = true
    _title_button.add_theme_font_size_override("font_size", 24) # Increased to 24
    _title_button.add_theme_color_override("font_color", Color("b0cff9")) # Light blue #b0cff9
    
    # Soft Shadow instead of Outline
    _title_button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
    _title_button.add_theme_constant_override("shadow_offset_x", 1)
    _title_button.add_theme_constant_override("shadow_offset_y", 1)
    
    _title_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
    _title_button.mouse_default_cursor_shape = Control.CURSOR_IBEAM
    _title_button.pressed.connect(_start_title_edit)
    title_container.add_child(_title_button)
    
    # Title LineEdit
    _title_edit = LineEdit.new()
    _title_edit.name = "TitleEdit"
    _title_edit.visible = false
    _title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _title_edit.add_theme_font_size_override("font_size", 16)
    _title_edit.context_menu_enabled = false
    # Make style invisible so it text just overlays
    var edit_style = StyleBoxFlat.new()
    edit_style.bg_color = Color(0, 0, 0, 0)
    _title_edit.add_theme_stylebox_override("normal", edit_style)
    _title_edit.add_theme_stylebox_override("focus", edit_style)
    
    _title_edit.text_submitted.connect(_finish_title_edit)
    _title_edit.focus_exited.connect(_finish_title_edit_no_arg)
    _title_edit.gui_input.connect(_on_title_edit_gui_input)
    title_container.add_child(_title_edit)
    
    # Color button
    _color_btn = _create_header_button("contrast.png", "Change Color")
    _color_btn.pressed.connect(_open_color_picker)
    title_container.add_child(_color_btn)
    
    # Pattern button
    _pattern_btn = _create_header_button("grid.png", "Pattern Settings")
    _pattern_btn.pressed.connect(_open_pattern_picker)
    title_container.add_child(_pattern_btn)
    
    # Duplicate button
    _duplicate_btn = _create_header_button("plus.png", "Duplicate Note")
    _duplicate_btn.pressed.connect(_on_duplicate_pressed)
    title_container.add_child(_duplicate_btn)
    
    # Delete button
    _delete_btn = _create_header_button("trash_bin.png", "Delete Note")
    _delete_btn.pressed.connect(_on_delete_pressed)
    title_container.add_child(_delete_btn)
    
    # === BODY PANEL ===
    _body_panel = Panel.new()
    _body_panel.name = "BodyPanel"
    _body_panel.anchor_left = 0
    _body_panel.anchor_top = 0
    _body_panel.anchor_right = 1
    _body_panel.anchor_bottom = 1
    _body_panel.offset_top = 56 # Matched to new header height (was 40)
    _body_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    # Use white stylebox for tinting
    # SQUARED TOP CORNERS for seamless look
    # HIGHER TRANSPARENCY for Body
    var body_style = StyleBoxFlat.new()
    body_style.bg_color = Color(1, 1, 1, 0.4) # Very transparent (glassy)
    body_style.corner_radius_top_left = 0
    body_style.corner_radius_top_right = 0
    body_style.corner_radius_bottom_right = 12
    body_style.corner_radius_bottom_left = 12
    body_style.shadow_color = Color(0, 0, 0, 0.1)
    body_style.shadow_size = 2
    # Ensure no borders
    body_style.border_width_left = 0
    body_style.border_width_top = 0
    body_style.border_width_right = 0
    body_style.border_width_bottom = 0
    _body_panel.add_theme_stylebox_override("panel", body_style)
    add_child(_body_panel)
    
    # Pattern Drawer for Body
    var body_pattern = PatternDrawerScript.new()
    body_pattern.set_anchors_preset(Control.PRESET_FULL_RECT)
    _body_panel.add_child(body_pattern)
    pattern_drawers.append(body_pattern)
    
    # Body text area
    _body_edit = TextEdit.new()
    _body_edit.name = "BodyEdit"
    _body_edit.placeholder_text = "Write notes here..."
    _body_edit.anchor_left = 0
    _body_edit.anchor_top = 0
    _body_edit.anchor_right = 1
    _body_edit.anchor_bottom = 1
    _body_edit.offset_left = 8
    _body_edit.offset_top = 8
    _body_edit.offset_right = -8
    _body_edit.offset_bottom = -8
    _body_edit.add_theme_font_size_override("font_size", 14)
    # Match group node text colors
    _body_edit.add_theme_color_override("font_placeholder_color", Color(0.8, 0.8, 0.8, 0.5))
    _body_edit.add_theme_color_override("font_color", Color(1, 1, 1))
    _body_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    _body_edit.context_menu_enabled = false
    
    var body_edit_style = StyleBoxFlat.new()
    body_edit_style.bg_color = Color(0, 0, 0, 0.15)
    body_edit_style.set_corner_radius_all(4)
    _body_edit.add_theme_stylebox_override("normal", body_edit_style)
    _body_edit.add_theme_stylebox_override("focus", body_edit_style)
    
    _body_edit.text_changed.connect(_on_body_changed)
    _body_edit.gui_input.connect(_on_body_gui_input)
    _body_edit.focus_entered.connect(func(): _set_selected(true))
    _body_panel.add_child(_body_edit)
    
    # === RESIZE HANDLES ===
    _build_resize_handles()

func _build_resize_handles() -> void:
    var dirs = [
        Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
        Vector2(-1, 0), Vector2(1, 0),
        Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)
    ]
    
    for dir in dirs:
        var handle = Control.new()
        handle.name = "ResizeHandle_%s_%s" % [dir.x, dir.y]
        handle.custom_minimum_size = Vector2(HANDLE_SIZE * 2 + 4, HANDLE_SIZE * 2 + 4) # Expanded hit area
        handle.mouse_filter = Control.MOUSE_FILTER_STOP # Block input (prevents camera move)
        handle.mouse_default_cursor_shape = _get_cursor_for_dir(dir)
        handle.gui_input.connect(func(event): _on_handle_gui_input(event, dir))
        
        # Don't draw here, parent draws dots
        add_child(handle)
        _resize_handles[dir] = handle

    _update_handle_positions()
    resized.connect(_update_handle_positions)

func _update_handle_positions() -> void:
    if _resize_handles.is_empty(): return
    
    var r = Rect2(Vector2.ZERO, size)
    r = r.grow(HANDLE_OFFSET)
    
    var positions = {
        Vector2(-1, -1): r.position, # Top-Left
        Vector2(0, -1): Vector2(r.position.x + r.size.x / 2, r.position.y), # Top
        Vector2(1, -1): Vector2(r.end.x, r.position.y), # Top-Right
        
        Vector2(-1, 0): Vector2(r.position.x, r.position.y + r.size.y / 2), # Left
        Vector2(1, 0): Vector2(r.end.x, r.position.y + r.size.y / 2), # Right
        
        Vector2(-1, 1): Vector2(r.position.x, r.end.y), # Bottom-Left
        Vector2(0, 1): Vector2(r.position.x + r.size.x / 2, r.end.y), # Bottom
        Vector2(1, 1): r.end # Bottom-Right
    }
    
    for dir in _resize_handles:
        var handle = _resize_handles[dir]
        var center = positions[dir]
        # Center the handle control on the target point
        handle.position = center - handle.custom_minimum_size / 2

func _create_header_button(icon_name: String, tooltip: String) -> Button:
    var btn = Button.new()
    btn.custom_minimum_size = Vector2(40, 40) # Matched to Node Group (Bigger)
    btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    btn.focus_mode = Control.FOCUS_NONE
    btn.theme_type_variation = "SettingButton"
    btn.add_theme_constant_override("icon_max_width", 20) # Matched to Node Group (Bigger)
    btn.icon = load("res://textures/icons/" + icon_name)
    btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    btn.expand_icon = true
    btn.tooltip_text = tooltip
    btn.pressed.connect(func(): _set_selected(true))
    return btn

func _setup_pickers() -> void:
    # Color Picker
    _color_picker_layer = _create_picker_layer("NoteColorPickerLayer")
    _color_picker = ColorPickerPanelScript.new()
    _color_picker.set_color(note_color)
    _color_picker.color_changed.connect(_on_color_changed)
    _color_picker.color_committed.connect(func(c): _close_picker(_color_picker_layer))
    _color_picker_layer.add_child(_color_picker)
    
    # Pattern Picker
    _pattern_picker_layer = _create_picker_layer("NotePatternPickerLayer")
    _pattern_picker = PatternPickerPanelScript.new()
    _pattern_picker.set_settings(pattern_index, pattern_color, pattern_alpha, pattern_spacing, pattern_thickness)
    _pattern_picker.settings_changed.connect(_on_pattern_settings_changed)
    _pattern_picker.settings_committed.connect(func(idx, c, a, sp, th): _close_picker(_pattern_picker_layer))
    _pattern_picker_layer.add_child(_pattern_picker)

func _create_picker_layer(layer_name: String) -> CanvasLayer:
    var layer = CanvasLayer.new()
    layer.name = layer_name
    layer.layer = 100
    layer.visible = false
    get_tree().root.call_deferred("add_child", layer)
    
    var bg = ColorRect.new()
    bg.color = Color(0, 0, 0, 0.4)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_STOP
    bg.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            _close_picker(layer)
    )
    layer.add_child(bg)
    return layer

func _open_color_picker() -> void:
    if _color_picker_layer:
        _color_picker.set_color(note_color)
        _open_picker(_color_picker_layer, _color_picker)

func _open_pattern_picker() -> void:
    if _pattern_picker_layer:
        _pattern_picker.set_settings(pattern_index, pattern_color, pattern_alpha, pattern_spacing, pattern_thickness)
        _open_picker(_pattern_picker_layer, _pattern_picker)

func _open_picker(layer: CanvasLayer, panel: Control) -> void:
    layer.visible = true
    panel.position = (panel.get_viewport_rect().size - panel.size) / 2
    Sound.play("click2")

func _close_picker(layer: CanvasLayer) -> void:
    if layer:
        layer.visible = false

# === Update Visuals ===
func update_color() -> void:
    if _title_panel:
        _title_panel.self_modulate = note_color
    if _body_panel:
        _body_panel.self_modulate = note_color

func update_pattern() -> void:
    for drawer in pattern_drawers:
        drawer.set_pattern(pattern_index)
        drawer.set_style(pattern_color, pattern_alpha, pattern_spacing, pattern_thickness)


func _set_selected(value: bool) -> void:
    if _is_selected != value:
        # If deselecting, save changes
        if _is_selected and not value:
            _emit_changed()
            
        _is_selected = value
        _update_visual_state()
        queue_redraw()
        
        selection_changed.emit(_is_selected)

func _update_visual_state() -> void:
    # Show/Hide handles based on selection
    for dir in _resize_handles:
        var handle = _resize_handles[dir]
        handle.visible = _is_selected # Hidden handles also block no input

# === Custom Drawing ===
func _draw() -> void:
    if _is_selected: # Only draw when selected
        var r = Rect2(Vector2.ZERO, size)
        
        # Draw Outline
        draw_rect(r, OUTLINE_COLOR, false, OUTLINE_WIDTH)
        
        # Draw Dots (at Control positions + offset to center them)
        for dir in _resize_handles:
            var handle = _resize_handles[dir]
            # Handle position is top-left of control.
            # Center of dot is center of control
            var center = handle.position + handle.custom_minimum_size / 2
            draw_circle(center, HANDLE_SIZE, HANDLE_COLOR)

func _get_cursor_for_dir(dir: Vector2) -> CursorShape:
    if dir == Vector2(-1, -1) or dir == Vector2(1, 1): return CURSOR_FDIAGSIZE
    if dir == Vector2(1, -1) or dir == Vector2(-1, 1): return CURSOR_BDIAGSIZE
    if dir.x != 0: return CURSOR_HSIZE
    if dir.y != 0: return CURSOR_VSIZE
    return CURSOR_ARROW

# === Input Handling ===
# Global input only for click-outside
# Handle selection when clicking the note background (margins)
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _set_selected(true)
        accept_event()

# Global input only for click-outside
func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if _is_selected:
            # Check if click is on any handle.
            var local_mouse = get_local_mouse_position()
            var on_handle = false
            for dir in _resize_handles:
                var handle = _resize_handles[dir]
                if handle.get_rect().has_point(local_mouse):
                    on_handle = true
                    break
            
            if not get_global_rect().has_point(get_global_mouse_position()) and not on_handle:
                _set_selected(false)

# Handle GUI Input (Blocks Camera!)
func _on_handle_gui_input(event: InputEvent, dir: Vector2) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _is_resizing = true
            _resize_dir = dir
            _resize_start_rect = Rect2(position, size)
            _resize_start_mouse = get_global_mouse_position()
            accept_event() # STOP PROPAGATION
        else:
            if _is_resizing:
                _is_resizing = false
                _emit_changed()
                queue_redraw()
                accept_event()
    
    elif event is InputEventMouseMotion:
        if _is_resizing:
            var current_mouse = get_global_mouse_position()
            var delta = current_mouse - _resize_start_mouse
            var new_rect = _resize_start_rect
            
            # Apply X resize
            if _resize_dir.x == 1: # Right
                new_rect.size.x = max(_min_size.x, _resize_start_rect.size.x + delta.x)
            elif _resize_dir.x == -1: # Left
                var max_delta = _resize_start_rect.size.x - _min_size.x
                var actual_delta = min(delta.x, max_delta)
                new_rect.position.x += actual_delta
                new_rect.size.x -= actual_delta
                
            # Apply Y resize
            if _resize_dir.y == 1: # Bottom
                new_rect.size.y = max(_min_size.y, _resize_start_rect.size.y + delta.y)
            elif _resize_dir.y == -1: # Top
                var max_delta = _resize_start_rect.size.y - _min_size.y
                var actual_delta = min(delta.y, max_delta)
                new_rect.position.y += actual_delta
                new_rect.size.y -= actual_delta
            
            position = new_rect.position
            size = new_rect.size
            if not is_nan(position.x) and not is_nan(position.y):
                _update_handle_positions()
                queue_redraw()
            
            accept_event() # CRITICAL: Stop camera

# === Event Handlers ===
func _on_color_changed(new_color: Color) -> void:
    note_color = new_color
    update_color()
    _emit_changed()

func _on_pattern_settings_changed(idx: int, c: Color, a: float, sp: float, th: float) -> void:
    pattern_index = idx
    pattern_color = c
    pattern_alpha = a
    pattern_spacing = sp
    pattern_thickness = th
    update_pattern()
    _emit_changed()

func _start_title_edit() -> void:
    _set_selected(true)
    _is_editing_title = true
    _title_button.visible = false
    _title_edit.visible = true
    _title_edit.text = title_text
    _title_edit.grab_focus()
    _title_edit.select_all()

func _finish_title_edit(new_text: String) -> void:
    title_text = new_text if new_text else "Note"
    _title_button.text = title_text
    _title_button.visible = true
    _title_edit.visible = false
    _is_editing_title = false
    _emit_changed()

func _finish_title_edit_no_arg() -> void:
    _finish_title_edit(_title_edit.text)

func _on_title_panel_input(event: InputEvent) -> void:
    if _is_editing_title: return
    
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _is_dragging = true
            _drag_offset = get_global_mouse_position() - global_position
            drag_started.emit()
            _set_selected(true)
        else:
            if _is_dragging:
                _is_dragging = false
                drag_ended.emit()
                _emit_changed()
        accept_event() # Stop inputs on title
    
    elif event is InputEventMouseMotion and _is_dragging:
        global_position = get_global_mouse_position() - _drag_offset
        _update_handle_positions()
        accept_event()

func _on_title_edit_gui_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_A and event.ctrl_pressed:
            _title_edit.select_all()
            accept_event()

func _on_duplicate_pressed() -> void:
    Sound.play("click2")
    note_duplicated.emit(note_id, position + Vector2(30, 30))

func _on_delete_pressed() -> void:
    Sound.play("close")
    note_deleted.emit(note_id)

func _on_body_changed() -> void:
    body_text = _body_edit.text
    # Optimization: Don't save on every character. 
    # Logic moved to _set_selected(false)

func _on_body_gui_input(event: InputEvent) -> void:
    # Force Enter key to insert newline if default behavior is blocked
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
            _body_edit.insert_text_at_caret("\n")
            accept_event()
        elif event.keycode == KEY_A and event.ctrl_pressed:
            _body_edit.select_all()
            accept_event()

func _emit_changed() -> void:
    note_changed.emit(note_id)

# === Public API ===
func set_note_id(id: String) -> void:
    note_id = id

func set_note_color(color: Color) -> void:
    note_color = color
    update_color()

func set_title(text: String) -> void:
    title_text = text if text else "Note"
    if _title_button: _title_button.text = title_text

func set_body(text: String) -> void:
    body_text = text
    if _body_edit: _body_edit.text = text

func set_manager(manager) -> void:
    _manager = manager

func get_data() -> Dictionary:
    return {
        "id": note_id,
        "position": [position.x, position.y],
        "size": [size.x, size.y],
        "title": title_text,
        "body": body_text,
        "color": note_color.to_html(true),
        "pattern_index": pattern_index,
        "pattern_color": pattern_color.to_html(true),
        "pattern_alpha": pattern_alpha,
        "pattern_spacing": pattern_spacing,
        "pattern_thickness": pattern_thickness
    }

func load_from_data(data: Dictionary) -> void:
    if data.has("id"): note_id = data["id"]
    if data.has("position"): position = Vector2(data["position"][0], data["position"][1])
    if data.has("size"): size = Vector2(data["size"][0], data["size"][1])
    if data.has("title"): set_title(data["title"])
    if data.has("body"): set_body(data["body"])
    if data.has("color"): set_note_color(Color.html(data["color"]))
    
    # Load pattern settings
    if data.has("pattern_index"): pattern_index = data["pattern_index"]
    if data.has("pattern_color"): pattern_color = Color.html(data["pattern_color"])
    if data.has("pattern_alpha"): pattern_alpha = data["pattern_alpha"]
    if data.has("pattern_spacing"): pattern_spacing = data["pattern_spacing"]
    if data.has("pattern_thickness"): pattern_thickness = data["pattern_thickness"]
    
    update_color()
    update_pattern()
