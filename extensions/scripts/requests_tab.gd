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
		# Update the child state
		if child.has_method("set_hide_completed"):
			# This updates the internal config AND triggers an update_all()
			child.set_hide_completed(_is_hiding_completed)
		elif child.has_method("update_all"):
			# Vanilla fallback or incomplete extension
			child.update_all()
			
		# Explicitly verify and enforce visibility
		# This acts as a safeguard even if the child's internal logic missed it
		if _is_hiding_completed and child.visible:
			var should_hide = false
			if child.has_method("is_claimed"):
				should_hide = child.is_claimed()
			else:
				# Fallback using global state directly
				should_hide = Globals.requests.get(child.name, 0) == 2
				
			if should_hide:
				child.visible = false
		
		# Count hidden items (claimed ones that we hid)
		# We check if it IS claimed, because hidden_count should count "Hidden Completed Requests", not locked ones.
		# But sticking to previous logic: count items that are NOT visible AND are claimed.
		if !child.visible:
			var claimed = false
			if child.has_method("is_claimed"):
				claimed = child.is_claimed()
			else:
				claimed = Globals.requests.get(child.name, 0) == 2
			
			if claimed:
				hidden_count += 1
			
	_counter_label.text = "Hidden: " + str(hidden_count)
	_sort_requests(container)

func _sort_requests(container: Control) -> void:
	# Custom sort: Completed (Unclaimed) > Active > Locked/Hidden (Claimed)
	var children = container.get_children()
	
	children.sort_custom(func(a, b):
		var priority_a = _get_request_priority(a)
		var priority_b = _get_request_priority(b)
		
		if priority_a != priority_b:
			return priority_a > priority_b
			
		# Secondary sort: Fallback to original order (or by name)
		# Since we don't have a reliable index, we can just keep stable or sort by name
		return a.name < b.name
	)
	
	# Apply order
	for i in range(children.size()):
		container.move_child(children[i], i)

func _get_request_priority(node: Node) -> int:
	# Priority 2: Completed but Unclaimed
	if _is_completed_unclaimed(node):
		return 2
		
	# Check for claimed status
	var is_claimed = false
	if node.has_method("is_claimed"):
		is_claimed = node.is_claimed()
	else:
		is_claimed = Globals.requests.get(node.name, 0) == 2
		
	# Priority 0: Claimed (Paid)
	if is_claimed:
		return 0
		
	# Priority 1: Active (Not completed, not claimed)
	return 1

func _is_completed_unclaimed(node: Node) -> bool:
	# 1. Check if claimed (if so, it is NOT "completed but unclaimed")
	if node.has_method("is_claimed") and node.is_claimed():
		return false
	if Globals.requests.get(node.name, 0) == 2:
		return false
		
	# 2. Check for "Completed" status via recursive search
	return _scan_for_completion(node)

func _scan_for_completion(node: Node) -> bool:
	for child in node.get_children():
		# Heuristic A: Label with "Completed"
		if child is Label and "Completed" in child.text:
			return true
			
		# Heuristic B: Active Button (Claim Button)
		# We assume the only active button in a request panel is the Claim button
		# (There might be others, but usually Claim is the main one)
		if child is Button and child.visible and !child.disabled:
			# Extra check: valid claim buttons usually have text like "Claim" or an icon
			# But "Completed" label is the strongest signal if present.
			# Let's trust the button state if we don't find the label yet.
			return true
		
		# Recurse
		if child.get_child_count() > 0:
			if _scan_for_completion(child):
				return true
				
	return false
