extends "res://scripts/upgrades_tab.gd"

const ConfigManager = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/config_manager.gd")
const HIDE_MAXED_CONFIG_KEY = "hide_maxed_upgrades"

var _filter_container: HBoxContainer
var _hide_toggle: CheckButton
var _counter_label: Label
var _empty_label: Label
var _config_manager
var _is_hiding_maxed: bool = true

func _ready() -> void:
	super._ready()
	_config_manager = ConfigManager.new()
	_is_hiding_maxed = _config_manager.get_value(HIDE_MAXED_CONFIG_KEY, true)
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
	_hide_toggle.text = "Hide maxed"
	_hide_toggle.button_pressed = _is_hiding_maxed
	_hide_toggle.toggled.connect(_on_hide_toggle_toggled)
	_filter_container.add_child(_hide_toggle)
	
	_counter_label = Label.new()
	_counter_label.text = ""
	_counter_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_filter_container.add_child(_counter_label)
	
	add_child(_filter_container)
	move_child(_filter_container, 0)

# OVERRIDDEN: Fixed crash caused by iterating children as Button when HBoxContainer exists
func set_tab(tab: int) -> void:
	$TabContainer.current_tab = tab
	for i in $ButtonsPanel/ButtonsContainer.get_children():
		if i is Button:
			i.button_pressed = tab == i.get_index()

func _on_tab_changed(_tab: int) -> void:
	call_deferred("_apply_visibility")

func _on_hide_toggle_toggled(pressed: bool) -> void:
	_is_hiding_maxed = pressed
	_config_manager.set_value(HIDE_MAXED_CONFIG_KEY, pressed)
	_apply_visibility()

func _on_menu_set(menu: int, tab: int) -> void:
	super._on_menu_set(menu, tab)
	if menu != Utils.menu_types.SIDE and tab != Utils.menus.UPGRADES: return
	call_deferred("_apply_visibility")

func _apply_visibility() -> void:
	var hidden_count := 0
	var visible_count := 0
	
	# Get current active tab index
	var tab_container = get_node_or_null("TabContainer")
	var current_tab = tab_container.current_tab if tab_container else 0
	
	# Container and scroll mappings by tab index
	var container_paths = [
		"TabContainer/Main/MarginContainer/Container",
		"TabContainer/Hacking/ScrollContainer/MarginContainer/Container",
		"TabContainer/Breach/MarginContainer/Container",
		"TabContainer/Optimizations/ScrollContainer/MarginContainer/UpgradesContainer",
		"TabContainer/Applications/ScrollContainer/MarginContainer/UpgradesContainer"
	]
	
	var scroll_paths = [
		"", # Main has no scroll
		"TabContainer/Hacking/ScrollContainer",
		"", # Breach has no scroll
		"TabContainer/Optimizations/ScrollContainer",
		"TabContainer/Applications/ScrollContainer"
	]
	
	# Process ONLY the active container
	var active_container_path = container_paths[current_tab] if current_tab < container_paths.size() else ""
	var active_scroll_path = scroll_paths[current_tab] if current_tab < scroll_paths.size() else ""
	
	var active_container = get_node_or_null(active_container_path) if active_container_path else null
	var active_scroll = get_node_or_null(active_scroll_path) if active_scroll_path else null
	
	if active_container:
		for child in active_container.get_children():
			# Skip our empty label
			if child == _empty_label:
				continue
			
			# Let vanilla logic run first - this restores proper state
			if child.has_method("update_all"):
				child.update_all()
			
			# Apply our additional filtering
			if _is_hiding_maxed and _is_upgrade_maxed(child.name):
				child.set_block_signals(true)
				child.visible = false
				child.set_block_signals(false)
				hidden_count += 1
			elif child.visible:
				visible_count += 1
		
		# Reset scroll position to top
		if active_scroll:
			active_scroll.scroll_vertical = 0
	
	# Update counter
	if _counter_label:
		if hidden_count > 0:
			_counter_label.text = "Hidden: " + str(hidden_count)
		else:
			_counter_label.text = ""
	
	# Show "Everything maxed" message if all items hidden
	_update_empty_message(active_container, visible_count)

func _update_empty_message(container: Control, visible_count: int) -> void:
	# Remove old empty label if exists
	if _empty_label and is_instance_valid(_empty_label):
		_empty_label.queue_free()
		_empty_label = null
	
	# Show message only if hiding is ON and no visible items
	if _is_hiding_maxed and visible_count == 0 and container:
		_empty_label = Label.new()
		_empty_label.text = "Everything maxed!"
		_empty_label.add_theme_font_size_override("font_size", 24)
		_empty_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(_empty_label)

func _is_upgrade_maxed(upgrade_name: String) -> bool:
	if not Data.upgrades.has(upgrade_name):
		return false
	
	var upgrade_data = Data.upgrades[upgrade_name]
	var max_level := 1
	
	if "limit" in upgrade_data:
		max_level = int(upgrade_data.limit)
	
	if max_level <= 0:
		return false
	
	var current_level = Globals.upgrades.get(upgrade_name, 0)
	if typeof(current_level) == TYPE_INT:
		return current_level >= max_level
	if typeof(current_level) == TYPE_FLOAT:
		return int(current_level) >= max_level
	return false
