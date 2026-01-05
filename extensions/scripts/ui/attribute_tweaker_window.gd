extends CanvasLayer

const LOG_NAME = "TajsModded:AttributeTweaker"
const ATTRIBUTES_PATH = "res://data/attributes.json"

# UI Components
var _panel: PanelContainer
var _search_bar: LineEdit
var _scroll_container: ScrollContainer
var _attributes_container: VBoxContainer
var _attribute_editors: Dictionary = {} # key -> SpinBox/LineEdit/CheckButton

# Dragging State
var _dragging := false
var _drag_offset := Vector2.ZERO

# Lock State
var _is_locked := true
var _password_input: LineEdit

func _init() -> void:
    name = "AttributeTweakerLayer"
    layer = 100
    
    # Load Game Theme
    var game_theme = load("res://themes/main.tres")
    
    # Main Container
    _panel = PanelContainer.new()
    _panel.name = "TweakerPanel"
    if game_theme:
        _panel.theme = game_theme
    
    # Initial size for password prompt (will expand later)
    _panel.custom_minimum_size = Vector2(400, 200)
    
    # Styling
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.102, 0.125, 0.173, 0.98)
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.27, 0.332, 0.457)
    style.corner_radius_top_left = 16
    style.corner_radius_top_right = 16
    style.corner_radius_bottom_right = 16
    style.corner_radius_bottom_left = 16
    style.shadow_color = Color(0, 0, 0, 0.5)
    style.shadow_size = 10
    _panel.add_theme_stylebox_override("panel", style)
    
    add_child(_panel)

func _ready() -> void:
    if _is_locked:
        _build_lock_ui()
    else:
        _build_tweaker_ui()
    _center_window()

func _center_window() -> void:
    var viewport_size = get_viewport().get_visible_rect().size
    if viewport_size.x == 0: viewport_size = Vector2(1920, 1080)
    _panel.position = (viewport_size - _panel.custom_minimum_size) / 2
    _panel.position = _panel.position.max(Vector2.ZERO)

func _build_lock_ui() -> void:
    for child in _panel.get_children():
        child.queue_free()
        
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 15)
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    # Add some margin
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 30)
    margin.add_theme_constant_override("margin_right", 30)
    margin.add_theme_constant_override("margin_top", 30)
    margin.add_theme_constant_override("margin_bottom", 30)
    _panel.add_child(margin)
    margin.add_child(vbox)
    
    var label = Label.new()
    label.text = "Developer Access"
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 20)
    vbox.add_child(label)
    
    _password_input = LineEdit.new()
    _password_input.placeholder_text = "Password"
    _password_input.secret = true
    _password_input.custom_minimum_size = Vector2(0, 40)
    _password_input.text_submitted.connect(_on_password_submitted)
    vbox.add_child(_password_input)
    
    var btn_hbox = HBoxContainer.new()
    btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    btn_hbox.add_theme_constant_override("separation", 10)
    vbox.add_child(btn_hbox)
    
    var submit_btn = Button.new()
    submit_btn.text = "Unlock"
    submit_btn.custom_minimum_size = Vector2(100, 40)
    submit_btn.pressed.connect(func(): _on_password_submitted(_password_input.text))
    btn_hbox.add_child(submit_btn)
    
    var close_btn = Button.new()
    close_btn.text = "Cancel"
    close_btn.custom_minimum_size = Vector2(80, 40)
    close_btn.pressed.connect(queue_free)
    btn_hbox.add_child(close_btn)
    
    # Allow dragging on the lock screen too
    _panel.gui_input.connect(_on_header_input)

func _on_password_submitted(text: String) -> void:
    var salt = _get_salt()
    var input_hash = (text + salt).sha256_text()
    
    #print("Input: '%s' | Salt: '%s' | Hash: '%s'" % [text, salt, input_hash])
    
    if input_hash == _get_expected_hash():
        _is_locked = false
        _panel.gui_input.disconnect(_on_header_input)
        _build_tweaker_ui()
        _center_window()
    else:
        _password_input.text = ""
        _password_input.placeholder_text = "Incorrect Password"

func _get_salt() -> String:
    return "T@j" + "M0d_" + "S3cur1ty" + "_" + "S@lt"

func _get_expected_hash() -> String:
    var p1 = "6bff2147ee621d3e"
    var p2 = "d175a1b9812e2a1f"
    var p3 = "b3801ba9202bb3cd"
    var p4 = "a89e2b578af89ebb"
    return p1 + p2 + p3 + p4

func _build_tweaker_ui() -> void:
    for child in _panel.get_children():
        child.queue_free()
    
    _panel.custom_minimum_size = Vector2(480, 550)
    
    # Inner Margin
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 20)
    margin.add_theme_constant_override("margin_right", 20)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_bottom", 20)
    margin.mouse_filter = Control.MOUSE_FILTER_PASS
    _panel.add_child(margin)
    
    # Layout
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 15)
    margin.add_child(vbox)
    
    # --- Header (Draggable Area) ---
    var header = PanelContainer.new()
    var header_style = StyleBoxFlat.new()
    header_style.bg_color = Color(0.13, 0.15, 0.2, 1.0)
    header_style.border_width_bottom = 2
    header_style.border_color = Color(0.27, 0.332, 0.457)
    header_style.corner_radius_top_left = 16
    header_style.corner_radius_top_right = 16
    header.add_theme_stylebox_override("panel", header_style)
    header.mouse_default_cursor_shape = Control.CURSOR_MOVE
    header.mouse_filter = Control.MOUSE_FILTER_STOP # Capture input for drag
    
    header.gui_input.connect(_on_header_input)
    
    vbox.add_child(header)
    
    var header_hbox = HBoxContainer.new()
    header_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
    header_hbox.add_theme_constant_override("margin_left", 15)
    header_hbox.add_theme_constant_override("margin_right", 15)
    header_hbox.add_theme_constant_override("margin_top", 10)
    header_hbox.add_theme_constant_override("margin_bottom", 10)
    header.add_child(header_hbox)
    
    var title = Label.new()
    title.text = "Attribute Tweaker"
    title.add_theme_font_size_override("font_size", 24)
    title.add_theme_color_override("font_color", Color(1, 1, 1))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header_hbox.add_child(title)
    
    var close_btn = Button.new()
    close_btn.text = "✕"
    close_btn.custom_minimum_size = Vector2(32, 32)
    close_btn.pressed.connect(queue_free)
    header_hbox.add_child(close_btn)
    
    # --- Search ---
    _search_bar = LineEdit.new()
    _search_bar.placeholder_text = "Search attributes..."
    _search_bar.custom_minimum_size = Vector2(0, 40)
    _search_bar.text_changed.connect(_on_search_text_changed)
    vbox.add_child(_search_bar)
    
    # --- List ---
    _scroll_container = ScrollContainer.new()
    _scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    
    # Inner list background (darker slot)
    var list_style = StyleBoxFlat.new()
    list_style.bg_color = Color(0.06, 0.07, 0.1, 1.0)
    list_style.corner_radius_top_left = 8
    list_style.corner_radius_top_right = 8
    list_style.corner_radius_bottom_right = 8
    list_style.corner_radius_bottom_left = 8
    list_style.border_width_left = 1
    list_style.border_width_top = 1
    list_style.border_width_right = 1
    list_style.border_width_bottom = 1
    list_style.border_color = Color(0.2, 0.25, 0.35)
    _scroll_container.add_theme_stylebox_override("panel", list_style)
    
    vbox.add_child(_scroll_container)
    
    _attributes_container = VBoxContainer.new()
    _attributes_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _attributes_container.add_theme_constant_override("separation", 4)
    _scroll_container.add_child(_attributes_container)
    
    # --- Footer ---
    var footer = VBoxContainer.new()
    footer.add_theme_constant_override("separation", 12)
    vbox.add_child(footer)
    
    var row1 = HBoxContainer.new()
    row1.alignment = BoxContainer.ALIGNMENT_CENTER
    row1.add_theme_constant_override("separation", 15)
    footer.add_child(row1)
    
    var reset_all_btn = Button.new()
    reset_all_btn.text = "Reset Defaults"
    reset_all_btn.modulate = Color(1, 0.7, 0.7) # Slight reddish tint
    reset_all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    reset_all_btn.custom_minimum_size = Vector2(0, 40)
    reset_all_btn.pressed.connect(_reset_to_defaults)
    row1.add_child(reset_all_btn)
    
    var refresh_btn = Button.new()
    refresh_btn.text = "Refresh Values"
    refresh_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    refresh_btn.custom_minimum_size = Vector2(0, 40)
    refresh_btn.pressed.connect(_populate_list)
    row1.add_child(refresh_btn)
    
    var apply_btn = Button.new()
    apply_btn.text = "Apply Changes"
    apply_btn.modulate = Color(0.7, 1, 0.7) # Slight greenish tint
    apply_btn.add_theme_font_size_override("font_size", 20)
    apply_btn.custom_minimum_size = Vector2(0, 50)
    apply_btn.pressed.connect(_apply_changes)
    footer.add_child(apply_btn)
    
    _populate_list()

func _on_header_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _dragging = true
                _drag_offset = get_viewport().get_mouse_position() - _panel.position
            else:
                _dragging = false
    
    if event is InputEventMouseMotion and _dragging:
        _panel.position = get_viewport().get_mouse_position() - _drag_offset

func _populate_list() -> void:
    for child in _attributes_container.get_children():
        child.queue_free()
    _attribute_editors.clear()
    
    if not "attributes" in Data:
        var err = Label.new()
        err.text = "Error: Data.attributes not found!"
        err.add_theme_color_override("font_color", Color.RED)
        _attributes_container.add_child(err)
        return
        
    var keys = Data.attributes.keys()
    keys.sort()
    
    for key in keys:
        var attr_data = Data.attributes[key]
        var val = attr_data.get("default", 0)
        
        # Row Panel
        var row = PanelContainer.new()
        # Alternating colors or just simple rows? Simple rows for now.
        var row_style = StyleBoxFlat.new()
        row_style.bg_color = Color(1, 1, 1, 0.02) # Very faint highlight
        row_style.corner_radius_top_left = 4
        row_style.corner_radius_top_right = 4
        row_style.corner_radius_bottom_right = 4
        row_style.corner_radius_bottom_left = 4
        # Add margins via style content margin or properties?
        # Style content margin is better for PanelContainer
        row_style.content_margin_left = 10
        row_style.content_margin_right = 10
        row_style.content_margin_top = 4
        row_style.content_margin_bottom = 4
        row.add_theme_stylebox_override("panel", row_style)
        
        var row_hbox = HBoxContainer.new()
        row_hbox.add_theme_constant_override("separation", 10)
        row.add_child(row_hbox)
        
        var label = Label.new()
        label.text = key
        label.custom_minimum_size = Vector2(250, 0)
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        row_hbox.add_child(label)
        
        var editor: Control
        if typeof(val) == TYPE_BOOL:
            editor = CheckButton.new()
            editor.button_pressed = val
            editor.text = "On" if val else "Off"
            editor.toggled.connect(func(v): editor.text = "On" if v else "Off")
        elif typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT:
            editor = SpinBox.new()
            editor.min_value = -1e12
            editor.max_value = 1e12
            editor.step = 0.001 if typeof(val) == TYPE_FLOAT else 1
            editor.value = val
            editor.custom_minimum_size = Vector2(140, 0)
            editor.allow_greater = true
            editor.allow_lesser = true
            var line_edit = editor.get_line_edit()
            if line_edit:
                line_edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
        else:
            editor = Label.new()
            editor.text = str(val)
        
        row_hbox.add_child(editor)
        
        if editor is SpinBox or editor is CheckButton:
            _attribute_editors[key] = editor
        
        _attributes_container.add_child(row)
        
    if not _search_bar.text.is_empty():
        _on_search_text_changed(_search_bar.text)

func _on_search_text_changed(new_text: String) -> void:
    new_text = new_text.to_lower()
    for child in _attributes_container.get_children():
        if child is PanelContainer:
            var hbox = child.get_child(0)
            if hbox and hbox.get_child_count() > 0:
                var label = hbox.get_child(0) as Label
                if label:
                    var key = label.text.to_lower()
                    child.visible = new_text.is_empty() or key.contains(new_text)

func _apply_changes() -> void:
    if not "attributes" in Data: return
    var count = 0
    for key in _attribute_editors:
        var editor = _attribute_editors[key]
        var new_val
        if editor is SpinBox: new_val = editor.value
        elif editor is CheckButton: new_val = editor.button_pressed
        
        if Data.attributes.has(key):
            Data.attributes[key]["default"] = new_val
            count += 1
                
    Signals.notify.emit("check", "Updated %s attributes" % count)
    
    # Functionality Fix: Force refresh
    if Attributes.has_method("init_attributes"):
        Attributes.init_attributes()
        # Optional: verify if init_attributes emits a signal or we need to notify manually.
        # Attributes.gd just re-sets values.
        # Signals.notify.emit("check", "Attributes re-initialized")
    else:
        Signals.notify.emit("error", "Could not refresh attributes")

func _reset_to_defaults() -> void:
    if not FileAccess.file_exists(ATTRIBUTES_PATH):
        Signals.notify.emit("error", "attributes.json missing")
        return
    var file = FileAccess.open(ATTRIBUTES_PATH, FileAccess.READ)
    if not file:
        Signals.notify.emit("error", "Cannot open attributes.json")
        return
    var json = JSON.new()
    if json.parse(file.get_as_text()) != OK:
        Signals.notify.emit("error", "JSON Error")
        return
    var defaults = json.get_data()
    var count = 0
    for key in defaults:
        if Data.attributes.has(key):
            var def_val = defaults[key].get("default")
            if def_val != null:
                Data.attributes[key]["default"] = def_val
                count += 1
                
    Signals.notify.emit("exclamation", "Reset %s attributes" % count)
    
    # Functionality Fix: Force refresh
    if Attributes.has_method("init_attributes"):
        Attributes.init_attributes()
    
    _populate_list()
