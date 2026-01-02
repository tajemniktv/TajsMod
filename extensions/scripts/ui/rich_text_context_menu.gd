# ==============================================================================
# Taj's Mod - Upload Labs
# Rich Text Context Menu - Custom styled context menu for text formatting
# Author: TajemnikTV
# ==============================================================================
extends PanelContainer
class_name RichTextContextMenu

const LOG_NAME = "TajsModded:ContextMenu"
const ColorPickerPanelScript = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/ui/color_picker_panel.gd")

signal format_requested(property: String, value)
signal clear_format_requested()
signal closed()

# UI Constants - Match game theme
const MENU_MIN_WIDTH = 180
const ITEM_HEIGHT = 32
const SEPARATOR_HEIGHT = 8
const ICON_SIZE = 16
const PADDING = 8

# Color presets for text color submenu
const COLOR_PRESETS = [
    Color.WHITE,
    Color.BLACK,
    Color("#ff6b6b"), # Soft red
    Color("#51cf66"), # Soft green
    Color("#339af0"), # Soft blue
    Color("#fcc419"), # Soft yellow
    Color("#ff922b"), # Orange
    Color("#cc5de8"), # Purple
]

# Internal state
var _items_container: VBoxContainer
var _color_submenu: Control = null
var _has_selection: bool = false
var _current_submenu: Control = null

# ColorPickerPanel reference for "Custom..." color
var _color_picker_layer: CanvasLayer = null
var _color_picker: Control = null


func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP


var _initialized: bool = false

func _ensure_initialized() -> void:
    if _initialized:
        return
    _initialized = true
    ModLoaderLog.debug("Building context menu structure", LOG_NAME)
    _setup_panel_style()
    _build_menu()
    _setup_color_picker()
    visible = false


func _ready() -> void:
    _ensure_initialized()
    set_process_input(true)


func _setup_panel_style() -> void:
    # Match game theme: dark blue-gray with blue border
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.0862745, 0.101961, 0.137255, 0.98) # Game bg color, slightly more opaque
    style.border_color = Color(0.270064, 0.332386, 0.457031, 1.0) # Game border color
    style.set_border_width_all(2)
    style.set_corner_radius_all(8)
    style.set_content_margin_all(PADDING)
    style.shadow_color = Color(0, 0, 0, 0.4)
    style.shadow_size = 8
    add_theme_stylebox_override("panel", style)


func _build_menu() -> void:
    _items_container = VBoxContainer.new()
    _items_container.add_theme_constant_override("separation", 2)
    add_child(_items_container)
    
    # Formatting toggles
    _add_menu_item("Bold", "bold", KEY_B)
    _add_menu_item("Italic", "italic", KEY_I)
    _add_menu_item("Underline", "underline", KEY_U)
    
    _add_separator()
    
    # Color submenu trigger
    _add_submenu_item("Text Color", "_open_color_submenu")
    
    # Size submenu trigger
    _add_submenu_item("Font Size", "_open_size_submenu")
    
    _add_separator()
    
    # Clear formatting
    _add_menu_item("Clear Formatting", "clear", KEY_NONE)


func _add_menu_item(label_text: String, action: String, shortcut_key: Key = KEY_NONE) -> Button:
    var btn = Button.new()
    btn.text = label_text
    btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
    btn.custom_minimum_size = Vector2(MENU_MIN_WIDTH, ITEM_HEIGHT)
    btn.flat = true
    btn.focus_mode = Control.FOCUS_NONE
    
    # Styling
    _apply_button_style(btn)
    
    # Store action in metadata
    btn.set_meta("action", action)
    
    # Add shortcut hint if applicable
    if shortcut_key != KEY_NONE:
        var shortcut_label = Label.new()
        shortcut_label.text = "Ctrl+" + char(shortcut_key)
        shortcut_label.add_theme_font_size_override("font_size", 11)
        shortcut_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
        shortcut_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        shortcut_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        # We'll use a custom approach since Button doesn't have easy right-aligned text
        btn.text = label_text + "        Ctrl+" + char(shortcut_key)
    
    btn.pressed.connect(_on_item_pressed.bind(action))
    
    _items_container.add_child(btn)
    return btn


func _add_submenu_item(label_text: String, callback: String) -> Button:
    var btn = Button.new()
    btn.text = label_text + "  ▶"
    btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
    btn.custom_minimum_size = Vector2(MENU_MIN_WIDTH, ITEM_HEIGHT)
    btn.flat = true
    btn.focus_mode = Control.FOCUS_NONE
    
    _apply_button_style(btn)
    
    btn.set_meta("submenu_callback", callback)
    btn.mouse_entered.connect(Callable(self, callback).bind(btn))
    
    _items_container.add_child(btn)
    return btn


func _add_separator() -> void:
    var sep = HSeparator.new()
    sep.custom_minimum_size.y = SEPARATOR_HEIGHT
    sep.add_theme_color_override("separation", Color(0.3, 0.3, 0.4, 0.5))
    _items_container.add_child(sep)


func _apply_button_style(btn: Button) -> void:
    btn.add_theme_font_size_override("font_size", 13)
    btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
    btn.add_theme_color_override("font_hover_color", Color.WHITE)
    btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))
    
    # Hover style
    var hover_style = StyleBoxFlat.new()
    hover_style.bg_color = Color(0.2, 0.25, 0.35, 0.8)
    hover_style.set_corner_radius_all(4)
    btn.add_theme_stylebox_override("hover", hover_style)
    
    # Normal style (transparent)
    var normal_style = StyleBoxEmpty.new()
    btn.add_theme_stylebox_override("normal", normal_style)
    btn.add_theme_stylebox_override("pressed", hover_style)
    btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _setup_color_picker() -> void:
    # Create color picker layer for "Custom..." option
    _color_picker_layer = CanvasLayer.new()
    _color_picker_layer.name = "ContextMenuColorPickerLayer"
    _color_picker_layer.layer = 110 # Above context menu
    _color_picker_layer.visible = false
    
    # Add background overlay
    var bg = ColorRect.new()
    bg.color = Color(0, 0, 0, 0.4)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_STOP
    bg.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            _close_color_picker()
    )
    _color_picker_layer.add_child(bg)
    
    # Create color picker
    _color_picker = ColorPickerPanelScript.new()
    _color_picker.color_changed.connect(_on_custom_color_selected)
    _color_picker.color_committed.connect(func(c): _close_color_picker())
    _color_picker_layer.add_child(_color_picker)


func _open_color_submenu(trigger_btn: Button) -> void:
    _close_current_submenu()
    
    var submenu = PanelContainer.new()
    _apply_submenu_style(submenu)
    
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 4)
    submenu.add_child(vbox)
    
    # Color grid
    var grid = GridContainer.new()
    grid.columns = 4
    grid.add_theme_constant_override("h_separation", 4)
    grid.add_theme_constant_override("v_separation", 4)
    vbox.add_child(grid)
    
    for color in COLOR_PRESETS:
        var swatch = Button.new()
        swatch.custom_minimum_size = Vector2(28, 28)
        swatch.flat = true
        swatch.focus_mode = Control.FOCUS_NONE
        
        var swatch_style = StyleBoxFlat.new()
        swatch_style.bg_color = color
        swatch_style.set_corner_radius_all(4)
        swatch_style.border_color = Color(0.4, 0.4, 0.4, 0.8)
        swatch_style.set_border_width_all(1)
        swatch.add_theme_stylebox_override("normal", swatch_style)
        
        var hover_style = swatch_style.duplicate()
        hover_style.border_color = Color.WHITE
        hover_style.set_border_width_all(2)
        swatch.add_theme_stylebox_override("hover", hover_style)
        swatch.add_theme_stylebox_override("pressed", hover_style)
        
        swatch.pressed.connect(_on_color_selected.bind(color))
        grid.add_child(swatch)
    
    # Custom button
    var custom_btn = Button.new()
    custom_btn.text = "Custom..."
    custom_btn.flat = true
    custom_btn.focus_mode = Control.FOCUS_NONE
    custom_btn.custom_minimum_size.y = ITEM_HEIGHT
    _apply_button_style(custom_btn)
    custom_btn.pressed.connect(_open_color_picker)
    vbox.add_child(custom_btn)
    
    # Position submenu
    add_child(submenu)
    submenu.position = Vector2(size.x - 4, trigger_btn.position.y)
    
    _current_submenu = submenu
    _color_submenu = submenu


func _open_size_submenu(trigger_btn: Button) -> void:
    _close_current_submenu()
    
    var submenu = PanelContainer.new()
    _apply_submenu_style(submenu)
    
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 2)
    submenu.add_child(vbox)
    
    var sizes = [
        ["Small", -1],
        ["Normal", 0],
        ["Large", 1]
    ]
    
    for size_data in sizes:
        var btn = Button.new()
        btn.text = size_data[0]
        btn.flat = true
        btn.focus_mode = Control.FOCUS_NONE
        btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
        btn.custom_minimum_size = Vector2(100, ITEM_HEIGHT)
        _apply_button_style(btn)
        btn.pressed.connect(_on_size_selected.bind(size_data[1]))
        vbox.add_child(btn)
    
    # Position submenu
    add_child(submenu)
    submenu.position = Vector2(size.x - 4, trigger_btn.position.y)
    
    _current_submenu = submenu


func _apply_submenu_style(submenu: PanelContainer) -> void:
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.0862745, 0.101961, 0.137255, 0.98)
    style.border_color = Color(0.270064, 0.332386, 0.457031, 1.0)
    style.set_border_width_all(2)
    style.set_corner_radius_all(8)
    style.set_content_margin_all(PADDING)
    style.shadow_color = Color(0, 0, 0, 0.3)
    style.shadow_size = 4
    submenu.add_theme_stylebox_override("panel", style)


func _close_current_submenu() -> void:
    if _current_submenu and is_instance_valid(_current_submenu):
        _current_submenu.queue_free()
    _current_submenu = null
    _color_submenu = null


func _open_color_picker() -> void:
    if not _color_picker_layer.is_inside_tree():
        var tree = get_tree()
        if tree:
            tree.root.add_child(_color_picker_layer)
        else:
            return
    
    _color_picker_layer.visible = true
    _color_picker.position = (_color_picker.get_viewport_rect().size - _color_picker.size) / 2


func _close_color_picker() -> void:
    if _color_picker_layer:
        _color_picker_layer.visible = false


# =============================================================================
# PUBLIC API
# =============================================================================

## Show the context menu at the given global position
## tree_ref: SceneTree reference (needed because menu may not be in tree yet)
func show_at(global_pos: Vector2, has_selection: bool = false, tree_ref: SceneTree = null) -> void:
    _ensure_initialized()
    
    _has_selection = has_selection
    _close_current_submenu()
    
    # Ensure we're in the tree
    if not is_inside_tree():
        if tree_ref:
            tree_ref.root.add_child(self)
        else:
            push_error("RichTextContextMenu: Cannot show menu - not in tree and no tree_ref provided")
            return
    
    # Update item states
    _update_item_states()
    
    # Clamp to viewport
    var viewport_size = get_viewport_rect().size
    var menu_size = custom_minimum_size if size == Vector2.ZERO else size
    
    var pos = global_pos
    if pos.x + menu_size.x > viewport_size.x:
        pos.x = viewport_size.x - menu_size.x - 8
    if pos.y + menu_size.y > viewport_size.y:
        pos.y = viewport_size.y - menu_size.y - 8
    
    pos.x = maxf(pos.x, 8)
    pos.y = maxf(pos.y, 8)
    
    # Use position (not global_position) since we're in a CanvasLayer
    position = pos
    visible = true
    z_index = 1000
    
    Sound.play("click2")


func hide_menu() -> void:
    _close_current_submenu()
    _close_color_picker()
    visible = false
    closed.emit()


func _update_item_states() -> void:
    for child in _items_container.get_children():
        if child is Button:
            var action = child.get_meta("action", "")
            # Disable formatting items if no selection
            if action in ["bold", "italic", "underline", "color", "font_size", "clear"]:
                child.disabled = not _has_selection
            
            # Submenu items
            if child.has_meta("submenu_callback"):
                child.disabled = not _has_selection


# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
    if not visible:
        return
    
    # Close on ESC
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        hide_menu()
        get_viewport().set_input_as_handled()
        return
    
    # Close on click outside
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var local_pos = get_local_mouse_position()
        var in_menu = Rect2(Vector2.ZERO, size).has_point(local_pos)
        
        # Check if in submenu
        var in_submenu = false
        if _current_submenu and is_instance_valid(_current_submenu):
            var submenu_local = _current_submenu.get_local_mouse_position()
            in_submenu = Rect2(Vector2.ZERO, _current_submenu.size).has_point(submenu_local)
        
        if not in_menu and not in_submenu:
            hide_menu()
            get_viewport().set_input_as_handled()


# =============================================================================
# CALLBACKS
# =============================================================================

func _on_item_pressed(action: String) -> void:
    Sound.play("click2")
    
    if action == "clear":
        clear_format_requested.emit()
    else:
        # Toggle actions pass null to let model determine state
        format_requested.emit(action, null)
    
    hide_menu()


func _on_color_selected(color: Color) -> void:
    Sound.play("click2")
    format_requested.emit("color", color)
    hide_menu()


func _on_custom_color_selected(color: Color) -> void:
    format_requested.emit("color", color)


func _on_size_selected(size_value: int) -> void:
    Sound.play("click2")
    format_requested.emit("font_size", size_value)
    hide_menu()


# =============================================================================
# CLEANUP
# =============================================================================

func _exit_tree() -> void:
    _close_current_submenu()
    if _color_picker_layer and is_instance_valid(_color_picker_layer):
        _color_picker_layer.queue_free()
