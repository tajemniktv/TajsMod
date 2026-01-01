# ==============================================================================
# Taj's Mod - Upload Labs
# Resource Definition Panel - UI for displaying resource/connector details
# Author: TajemnikTV
# ==============================================================================
class_name TajsModResourceDefinitionPanel
extends PanelContainer

signal back_requested
signal show_inputs_requested(shape: String, color: String)
signal show_outputs_requested(shape: String, color: String)

const LOG_NAME = "TajsModded:ResourceDefPanel"

# Styling constants
const COLOR_BG = Color(0.08, 0.1, 0.14, 0.95)
const COLOR_BORDER = Color(0.3, 0.5, 0.7, 0.6)
const COLOR_HEADER = Color(0.12, 0.15, 0.2, 1.0)
const COLOR_SECTION_BG = Color(0.1, 0.12, 0.16, 0.6)

# UI References
var _title_label: Label
var _shape_label: Label
var _color_swatch: ColorRect
var _color_name_label: Label
var _description_label: Label

var _current_resource_id: String = ""
var _current_shape: String = ""
var _current_color: String = ""

var _wire_colors = null


func _init() -> void:
    name = "ResourceDefinitionPanel"
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL
    _build_ui()


func _input(event: InputEvent) -> void:
    if not visible:
        return
    # Handle mouse back button
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_XBUTTON1 and event.pressed:
            back_requested.emit()
            get_viewport().set_input_as_handled()


func set_wire_colors(wc) -> void:
    _wire_colors = wc


func _build_ui() -> void:
    # Main style
    var style = StyleBoxFlat.new()
    style.bg_color = COLOR_BG
    style.border_color = COLOR_BORDER
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    add_theme_stylebox_override("panel", style)
    
    var main_vbox = VBoxContainer.new()
    main_vbox.add_theme_constant_override("separation", 0)
    add_child(main_vbox)
    
    # === Header ===
    var header_panel = PanelContainer.new()
    var header_style = StyleBoxFlat.new()
    header_style.bg_color = COLOR_HEADER
    header_style.set_corner_radius_all(12)
    header_style.corner_radius_bottom_left = 0
    header_style.corner_radius_bottom_right = 0
    header_panel.add_theme_stylebox_override("panel", header_style)
    main_vbox.add_child(header_panel)
    
    var header_margin = MarginContainer.new()
    header_margin.add_theme_constant_override("margin_left", 16)
    header_margin.add_theme_constant_override("margin_right", 16)
    header_margin.add_theme_constant_override("margin_top", 12)
    header_margin.add_theme_constant_override("margin_bottom", 12)
    header_panel.add_child(header_margin)
    
    var header_hbox = HBoxContainer.new()
    header_hbox.add_theme_constant_override("separation", 12)
    header_margin.add_child(header_hbox)
    
    # Color swatch
    var swatch_container = PanelContainer.new()
    var swatch_style = StyleBoxFlat.new()
    swatch_style.bg_color = Color(0, 0, 0, 0.3)
    swatch_style.set_corner_radius_all(8)
    swatch_container.add_theme_stylebox_override("panel", swatch_style)
    header_hbox.add_child(swatch_container)
    
    var swatch_margin = MarginContainer.new()
    swatch_margin.add_theme_constant_override("margin_top", 4)
    swatch_margin.add_theme_constant_override("margin_bottom", 4)
    swatch_margin.add_theme_constant_override("margin_left", 4)
    swatch_margin.add_theme_constant_override("margin_right", 4)
    swatch_container.add_child(swatch_margin)
    
    _color_swatch = ColorRect.new()
    _color_swatch.custom_minimum_size = Vector2(48, 48)
    _color_swatch.color = Color.WHITE
    swatch_margin.add_child(_color_swatch)
    
    # Title and info
    var title_vbox = VBoxContainer.new()
    title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_vbox.add_theme_constant_override("separation", 4)
    header_hbox.add_child(title_vbox)
    
    _title_label = Label.new()
    _title_label.text = "Resource Name"
    _title_label.add_theme_font_size_override("font_size", 28)
    _title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
    title_vbox.add_child(_title_label)
    
    _shape_label = Label.new()
    _shape_label.text = "Shape: circle"
    _shape_label.add_theme_font_size_override("font_size", 16)
    _shape_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
    title_vbox.add_child(_shape_label)
    
    # Back button
    var back_btn = Button.new()
    back_btn.text = "← Back"
    back_btn.custom_minimum_size = Vector2(80, 40)
    back_btn.focus_mode = Control.FOCUS_NONE
    back_btn.pressed.connect(func():
        back_requested.emit()
        Sound.play("click")
    )
    header_hbox.add_child(back_btn)
    
    # Content Area
    var content_scroll = ScrollContainer.new()
    content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    main_vbox.add_child(content_scroll)
    
    var content_margin = MarginContainer.new()
    content_margin.add_theme_constant_override("margin_left", 20)
    content_margin.add_theme_constant_override("margin_right", 20)
    content_margin.add_theme_constant_override("margin_top", 16)
    content_margin.add_theme_constant_override("margin_bottom", 16)
    content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_scroll.add_child(content_margin)
    
    var content_vbox = VBoxContainer.new()
    content_vbox.add_theme_constant_override("separation", 16)
    content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_margin.add_child(content_vbox)
    
    # Color name section
    var color_section = _create_section("Color", content_vbox)
    _color_name_label = Label.new()
    _color_name_label.text = "white"
    _color_name_label.add_theme_font_size_override("font_size", 18)
    color_section.add_child(_color_name_label)
    
    # Description section (if available)
    var desc_section = _create_section("Description", content_vbox)
    _description_label = Label.new()
    _description_label.text = "This resource type is used for connections."
    _description_label.add_theme_font_size_override("font_size", 16)
    _description_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
    _description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    desc_section.add_child(_description_label)
    
    # Action buttons section
    var actions_section = _create_section("Find Related Nodes", content_vbox)
    
    var btn_inputs = Button.new()
    btn_inputs.text = "🔍 Show Nodes with this INPUT"
    btn_inputs.custom_minimum_size = Vector2(0, 45)
    btn_inputs.focus_mode = Control.FOCUS_NONE
    btn_inputs.pressed.connect(func():
        show_inputs_requested.emit(_current_shape, _current_color)
        Sound.play("click")
    )
    actions_section.add_child(btn_inputs)
    
    var btn_outputs = Button.new()
    btn_outputs.text = "🔍 Show Nodes with this OUTPUT"
    btn_outputs.custom_minimum_size = Vector2(0, 45)
    btn_outputs.focus_mode = Control.FOCUS_NONE
    btn_outputs.pressed.connect(func():
        show_outputs_requested.emit(_current_shape, _current_color)
        Sound.play("click")
    )
    actions_section.add_child(btn_outputs)


func _create_section(title: String, parent: Control) -> VBoxContainer:
    var section = VBoxContainer.new()
    section.add_theme_constant_override("separation", 8)
    parent.add_child(section)
    
    var title_label = Label.new()
    title_label.text = title
    title_label.add_theme_font_size_override("font_size", 14)
    title_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
    section.add_child(title_label)
    
    var content = VBoxContainer.new()
    content.add_theme_constant_override("separation", 4)
    section.add_child(content)
    
    return content


func display_resource(resource_id: String, shape: String, color: String, label: String) -> void:
    _current_resource_id = resource_id
    _current_shape = shape
    _current_color = color
    
    # Set title - try to find friendly name
    var display_name = label if label != "" else resource_id
    
    # Check CONFIGURABLE_WIRES for friendly name
    if Data.resources.has(resource_id):
        var res_data = Data.resources[resource_id]
        if res_data.has("name"):
            display_name = tr(res_data.name)
    
    _title_label.text = display_name.capitalize()
    _shape_label.text = "Shape: %s" % shape
    _color_name_label.text = color.capitalize()
    
    # Set color swatch
    var swatch_color = _resolve_color(shape, color)
    _color_swatch.color = swatch_color
    _color_name_label.add_theme_color_override("font_color", swatch_color)
    
    # Try to get description for this resource type
    var description = "A connector type used for node connections."
    var res_data = _find_resource_data(resource_id, shape, label)
    
    if not res_data.is_empty():
        # Update description
        if res_data.has("description"):
            description = tr(res_data.description)
            
        # Update title if it was just the ID
        if label == "" and res_data.has("name"):
            _title_label.text = tr(res_data.name).capitalize()
            
    if description == "A connector type used for node connections.":
        var tried_keys = [resource_id, resource_id.to_lower()]
        if label != "": tried_keys.append(label.to_lower().replace(" ", "_"))
        tried_keys.append(shape)
        
        # Find potential matches
        var candidates = []
        var search_terms = label.to_lower().split(" ")
        if search_terms.size() > 0:
            for key in Data.resources:
                var str_key = str(key).to_lower()
                for term in search_terms:
                    if term.length() > 2 and term in str_key:
                        candidates.append(key)
                        break
                        
        description += "\n\n(Debug Info: Not found in Data.[resources/connectors/items]. Used ID='%s'. Tried keys: %s. Total Res: %d)" % [resource_id, str(tried_keys), Data.resources.size()]
        # Enhanced Debug
        description += "\n(Input Args: id='%s', shape='%s', color='%s', label='%s')" % [resource_id, shape, color, label]
        if not candidates.is_empty():
            description += "\n(Did you mean? %s)" % str(candidates.slice(0, 10)) # Show first 10
        if not res_data.is_empty():
            description += "\n(Found Data Keys: %s)" % str(res_data.keys())
        
    _description_label.text = description


func _find_resource_data(id: String, shape: String, label: String) -> Dictionary:
    var keys_to_try = []
    
    # Priority 1: ID
    if id != "":
        keys_to_try.append(id)
        keys_to_try.append(id.to_lower())
    
    # Priority 2: Label (converted to ID format)
    if label != "":
        keys_to_try.append(label.to_lower().replace(" ", "_"))
    
    # Priority 3: Shape (less reliable but possible)
    if shape != "":
        keys_to_try.append(shape)
    
    var best_match = {}
    
    # 1. Check Resources (Highest Priority - contains descriptions/names)
    for key in keys_to_try:
        # Check standard keys
        if Data.resources.has(key):
            var res = Data.resources[key]
            # If we find a description, this is definitely what we want
            if res.has("description") and not res.description.is_empty():
                return res
            # Otherwise keep it as a fallback if we haven't found anything yet
            if best_match.is_empty():
                best_match = res
        
        # Handle custom_ prefix (e.g. custom_neuron_image -> neuron_image)
        if key.begins_with("custom_"):
            var clean_key = key.trim_prefix("custom_")
            if Data.resources.has(clean_key):
                var res = Data.resources[clean_key]
                if res.has("description") and not res.description.is_empty():
                    return res
                if best_match.is_empty():
                    best_match = res
            
    # 2. Check Items (Secondary Priority)
    if "items" in Data:
        # Check for label/shape keys as well if items dictionary exists
        var item_keys = keys_to_try
        for k in item_keys:
            if Data.items.has(k):
                var item = Data.items[k]
                if item.has("description") and not item.description.is_empty():
                    return item
                if best_match.is_empty():
                    best_match = item

    # 3. Check Connectors (Lowest Priority - mostly just visual info)
    for key in keys_to_try:
        if Data.connectors.has(key):
            var conn = Data.connectors[key]
            if best_match.is_empty():
                best_match = conn
            
    # 4. Final Fallback: Reverse lookup by Name
    # (e.g. Label "Image Neuron" -> check all resource names)
    if label != "":
        var label_lower = label.to_lower()
        for key in Data.resources:
            # Be careful, Data.resources values might not be Dicts or might be Resources
            if Data.resources[key] is Dictionary and Data.resources[key].has("name"):
                # Compare translated name to label
                var res_name = tr(Data.resources[key].name).to_lower()
                if res_name == label_lower:
                    var res = Data.resources[key]
                    if res.has("description") and not res.description.is_empty():
                        return res
                    if best_match.is_empty():
                        best_match = res
                    
    return best_match


func _resolve_color(shape: String, color_key: String) -> Color:
    # 1. Custom Overrides (highest priority)
    if _wire_colors:
        var override = _wire_colors.get_override_for_connector(shape)
        if override.a > 0:
            return override
            
    # 2. Game Data
    if Data.connectors.has(shape):
        return Color(Data.connectors[shape].color)
    if Data.connectors.has(color_key):
        return Color(Data.connectors[color_key].color)
        
    # 3. Fallback
    return Color.WHITE
