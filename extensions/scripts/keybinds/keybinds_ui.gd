# ==============================================================================
# Taj's Mod - Upload Labs
# Keybinds UI - Settings panel for viewing and rebinding keybinds
# Author: TajemnikTV
# ==============================================================================
class_name TajsModKeybindsUI
extends RefCounted

const LOG_NAME = "TajsModded:KeybindsUI"

# References
var _manager # TajsModKeybindsManager
var _ui # TajsModSettingsUI
var _container: VBoxContainer
var _rebind_overlay: CanvasLayer
var _rebind_bind_id: String = ""
var _item_rows: Dictionary = {} # bind_id -> row Control

# Colors
const COLOR_CONFLICT = Color(1.0, 0.6, 0.4, 1.0)
const COLOR_EXTERNAL = Color(0.6, 0.8, 1.0, 1.0)
const COLOR_CATEGORY = Color(0.8, 0.8, 0.8, 1.0)


func setup(manager, ui, container: VBoxContainer) -> void:
    _manager = manager
    _ui = ui
    _container = container
    
    # Connect to manager signals
    _manager.binding_changed.connect(_on_binding_changed)
    _manager.conflict_detected.connect(_on_conflict_detected)
    
    # Build initial UI
    _build_ui()


func _build_ui() -> void:
    # Clear existing
    for child in _container.get_children():
        child.queue_free()
    _item_rows.clear()
    
    # Get conflicts for highlighting
    var conflicts = _manager.get_conflicts()
    var conflicting_ids: Array[String] = []
    for conflict in conflicts:
        if conflict.bind_id1 not in conflicting_ids:
            conflicting_ids.append(conflict.bind_id1)
        if conflict.bind_id2 not in conflicting_ids:
            conflicting_ids.append(conflict.bind_id2)
    
    # Build by category
    var categories = _manager.get_categories()
    
    for category in categories:
        _add_category_header(category)
        
        var binds = _manager.get_binds_by_category(category)
        for bind in binds:
            var has_conflict = bind.id in conflicting_ids
            _add_bind_row(bind, has_conflict)
    
    # Add Reset All button at bottom
    _add_reset_all_button()


func _add_category_header(category: String) -> void:
    var header = Label.new()
    header.text = category
    header.add_theme_font_size_override("font_size", 26)
    header.add_theme_color_override("font_color", COLOR_CATEGORY)
    
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_top", 15)
    margin.add_theme_constant_override("margin_bottom", 5)
    margin.add_child(header)
    
    _container.add_child(margin)


func _add_bind_row(bind: Dictionary, has_conflict: bool) -> void:
    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    
    # Name column (with tooltip for description)
    var name_label = Label.new()
    var display_name = bind.display_name
    
    # Try translation, fall back to literal
    var translated = tr(display_name)
    if translated != display_name:
        display_name = translated
    
    # Add external mod indicator
    if bind.mod_id != "taj":
        display_name = "(%s) %s" % [bind.mod_id, display_name]
        name_label.add_theme_color_override("font_color", COLOR_EXTERNAL)
    
    name_label.text = display_name
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_label.add_theme_font_size_override("font_size", 22)
    
    # Tooltip with description
    var desc = bind.get("description", "")
    if not desc.is_empty():
        var translated_desc = tr(desc)
        if translated_desc != desc:
            desc = translated_desc
        name_label.tooltip_text = desc
    
    row.add_child(name_label)
    
    # Current binding display
    var binding_label = Label.new()
    binding_label.text = _manager.get_binding_display_string(bind.id)
    binding_label.add_theme_font_size_override("font_size", 22)
    binding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    binding_label.custom_minimum_size.x = 150
    
    if has_conflict:
        binding_label.add_theme_color_override("font_color", COLOR_CONFLICT)
        binding_label.tooltip_text = "⚠️ Conflicts with another keybind"
    
    row.add_child(binding_label)
    
    # Rebind button
    var rebind_btn = Button.new()
    rebind_btn.text = "Rebind"
    rebind_btn.add_theme_font_size_override("font_size", 16)
    rebind_btn.custom_minimum_size.x = 60
    rebind_btn.disabled = not bind.allow_rebind
    rebind_btn.pressed.connect(_on_rebind_pressed.bind(bind.id))
    row.add_child(rebind_btn)
    
    # Reset button
    var reset_btn = Button.new()
    reset_btn.text = "↺"
    reset_btn.tooltip_text = "Reset to default"
    reset_btn.custom_minimum_size.x = 35
    reset_btn.disabled = not bind.allow_rebind
    reset_btn.pressed.connect(_on_reset_pressed.bind(bind.id))
    row.add_child(reset_btn)
    
    _container.add_child(row)
    
    # Store reference for updates
    _item_rows[bind.id] = {
        "row": row,
        "binding_label": binding_label,
        "rebind_btn": rebind_btn,
        "reset_btn": reset_btn
    }


func _add_reset_all_button() -> void:
    var spacer = MarginContainer.new()
    spacer.add_theme_constant_override("margin_top", 20)
    
    var btn = Button.new()
    btn.text = "Reset All Keybinds"
    btn.pressed.connect(_on_reset_all_pressed)
    spacer.add_child(btn)
    
    _container.add_child(spacer)


# ============== Event Handlers ==============

func _on_rebind_pressed(bind_id: String) -> void:
    _rebind_bind_id = bind_id
    _show_rebind_overlay()


func _on_reset_pressed(bind_id: String) -> void:
    _manager.reset_binding(bind_id)
    Sound.play("click")


func _on_reset_all_pressed() -> void:
    _manager.reset_all_bindings()
    _rebuild_ui()
    Sound.play("click")
    Signals.notify.emit("check", "All keybinds reset to defaults")


func _on_binding_changed(bind_id: String, new_binding: Dictionary) -> void:
    if _item_rows.has(bind_id):
        var item = _item_rows[bind_id]
        item.binding_label.text = _manager.binding_to_display_string(new_binding)
        
        # Update conflict highlight
        var conflicts = _manager.get_conflicts()
        var has_conflict = false
        for conflict in conflicts:
            if conflict.bind_id1 == bind_id or conflict.bind_id2 == bind_id:
                has_conflict = true
                break
        
        if has_conflict:
            item.binding_label.add_theme_color_override("font_color", COLOR_CONFLICT)
            item.binding_label.tooltip_text = "⚠️ Conflicts with another keybind"
        else:
            item.binding_label.remove_theme_color_override("font_color")
            item.binding_label.tooltip_text = ""


func _on_conflict_detected(bind_id1: String, bind_id2: String) -> void:
    # Update visual state
    for bind_id in [bind_id1, bind_id2]:
        if _item_rows.has(bind_id):
            var item = _item_rows[bind_id]
            item.binding_label.add_theme_color_override("font_color", COLOR_CONFLICT)


func _rebuild_ui() -> void:
    _build_ui()


# ============== Rebind Overlay ==============

func _show_rebind_overlay() -> void:
    # Prevent duplication
    if _rebind_overlay and is_instance_valid(_rebind_overlay):
        return
        
    var root = _container.get_tree().root
    
    # Create CanvasLayer to ensure input capture and visibility
    # This prevents the "weird place" issue and ensures it's on top
    var canvas = CanvasLayer.new()
    canvas.layer = 200 # High layer
    canvas.name = "KeybindRebindLayer"
    
    # Create background dimmer
    var bg = ColorRect.new()
    bg.color = Color(0, 0, 0, 0.8)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    # Create CenterContainer for positioning
    var center = CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_STOP
    center.focus_mode = Control.FOCUS_ALL # Capture focus here for key events
    
    # Store reference to the LAYER (so we can free the whole thing)
    _rebind_overlay = canvas
    
    # Create panel
    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(400, 200)
    
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 20)
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    
    var title = Label.new()
    title.text = "Press any key..."
    title.add_theme_font_size_override("font_size", 28)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)
    
    var bind = _manager.get_bind(_rebind_bind_id)
    var bind_name = tr(bind.display_name) if not bind.is_empty() else _rebind_bind_id
    
    var subtitle = Label.new()
    subtitle.text = "Rebinding: %s" % bind_name
    subtitle.add_theme_font_size_override("font_size", 18)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
    vbox.add_child(subtitle)
    
    var cancel_btn = Button.new()
    cancel_btn.text = "Cancel (Escape)"
    cancel_btn.pressed.connect(_hide_rebind_overlay)
    cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    vbox.add_child(cancel_btn)
    
    panel.add_child(vbox)
    center.add_child(panel)
    
    canvas.add_child(bg)
    canvas.add_child(center)
    
    # Connect input on the CenterContainer (which covers full screen)
    center.gui_input.connect(_on_rebind_input)
    
    root.add_child(canvas)
    center.grab_focus()


func _hide_rebind_overlay() -> void:
    if _rebind_overlay and is_instance_valid(_rebind_overlay):
        _rebind_overlay.queue_free()
        _rebind_overlay = null
    _rebind_bind_id = ""


func _on_rebind_input(event: InputEvent) -> void:
    # Cancel on Escape
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_ESCAPE:
            _hide_rebind_overlay()
            return
        
        # Ignore modifier-only presses
        if event.keycode in [KEY_CTRL, KEY_ALT, KEY_SHIFT, KEY_META]:
            return
        
        # Capture the binding
        var new_binding = _manager.binding_from_event(event)
        _manager.set_binding(_rebind_bind_id, new_binding)
        
        _hide_rebind_overlay()
        Sound.play("click")
        
        var display = _manager.binding_to_display_string(new_binding)
        Signals.notify.emit("check", "Rebound to: %s" % display)
    
    elif event is InputEventMouseButton and event.pressed:
        # Allow mouse button rebinding (except left click which dismisses)
        if event.button_index == MOUSE_BUTTON_LEFT:
            return
        
        var new_binding = _manager.binding_from_event(event)
        _manager.set_binding(_rebind_bind_id, new_binding)
        
        _hide_rebind_overlay()
        Sound.play("click")
        
        var display = _manager.binding_to_display_string(new_binding)
        Signals.notify.emit("check", "Rebound to: %s" % display)
