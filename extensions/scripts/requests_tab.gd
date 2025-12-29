extends "res://scripts/requests_tab.gd"

const ConfigManager = preload("res://mods-unpacked/TajemnikTV-TajsModded/extensions/scripts/utilities/config_manager.gd")
const HIDE_COMPLETED_CONFIG_KEY = "hide_claimed_requests"

var _filter_container: HBoxContainer
var _hide_toggle: CheckButton
var _counter_label: Label
var _config_manager
var _is_hiding_completed: bool = true

func _ready() -> void:
	# Super _ready connects Signals.menu_set to the vanilla _on_menu_set
	# However, since we override _on_menu_set, that signal will call OUR implementation.
	super._ready()
	
	# Init config
	_config_manager = ConfigManager.new()
	_is_hiding_completed = _config_manager.get_value(HIDE_COMPLETED_CONFIG_KEY, true)
	
	# Setup UI
	_setup_filter_ui()
	
	# Connect signals for updates
	Signals.request_claimed.connect(_on_request_claimed_mod)
	# We don't need to connect Signals.menu_set manually because super did it, 
	# and it calls the method on 'self', which is this script.

func _setup_filter_ui() -> void:
	if _filter_container: return
	
	_filter_container = HBoxContainer.new()
	_filter_container.name = "FilterContainer"
	
	# Add simple spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(10, 0)
	_filter_container.add_child(spacer)
	
	# Toggle
	_hide_toggle = CheckButton.new()
	_hide_toggle.text = "Hide completed (paid)"
	_hide_toggle.button_pressed = _is_hiding_completed
	_hide_toggle.toggled.connect(_on_hide_toggle_toggled)
	_filter_container.add_child(_hide_toggle)
	
	# Counter
	_counter_label = Label.new()
	_counter_label.text = "Hidden: 0"
	_counter_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_filter_container.add_child(_counter_label)
	
	# Add to beginning of VBox
	add_child(_filter_container)
	move_child(_filter_container, 0)

# OVERRIDDEN FROM VANILLA
func _on_menu_set(menu: int, tab: int) -> void:
	if menu != Utils.menu_types.SIDE and tab != Utils.menus.REQUESTS: return

	if initialized:
		# Even if initialized, check updates
		_update_request_visibility()
		return

	# Replaced implementation using 'load' instead of 'preload' 
	# and applying settings immediately.
	# This ensures we pick up any script extensions or overrides dynamicallly.
	var panel_scene = load("res://scenes/request_panel.tscn")
	
	for i: String in Data.requests:
		var instance: Panel = panel_scene.instantiate()
		instance.name = i
		$Requests/MarginContainer/RequestsContainer.add_child(instance)
		
		# Apply setting immediately if supported
		if instance.has_method("set_hide_completed"):
			instance.set_hide_completed(_is_hiding_completed)

	initialized = true
	_update_request_visibility()

func _on_hide_toggle_toggled(pressed: bool) -> void:
	_is_hiding_completed = pressed
	_config_manager.set_value(HIDE_COMPLETED_CONFIG_KEY, pressed)
	_update_request_visibility()

func _on_request_claimed_mod(_request_name: String) -> void:
	_update_request_visibility()

func _update_request_visibility() -> void:
	# Ensure children are present
	var container = get_node_or_null("Requests/MarginContainer/RequestsContainer")
	if !container: return
	
	var hidden_count = 0
	
	for child in container.get_children():
		# Reset state first by calling update_all()
		# This ensures 'visible' is set to 'unlocked' (true) by default before we apply extra filtering
		if child.has_method("update_all"):
			child.update_all()
			
		if child.has_method("set_hide_completed"):
			# Pass the setting to the child (which triggers another update_all effectively, but safe)
			child.set_hide_completed(_is_hiding_completed)
			
			# Check result
			if !child.visible and child.has_method("is_claimed") and child.is_claimed():
				hidden_count += 1
		else:
			# Fallback for vanilla nodes if extension fails
			# Since we called update_all() above, visible should be true if unlocked.
			if _is_hiding_completed:
				var completed = Globals.requests.get(child.name, 0) == 2
				if completed and child.visible:
					child.visible = false
					hidden_count += 1
			
	_counter_label.text = "Hidden: " + str(hidden_count)
