extends "res://scripts/achievements_tab.gd"

const ConfigManager = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/config_manager.gd")
const HIDE_CLAIMED_CONFIG_KEY = "hide_claimed_achievements"

var _filter_container: HBoxContainer
var _hide_toggle: CheckButton
var _counter_label: Label
var _config_manager
var _is_hiding_claimed: bool = true

func _ready() -> void:
	super._ready()
	_config_manager = ConfigManager.new()
	_is_hiding_claimed = _config_manager.get_value(HIDE_CLAIMED_CONFIG_KEY, true)
	_setup_filter_ui()

func _setup_filter_ui() -> void:
	if _filter_container: return
	
	_filter_container = HBoxContainer.new()
	_filter_container.name = "FilterContainer"
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(10, 0)
	_filter_container.add_child(spacer)
	
	_hide_toggle = CheckButton.new()
	_hide_toggle.text = "Hide claimed"
	_hide_toggle.button_pressed = _is_hiding_claimed
	_hide_toggle.toggled.connect(_on_hide_toggle_toggled)
	_filter_container.add_child(_hide_toggle)
	
	_counter_label = Label.new()
	_counter_label.text = "Hidden: 0"
	_counter_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_filter_container.add_child(_counter_label)
	
	add_child(_filter_container)
	move_child(_filter_container, 0)

func _on_hide_toggle_toggled(pressed: bool) -> void:
	_is_hiding_claimed = pressed
	_config_manager.set_value(HIDE_CLAIMED_CONFIG_KEY, pressed)
	_apply_visibility()

func _on_menu_set(menu: int, tab: int) -> void:
	super._on_menu_set(menu, tab)
	if menu != Utils.menu_types.SIDE and tab != Utils.menus.ACHIEVEMENTS: return
	call_deferred("_apply_visibility")

func _apply_visibility() -> void:
	var container = get_node_or_null("ScrollContainer/MarginContainer/AchievementsContainer")
	if not container:
		return
	
	var hidden_count := 0
	
	# Categorize children by status
	var claimable: Array = [] # Unlocked but not claimed (status == 1) - TOP
	var locked: Array = [] # Not unlocked (status == 0) - MIDDLE
	var claimed: Array = [] # Already claimed (status == 2) - BOTTOM
	
	for child in container.get_children():
		var status = Globals.achievements.get(child.name, 0)
		if status == 1:
			claimable.append(child)
		elif status == 2:
			claimed.append(child)
		else:
			locked.append(child)
	
	# Reorder children: claimable first, then locked, then claimed
	var sort_index := 0
	for child in claimable:
		container.move_child(child, sort_index)
		sort_index += 1
	for child in locked:
		container.move_child(child, sort_index)
		sort_index += 1
	for child in claimed:
		container.move_child(child, sort_index)
		sort_index += 1
	
	# Apply visibility
	for child in container.get_children():
		# Let vanilla logic update UI state
		if child.has_method("update_all"):
			child.update_all()
		
		var status = Globals.achievements.get(child.name, 0)
		
		# Claimable achievements are ALWAYS visible (ignore hide toggle)
		if status == 1:
			child.set_block_signals(true)
			child.visible = true
			child.set_block_signals(false)
		# Claimed achievements follow the hide toggle
		elif status == 2:
			child.set_block_signals(true)
			if _is_hiding_claimed:
				child.visible = false
				hidden_count += 1
			else:
				child.visible = true
			child.set_block_signals(false)
		# Locked achievements are always visible
		else:
			child.set_block_signals(true)
			child.visible = true
			child.set_block_signals(false)
	
	if _counter_label:
		_counter_label.text = "Hidden: " + str(hidden_count)
