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

# Code values - dynamically loaded from game source
var _code_values: Dictionary = {}

# UI References
var _title_label: Label
var _shape_label: Label
var _color_swatch: ColorRect
var _color_name_label: Label
var _description_label: Label

# Properties section
var _properties_section: VBoxContainer
var _quality_label: Label
var _value_label: Label
var _size_label: Label
var _research_label: Label
var _modifiers_label: Label

var _current_resource_id: String = ""
var _current_shape: String = ""
var _current_color: String = ""

var _wire_colors = null


func _init() -> void:
    name = "ResourceDefinitionPanel"
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL
    _load_code_values()
    _build_ui()


func _load_code_values() -> void:
    # Load the window_commit.gd script to get the 'values' constant
    var commit_script = load("res://scenes/windows/window_commit.gd")
    if commit_script and "values" in commit_script:
        _code_values = commit_script.values.duplicate()
    else:
        # Fallback to known values if script loading fails
        _code_values = {
            "code_bugfix": 1.0,
            "code_optimization": 4.0,
            "code_application": 16.0,
            "code_driver": 64.0
        }


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
    
    # Properties section (for Files and Code)
    _properties_section = _create_section("Properties", content_vbox)
    _properties_section.visible = false
    
    _modifiers_label = Label.new()
    _modifiers_label.text = ""
    _modifiers_label.add_theme_font_size_override("font_size", 16)
    _modifiers_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
    _modifiers_label.visible = false
    _properties_section.add_child(_modifiers_label)
    
    _quality_label = Label.new()
    _quality_label.text = "Quality: 1.0"
    _quality_label.add_theme_font_size_override("font_size", 16)
    _quality_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
    _properties_section.add_child(_quality_label)
    
    _value_label = Label.new()
    _value_label.text = "Value: 0"
    _value_label.add_theme_font_size_override("font_size", 16)
    _value_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
    _properties_section.add_child(_value_label)
    
    _size_label = Label.new()
    _size_label.text = "Size: 0b"
    _size_label.add_theme_font_size_override("font_size", 16)
    _size_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
    _properties_section.add_child(_size_label)
    
    _research_label = Label.new()
    _research_label.text = "Research: 0"
    _research_label.add_theme_font_size_override("font_size", 16)
    _research_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
    _properties_section.add_child(_research_label)
    
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


func display_resource(resource_id: String, shape: String, color: String, label: String, applied_modifiers: Array = []) -> void:
    var resolved_id = resource_id
    var resolved_color = color
    var label_text = label
    var is_any_file = false
    
    # Heuristic: white square "Input" is usually an any-file input
    if resolved_id == "white" and shape == "square":
        var label_lower = label_text.to_lower()
        if _is_generic_file_label(label_lower) or label_lower.is_empty():
            var guessed_id = _guess_file_resource_id()
            if guessed_id != "":
                resolved_id = guessed_id
            label_text = "File Wildcard"
            is_any_file = true
    
    _current_resource_id = resolved_id
    _current_shape = shape
    _current_color = resolved_color
    
    # Set title - try to find friendly name
    var display_name = label_text if label_text != "" else resolved_id
    
    # Check CONFIGURABLE_WIRES for friendly name
    if Data.resources.has(resolved_id):
        var res_data = Data.resources[resolved_id]
        if res_data.has("name"):
            display_name = tr(res_data.name)
    
    _title_label.text = display_name.capitalize()
    _shape_label.text = "Shape: %s" % shape
    _color_name_label.text = resolved_color.capitalize()
    
    # Set color swatch
    var swatch_color = _resolve_color(shape, resolved_color)
    _color_swatch.color = swatch_color
    _color_name_label.add_theme_color_override("font_color", swatch_color)
    
    # Try to get description for this resource type
    var description = "A connector type used for node connections."
    var res_data = _find_resource_data(resolved_id, shape, label_text)
    
    if not res_data.is_empty():
        # Update description
        if res_data.has("description"):
            description = tr(res_data.description)
            
        # Update title if it was just the ID
        if label_text == "" and res_data.has("name"):
            _title_label.text = tr(res_data.name).capitalize()
    
    if is_any_file:
        description = "Accepts any file type. " + description
            
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
    
    # Update Properties section
    var variation = _calculate_variation(applied_modifiers)
    
    if not applied_modifiers.is_empty():
        var names = []
        for mod in applied_modifiers:
            names.append(str(mod.get("name", mod.get("id", "Modifier"))))
        _modifiers_label.text = "Activated: " + ", ".join(names)
        _modifiers_label.visible = true
    else:
        _modifiers_label.visible = false
        
    _update_properties(resolved_id, variation)


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


    # 4. Check Connectors (Lowest Priority - mostly just visual info)
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


func _is_generic_file_label(label_lower: String) -> bool:
    if label_lower.contains("input") or label_lower.contains("output"):
        return true
    if label_lower.contains("file") or label_lower.contains("empty"):
        return true
    return false


func _guess_file_resource_id() -> String:
    var best_id = ""
    var best_score = -1
    if not Data or not "resources" in Data:
        return best_id
    
    for id in Data.resources:
        var res = Data.resources[id]
        if not (res is Dictionary):
            continue
        
        var score = 0
        if str(res.get("connection", "")).to_lower() == "square":
            score += 50
        if str(res.get("color", "")).to_lower() == "green":
            score += 20
        
        var key = str(id).to_lower()
        var name = str(res.get("name", id)).to_lower()
        if "file" in key or "file" in name:
            score += 30
        
        var desc = str(res.get("description", "")).to_lower()
        if "file" in desc:
            score += 10
        
        if score > best_score:
            best_score = score
            best_id = str(id)
    
    return best_id


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


func _calculate_variation(modifiers: Array) -> int:
    var variation = 0
    var counts = {} # Count occurrences of each modifier type
    
    for mod in modifiers:
        var id = str(mod.get("id", "")).to_lower()
        counts[id] = counts.get(id, 0) + 1
        
    # Apply bits based on counts (matches Utils.file_variations)
    if counts.get("scanned", 0) > 0: variation |= (1 << 0)
    if counts.get("validated", 0) > 0: variation |= (1 << 1)
    
    # Compressed (stacks up to 3)
    var comp_count = counts.get("compressed", 0)
    if comp_count >= 1: variation |= (1 << 2)
    if comp_count >= 2: variation |= (1 << 3)
    if comp_count >= 3: variation |= (1 << 4)
    
    # Enhanced (stacks up to 3)
    var enh_count = counts.get("enhanced", 0)
    if enh_count >= 1: variation |= (1 << 5)
    if enh_count >= 2: variation |= (1 << 6)
    if enh_count >= 3: variation |= (1 << 7)
    
    if counts.get("infected", 0) > 0: variation |= (1 << 8)
    if counts.get("refined", 0) > 0: variation |= (1 << 9)
    if counts.get("distilled", 0) > 0: variation |= (1 << 10)
    if counts.get("analyzed", 0) > 0: variation |= (1 << 11)
    if counts.get("hacked", 0) > 0: variation |= (1 << 12)
    if counts.get("corrupted", 0) > 0: variation |= (1 << 13)
    if counts.get("ai", 0) > 0: variation |= (1 << 14)
    if counts.get("encrypted", 0) > 0: variation |= (1 << 15)
    if counts.get("decrypted", 0) > 0: variation |= (1 << 16)
    
    # Code variations if relevant
    # DEBUGGED (1), BUGGED (2), OPTIMIZED (4) etc. are for code
    # We can add mapping for them if we want to support code modifiers too
    
    return variation


func _update_properties(resource_id: String, variation: int) -> void:
    # Check if this is a File resource (in Data.files)
    if Data.files.has(resource_id):
        _properties_section.visible = true
        _size_label.visible = true
        _research_label.visible = true
        
        var quality = Utils.get_variation_quality_multiplier(variation)
        var value = Utils.get_file_value(resource_id, variation)
        var size = Utils.get_file_size(resource_id, variation)
        var research = Utils.get_file_research(resource_id, variation)
        
        _quality_label.text = tr("quality") + ": %.1f" % quality
        _value_label.text = tr("value") + ": " + Utils.print_string(value, false)
        _size_label.text = tr("size") + ": " + Utils.print_metric(size, false) + "b"
        _research_label.text = tr("research") + ": " + Utils.print_string(research, false)
        return
    
    # Check if this is a Code resource
    if _code_values.has(resource_id):
        _properties_section.visible = true
        _size_label.visible = false # No size defined for Code
        _research_label.visible = false # No research defined for Code
        
        var base_value = _code_values[resource_id]
        var quality = Utils.get_code_value_multiplier(variation)
        var value = base_value * quality
        
        _quality_label.text = tr("quality") + ": %.1f" % quality
        _value_label.text = tr("value") + ": " + Utils.print_string(value, false)
        return
    
    # Check if resource has "code" symbols (other code types)
    if Data.resources.has(resource_id):
        var res_data = Data.resources[resource_id]
        if res_data.has("symbols") and res_data.symbols == "code":
            _properties_section.visible = true
            _size_label.visible = false
            _research_label.visible = false
            
            var quality = Utils.get_code_value_multiplier(variation)
            # Default base value for unknown code types
            var base_value = 1.0
            var value = base_value * quality
            
            _quality_label.text = tr("quality") + ": %.1f" % quality
            _value_label.text = tr("value") + ": " + Utils.print_string(value, false)
            return
    
    # Not a File or Code resource - hide properties
    _properties_section.visible = false
