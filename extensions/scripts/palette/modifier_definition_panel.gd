# ==============================================================================
# Taj's Mod - Upload Labs
# Modifier Definition Panel - UI for displaying file modifier details
# Author: TajemnikTV
# ==============================================================================
class_name TajsModModifierDefinitionPanel
extends PanelContainer

signal back_requested
signal show_nodes_that_add(modifier_id: String)

const LOG_NAME = "TajsModded:ModifierDefPanel"

# Styling constants
const COLOR_BG = Color(0.08, 0.1, 0.14, 0.95)
const COLOR_BORDER = Color(0.3, 0.5, 0.7, 0.6)
const COLOR_HEADER = Color(0.12, 0.15, 0.2, 1.0)
const COLOR_SECTION_BG = Color(0.1, 0.12, 0.16, 0.6)
const COLOR_POSITIVE = Color(0.4, 1.0, 0.5)
const COLOR_NEGATIVE = Color(1.0, 0.5, 0.4)
const COLOR_NEUTRAL = Color(0.8, 0.85, 0.9)

# Modifier definitions with effects parsed from Utils.gd
# Format: { effects: [{stat, multiplier, icon}], applies_to, incompatible_with }
const MODIFIER_DATA = {
    "scanned": {
        "name": "Scanned",
        "icon": "antivirus",
        "description_key": "guide_file_modifiers_scanned",
        "applies_to": "Files",
        "effects": [
            {"stat": "Value", "multiplier": 4.0, "icon": "money"}
        ],
        "incompatible_with": ["encrypted", "hacked"]
    },
    "validated": {
        "name": "Validated",
        "icon": "puzzle",
        "description_key": "guide_file_modifiers_validated",
        "applies_to": "Files",
        "effects": [
            {"stat": "Value", "multiplier": 4.0, "icon": "money"}
        ],
        "incompatible_with": []
    },
    "compressed": {
        "name": "Compressed",
        "icon": "minimize",
        "description_key": "guide_file_modifiers_compressed",
        "applies_to": "Files",
        "effects": [
            {"stat": "Size", "multiplier": 0.5, "icon": "database"}
        ],
        "incompatible_with": ["encrypted"],
        "stacks": 3
    },
    "enhanced": {
        "name": "Enhanced",
        "icon": "up_arrow",
        "description_key": "guide_file_modifiers_enhanced",
        "applies_to": "Files",
        "effects": [
            {"stat": "Quality", "multiplier": 2.0, "icon": "star"},
            {"stat": "Size", "multiplier": 2.0, "icon": "database"}
        ],
        "incompatible_with": ["encrypted"],
        "stacks": 3
    },
    "infected": {
        "name": "Infected",
        "icon": "virus",
        "description_key": "guide_file_modifiers_infected",
        "applies_to": "Files",
        "effects": [
            {"stat": "Value", "multiplier": 0.25, "icon": "money"}
        ],
        "incompatible_with": []
    },
    "refined": {
        "name": "Refined",
        "icon": "filter",
        "description_key": "guide_file_modifiers_refined",
        "applies_to": "Files",
        "effects": [
            {"stat": "Research", "multiplier": 2.0, "icon": "tube"}
        ],
        "incompatible_with": []
    },
    "distilled": {
        "name": "Distilled",
        "icon": "connections",
        "description_key": "guide_file_modifiers_distilled",
        "applies_to": "Files",
        "effects": [
            {"stat": "Neuron Output", "multiplier": 2.0, "icon": "connections"}
        ],
        "incompatible_with": ["encrypted"]
    },
    "analyzed": {
        "name": "Analyzed",
        "icon": "magnifying_glass",
        "description_key": "guide_file_modifiers_analyzed",
        "applies_to": "Files",
        "effects": [
            {"stat": "Data Lab Output", "multiplier": 1.0, "icon": "data", "note": "Enables Data Lab processing"}
        ],
        "incompatible_with": []
    },
    "hacked": {
        "name": "Hacked",
        "icon": "hacker",
        "description_key": "guide_file_modifiers_hacked",
        "applies_to": "Files",
        "effects": [],
        "incompatible_with": ["scanned"]
    },
    "corrupted": {
        "name": "Corrupted",
        "icon": "warning",
        "description_key": "guide_file_modifiers_corrupted",
        "applies_to": "Files",
        "effects": [
            {"stat": "Value", "multiplier": 0.1, "icon": "money"},
            {"stat": "Size", "multiplier": 0.2, "icon": "database"}
        ],
        "incompatible_with": []
    },
    "ai": {
        "name": "AI-Generated",
        "icon": "brain",
        "description_key": "guide_file_modifiers_ai",
        "applies_to": "Files",
        "effects": [
            {"stat": "Quality", "multiplier": 0.1, "icon": "star"},
            {"stat": "Value", "multiplier": 20000000.0, "icon": "money"},
            {"stat": "Neuron Output", "multiplier": 0.0, "icon": "connections"}
        ],
        "incompatible_with": []
    },
    "encrypted": {
        "name": "Encrypted",
        "icon": "padlock",
        "description_key": "guide_file_modifiers_encrypted",
        "applies_to": "Files",
        "effects": [
            {"stat": "Quality", "multiplier": 0.0, "icon": "star", "note": "Cannot be processed until decrypted"}
        ],
        "incompatible_with": ["compressed", "enhanced", "distilled"]
    },
    "decrypted": {
        "name": "Decrypted",
        "icon": "padlock_open",
        "description_key": "guide_file_modifiers_decrypted",
        "applies_to": "Files",
        "effects": [
            {"stat": "Quality", "multiplier": 4.0, "icon": "star"}
        ],
        "incompatible_with": []
    },
    "trojan": {
        "name": "Trojan",
        "icon": "trojan",
        "description_key": "guide_file_modifiers_trojan",
        "applies_to": "Files",
        "effects": [
            {"stat": "Infected Computers", "multiplier": 1.0, "icon": "computer_infected", "note": "Grants Infected Computers on upload"}
        ],
        "incompatible_with": []
    },
}

# UI References
var _title_label: Label
var _icon_rect: TextureRect
var _description_label: Label
var _effects_container: VBoxContainer
var _info_container: VBoxContainer
var _current_modifier_id: String = ""


func _init() -> void:
    name = "ModifierDefinitionPanel"
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
    header_hbox.add_theme_constant_override("separation", 16)
    header_margin.add_child(header_hbox)
    
    # Icon container
    var icon_bg = PanelContainer.new()
    var icon_style = StyleBoxFlat.new()
    icon_style.bg_color = Color(0, 0, 0, 0.3)
    icon_style.set_corner_radius_all(8)
    icon_bg.add_theme_stylebox_override("panel", icon_style)
    header_hbox.add_child(icon_bg)
    
    var icon_margin = MarginContainer.new()
    icon_margin.add_theme_constant_override("margin_top", 8)
    icon_margin.add_theme_constant_override("margin_bottom", 8)
    icon_margin.add_theme_constant_override("margin_left", 8)
    icon_margin.add_theme_constant_override("margin_right", 8)
    icon_bg.add_child(icon_margin)
    
    _icon_rect = TextureRect.new()
    _icon_rect.custom_minimum_size = Vector2(48, 48)
    _icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon_margin.add_child(_icon_rect)
    
    # Title
    var title_vbox = VBoxContainer.new()
    title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_vbox.add_theme_constant_override("separation", 4)
    header_hbox.add_child(title_vbox)
    
    _title_label = Label.new()
    _title_label.text = "Modifier Name"
    _title_label.add_theme_font_size_override("font_size", 28)
    _title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
    title_vbox.add_child(_title_label)
    
    var type_label = Label.new()
    type_label.text = "File Modifier"
    type_label.add_theme_font_size_override("font_size", 16)
    type_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
    title_vbox.add_child(type_label)
    
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
    
    # === Content Area ===
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
    
    # Description section
    var desc_section = _create_section("Description", content_vbox)
    _description_label = Label.new()
    _description_label.text = "This modifier affects files."
    _description_label.add_theme_font_size_override("font_size", 18)
    _description_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
    _description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    desc_section.add_child(_description_label)
    
    # Effects section
    var effects_section = _create_section("Effects", content_vbox)
    _effects_container = effects_section
    
    # Info section (applies to, incompatibilities, stacking)
    var info_section = _create_section("Info", content_vbox)
    _info_container = info_section
    
    # Action button
    var action_section = _create_section("Find Related Nodes", content_vbox)
    
    var btn_nodes = Button.new()
    btn_nodes.text = "🔍 Show Nodes that Add this Modifier"
    btn_nodes.custom_minimum_size = Vector2(0, 45)
    btn_nodes.focus_mode = Control.FOCUS_NONE
    btn_nodes.pressed.connect(func():
        show_nodes_that_add.emit(_current_modifier_id)
        Sound.play("click")
    )
    action_section.add_child(btn_nodes)


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


func display_modifier(modifier_id: String) -> void:
    _current_modifier_id = modifier_id
    var id_lower = modifier_id.to_lower()
    
    # Clear previous content
    _clear_container(_effects_container)
    _clear_container(_info_container)
    
    # Get modifier data
    var mod_data = MODIFIER_DATA.get(id_lower, {})
    
    if mod_data.is_empty():
        # Unknown modifier - show basic info
        _title_label.text = modifier_id.capitalize()
        _icon_rect.texture = null
        _description_label.text = "No detailed information available for this modifier."
        _add_info_row(_info_container, "ID", modifier_id)
        return
    
    # Set title
    _title_label.text = mod_data.get("name", modifier_id.capitalize())
    
    # Set icon
    var icon_name = mod_data.get("icon", "")
    if icon_name != "":
        var icon_path = "res://textures/icons/" + icon_name + ".png"
        if ResourceLoader.exists(icon_path):
            _icon_rect.texture = load(icon_path)
        else:
            _icon_rect.texture = null
    else:
        _icon_rect.texture = null
    
    # Set description (try translation first)
    var desc_key = mod_data.get("description_key", "")
    var description = ""
    if desc_key != "":
        var translated = tr(desc_key)
        if translated != desc_key:
            description = translated
    
    if description.is_empty():
        description = "Modifies file properties when applied."
    
    _description_label.text = description
    
    # Add effects
    var effects = mod_data.get("effects", [])
    if effects.is_empty():
        var no_effect = Label.new()
        no_effect.text = "No direct stat effects"
        no_effect.add_theme_font_size_override("font_size", 16)
        no_effect.add_theme_color_override("font_color", COLOR_NEUTRAL)
        _effects_container.add_child(no_effect)
    else:
        for effect in effects:
            _add_effect_row(_effects_container, effect)
    
    # Add info
    var applies_to = mod_data.get("applies_to", "Files")
    _add_info_row(_info_container, "Applies To", applies_to)
    
    var stacks = mod_data.get("stacks", 0)
    if stacks > 0:
        _add_info_row(_info_container, "Stacks", "Up to %d times" % stacks)
    
    var incompatible = mod_data.get("incompatible_with", [])
    if not incompatible.is_empty():
        var incompat_names = []
        for inc_id in incompatible:
            var inc_data = MODIFIER_DATA.get(inc_id, {})
            incompat_names.append(inc_data.get("name", inc_id.capitalize()))
        _add_info_row(_info_container, "Incompatible With", ", ".join(incompat_names))


func _add_effect_row(container: Control, effect: Dictionary) -> void:
    var hbox = HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 8)
    container.add_child(hbox)
    
    # Icon
    var icon_name = effect.get("icon", "")
    if icon_name != "":
        var icon_path = "res://textures/icons/" + icon_name + ".png"
        if ResourceLoader.exists(icon_path):
            var icon_rect = TextureRect.new()
            icon_rect.texture = load(icon_path)
            icon_rect.custom_minimum_size = Vector2(24, 24)
            icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            hbox.add_child(icon_rect)
    
    # Stat name and multiplier
    var label = Label.new()
    var stat_name = effect.get("stat", "Unknown")
    var multiplier = effect.get("multiplier", 1.0)
    var note = effect.get("note", "")
    
    var mult_text = ""
    var color = COLOR_NEUTRAL
    
    if note != "":
        mult_text = note
        color = Color(0.7, 0.85, 1.0)
    elif multiplier == 0.0:
        mult_text = "×0 (Disabled)"
        color = COLOR_NEGATIVE
    elif multiplier < 1.0:
        mult_text = "×%.2f (%.0f%% reduction)" % [multiplier, (1.0 - multiplier) * 100]
        color = COLOR_NEGATIVE
    elif multiplier > 1.0:
        mult_text = "×%.2f (%.0f%% increase)" % [multiplier, (multiplier - 1.0) * 100]
        color = COLOR_POSITIVE
    else:
        mult_text = "×1.0 (No change)"
        color = COLOR_NEUTRAL
    
    label.text = "%s: %s" % [stat_name, mult_text]
    label.add_theme_font_size_override("font_size", 18)
    label.add_theme_color_override("font_color", color)
    hbox.add_child(label)


func _add_info_row(container: Control, label_text: String, value_text: String) -> void:
    var hbox = HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 8)
    container.add_child(hbox)
    
    var label = Label.new()
    label.text = label_text + ":"
    label.add_theme_font_size_override("font_size", 16)
    label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
    label.custom_minimum_size.x = 150
    hbox.add_child(label)
    
    var value = Label.new()
    value.text = value_text
    value.add_theme_font_size_override("font_size", 16)
    value.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
    hbox.add_child(value)


func _clear_container(container: Control) -> void:
    for child in container.get_children():
        child.queue_free()
