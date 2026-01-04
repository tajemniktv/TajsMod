# ==============================================================================
# Taj's Mod - Upload Labs
# Node Definition Panel - UI for displaying node details
# Author: TajemnikTV
# ==============================================================================
class_name TajsModNodeDefinitionPanel
extends PanelContainer

signal back_requested
signal close_requested
signal open_in_shop_requested(node_id: String)
signal port_clicked(resource_id: String, shape: String, color: String, label: String, applied_modifiers: Array)
signal modifier_clicked(modifier_id: String)

const LOG_NAME = "TajsModded:NodeDefPanel"

# Styling constants (matching PaletteOverlay)
const COLOR_BG = Color(0.08, 0.1, 0.14, 0.95)
const COLOR_BORDER = Color(0.3, 0.5, 0.7, 0.6)
const COLOR_HEADER = Color(0.12, 0.15, 0.2, 1.0)
const COLOR_TEXT_GLOW = Color(0.4, 0.65, 1.0, 0.5)
const COLOR_SECTION_BG = Color(0.1, 0.12, 0.16, 0.6)

# UI References
var _title_label: Label
var _category_label: Label
var _description_label: Label
var _icon_rect: TextureRect
var _inputs_container: VBoxContainer
var _outputs_container: VBoxContainer
var _unlock_label: Label
var _shop_button: Button
var _modifiers_panel: PanelContainer
var _modifiers_container: VBoxContainer

var _current_node_id: String = ""
var _current_modifiers: Array = []

func _init() -> void:
    name = "NodeDefinitionPanel"
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL
    # Set max width for better centering
    custom_minimum_size = Vector2(0, 0)
    _build_ui()


func _input(event: InputEvent) -> void:
    if not visible:
        return
    # Handle mouse back button
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_XBUTTON1 and event.pressed:
            back_requested.emit()
            get_viewport().set_input_as_handled()

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
    header_style.set_corner_radius_all(12) # Rounded top
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
    header_hbox.add_theme_constant_override("separation", 16)
    header_margin.add_child(header_hbox)
    
    # Icon
    var icon_bg = PanelContainer.new()
    var icon_style = StyleBoxFlat.new()
    icon_style.bg_color = Color(0, 0, 0, 0.3)
    icon_style.set_corner_radius_all(8)
    icon_bg.add_theme_stylebox_override("panel", icon_style)
    header_hbox.add_child(icon_bg)
    
    _icon_rect = TextureRect.new()
    _icon_rect.custom_minimum_size = Vector2(48, 48)
    _icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    # Add some margin around the icon
    var icon_margin = MarginContainer.new()
    icon_margin.add_theme_constant_override("margin_top", 4)
    icon_margin.add_theme_constant_override("margin_bottom", 4)
    icon_margin.add_theme_constant_override("margin_left", 4)
    icon_margin.add_theme_constant_override("margin_right", 4)
    icon_margin.add_child(_icon_rect)
    icon_bg.add_child(icon_margin)
    
    # Title & Category
    var titles_vbox = VBoxContainer.new()
    titles_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    titles_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    header_hbox.add_child(titles_vbox)
    
    _title_label = Label.new()
    _title_label.add_theme_font_size_override("font_size", 20)
    _title_label.add_theme_constant_override("outline_size", 5)
    _title_label.add_theme_color_override("font_outline_color", COLOR_TEXT_GLOW)
    titles_vbox.add_child(_title_label)
    
    _category_label = Label.new()
    _category_label.add_theme_font_size_override("font_size", 14)
    _category_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
    titles_vbox.add_child(_category_label)
    
    # === Body ===
    var body_scroll = ScrollContainer.new()
    body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    main_vbox.add_child(body_scroll)
    
    var body_margin = MarginContainer.new()
    body_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body_margin.add_theme_constant_override("margin_left", 20)
    body_margin.add_theme_constant_override("margin_right", 20)
    body_margin.add_theme_constant_override("margin_top", 16)
    body_margin.add_theme_constant_override("margin_bottom", 16)
    body_scroll.add_child(body_margin)
    
    var body_vbox = VBoxContainer.new()
    body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body_vbox.add_theme_constant_override("separation", 20)
    body_margin.add_child(body_vbox)
    
    # Description
    _description_label = Label.new()
    _description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _description_label.add_theme_font_size_override("font_size", 20)
    _description_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
    body_vbox.add_child(_description_label)
    
    # Ports Section
    var ports_grid = HBoxContainer.new()
    ports_grid.add_theme_constant_override("separation", 20)
    body_vbox.add_child(ports_grid)
    
    # Inputs
    var inputs_panel = _create_section_panel("Inputs")
    inputs_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ports_grid.add_child(inputs_panel)
    _inputs_container = inputs_panel.get_meta("container")
    
    # Outputs
    var outputs_panel = _create_section_panel("Outputs")
    outputs_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ports_grid.add_child(outputs_panel)
    _outputs_container = outputs_panel.get_meta("container")
    
    # Modifiers Added
    _modifiers_panel = _create_section_panel("Modifiers Added")
    _modifiers_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _modifiers_panel.visible = false
    body_vbox.add_child(_modifiers_panel)
    _modifiers_container = _modifiers_panel.get_meta("container")
    
    # Unlock Info
    var unlock_panel = PanelContainer.new()
    var unlock_style = StyleBoxFlat.new()
    unlock_style.bg_color = COLOR_SECTION_BG
    unlock_style.set_corner_radius_all(6)
    unlock_panel.add_theme_stylebox_override("panel", unlock_style)
    body_vbox.add_child(unlock_panel)
    
    var unlock_margin = MarginContainer.new()
    unlock_margin.add_theme_constant_override("margin_left", 12)
    unlock_margin.add_theme_constant_override("margin_right", 12)
    unlock_margin.add_theme_constant_override("margin_top", 8)
    unlock_margin.add_theme_constant_override("margin_bottom", 8)
    unlock_panel.add_child(unlock_margin)
    
    _unlock_label = Label.new()
    _unlock_label.add_theme_font_size_override("font_size", 18)
    _unlock_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
    unlock_margin.add_child(_unlock_label)
    
    # === Footer ===
    var footer = PanelContainer.new()
    var footer_style = StyleBoxFlat.new()
    footer_style.bg_color = Color(0.06, 0.08, 0.1, 0.8)
    footer_style.corner_radius_bottom_left = 12
    footer_style.corner_radius_bottom_right = 12
    footer.add_theme_stylebox_override("panel", footer_style)
    main_vbox.add_child(footer)
    
    var footer_margin = MarginContainer.new()
    footer_margin.add_theme_constant_override("margin_left", 16)
    footer_margin.add_theme_constant_override("margin_right", 16)
    footer_margin.add_theme_constant_override("margin_top", 12)
    footer_margin.add_theme_constant_override("margin_bottom", 12)
    footer.add_child(footer_margin)
    
    var footer_hbox = HBoxContainer.new()
    footer_hbox.alignment = BoxContainer.ALIGNMENT_END
    footer_hbox.add_theme_constant_override("separation", 12)
    footer_margin.add_child(footer_hbox)
    
    # Shop Button (hidden by default)
    _shop_button = Button.new()
    _shop_button.text = "Open in Shop"
    _shop_button.visible = false
    # _shop_button.pressed.connect(_on_shop_pressed) # To be implemented if needed
    footer_hbox.add_child(_shop_button)
    
    # Back Button
    var back_btn = Button.new()
    back_btn.text = "Back"
    back_btn.custom_minimum_size = Vector2(60, 28)
    back_btn.add_theme_font_size_override("font_size", 12)
    back_btn.pressed.connect(func(): back_requested.emit())
    footer_hbox.add_child(back_btn)


func _create_section_panel(title: String) -> PanelContainer:
    var panel = PanelContainer.new()
    var style = StyleBoxFlat.new()
    style.bg_color = COLOR_SECTION_BG
    style.set_corner_radius_all(6)
    # Force some content padding/size
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    panel.add_theme_stylebox_override("panel", style)
    
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 12)
    panel.add_child(margin)
    
    var vbox = VBoxContainer.new()
    margin.add_child(vbox)
    
    var label = Label.new()
    label.text = title
    label.add_theme_font_size_override("font_size", 14)
    label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
    vbox.add_child(label)
    
    # Container for list items
    var item_container = VBoxContainer.new()
    vbox.add_child(item_container)
    
    # Metadata to retrieve container later
    panel.set_meta("container", item_container)
    
    return panel


func display_node(data: Dictionary) -> void:
    _current_node_id = data.get("id", "")
    _current_modifiers = data.get("modifiers_added", [])
    
    # Header
    _title_label.text = data.get("name", "Unknown Node")
    _category_label.text = data.get("category", "General")
    if data.get("sub_category", "") != "":
        _category_label.text += " • " + data.get("sub_category", "")
    
    _icon_rect.texture = null
    var icon_name = data.get("icon", "")
    if icon_name != "":
        var icon_path = "res://textures/icons/" + icon_name + ".png"
        if ResourceLoader.exists(icon_path):
            _icon_rect.texture = load(icon_path)
    
    # Description
    var desc = data.get("description", "")
    if desc.strip_edges().is_empty():
        desc = "No description available."
    _description_label.text = desc
    
    # Ports
    _clear_container(_inputs_container)
    _clear_container(_outputs_container)
    _clear_container(_modifiers_container)
    
    var inputs = data.get("inputs", [])
    if inputs.is_empty():
        _add_placeholder(_inputs_container, "None")
    else:
        for port in inputs:
            _add_port_row(_inputs_container, port)
            
    var outputs = data.get("outputs", [])
    if outputs.is_empty():
        _add_placeholder(_outputs_container, "None")
    else:
        for port in outputs:
            _add_port_row(_outputs_container, port)
    
    # Modifiers
    var modifiers = data.get("modifiers_added", [])
    if modifiers.is_empty():
        _modifiers_panel.visible = false
    else:
        _modifiers_panel.visible = true
        for modifier in modifiers:
            _add_modifier_row(_modifiers_container, modifier)
            
    # Unlock Info
    var unlock = data.get("unlock_info", {})
    var status = unlock.get("status", "Available")
    
    if status == "Research Required":
        var r_name = unlock.get("research_name", unlock.get("research_id", "Unknown"))
        var r_cost = unlock.get("research_cost", 0)
        var r_currency = unlock.get("research_currency", "research")
        # Translate internal name to friendly display name
        r_name = tr(r_name)
        if r_cost > 0:
            _unlock_label.text = "🔒 Research: %s (%s %s)" % [r_name, _format_number(r_cost), r_currency.capitalize()]
        else:
            _unlock_label.text = "🔒 Research: " + r_name
        _unlock_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
    elif status == "Shop Purchase":
        var price = unlock.get("price", 0)
        var upgrade_name = unlock.get("upgrade_name", unlock.get("upgrade_id", ""))
        # Translate internal name to friendly display name
        if upgrade_name != "":
            upgrade_name = tr(upgrade_name)
            _unlock_label.text = "🛒 Upgrade: %s (%s)" % [upgrade_name, _format_number(price)]
        else:
            _unlock_label.text = "🛒 Shop: %s" % _format_number(price)
        _unlock_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
    elif status == "Perk Required":
        var perk_name = unlock.get("perk_name", unlock.get("perk_id", "Unknown"))
        # Translate internal name to friendly display name
        perk_name = tr(perk_name)
        _unlock_label.text = "⭐ Perk: " + perk_name
        _unlock_label.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
    else:
        _unlock_label.text = "🔓 Available from start"
        _unlock_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))


var _wire_colors = null

func set_wire_colors(wc) -> void:
    _wire_colors = wc


func _add_port_row(container: Control, port: Dictionary) -> void:
    var shape = port.get("shape", "?")
    var color_name = text_str(port.get("color", "white")).to_lower()
    var label_text = port.get("label", shape)
    var count = port.get("count", 1)
    
    # Get the resource_id from port data (may be populated by filter)
    var resource_id = port.get("resource_id", "")
    var label_lower = label_text.to_lower()
    var forced_any_file = false
    
    # Heuristic: some file inputs are defined as white square "Input" with no resource_id
    # Only apply "File Wildcard" when there's no specific resource_id AND it looks generic
    if resource_id == "" and shape == "square" and _is_generic_file_label(label_lower):
        forced_any_file = true
        var guessed_id = _guess_file_resource_id()
        if guessed_id != "":
            resource_id = guessed_id
        label_text = "File Wildcard"
        color_name = "white"
    
    # Create clickable button for the port
    var btn = Button.new()
    btn.flat = true
    btn.focus_mode = Control.FOCUS_NONE
    btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    
    # Get display color
    var color = _resolve_color(shape, color_name)
    
    # If resource_id is present, use its localized name for the label
    # This fixes generic "Neuron" labels when the underlying resource is specific (e.g. "neuron_image")
    if resource_id != "" and Data.resources.has(resource_id):
        if not forced_any_file:
            var res = Data.resources[resource_id]
            if res.has("name"):
                label_text = tr(res.name)
    
    # Set button text
    btn.text = "%dx %s (%s)" % [count, label_text, shape]
    btn.add_theme_font_size_override("font_size", 18)
    btn.add_theme_color_override("font_color", color)
    btn.add_theme_color_override("font_hover_color", color.lightened(0.3))
    btn.add_theme_color_override("font_pressed_color", color.darkened(0.2))
    btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
    
    # Add tooltip with description if available
    var keys_to_try = []
    
    if resource_id != "":
        keys_to_try.append(resource_id)
        
    keys_to_try.append(color_name)
    keys_to_try.append(color_name.to_lower())
    
    if label_text != "":
        keys_to_try.append(label_text.to_lower().replace(" ", "_"))
    keys_to_try.append(shape)
    
    for key in keys_to_try:
        if Data.resources.has(key):
            var res = Data.resources[key]
            if res.has("description"):
                btn.tooltip_text = tr(res.description)
                break
    
    # Store port data for click handler
    var port_shape = shape
    var port_color = color_name
    var port_label = label_text
    
    # Determine best resource ID to pass
    var port_res_id = resource_id
    
    if port_res_id == "":
        # Try to infer from label first
        var label_str = str(label_text)
        if label_str != "":
            # 0. Pre-process PascalCase/CamelCase (e.g. "TextNeuron" -> "Text Neuron")
            var spaced_label = ""
            for i in range(label_str.length()):
                var char = label_str[i]
                # Insert space before capital letters if it's not the start and previous char isn't a space
                if char == char.to_upper() and char != char.to_lower() and i > 0:
                    # Safe check for previous char since we're using String
                    if label_str[i - 1] != " " and label_str[i - 1] != "_" and label_str[i - 1] != "-":
                        spaced_label += " "
                spaced_label += char
            
            var clean_label = spaced_label.to_lower().replace("-", "_")
            
            # 1. Direct conversion (e.g. "some thing" -> "some_thing")
            var generated_id = clean_label.replace(" ", "_")
            if Data.resources.has(generated_id):
                port_res_id = generated_id
            
            # 2. Swapped conversion (e.g. "Text Neuron" -> "neuron_text")
            if port_res_id == "":
                var parts = clean_label.split(" ", false) # false to skip empty strings
                if parts.size() >= 2:
                    # Try swapping the first two significant parts
                    var swapped_id = parts[1] + "_" + parts[0]
                    if Data.resources.has(swapped_id):
                        port_res_id = swapped_id
                        
            # 3. Handle resource_ prefix just in case (e.g. "resource_neuron_text")
            if port_res_id == "":
                if Data.resources.has("resource_" + generated_id):
                    port_res_id = "resource_" + generated_id
    
    # Fallback to color if still empty
    if port_res_id == "":
        port_res_id = color_name
    
    # Determine modifiers to pass (only for outputs)
    var modifiers_to_pass = []
    if container == _outputs_container:
        modifiers_to_pass = _current_modifiers
    
    btn.pressed.connect(func():
        port_clicked.emit(port_res_id, port_shape, port_color, port_label, modifiers_to_pass)
        Sound.play("click")
    )
    
    container.add_child(btn)
    
func text_str(val) -> String:
    return str(val)


func _format_number(num: float) -> String:
    if num >= 1e24:
        return "%.1fY" % (num / 1e24)
    elif num >= 1e21:
        return "%.1fZ" % (num / 1e21)
    elif num >= 1e18:
        return "%.1fE" % (num / 1e18)
    elif num >= 1e15:
        return "%.1fP" % (num / 1e15)
    elif num >= 1e12:
        return "%.1fT" % (num / 1e12)
    elif num >= 1e9:
        return "%.1fB" % (num / 1e9)
    elif num >= 1e6:
        return "%.1fM" % (num / 1e6)
    elif num >= 1000:
        return "%.1fK" % (num / 1000.0)
    return str(num)


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
        
    # 3. Hardcoded Fallbacks (legacy)
    match color_key:
        "red": return Color(1, 0.4, 0.4)
        "green": return Color(0.4, 1, 0.4)
        "blue": return Color(0.4, 0.6, 1)
        "yellow": return Color(1, 1, 0.4)
        "cyan": return Color(0.4, 1, 1)
        "magenta": return Color(1, 0.4, 1)
        "orange": return Color(1, 0.6, 0.2)
        "purple": return Color(0.7, 0.4, 1.0)
        "lime": return Color(0.6, 1.0, 0.4)
        "violet": return Color(0.8, 0.4, 1.0)
        "pink": return Color(1.0, 0.6, 0.8)
        "teal": return Color(0.4, 0.8, 0.8)
        
    return Color(1, 1, 1)


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


func _add_placeholder(container: Control, text: String) -> void:
    var label = Label.new()
    label.text = text
    label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
    label.add_theme_font_size_override("font_size", 12)
    container.add_child(label)


func _add_modifier_row(container: Control, modifier: Dictionary) -> void:
    var hbox = HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 8)
    
    # Icon (with proper sizing)
    var icon_name = str(modifier.get("icon", ""))
    if icon_name != "":
        var icon_path = "res://textures/icons/" + icon_name + ".png"
        if ResourceLoader.exists(icon_path):
            var icon_rect = TextureRect.new()
            icon_rect.texture = load(icon_path)
            icon_rect.custom_minimum_size = Vector2(20, 20)
            icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            hbox.add_child(icon_rect)
    
    # Button for the text (clickable)
    var row = Button.new()
    row.flat = true
    row.focus_mode = Control.FOCUS_NONE
    row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    row.alignment = HORIZONTAL_ALIGNMENT_LEFT
    row.add_theme_font_size_override("font_size", 16)
    row.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
    row.add_theme_color_override("font_hover_color", Color(0.9, 0.95, 1.0))
    
    var name = str(modifier.get("name", modifier.get("id", "Modifier")))
    row.text = name
    
    var desc = str(modifier.get("description", "")).strip_edges()
    if not desc.is_empty():
        row.tooltip_text = desc
        hbox.tooltip_text = desc
    
    var mod_id = str(modifier.get("id", ""))
    row.pressed.connect(func():
        if mod_id != "":
            modifier_clicked.emit(mod_id)
            Sound.play("click")
    )
    
    hbox.add_child(row)
    container.add_child(hbox)


func _clear_container(container: Control) -> void:
    for child in container.get_children():
        child.queue_free()
