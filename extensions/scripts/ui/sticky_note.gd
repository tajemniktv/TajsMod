# ==============================================================================
# Taj's Mod - Upload Labs
# Sticky Note - Draggable, editable text notes for canvas labeling
# Styled to match Group Node aesthetic
# Author: TajemnikTV
# ==============================================================================
extends Control
class_name TajsStickyNote

const LOG_NAME = "TajsModded:StickyNote"

# Preload color picker
const ColorPickerPanelScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/ui/color_picker_panel.gd")

# Signals for manager synchronization
signal note_changed(note_id: String)
signal note_deleted(note_id: String)
signal note_duplicated(note_id: String, new_position: Vector2)
signal drag_started()
signal drag_ended()

# Note properties
var note_id: String = ""
var title_text: String = "Note"
var body_text: String = ""
var note_color: Color = Color("1a202c") # Match default group color

# UI References
var _title_panel: Panel
var _body_panel: Panel
var _title_button: Button
var _title_edit: LineEdit
var _body_edit: TextEdit
var _color_btn: Button
var _duplicate_btn: Button
var _delete_btn: Button

# Color picker overlay
var _color_picker_layer: CanvasLayer = null
var _color_picker: Control = null

# State
var _is_dragging := false
var _drag_offset := Vector2.ZERO
var _is_resizing := false
var _resize_start_size := Vector2.ZERO
var _resize_start_mouse := Vector2.ZERO
var _min_size := Vector2(150, 80)
var _is_editing_title := false

# Manager reference
var _manager = null

func _init() -> void:
    custom_minimum_size = Vector2(200, 100)
    size = Vector2(280, 140)
    mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
    _build_ui()
    _setup_color_picker()
    
    # Apply initial content
    if _title_button:
        _title_button.text = title_text if title_text else "Note"
    if _body_edit:
        _body_edit.text = body_text
    
    z_index = 10

func _build_ui() -> void:
    # === TITLE PANEL (like Group Node) ===
    _title_panel = Panel.new()
    _title_panel.name = "TitlePanel"
    _title_panel.anchor_left = 0
    _title_panel.anchor_top = 0
    _title_panel.anchor_right = 1
    _title_panel.anchor_bottom = 0
    _title_panel.offset_bottom = 40
    _title_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _title_panel.gui_input.connect(_on_title_panel_input)
    
    var title_style = StyleBoxFlat.new()
    title_style.bg_color = Color(0.18, 0.20, 0.26, 0.98)
    title_style.set_corner_radius_all(6)
    title_style.set_border_width_all(1)
    title_style.border_color = Color(0.35, 0.38, 0.45, 0.9)
    _title_panel.add_theme_stylebox_override("panel", title_style)
    add_child(_title_panel)
    
    # Title container (HBoxContainer like Group Node)
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
    
    # Note icon (📝)
    var note_icon = Label.new()
    note_icon.text = "📝"
    note_icon.add_theme_font_size_override("font_size", 18)
    note_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    note_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title_container.add_child(note_icon)
    
    # Title button (click to edit, like Group Node)
    _title_button = Button.new()
    _title_button.name = "TitleButton"
    _title_button.text = "Note"
    _title_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _title_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    _title_button.flat = true
    _title_button.add_theme_font_size_override("font_size", 16)
    _title_button.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
    _title_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
    _title_button.mouse_default_cursor_shape = Control.CURSOR_IBEAM
    _title_button.pressed.connect(_start_title_edit)
    title_container.add_child(_title_button)
    
    # Title LineEdit (hidden by default, shown when editing)
    _title_edit = LineEdit.new()
    _title_edit.name = "TitleEdit"
    _title_edit.visible = false
    _title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _title_edit.add_theme_font_size_override("font_size", 16)
    _title_edit.context_menu_enabled = false
    _title_edit.text_submitted.connect(_finish_title_edit)
    _title_edit.focus_exited.connect(_finish_title_edit_no_arg)
    title_container.add_child(_title_edit)
    
    # Color button
    _color_btn = Button.new()
    _color_btn.name = "ColorButton"
    _color_btn.custom_minimum_size = Vector2(32, 32)
    _color_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _color_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _color_btn.focus_mode = Control.FOCUS_NONE
    _color_btn.theme_type_variation = "SettingButton"
    _color_btn.add_theme_constant_override("icon_max_width", 18)
    _color_btn.icon = load("res://textures/icons/contrast.png")
    _color_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _color_btn.expand_icon = true
    _color_btn.tooltip_text = "Change Color"
    _color_btn.pressed.connect(_open_color_picker)
    title_container.add_child(_color_btn)
    
    # Duplicate button
    _duplicate_btn = Button.new()
    _duplicate_btn.name = "DuplicateButton"
    _duplicate_btn.custom_minimum_size = Vector2(32, 32)
    _duplicate_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _duplicate_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _duplicate_btn.focus_mode = Control.FOCUS_NONE
    _duplicate_btn.theme_type_variation = "SettingButton"
    _duplicate_btn.add_theme_constant_override("icon_max_width", 18)
    _duplicate_btn.icon = load("res://textures/icons/plus.png")
    _duplicate_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _duplicate_btn.expand_icon = true
    _duplicate_btn.tooltip_text = "Duplicate Note"
    _duplicate_btn.pressed.connect(_on_duplicate_pressed)
    title_container.add_child(_duplicate_btn)
    
    # Delete button
    _delete_btn = Button.new()
    _delete_btn.name = "DeleteButton"
    _delete_btn.custom_minimum_size = Vector2(32, 32)
    _delete_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _delete_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _delete_btn.focus_mode = Control.FOCUS_NONE
    _delete_btn.theme_type_variation = "SettingButton"
    _delete_btn.add_theme_constant_override("icon_max_width", 18)
    _delete_btn.icon = load("res://textures/icons/trash_bin.png")
    _delete_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _delete_btn.expand_icon = true
    _delete_btn.tooltip_text = "Delete Note"
    _delete_btn.pressed.connect(_on_delete_pressed)
    title_container.add_child(_delete_btn)
    
    # === BODY PANEL ===
    _body_panel = Panel.new()
    _body_panel.name = "BodyPanel"
    _body_panel.anchor_left = 0
    _body_panel.anchor_top = 0
    _body_panel.anchor_right = 1
    _body_panel.anchor_bottom = 1
    _body_panel.offset_top = 40
    _body_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    var body_style = StyleBoxFlat.new()
    body_style.bg_color = Color(0.14, 0.16, 0.20, 0.95)
    body_style.set_corner_radius_all(6)
    body_style.set_border_width_all(1)
    body_style.border_color = Color(0.30, 0.32, 0.38, 0.85)
    _body_panel.add_theme_stylebox_override("panel", body_style)
    add_child(_body_panel)
    
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
    _body_edit.offset_bottom = -16 # Space for resize handle
    _body_edit.add_theme_font_size_override("font_size", 14)
    _body_edit.add_theme_color_override("font_placeholder_color", Color(0.5, 0.5, 0.55, 0.6))
    _body_edit.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
    _body_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    _body_edit.context_menu_enabled = false
    
    var edit_style = StyleBoxFlat.new()
    edit_style.bg_color = Color(0, 0, 0, 0.15)
    edit_style.set_corner_radius_all(4)
    _body_edit.add_theme_stylebox_override("normal", edit_style)
    _body_edit.add_theme_stylebox_override("focus", edit_style)
    
    _body_edit.text_changed.connect(_on_body_changed)
    _body_panel.add_child(_body_edit)
    
    # Resize handle (bottom-right)
    var resize_handle = Control.new()
    resize_handle.name = "ResizeHandle"
    resize_handle.anchor_left = 1.0
    resize_handle.anchor_top = 1.0
    resize_handle.anchor_right = 1.0
    resize_handle.anchor_bottom = 1.0
    resize_handle.offset_left = -16
    resize_handle.offset_top = -16
    resize_handle.mouse_filter = Control.MOUSE_FILTER_STOP
    resize_handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
    resize_handle.gui_input.connect(_on_resize_input)
    add_child(resize_handle)
    
    var resize_icon = Label.new()
    resize_icon.text = "◢"
    resize_icon.add_theme_font_size_override("font_size", 12)
    resize_icon.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.5))
    resize_icon.position = Vector2(3, 0)
    resize_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    resize_handle.add_child(resize_icon)

func _setup_color_picker() -> void:
    _color_picker_layer = CanvasLayer.new()
    _color_picker_layer.name = "NoteColorPickerLayer"
    _color_picker_layer.layer = 100
    _color_picker_layer.visible = false
    get_tree().root.call_deferred("add_child", _color_picker_layer)
    
    var bg_overlay = ColorRect.new()
    bg_overlay.name = "BackgroundOverlay"
    bg_overlay.color = Color(0, 0, 0, 0.4)
    bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    bg_overlay.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            _close_color_picker()
    )
    _color_picker_layer.add_child(bg_overlay)
    
    _color_picker = ColorPickerPanelScript.new()
    _color_picker.name = "ColorPickerPanel"
    _color_picker.set_color(note_color)
    _color_picker.color_changed.connect(_on_color_changed)
    _color_picker.color_committed.connect(func(c): _close_color_picker())
    _color_picker_layer.add_child(_color_picker)

func _open_color_picker() -> void:
    if _color_picker_layer:
        _color_picker.set_color(note_color)
        _color_picker_layer.visible = true
        _color_picker.position = (_color_picker.get_viewport_rect().size - _color_picker.size) / 2
        Sound.play("click2")

func _close_color_picker() -> void:
    if _color_picker_layer:
        _color_picker_layer.visible = false

func _on_color_changed(new_color: Color) -> void:
    set_note_color(new_color)
    _emit_changed()

# === Title Editing ===
func _start_title_edit() -> void:
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

# === Drag & Resize ===
func _on_title_panel_input(event: InputEvent) -> void:
    if _is_editing_title:
        return
    
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _is_dragging = true
            _drag_offset = get_global_mouse_position() - global_position
            drag_started.emit()
        else:
            if _is_dragging:
                _is_dragging = false
                drag_ended.emit()
                _emit_changed()
        accept_event()

func _on_resize_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _is_resizing = true
            _resize_start_size = size
            _resize_start_mouse = get_global_mouse_position()
        else:
            if _is_resizing:
                _is_resizing = false
                _emit_changed()
        accept_event()

func _input(event: InputEvent) -> void:
    if _is_dragging and event is InputEventMouseMotion:
        global_position = get_global_mouse_position() - _drag_offset
        get_viewport().set_input_as_handled()
    
    if _is_resizing and event is InputEventMouseMotion:
        var delta = get_global_mouse_position() - _resize_start_mouse
        var new_size = _resize_start_size + delta
        size = Vector2(max(_min_size.x, new_size.x), max(_min_size.y, new_size.y))
        get_viewport().set_input_as_handled()

# === Actions ===
func _on_duplicate_pressed() -> void:
    Sound.play("click2")
    note_duplicated.emit(note_id, position + Vector2(30, 30))

func _on_delete_pressed() -> void:
    Sound.play("close")
    note_deleted.emit(note_id)

func _on_body_changed() -> void:
    body_text = _body_edit.text
    _emit_changed()

func _emit_changed() -> void:
    note_changed.emit(note_id)

# === Public API ===
func set_note_id(id: String) -> void:
    note_id = id

func set_note_color(color: Color) -> void:
    note_color = color
    # Apply color by modifying panel background colors
    if _title_panel:
        var style = StyleBoxFlat.new()
        style.bg_color = Color(color.r * 0.7 + 0.1, color.g * 0.7 + 0.1, color.b * 0.7 + 0.1, 0.98)
        style.set_corner_radius_all(6)
        style.set_border_width_all(1)
        style.border_color = Color(color.r + 0.2, color.g + 0.2, color.b + 0.2, 0.9)
        _title_panel.add_theme_stylebox_override("panel", style)
    if _body_panel:
        var style = StyleBoxFlat.new()
        style.bg_color = Color(color.r * 0.5 + 0.08, color.g * 0.5 + 0.08, color.b * 0.5 + 0.08, 0.95)
        style.set_corner_radius_all(6)
        style.set_border_width_all(1)
        style.border_color = Color(color.r + 0.15, color.g + 0.15, color.b + 0.15, 0.85)
        _body_panel.add_theme_stylebox_override("panel", style)

func set_title(text: String) -> void:
    title_text = text if text else "Note"
    if _title_button:
        _title_button.text = title_text

func set_body(text: String) -> void:
    body_text = text
    if _body_edit:
        _body_edit.text = text

func get_data() -> Dictionary:
    return {
        "id": note_id,
        "position": [position.x, position.y],
        "size": [size.x, size.y],
        "title": title_text,
        "body": body_text,
        "color": note_color.to_html(true)
    }

func load_from_data(data: Dictionary) -> void:
    if data.has("id"):
        note_id = data["id"]
    if data.has("position") and data["position"] is Array:
        position = Vector2(data["position"][0], data["position"][1])
    if data.has("size") and data["size"] is Array:
        size = Vector2(data["size"][0], data["size"][1])
    if data.has("title"):
        set_title(data["title"])
    if data.has("body"):
        set_body(data["body"])
    if data.has("color"):
        set_note_color(Color.html(data["color"]))

func set_manager(manager) -> void:
    _manager = manager
