extends "res://scripts/tokens_tab.gd"

const ConfigManager = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/config_manager.gd")
const HIDE_PURCHASED_CONFIG_KEY = "hide_purchased_tokens"

var _filter_container: HBoxContainer
var _hide_toggle: CheckButton
var _counter_label: Label
var _empty_label: Label
var _config_manager
var _is_hiding_purchased: bool = true

func _ready() -> void:
    super._ready()
    _config_manager = ConfigManager.new()
    _is_hiding_purchased = _config_manager.get_value(HIDE_PURCHASED_CONFIG_KEY, true)
    _setup_filter_ui()
    
    var tab_container = get_node_or_null("TabContainer")
    if tab_container:
        tab_container.tab_changed.connect(_on_tab_changed)

func _setup_filter_ui() -> void:
    if _filter_container: return
    
    _filter_container = HBoxContainer.new()
    _filter_container.name = "FilterContainer"
    
    var spacer = Control.new()
    spacer.custom_minimum_size = Vector2(10, 0)
    _filter_container.add_child(spacer)
    
    _hide_toggle = CheckButton.new()
    _hide_toggle.text = "Hide purchased"
    _hide_toggle.button_pressed = _is_hiding_purchased
    _hide_toggle.toggled.connect(_on_hide_toggle_toggled)
    _filter_container.add_child(_hide_toggle)
    
    _counter_label = Label.new()
    _counter_label.text = ""
    _counter_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
    _filter_container.add_child(_counter_label)
    
    add_child(_filter_container)
    move_child(_filter_container, 0)

func _on_tab_changed(_tab: int) -> void:
    call_deferred("_apply_visibility")

func _on_hide_toggle_toggled(pressed: bool) -> void:
    _is_hiding_purchased = pressed
    _config_manager.set_value(HIDE_PURCHASED_CONFIG_KEY, pressed)
    _apply_visibility()

func _on_menu_set(menu: int, tab: int) -> void:
    super._on_menu_set(menu, tab)
    if menu != Utils.menu_types.SIDE and tab != Utils.menus.TOKENS: return
    call_deferred("_apply_visibility")

func _apply_visibility() -> void:
    var hidden_count := 0
    var visible_count := 0
    var total_in_tab := 0
    
    # Get current active tab
    var tab_container = get_node_or_null("TabContainer")
    var current_tab = tab_container.current_tab if tab_container else 0
    
    # Get only the active container (not Services - tab index 3)
    var active_container: Control = null
    match current_tab:
        0: active_container = get_node_or_null("TabContainer/Nodes/MarginContainer/PerksContainer")
        1: active_container = get_node_or_null("TabContainer/Perks/MarginContainer/PerksContainer")
        2: active_container = get_node_or_null("TabContainer/Boosts/MarginContainer/BoostsContainer")
        3: active_container = get_node_or_null("TabContainer/Services/MarginContainer/ServicesContainer")
    
    # Hide toggle for Services tab (tab 3) since it's not needed
    if _hide_toggle:
        _hide_toggle.visible = (current_tab != 3)
    
    # Process all containers to apply visibility
    var all_containers = [
        get_node_or_null("TabContainer/Nodes/MarginContainer/PerksContainer"),
        get_node_or_null("TabContainer/Perks/MarginContainer/PerksContainer"),
        get_node_or_null("TabContainer/Boosts/MarginContainer/BoostsContainer"),
        get_node_or_null("TabContainer/Services/MarginContainer/ServicesContainer")
    ]
    
    for i in range(all_containers.size()):
        var container = all_containers[i]
        if not container:
            continue
        
        var is_active = (container == active_container)
        var is_services = (i == 3)
        
        for child in container.get_children():
            # Let vanilla logic run first
            if child.has_method("update_all"):
                child.update_all()
            
            # Skip hiding for Services tab
            if is_services:
                continue
            
            # Apply our additional filtering
            if _is_hiding_purchased and _is_item_maxed(child.name):
                child.set_block_signals(true)
                child.visible = false
                child.set_block_signals(false)
                if is_active:
                    hidden_count += 1
            elif is_active and child.visible:
                visible_count += 1
        
        if is_active:
            total_in_tab = hidden_count + visible_count
    
    # Update counter (only show when toggle is visible and items are hidden)
    if _counter_label:
        if current_tab == 3:
            _counter_label.text = ""
        elif hidden_count > 0:
            _counter_label.text = "Hidden: " + str(hidden_count)
        else:
            _counter_label.text = ""
    
    # Show "Everything purchased" message if all items hidden
    _update_empty_message(active_container, visible_count, current_tab)

func _update_empty_message(container: Control, visible_count: int, tab_index: int) -> void:
    # Remove old empty label if exists
    if _empty_label and is_instance_valid(_empty_label):
        _empty_label.queue_free()
        _empty_label = null
    
    # Don't show for Services tab
    if tab_index == 3:
        return
    
    # Show message only if hiding is ON and no visible items
    if _is_hiding_purchased and visible_count == 0 and container:
        _empty_label = Label.new()
        _empty_label.text = "Everything purchased!"
        _empty_label.add_theme_font_size_override("font_size", 24)
        _empty_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
        _empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        container.add_child(_empty_label)

func _is_item_maxed(item_name: String) -> bool:
    if not Globals.perks.has(item_name):
        return false
        
    var current_level = Globals.perks[item_name]
    var current_int = 0
    
    if typeof(current_level) == TYPE_INT:
        current_int = current_level
    elif typeof(current_level) == TYPE_FLOAT:
        current_int = int(current_level)
    else:
        return false # Should not happen
        
    # Check if we can find max level data
    var max_level = 1
    var has_data = false
    
    # Check Data.perks safely
    if "perks" in Data and Data.perks.has(item_name):
        var perk_data = Data.perks[item_name]
        if "limit" in perk_data:
            max_level = int(perk_data.limit)
            has_data = true
    
    # If we found Data, use it
    if has_data:
        if max_level <= 0: return false # Infinite or special?
        return current_int >= max_level
        
    # Fallback if no Data found: hide if level >= 1 (old behavior)
    # This sucks for multi-level perks but prevents crashes
    return current_int >= 1
