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
	
	for child in container.get_children():
		# First, let vanilla logic determine base visibility
		if child.has_method("update_all"):
			child.update_all()
		
		# Now apply our additional filtering on top
		if _is_hiding_claimed:
			var is_claimed = Globals.achievements.get(child.name, 0) >= 1
			if is_claimed:
				# Use set_block_signals to prevent feedback loop
				child.set_block_signals(true)
				child.visible = false
				child.set_block_signals(false)
				hidden_count += 1
	
	if _counter_label:
		_counter_label.text = "Hidden: " + str(hidden_count)
